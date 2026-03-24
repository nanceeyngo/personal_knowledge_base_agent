"""
VectorStoreManager
------------------
One LangChain Chroma vectorstore per knowledge-base collection.
Collection names in Chroma are prefixed with "kb_" + collection_id.

LangChain's Chroma handles embedding internally via the EmbeddingService —
no manual embedding computation needed.
"""

from __future__ import annotations
import os
from typing import Any, Dict, List

from langchain_chroma import Chroma
from langchain_core.documents import Document

from app.core.config import CHROMA_PERSIST_DIRECTORY, MAX_CHUNKS_RETRIEVED
from app.services.embeddings import EmbeddingService


class VectorStoreManager:
    _instance: "VectorStoreManager | None" = None
    _stores: Dict[str, Chroma] = {}

    def __init__(self) -> None:
        self.embedding_svc = EmbeddingService.get()
        self.persist_dir = CHROMA_PERSIST_DIRECTORY
        os.makedirs(self.persist_dir, exist_ok=True)
        print(f"[VectorStore] Chroma persist dir: {self.persist_dir} ✓")

    @classmethod
    def get(cls) -> "VectorStoreManager":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _collection_name(self, collection_id: str) -> str:
        # Chroma names: 3-63 chars, alphanumeric + hyphens only
        return f"kb-{collection_id}"

    def _get_store(self, collection_id: str) -> Chroma:
        """Get or create a LangChain Chroma vectorstore for a collection."""
        if collection_id not in self._stores:
            self._stores[collection_id] = Chroma(
                collection_name=self._collection_name(collection_id),
                embedding_function=self.embedding_svc.embeddings,
                persist_directory=self.persist_dir,
            )
        return self._stores[collection_id]

    # ── Write ─────────────────────────────────────────────────────────────────

    def add_documents(self, collection_id: str, documents: List[Document]) -> int:
        """Add LangChain Document objects to the vectorstore."""
        if not documents:
            return 0
        store = self._get_store(collection_id)
        store.add_documents(documents)
        return len(documents)

    # ── Read ──────────────────────────────────────────────────────────────────

    def search(
        self,
        collection_id: str,
        query: str,
        n_results: int = MAX_CHUNKS_RETRIEVED,
    ) -> List[Dict[str, Any]]:
        """Return top-n chunks most relevant to query with scores."""
        store = self._get_store(collection_id)

        # similarity_search_with_score returns (Document, score) tuples
        try:
            results = store.similarity_search_with_score(query, k=n_results)
        except Exception as exc:
            print(f"[VectorStore] Search error: {exc}")
            return []

        formatted = []
        for rank, (doc, score) in enumerate(results):
            # Chroma cosine distance: lower = more similar → convert to 0-1 relevance
            relevance = round(max(0.0, min(1.0, float(score))), 4)
            formatted.append({
                "text": doc.page_content,
                "metadata": doc.metadata,
                "score": relevance,
                "rank": rank + 1,
            })

        return formatted

    # ── Delete ────────────────────────────────────────────────────────────────

    def delete_document(self, collection_id: str, document_id: str) -> int:
        """Remove all chunks belonging to document_id."""
        store = self._get_store(collection_id)
        # LangChain Chroma exposes the underlying collection via _collection
        col = store._collection
        existing = col.get(where={"document_id": document_id})
        ids = existing.get("ids", [])
        if ids:
            col.delete(ids=ids)
        return len(ids)

    def delete_collection(self, collection_id: str) -> None:
        """Drop the entire Chroma collection for this KB."""
        store = self._get_store(collection_id)
        store.delete_collection()
        # Remove from cache so next access re-creates it fresh
        self._stores.pop(collection_id, None)
        print(f"[VectorStore] Deleted collection: {self._collection_name(collection_id)}")

    def collection_count(self, collection_id: str) -> int:
        store = self._get_store(collection_id)
        return store._collection.count()


# """
# VectorStoreManager
# ------------------
# One LangChain Chroma vectorstore per knowledge-base collection.
# Collection names in Chroma are prefixed with "kb_" + collection_id.

