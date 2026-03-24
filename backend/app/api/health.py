from fastapi import APIRouter
from app.core.config import EMBED_MODEL_NAME, MODEL_NAME
from app.models.schemas import HealthOut
from app.services.embeddings import EmbeddingService
from app.services.vectorstore import VectorStoreManager
from app.services.rag_agent import RAGAgent

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthOut)
def health():
    emb = EmbeddingService.get()
    vs = VectorStoreManager.get()
    agent = RAGAgent.get()

    return HealthOut(
        status="ok",
        llm="ready" if agent.llm else "error",
        embeddings="ready" if emb.model else "error",
        chroma="ready" if vs.client else "error",
        sqlite="ready",
        model=MODEL_NAME,
        embed_model=EMBED_MODEL_NAME,
    )


@router.get("/")
def root():
    return {
        "name": "RAG Knowledge Agent API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }