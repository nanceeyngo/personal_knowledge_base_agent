"""
/collections/{collection_id}/documents  endpoints
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.db.database import Collection as CollectionModel
from app.db.database import Document as DocumentModel
from app.db.database import get_db
from app.models.schemas import DocumentOut, ReindexOut
from app.services.ingestion import IngestionService, save_upload

router = APIRouter(tags=["Documents"])

ALLOWED_EXTENSIONS = {".pdf", ".txt", ".md", ".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp"}
MAX_FILE_SIZE_MB = 50


def _get_collection_or_404(collection_id: str, db: Session) -> CollectionModel:
    col = db.get(CollectionModel, collection_id)
    if not col:
        raise HTTPException(404, "Collection not found")
    return col


async def _process_upload(
    col: CollectionModel,
    upload: UploadFile,
    db: Session,
) -> DocumentOut:
    """Process a single uploaded file and return the created DocumentOut."""
    ext = os.path.splitext(upload.filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            400,
            f"Unsupported file type '{ext}'. Allowed: {sorted(ALLOWED_EXTENSIONS)}",
        )

    content = await upload.read()
    if not content:
        raise HTTPException(400, f"File '{upload.filename}' is empty.")

    size_mb = len(content) / (1024 * 1024)
    if size_mb > MAX_FILE_SIZE_MB:
        raise HTTPException(413, f"'{upload.filename}' exceeds {MAX_FILE_SIZE_MB} MB.")

    doc_id = str(uuid.uuid4())
    file_path = save_upload(col.id, doc_id, upload.filename, content)

    ingestor = IngestionService()
    try:
        chunk_count = ingestor.ingest_file(col.id, doc_id, upload.filename, content)
    except Exception as exc:
        if os.path.exists(file_path):
            os.remove(file_path)
        raise HTTPException(422, f"Failed to process '{upload.filename}': {exc}")

    doc = DocumentModel(
        id=doc_id,
        collection_id=col.id,
        filename=f"{doc_id}_{upload.filename}",
        original_filename=upload.filename,
        file_type=ext.lstrip("."),
        file_size=len(content),
        file_path=file_path,
        chunk_count=chunk_count,
        is_indexed=True,
    )
    db.add(doc)
    col.document_count += 1
    col.chunk_count += chunk_count
    col.is_indexed = True
    col.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(doc)
    return doc


# ── Single-file upload (works perfectly in Swagger UI) ───────────────────────
@router.post(
    "/collections/{collection_id}/documents",
    response_model=List[DocumentOut],
    status_code=201,
    summary="Upload documents",
    description=(
        "Upload one file at a time via Swagger UI. "
        "To upload multiple files at once use curl or Postman — "
        "send multiple `file` fields in the same multipart request."
    ),
)
async def upload_documents(
    collection_id: str,
    file: UploadFile = File(..., description="File to ingest (PDF, TXT, MD, PNG, JPG…)"),
    db: Session = Depends(get_db),
):
    """
    Ingest a document into the collection.

    **Swagger UI**: upload one file at a time using the file picker below.

    **curl (multiple files at once)**:
    ```
    curl -X POST "http://localhost:8000/collections/{id}/documents" \\
      -F "file=@paper.pdf" \\
      -F "file=@notes.md"
    ```
    """
    col = _get_collection_or_404(collection_id, db)
    doc = await _process_upload(col, file, db)
    return [doc]


# ── Multi-file upload endpoint (curl / Postman / Flutter) ────────────────────
@router.post(
    "/collections/{collection_id}/documents/batch",
    response_model=List[DocumentOut],
    status_code=201,
    summary="Upload multiple documents (batch)",
    description="Upload multiple files in a single request. Use curl or Postman — Swagger UI does not support multi-file upload reliably.",
)
async def upload_documents_batch(
    collection_id: str,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
):
    """
    Batch ingest multiple documents.

    **curl example**:
    ```
    curl -X POST "http://localhost:8000/collections/{id}/documents/batch" \\
      -F "files=@paper.pdf" \\
      -F "files=@notes.md" \\
      -F "files=@data.txt"
    ```
    """
    col = _get_collection_or_404(collection_id, db)
    created = []
    for upload in files:
        doc = await _process_upload(col, upload, db)
        created.append(doc)
    return created


# ── List ──────────────────────────────────────────────────────────────────────
@router.get("/collections/{collection_id}/documents", response_model=List[DocumentOut])
def list_documents(collection_id: str, db: Session = Depends(get_db)):
    """List all documents in a collection."""
    _get_collection_or_404(collection_id, db)
    return (
        db.query(DocumentModel)
        .filter(DocumentModel.collection_id == collection_id)
        .order_by(DocumentModel.created_at.desc())
        .all()
    )


# ── Delete ────────────────────────────────────────────────────────────────────
@router.delete("/collections/{collection_id}/documents/{document_id}", status_code=204)
def delete_document(collection_id: str, document_id: str, db: Session = Depends(get_db)):
    """Delete a document from a collection."""
    col = _get_collection_or_404(collection_id, db)
    doc = db.get(DocumentModel, document_id)
    if not doc or doc.collection_id != collection_id:
        raise HTTPException(404, "Document not found in this collection")

    from app.services.vectorstore import VectorStoreManager
    VectorStoreManager.get().delete_document(collection_id, document_id)

    if os.path.exists(doc.file_path):
        os.remove(doc.file_path)

    col.document_count = max(0, col.document_count - 1)
    col.chunk_count = max(0, col.chunk_count - doc.chunk_count)
    col.updated_at = datetime.utcnow()
    db.delete(doc)
    db.commit()


# ── Reindex ───────────────────────────────────────────────────────────────────
@router.post("/collections/{collection_id}/reindex", response_model=ReindexOut)
def reindex_collection(collection_id: str, db: Session = Depends(get_db)):
    """Drop and re-embed all documents in a collection."""
    col = _get_collection_or_404(collection_id, db)
    docs = (
        db.query(DocumentModel)
        .filter(DocumentModel.collection_id == collection_id)
        .all()
    )
    if not docs:
        raise HTTPException(400, "No documents in this collection to reindex.")

    from app.services.vectorstore import VectorStoreManager
    VectorStoreManager.get().delete_collection(collection_id)

    ingestor = IngestionService()
    total_chunks = 0
    for doc in docs:
        if not os.path.exists(doc.file_path):
            print(f"[Reindex] WARNING: file missing for doc {doc.id}, skipping.")
            continue
        try:
            chunks = ingestor.reindex_document(
                col.id, doc.id, doc.original_filename, doc.file_path
            )
            doc.chunk_count = chunks
            doc.is_indexed = True
            total_chunks += chunks
        except Exception as exc:
            print(f"[Reindex] Failed for {doc.original_filename}: {exc}")

    col.chunk_count = total_chunks
    col.is_indexed = True
    col.updated_at = datetime.utcnow()
    db.commit()

    return ReindexOut(
        collection_id=collection_id,
        documents_reindexed=len(docs),
        total_chunks=total_chunks,
        message=f"Reindexed {len(docs)} documents ({total_chunks} chunks).",
    )



# """
# /collections/{collection_id}/documents  endpoints
# """