# LangChain's Chroma handles embedding internally via the EmbeddingService —
# no manual embedding computation needed.
# """

# from __future__ import annotations
# import os
# from typing import Any, Dict, List

# from langchain_chroma import Chroma
# from langchain_core.documents import Document

# from app.core.config import CHROMA_PERSIST_DIRECTORY, MAX_CHUNKS_RETRIEVED
# from app.services.embeddings import EmbeddingService


# class VectorStoreManager:
#     _instance: "VectorStoreManager | None" = None
#     _stores: Dict[str, Chroma] = {}

#     def __init__(self) -> None:
#         self.embedding_svc = EmbeddingService.get()
#         self.persist_dir = CHROMA_PERSIST_DIRECTORY
#         os.makedirs(self.persist_dir, exist_ok=True)
#         print(f"[VectorStore] Chroma persist dir: {self.persist_dir} ✓")

#     @classmethod
#     def get(cls) -> "VectorStoreManager":
#         if cls._instance is None:
#             cls._instance = cls()
#         return cls._instance

#     def _collection_name(self, collection_id: str) -> str:
#         # Chroma names: 3-63 chars, alphanumeric + hyphens only
#         return f"kb-{collection_id}"

#     def _get_store(self, collection_id: str) -> Chroma:
#         """Get or create a LangChain Chroma vectorstore for a collection."""
#         if collection_id not in self._stores:
#             self._stores[collection_id] = Chroma(
#                 collection_name=self._collection_name(collection_id),
#                 embedding_function=self.embedding_svc.embeddings,
#                 persist_directory=self.persist_dir,
#             )
#         return self._stores[collection_id]

#     # ── Write ─────────────────────────────────────────────────────────────────

#     def add_documents(self, collection_id: str, documents: List[Document]) -> int:
#         """Add LangChain Document objects to the vectorstore."""
#         if not documents:
#             return 0
#         store = self._get_store(collection_id)
#         store.add_documents(documents)
#         return len(documents)

#     # ── Read ──────────────────────────────────────────────────────────────────

#     def search(
#         self,
#         collection_id: str,
#         query: str,
#         n_results: int = MAX_CHUNKS_RETRIEVED,
#     ) -> List[Dict[str, Any]]:
#         """Return top-n chunks most relevant to query with scores."""
#         store = self._get_store(collection_id)

#         # similarity_search_with_score returns (Document, score) tuples
#         try:
#             results = store.similarity_search_with_score(query, k=n_results)
#         except Exception as exc:
#             print(f"[VectorStore] Search error: {exc}")
#             return []

#         formatted = []
#         for rank, (doc, score) in enumerate(results):
#             # Chroma cosine distance: lower = more similar → convert to 0-1 relevance
#             relevance = round(max(0.0, 1.0 - float(score)), 4)
#             formatted.append({
#                 "text": doc.page_content,
#                 "metadata": doc.metadata,
#                 "score": relevance,
#                 "rank": rank + 1,
#             })

#         return formatted

#     # ── Delete ────────────────────────────────────────────────────────────────

#     def delete_document(self, collection_id: str, document_id: str) -> int:
#         """Remove all chunks belonging to document_id."""
#         store = self._get_store(collection_id)
#         # LangChain Chroma exposes the underlying collection via _collection
#         col = store._collection
#         existing = col.get(where={"document_id": document_id})
#         ids = existing.get("ids", [])
#         if ids:
#             col.delete(ids=ids)
#         return len(ids)

#     def delete_collection(self, collection_id: str) -> None:
#         """Drop the entire Chroma collection for this KB."""
#         store = self._get_store(collection_id)
#         store.delete_collection()
#         # Remove from cache so next access re-creates it fresh
#         self._stores.pop(collection_id, None)
#         print(f"[VectorStore] Deleted collection: {self._collection_name(collection_id)}")

#     def collection_count(self, collection_id: str) -> int:
#         store = self._get_store(collection_id)
#         return store._collection.count()