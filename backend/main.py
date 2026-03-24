"""
main.py  –  FastAPI application entry point
"""

from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import ALLOWED_ORIGINS, PORT, RAG_DATA_DIR, CHROMA_PERSIST_DIRECTORY, validate
from app.db.database import init_db
from app.api import collections, documents, chat, health

# ── Ensure data directories exist ─────────────────────────────────────────────
os.makedirs(RAG_DATA_DIR, exist_ok=True)
os.makedirs(CHROMA_PERSIST_DIRECTORY, exist_ok=True)
os.makedirs(os.path.dirname("./data/rag.db"), exist_ok=True)

# ── Create tables ─────────────────────────────────────────────────────────────
init_db()

# ── Validate env ──────────────────────────────────────────────────────────────
errors = validate()
if errors:
    for e in errors:
        print(f"[Config] WARNING: {e}")

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Personal Knowledge Base Agent",
    description="Personal knowledge base powered by LangChain, ChromaDB, and OpenRouter",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(health.router)
app.include_router(collections.router)
app.include_router(documents.router)
app.include_router(chat.router)