# from __future__ import annotations

# import os
# import uuid
# from datetime import datetime
# from typing import List

# from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
# from sqlalchemy.orm import Session

# from app.db.database import Collection as CollectionModel
# from app.db.database import Document as DocumentModel
# from app.db.database import get_db
# from app.models.schemas import DocumentOut, ReindexOut
# from app.services.ingestion import IngestionService, save_upload

# router = APIRouter(tags=["Documents"])

# ALLOWED_EXTENSIONS = {".pdf", ".txt", ".md", ".png", ".jpg", ".jpeg", ".tiff", ".bmp", ".webp"}
# MAX_FILE_SIZE_MB = 50


# def _get_collection_or_404(collection_id: str, db: Session) -> CollectionModel:
#     col = db.get(CollectionModel, collection_id)
#     if not col:
#         raise HTTPException(404, "Collection not found")
#     return col


# @router.post("/collections/{collection_id}/documents", response_model=List[DocumentOut], status_code=201)
# async def upload_documents(
#     collection_id: str,
#     files: List[UploadFile] = File(...),
#     db: Session = Depends(get_db),
# ):
#     """Upload and ingest one or more documents into a collection."""
#     col = _get_collection_or_404(collection_id, db)
#     ingestor = IngestionService()
#     created_docs = []

#     for upload in files:
#         ext = os.path.splitext(upload.filename)[1].lower()
#         if ext not in ALLOWED_EXTENSIONS:
#             raise HTTPException(400, f"Unsupported file type: {ext}. Allowed: {ALLOWED_EXTENSIONS}")

