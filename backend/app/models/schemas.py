"""
Pydantic schemas (request bodies + response shapes).
Kept separate from SQLAlchemy ORM models.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, List, Optional

from pydantic import BaseModel, Field


# ── Collections ───────────────────────────────────────────────────────────────
class CollectionCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    description: Optional[str] = ""


class CollectionOut(BaseModel):
    id: str
    name: str
    description: str
    created_at: datetime
    updated_at: datetime
    document_count: int
    chunk_count: int
    is_indexed: bool

    model_config = {"from_attributes": True}


# ── Documents ─────────────────────────────────────────────────────────────────
class DocumentOut(BaseModel):
    id: str
    collection_id: str
    filename: str
    original_filename: str
    file_type: str
    file_size: int
    chunk_count: int
    is_indexed: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Conversations ─────────────────────────────────────────────────────────────
class ConversationCreate(BaseModel):
    title: Optional[str] = "New Conversation"


class ConversationOut(BaseModel):
    id: str
    collection_id: str
    title: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Messages ──────────────────────────────────────────────────────────────────
class SourceRef(BaseModel):
    """A single retrieved chunk that grounded the answer."""
    document_id: str
    filename: str
    chunk_index: int
    excerpt: str          # first ~200 chars of the chunk
    score: float
    page_number: Optional[int] = None


class MessageOut(BaseModel):
    id: str
    conversation_id: str
    role: str             # "user" | "assistant"
    content: str
    sources: List[SourceRef] = []
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Chat request ──────────────────────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    conversation_id: Optional[str] = None   # if None → new conversation


# ── Reindex response ──────────────────────────────────────────────────────────
class ReindexOut(BaseModel):
    collection_id: str
    documents_reindexed: int
    total_chunks: int
    message: str


# ── Health ────────────────────────────────────────────────────────────────────
class HealthOut(BaseModel):
    status: str
    llm: str
    embeddings: str
    chroma: str
    sqlite: str
    model: str
    embed_model: str