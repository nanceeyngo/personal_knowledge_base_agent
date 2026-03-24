"""
EmbeddingService
----------------
Thin singleton wrapper around LangChain's HuggingFaceEmbeddings.
Using LangChain's native embedding class integrates directly with
langchain_chroma.Chroma — no manual embedding calls needed anywhere.
"""

from __future__ import annotations
from langchain_huggingface import HuggingFaceEmbeddings
from app.core.config import EMBED_MODEL_NAME


class EmbeddingService:
    _instance: "EmbeddingService | None" = None

    def __init__(self) -> None:
        self.model_name = EMBED_MODEL_NAME
        self.embeddings: HuggingFaceEmbeddings | None = None
        self._load()

    @classmethod
    def get(cls) -> "EmbeddingService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _load(self) -> None:
        try:
            print(f"[Embeddings] Loading model: {self.model_name}")
            self.embeddings = HuggingFaceEmbeddings(
                model_name=self.model_name,
                model_kwargs={"device": "cpu"},
                encode_kwargs={"normalize_embeddings": True},
            )
            print("[Embeddings] Model ready ✓")
        except Exception as exc:
            print(f"[Embeddings] ERROR: {exc}. Falling back to all-MiniLM-L6-v2")
            self.embeddings = HuggingFaceEmbeddings(
                model_name="all-MiniLM-L6-v2",
                model_kwargs={"device": "cpu"},
                encode_kwargs={"normalize_embeddings": True},
            )










# """
# EmbeddingService
# ----------------
# Wraps a local HuggingFace sentence-transformers model.
# Embeddings are computed manually so we keep full control
# (same pattern as the previous project).
# """

# from __future__ import annotations

# from typing import List

# from sentence_transformers import SentenceTransformer

# from app.core.config import EMBED_MODEL_NAME


# class EmbeddingService:
#     _instance: "EmbeddingService | None" = None

#     def __init__(self) -> None:
#         self.model_name = EMBED_MODEL_NAME
#         self.model: SentenceTransformer | None = None
#         self._load()

#     # ── Singleton ─────────────────────────────────────────────────────────────
#     @classmethod
#     def get(cls) -> "EmbeddingService":
#         if cls._instance is None:
#             cls._instance = cls()
#         return cls._instance

#     # ── Init ──────────────────────────────────────────────────────────────────
#     def _load(self) -> None:
#         try:
#             print(f"[Embeddings] Loading model: {self.model_name}")
#             self.model = SentenceTransformer(self.model_name)
#             print(f"[Embeddings] Model ready ✓")
#         except Exception as exc:
#             print(f"[Embeddings] ERROR loading {self.model_name}: {exc}")
#             # Fallback to the smallest reliable model
#             fallback = "all-MiniLM-L6-v2"
#             print(f"[Embeddings] Falling back to {fallback}")
#             self.model = SentenceTransformer(fallback)

#     # ── Public API ────────────────────────────────────────────────────────────
#     def embed(self, texts: List[str]) -> List[List[float]]:
#         """Return a list of embedding vectors (one per text)."""
#         if not self.model:
#             raise RuntimeError("Embedding model is not initialised.")
#         if not texts:
#             raise ValueError("texts list is empty.")
#         embeddings = self.model.encode(texts, convert_to_numpy=True)
#         return embeddings.tolist()

#     def embed_one(self, text: str) -> List[float]:
#         return self.embed([text])[0]

#     @property
#     def dimension(self) -> int:
#         """Embedding vector size (needed when creating Chroma collections)."""
#         if self.model:
#             return self.model.get_sentence_embedding_dimension()
#         return 384  # default for all-MiniLM-L6-v2