#         content = await upload.read()

#         size_mb = len(content) / (1024 * 1024)
#         if size_mb > MAX_FILE_SIZE_MB:
#             raise HTTPException(413, f"File '{upload.filename}' exceeds {MAX_FILE_SIZE_MB} MB limit.")

#         doc_id = str(uuid.uuid4())
#         file_path = save_upload(collection_id, doc_id, upload.filename, content)

#         try:
#             chunk_count = ingestor.ingest_file(collection_id, doc_id, upload.filename, content)
#         except Exception as exc:
#             if os.path.exists(file_path):
#                 os.remove(file_path)
#             raise HTTPException(422, f"Failed to process '{upload.filename}': {exc}")

#         doc = DocumentModel(
#             id=doc_id,
#             collection_id=collection_id,
#             filename=f"{doc_id}_{upload.filename}",
#             original_filename=upload.filename,
#             file_type=ext.lstrip("."),
#             file_size=len(content),
#             file_path=file_path,
#             chunk_count=chunk_count,
#             is_indexed=True,
#         )
#         db.add(doc)

#         col.document_count += 1
#         col.chunk_count += chunk_count
#         col.is_indexed = True
#         col.updated_at = datetime.utcnow()

#         db.commit()
#         db.refresh(doc)
#         created_docs.append(doc)

#     return created_docs


# @router.get("/collections/{collection_id}/documents", response_model=List[DocumentOut])
# def list_documents(collection_id: str, db: Session = Depends(get_db)):
#     """List all documents in a collection."""
#     _get_collection_or_404(collection_id, db)
#     return (
#         db.query(DocumentModel)
#         .filter(DocumentModel.collection_id == collection_id)
#         .order_by(DocumentModel.created_at.desc())
#         .all()
#     )


# @router.delete("/collections/{collection_id}/documents/{document_id}", status_code=204)
# def delete_document(collection_id: str, document_id: str, db: Session = Depends(get_db)):
#     """Delete a document from a collection."""
#     col = _get_collection_or_404(collection_id, db)
#     doc = db.get(DocumentModel, document_id)
#     if not doc or doc.collection_id != collection_id:
#         raise HTTPException(404, "Document not found in this collection")

#     from app.services.vectorstore import VectorStoreManager
#     VectorStoreManager.get().delete_document(collection_id, document_id)

#     if os.path.exists(doc.file_path):
#         os.remove(doc.file_path)

#     col.document_count = max(0, col.document_count - 1)
#     col.chunk_count = max(0, col.chunk_count - doc.chunk_count)
#     col.updated_at = datetime.utcnow()

#     db.delete(doc)
#     db.commit()


# @router.post("/collections/{collection_id}/reindex", response_model=ReindexOut)
# def reindex_collection(collection_id: str, db: Session = Depends(get_db)):
#     """Drop and re-embed all documents in a collection."""
#     col = _get_collection_or_404(collection_id, db)
#     docs = (
#         db.query(DocumentModel)
#         .filter(DocumentModel.collection_id == collection_id)
#         .all()
#     )

#     if not docs:
#         raise HTTPException(400, "No documents in this collection to reindex.")

#     from app.services.vectorstore import VectorStoreManager
#     VectorStoreManager.get().delete_collection(collection_id)

#     ingestor = IngestionService()
#     total_chunks = 0

#     for doc in docs:
#         if not os.path.exists(doc.file_path):
#             print(f"[Reindex] WARNING: file missing for doc {doc.id}, skipping.")
#             continue
#         try:
#             chunks = ingestor.reindex_document(
#                 collection_id, doc.id, doc.original_filename, doc.file_path
#             )
#             doc.chunk_count = chunks
#             doc.is_indexed = True
#             total_chunks += chunks
#         except Exception as exc:
#             print(f"[Reindex] Failed for {doc.original_filename}: {exc}")

#     col.chunk_count = total_chunks
#     col.is_indexed = True
#     col.updated_at = datetime.utcnow()
#     db.commit()

#     return ReindexOut(
#         collection_id=collection_id,
#         documents_reindexed=len(docs),
#         total_chunks=total_chunks,
#         message=f"Reindexed {len(docs)} documents ({total_chunks} chunks).",
#     )