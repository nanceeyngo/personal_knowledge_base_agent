"""
SQLite database setup via SQLAlchemy.

Tables
------
collections   – a named knowledge-base bucket
documents     – every file ingested into a collection
conversations – a chat session tied to one collection
messages      – individual turns inside a conversation
"""

from __future__ import annotations

import os
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    create_engine,
)
from sqlalchemy.orm import DeclarativeBase, Session, relationship, sessionmaker

from app.core.config import SQLITE_DB_PATH

# Ensure parent directory exists
os.makedirs(os.path.dirname(SQLITE_DB_PATH), exist_ok=True)

DATABASE_URL = f"sqlite:///{SQLITE_DB_PATH}"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},  # needed for SQLite + FastAPI
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# ── Base ──────────────────────────────────────────────────────────────────────
class Base(DeclarativeBase):
    pass


# ── Models ────────────────────────────────────────────────────────────────────
class Collection(Base):
    __tablename__ = "collections"

    id = Column(String, primary_key=True)          # UUID str
    name = Column(String, nullable=False)
    description = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    document_count = Column(Integer, default=0)
    chunk_count = Column(Integer, default=0)
    is_indexed = Column(Boolean, default=False)

    documents = relationship("Document", back_populates="collection", cascade="all, delete-orphan")
    conversations = relationship("Conversation", back_populates="collection", cascade="all, delete-orphan")


class Document(Base):
    __tablename__ = "documents"

    id = Column(String, primary_key=True)          # UUID str
    collection_id = Column(String, ForeignKey("collections.id"), nullable=False)
    filename = Column(String, nullable=False)
    original_filename = Column(String, nullable=False)
    file_type = Column(String, nullable=False)     # pdf | txt | md | image
    file_size = Column(Integer, default=0)         # bytes
    file_path = Column(String, nullable=False)     # absolute path on disk
    chunk_count = Column(Integer, default=0)
    is_indexed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    collection = relationship("Collection", back_populates="documents")


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(String, primary_key=True)          # UUID str
    collection_id = Column(String, ForeignKey("collections.id"), nullable=False)
    title = Column(String, default="New Conversation")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    collection = relationship("Collection", back_populates="conversations")
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan", order_by="Message.created_at")


class Message(Base):
    __tablename__ = "messages"

    id = Column(String, primary_key=True)          # UUID str
    conversation_id = Column(String, ForeignKey("conversations.id"), nullable=False)
    role = Column(String, nullable=False)          # "user" | "assistant"
    content = Column(Text, nullable=False)
    sources = Column(Text, default="[]")           # JSON-serialised list of source refs
    created_at = Column(DateTime, default=datetime.utcnow)

    conversation = relationship("Conversation", back_populates="messages")


# ── Helpers ───────────────────────────────────────────────────────────────────
def init_db() -> None:
    """Create all tables if they don't exist yet."""
    Base.metadata.create_all(bind=engine)


def get_db():
    """FastAPI dependency: yield a DB session and close it after the request."""
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()