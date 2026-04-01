import os
from dotenv import load_dotenv

load_dotenv()

# ── LLM (OpenRouter) ──────────────────────────────────────────────────────────
OPENROUTER_API_KEY: str = os.getenv("OPENROUTER_API_KEY", "")
MODEL_NAME: str = os.getenv("MODEL_NAME", "openai/gpt-4o-mini")
OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"

# ── Embeddings (HuggingFace local) ────────────────────────────────────────────
EMBED_MODEL_NAME: str = os.getenv("EMBED_MODEL_NAME", "sentence-transformers/all-MiniLM-L6-v2")

# ── ChromaDB ──────────────────────────────────────────────────────────────────
CHROMA_PERSIST_DIRECTORY: str = os.getenv("CHROMA_PERSIST_DIRECTORY", "./chroma_data")

# ── SQLite ────────────────────────────────────────────────────────────────────
SQLITE_DB_PATH: str = os.getenv("SQLITE_DB_PATH", "./data/rag.db")

# ── Ingestion ─────────────────────────────────────────────────────────────────
RAG_DATA_DIR: str = os.getenv("RAG_DATA_DIR", "./data/uploads")
CHUNK_SIZE: int = int(os.getenv("CHUNK_SIZE", "800"))
CHUNK_OVERLAP: int = int(os.getenv("CHUNK_OVERLAP", "120"))
MAX_CHUNKS_RETRIEVED: int = int(os.getenv("MAX_CHUNKS_RETRIEVED", "5"))

# ── Server ────────────────────────────────────────────────────────────────────
PORT: int = int(os.getenv("PORT", "8000"))
ALLOWED_ORIGINS: list = os.getenv("ALLOWED_ORIGINS", "*").split(",")


def validate() -> list[str]:
    """Return list of error strings; empty list means all good."""
    errors = []
    if not OPENROUTER_API_KEY:
        errors.append("OPENROUTER_API_KEY is not set")
    return errors