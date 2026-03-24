"""
IngestionService
----------------
Full pipeline: file bytes → text extraction → LangChain chunking → vectorstore

Uses LangChain's RecursiveCharacterTextSplitter
instead of a hand-rolled chunker.

Supported formats:
  .txt / .md   — direct decode
  .pdf         — PyMuPDF for text PDFs; Tesseract OCR fallback for scanned pages
  .png/.jpg/etc — Tesseract OCR
"""

from __future__ import annotations

import os
import uuid
from io import BytesIO
from typing import Dict, List, Optional, Tuple

from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter

from app.core.config import CHUNK_OVERLAP, CHUNK_SIZE, RAG_DATA_DIR
from app.services.vectorstore import VectorStoreManager

# ── Optional system-level deps (graceful degradation) ────────────────────────
try:
    import fitz  # PyMuPDF
    HAS_PYMUPDF = True
except ImportError:
    HAS_PYMUPDF = False
    print("[Ingestion] WARNING: PyMuPDF not installed (pip install pymupdf)")

try:
    import pytesseract
    from PIL import Image
    HAS_TESSERACT = True
except ImportError:
    HAS_TESSERACT = False
    print("[Ingestion] WARNING: pytesseract/Pillow not installed — OCR disabled")

try:
    from pdf2image import convert_from_bytes
    HAS_PDF2IMAGE = True
except ImportError:
    HAS_PDF2IMAGE = False
    print("[Ingestion] WARNING: pdf2image not installed — scanned-PDF OCR disabled")


# ── Text extraction helpers ───────────────────────────────────────────────────

def _decode(content: bytes) -> str:
    try:
        return content.decode("utf-8")
    except UnicodeDecodeError:
        return content.decode("latin-1", errors="ignore")


def _extract_pdf(content: bytes) -> Tuple[str, Dict[int, int]]:
    """
    Extract text from a PDF.
    Returns (full_text, page_char_map) where page_char_map maps
    cumulative char offset → page number (used to tag chunks).
    Falls back to Tesseract for pages with no extractable text.
    """
    if not HAS_PYMUPDF:
        raise RuntimeError("pymupdf required for PDF parsing: pip install pymupdf")

    doc = fitz.open(stream=content, filetype="pdf")
    parts: List[str] = []
    page_char_map: Dict[int, int] = {}

    for page_num, page in enumerate(doc, start=1):
        text = page.get_text()

        if not text.strip() and HAS_TESSERACT and HAS_PDF2IMAGE:
            try:
                images = convert_from_bytes(content, first_page=page_num, last_page=page_num, dpi=200)
                if images:
                    text = pytesseract.image_to_string(images[0])
            except Exception as exc:
                print(f"[Ingestion] OCR failed on page {page_num}: {exc}")

        page_char_map[sum(len(p) for p in parts)] = page_num
        parts.append(text)

    doc.close()
    return "\n".join(parts), page_char_map


def _extract_image(content: bytes) -> str:
    if not HAS_TESSERACT:
        raise RuntimeError("pytesseract + Pillow required for image OCR")
    img = Image.open(BytesIO(content))
    return pytesseract.image_to_string(img)


def extract_text(filename: str, content: bytes) -> Tuple[str, Dict[int, int]]:
    """Dispatch to the right extractor. Returns (text, page_char_map)."""
    lower = filename.lower()

    if lower.endswith((".txt", ".md")):
        return _decode(content), {}

    if lower.endswith(".pdf"):
        return _extract_pdf(content)

    if lower.endswith((".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp")):
        return _extract_image(content), {}

    return _decode(content), {}


def _page_for_offset(offset: int, page_char_map: Dict[int, int]) -> Optional[int]:
    if not page_char_map:
        return None
    page = 1
    for char_start, pg in sorted(page_char_map.items()):
        if offset >= char_start:
            page = pg
        else:
            break
    return page


# ── File persistence ──────────────────────────────────────────────────────────

def save_upload(collection_id: str, document_id: str, filename: str, content: bytes) -> str:
    dest_dir = os.path.join(RAG_DATA_DIR, collection_id)
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, f"{document_id}_{filename}")
    with open(dest_path, "wb") as f:
        f.write(content)
    return dest_path


# ── Main ingestion service ────────────────────────────────────────────────────

class IngestionService:
    """
    Uses LangChain's RecursiveCharacterTextSplitter to chunk text,
    then stores LangChain Document objects in Chroma via VectorStoreManager.
    """

    def __init__(self) -> None:
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=CHUNK_SIZE,
            chunk_overlap=CHUNK_OVERLAP,
            separators=["\n\n", "\n", ". ", " ", ""],
        )
        self.vs = VectorStoreManager.get()

    def ingest_file(
        self,
        collection_id: str,
        document_id: str,
        filename: str,
        content: bytes,
    ) -> int:
        """
        Full pipeline for one file.
        Returns number of chunks stored.
        """
        # 1. Extract text + page map
        text, page_char_map = extract_text(filename, content)
        if not text.strip():
            raise ValueError(f"No text could be extracted from '{filename}'.")

        # 2. Split with LangChain's splitter
        raw_chunks = self.splitter.split_text(text)

        # 3. Wrap in LangChain Document objects with rich metadata
        file_ext = os.path.splitext(filename)[1].lstrip(".").lower() or "unknown"
        documents: List[Document] = []

        char_cursor = 0
        for i, chunk_text in enumerate(raw_chunks):
            page = _page_for_offset(char_cursor, page_char_map)
            documents.append(Document(
                page_content=chunk_text,
                metadata={
                    "document_id": document_id,
                    "filename": filename,
                    "chunk_index": i,
                    "total_chunks": len(raw_chunks),
                    "file_type": file_ext,
                    "page_number": page or -1,
                    "collection_id": collection_id,
                    "source": filename,
                },
            ))
            char_cursor += len(chunk_text)

        # 4. Store in Chroma via VectorStoreManager
        stored = self.vs.add_documents(collection_id, documents)
        print(f"[Ingestion] '{filename}' → {stored} chunks in collection {collection_id}")
        return stored

    def reindex_document(
        self,
        collection_id: str,
        document_id: str,
        filename: str,
        file_path: str,
    ) -> int:
        """Re-embed a document already on disk (used by /reindex endpoint)."""
        deleted = self.vs.delete_document(collection_id, document_id)
        print(f"[Reindex] Removed {deleted} old chunks for doc {document_id}")

        with open(file_path, "rb") as f:
            content = f.read()

        return self.ingest_file(collection_id, document_id, filename, content)



# """
# IngestionService
# ----------------
# Handles the full pipeline:
#   file bytes → text extraction → chunking → embedding → ChromaDB

# Supported formats:
#   • .txt / .md   — direct decode
#   • .pdf         — PyMuPDF for text-PDFs; Tesseract OCR for scanned pages
#   • .png/.jpg/.jpeg/.tiff/.bmp — Tesseract OCR
# """

# from __future__ import annotations

# import os
# import re
# import uuid
# from io import BytesIO
# from typing import Any, Dict, List, Optional, Tuple

# from app.core.config import CHUNK_OVERLAP, CHUNK_SIZE, RAG_DATA_DIR
# from app.services.vector_store import VectorStoreManager

# # ── Optional imports (graceful degradation) ───────────────────────────────────
# try:
#     import fitz  # PyMuPDF
#     HAS_PYMUPDF = True
# except ImportError:
#     HAS_PYMUPDF = False
#     print("[Ingestion] WARNING: PyMuPDF not installed. PDF support limited.")

# try:
#     import pytesseract
#     from PIL import Image
#     HAS_TESSERACT = True
# except ImportError:
#     HAS_TESSERACT = False
#     print("[Ingestion] WARNING: pytesseract/Pillow not installed. OCR disabled.")

# try:
#     from pdf2image import convert_from_bytes
#     HAS_PDF2IMAGE = True
# except ImportError:
#     HAS_PDF2IMAGE = False
#     print("[Ingestion] WARNING: pdf2image not installed. Scanned-PDF OCR disabled.")


# # ── Text extraction ───────────────────────────────────────────────────────────

# def _extract_txt_md(content: bytes) -> str:
#     try:
#         return content.decode("utf-8")
#     except UnicodeDecodeError:
#         return content.decode("latin-1", errors="ignore")


# def _extract_pdf(content: bytes) -> Tuple[str, Dict[int, int]]:
#     """
#     Returns (full_text, page_char_map).
#     page_char_map: {char_offset: page_number} – used to tag chunks with page numbers.
#     Falls back to Tesseract OCR for pages that yield no text.
#     """
#     if not HAS_PYMUPDF:
#         raise RuntimeError("PyMuPDF (fitz) is required for PDF parsing. pip install pymupdf")

#     doc = fitz.open(stream=content, filetype="pdf")
#     parts: List[str] = []
#     page_char_map: Dict[int, int] = {}  # cumulative_char_start → page_number

#     for page_num, page in enumerate(doc, start=1):
#         text = page.get_text()

#         # Fall back to OCR if the page has no extractable text (scanned PDF)
#         if not text.strip() and HAS_TESSERACT and HAS_PDF2IMAGE:
#             try:
#                 images = convert_from_bytes(content, first_page=page_num, last_page=page_num, dpi=200)
#                 if images:
#                     text = pytesseract.image_to_string(images[0])
#             except Exception as exc:
#                 print(f"[Ingestion] OCR failed on page {page_num}: {exc}")

#         page_char_map[sum(len(p) for p in parts)] = page_num
#         parts.append(text)

#     doc.close()
#     return "\n".join(parts), page_char_map


# def _extract_image(content: bytes) -> str:
#     """OCR an image file directly."""
#     if not HAS_TESSERACT:
#         raise RuntimeError("pytesseract + Pillow required for image OCR.")
#     img = Image.open(BytesIO(content))
#     return pytesseract.image_to_string(img)


# def extract_text(filename: str, content: bytes) -> Tuple[str, Dict[int, int]]:
#     """
#     Dispatch to the right extractor.
#     Returns (text, page_char_map).
#     page_char_map is empty for non-PDF formats.
#     """
#     lower = filename.lower()

#     if lower.endswith((".txt", ".md")):
#         return _extract_txt_md(content), {}

#     if lower.endswith(".pdf"):
#         return _extract_pdf(content)

#     if lower.endswith((".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp")):
#         return _extract_image(content), {}

#     # Generic fallback
#     try:
#         return content.decode("utf-8"), {}
#     except Exception:
#         return content.decode("latin-1", errors="ignore"), {}


# # ── Chunking ──────────────────────────────────────────────────────────────────

# def _get_page_number(char_offset: int, page_char_map: Dict[int, int]) -> Optional[int]:
#     """Return the page number for a given character offset."""
#     if not page_char_map:
#         return None
#     page = 1
#     for offset, pg in sorted(page_char_map.items()):
#         if char_offset >= offset:
#             page = pg
#         else:
#             break
#     return page


# def semantic_chunk(
#     text: str,
#     chunk_size: int = CHUNK_SIZE,
#     overlap: int = CHUNK_OVERLAP,
#     page_char_map: Optional[Dict[int, int]] = None,
# ) -> List[Dict[str, Any]]:
#     """
#     Split text into overlapping sentence-aware chunks.
#     Returns list of dicts: {text, char_start, page_number}.
#     """
#     # Normalise whitespace
#     text = re.sub(r"\n{3,}", "\n\n", text).strip()

#     # Split into sentences
#     sentences = re.split(r"(?<=[.!?])\s+", text)

#     chunks: List[Dict[str, Any]] = []
#     current_words: List[str] = []
#     current_len = 0
#     char_cursor = 0

#     def flush(words: List[str], offset: int) -> None:
#         joined = " ".join(words).strip()
#         if joined:
#             page = _get_page_number(offset, page_char_map or {})
#             chunks.append({"text": joined, "char_start": offset, "page_number": page})

#     for sentence in sentences:
#         s_len = len(sentence)

#         if current_len + s_len + 1 <= chunk_size:
#             current_words.append(sentence)
#             current_len += s_len + 1
#         else:
#             flush(current_words, char_cursor)

#             # Overlap: carry last N characters worth of sentences into next chunk
#             overlap_words: List[str] = []
#             overlap_len = 0
#             for w in reversed(current_words):
#                 if overlap_len + len(w) <= overlap:
#                     overlap_words.insert(0, w)
#                     overlap_len += len(w)
#                 else:
#                     break

#             char_cursor += current_len - overlap_len
#             current_words = overlap_words + [sentence]
#             current_len = sum(len(w) for w in current_words) + len(current_words)

#     flush(current_words, char_cursor)
#     return chunks


# # ── File persistence ──────────────────────────────────────────────────────────

# def save_upload(collection_id: str, document_id: str, filename: str, content: bytes) -> str:
#     """Save raw file bytes to disk and return the absolute path."""
#     dest_dir = os.path.join(RAG_DATA_DIR, collection_id)
#     os.makedirs(dest_dir, exist_ok=True)
#     # Prefix with document_id to avoid name collisions
#     safe_name = f"{document_id}_{filename}"
#     dest_path = os.path.join(dest_dir, safe_name)
#     with open(dest_path, "wb") as f:
#         f.write(content)
#     return dest_path


# # ── Main ingest entry-point ───────────────────────────────────────────────────

# class IngestionService:
#     def __init__(self) -> None:
#         self.vs = VectorStoreManager.get()

#     def ingest_file(
#         self,
#         collection_id: str,
#         document_id: str,
#         filename: str,
#         content: bytes,
#     ) -> int:
#         """
#         Full pipeline for one file.
#         Returns number of chunks stored.
#         """
#         # 1. Extract text
#         text, page_char_map = extract_text(filename, content)
#         if not text.strip():
#             raise ValueError(f"Could not extract any text from '{filename}'.")

#         # 2. Chunk
#         raw_chunks = semantic_chunk(text, page_char_map=page_char_map)

#         # 3. Build chunk dicts for vector store
#         file_ext = os.path.splitext(filename)[1].lstrip(".").lower() or "unknown"
#         vs_chunks = [
#             {
#                 "text": c["text"],
#                 "document_id": document_id,
#                 "filename": filename,
#                 "chunk_index": i,
#                 "total_chunks": len(raw_chunks),
#                 "file_type": file_ext,
#                 "page_number": c.get("page_number"),
#             }
#             for i, c in enumerate(raw_chunks)
#         ]

#         # 4. Embed + store
#         stored = self.vs.add_chunks(collection_id, vs_chunks)
#         print(f"[Ingestion] '{filename}' → {stored} chunks stored in collection {collection_id}")
#         return stored

#     def reindex_document(
#         self,
#         collection_id: str,
#         document_id: str,
#         filename: str,
#         file_path: str,
#     ) -> int:
#         """Re-embed a document that's already on disk."""
#         # Remove old chunks first
#         deleted = self.vs.delete_document(collection_id, document_id)
#         print(f"[Reindex] Removed {deleted} old chunks for doc {document_id}")

#         with open(file_path, "rb") as f:
#             content = f.read()

#         return self.ingest_file(collection_id, document_id, filename, content)