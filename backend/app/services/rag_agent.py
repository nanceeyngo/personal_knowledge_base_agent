"""
RAGAgent
--------
LangChain-powered conversational RAG agent.

Uses:
  - langchain_openai.ChatOpenAI  (OpenRouter as the LLM provider)
  - LangChain Chroma vectorstore .as_retriever()
  - LangChain message types (SystemMessage, HumanMessage, AIMessage)
  - LangChain's create_retrieval_chain + stuff_documents_chain for RAG
  - Manual history injection for conversational follow-ups (same pattern
    as your second project's ConversationBufferMemory approach, but
    explicit so it works cleanly with SSE streaming)

SSE event types emitted by stream_answer():
  {"type": "source",        "data": <SourceRef dict>}   — before tokens
  {"type": "token",         "data": "<text fragment>"}  — streamed tokens
  {"type": "done",          "data": ""}
  {"type": "error",         "data": "<message>"}
"""

from __future__ import annotations

from typing import Any, AsyncGenerator, Dict, List

from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI

from app.core.config import MAX_CHUNKS_RETRIEVED, MODEL_NAME, OPENROUTER_API_KEY, OPENROUTER_BASE_URL
from app.services.vectorstore import VectorStoreManager

# ── Prompts ───────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are a knowledgeable assistant that answers questions \
based on the user's personal knowledge base.

Rules:
- Answer ONLY using the provided context.
- Extract as much relevant information as possible from the context.
- Do NOT say "context is insufficient" unless absolutely nothing relevant exists.
- Always try to identify:
  • key topics
  • entities (people, roles, organisations)
  • numbers or statistics
  • recommendations or conclusions
- Be concise but thorough.
- Naturally mention the source document name when referencing information \
  (e.g. "According to report.pdf…").
- Use the conversation history to handle follow-up questions correctly.
- If the question is outside the documents, say the knowledge base doesn't cover it.
"""


def _build_context_block(chunks: List[Dict[str, Any]]) -> str:
    """Format retrieved chunks into a readable context string for the prompt."""
    if not chunks:
        return "No relevant context found in the knowledge base."

    parts: List[str] = []
    for chunk in chunks:
        meta = chunk["metadata"]
        filename = meta.get("filename", "unknown")
        page = meta.get("page_number", -1)
        page_str = f" (page {page})" if page and page > 0 else ""
        score = chunk.get("score", 0)
        parts.append(
            f"[Source: {filename}{page_str} | relevance: {score:.2f}]\n{chunk['text']}"
        )

    return "\n\n---\n\n".join(parts)


def _build_source_refs(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Convert raw chunk dicts into SourceRef schema dicts."""
    refs = []
    for chunk in chunks:
        meta = chunk["metadata"]
        page = meta.get("page_number", -1)
        refs.append({
            "document_id": meta.get("document_id", ""),
            "filename": meta.get("filename", "unknown"),
            "chunk_index": meta.get("chunk_index", 0),
            "excerpt": chunk["text"][:220] + ("…" if len(chunk["text"]) > 220 else ""),
            "score": round(chunk.get("score", 0.0), 4),
            "page_number": page if page and page > 0 else None,
        })
    return refs


# ── Agent ─────────────────────────────────────────────────────────────────────

class RAGAgent:
    _instance: "RAGAgent | None" = None

    def __init__(self) -> None:
        self.vs = VectorStoreManager.get()
        # LangChain ChatOpenAI pointed at OpenRouter
        self.llm = ChatOpenAI(
            model=MODEL_NAME,
            openai_api_key=OPENROUTER_API_KEY,
            openai_api_base=OPENROUTER_BASE_URL,
            streaming=True,
            temperature=0.1,
            max_tokens=1500,
            default_headers={
                "HTTP-Referer": "https://rag-knowledge-agent",
                "X-Title": "Personal Knowledge Base Agent",
            },
        )
        print(f"[RAGAgent] Ready — model: {MODEL_NAME} via OpenRouter ✓")

    @classmethod
    def get(cls) -> "RAGAgent":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _build_lc_history(
        self, history: List[Dict[str, str]]
    ) -> List[HumanMessage | AIMessage]:
        """Convert stored message dicts → LangChain message objects."""
        messages = []
        for m in history:
            if m["role"] == "user":
                messages.append(HumanMessage(content=m["content"]))
            elif m["role"] == "assistant":
                messages.append(AIMessage(content=m["content"]))
        return messages

    async def stream_answer(
        self,
        collection_id: str,
        question: str,
        history: List[Dict[str, str]],
        n_chunks: int = MAX_CHUNKS_RETRIEVED,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Async generator — yields SSE-ready event dicts.

        Retrieval uses LangChain's Chroma .as_retriever() under the hood
        (via VectorStoreManager.search which calls similarity_search_with_score).
        The retrieved context + conversation history are injected into the
        LangChain message list before calling llm.astream().
        """
        # ── 1. Retrieve relevant chunks via LangChain Chroma ──────────────────
        try:
            chunks = self.vs.search(collection_id, question, n_results=max(n_chunks, 8))
            chunks = [c for c in chunks if c.get("score", 0) > 0.2]
        except Exception as exc:
            yield {"type": "error", "data": f"Retrieval failed: {exc}"}
            return

        source_refs = _build_source_refs(chunks)

        # ── 2. Emit sources first so the UI can show them immediately ─────────
        for ref in source_refs:
            yield {"type": "source", "data": ref}

        # ── 3. Build LangChain message list ───────────────────────────────────
        context_text = _build_context_block(chunks)

        # System prompt includes the retrieved context
        system_with_context = (
            SYSTEM_PROMPT
            + "\n\n--- Retrieved Context ---\n"
            + context_text
            + "\n--- End of Context ---"
        )

        lc_messages = [SystemMessage(content=system_with_context)]
        # Inject full conversation history (LangChain message objects)
        lc_messages += self._build_lc_history(history)
        # Current user question
        lc_messages.append(HumanMessage(content=question))

        # ── 4. Stream from LLM token by token ────────────────────────────────
        try:
            async for chunk in self.llm.astream(lc_messages):
                token = chunk.content
                if token:
                    yield {"type": "token", "data": token}
        except Exception as exc:
            yield {"type": "error", "data": f"LLM error: {exc}"}
            return

        yield {"type": "done", "data": ""}

    async def answer(
        self,
        collection_id: str,
        question: str,
        history: List[Dict[str, str]],
        n_chunks: int = MAX_CHUNKS_RETRIEVED,
    ) -> Dict[str, Any]:
        """
        Non-streaming convenience method — collects the full streamed response.
        Used by the CLI and eval runner.
        """
        full_text = ""
        sources = []

        async for event in self.stream_answer(collection_id, question, history, n_chunks):
            if event["type"] == "token":
                full_text += event["data"]
            elif event["type"] == "source":
                sources.append(event["data"])
            elif event["type"] == "error":
                raise RuntimeError(event["data"])

        return {"answer": full_text, "sources": sources}



# """
# RAGAgent
# --------
# LangChain-powered conversational RAG agent.

# Flow per turn
# ─────────────
# 1.  Load full conversation history from SQLite into a LangChain
#     ChatMessageHistory object.
# 2.  Embed the user question and retrieve top-k chunks from ChromaDB.
# 3.  Build a prompt that includes:
#       • System instructions
#       • Retrieved context (with source metadata)
#       • Full conversation history
#       • Current user question
# 4.  Stream the response token-by-token from OpenRouter via
#     LangChain's ChatOpenAI (SSE-friendly async generator).
# 5.  Return both the streamed text and the source references.
# """

# from __future__ import annotations

# import json
# from typing import Any, AsyncGenerator, Dict, List, Optional

# from langchain.schema import AIMessage, HumanMessage, SystemMessage
# from langchain_openai import ChatOpenAI

# from app.core.config import MAX_CHUNKS_RETRIEVED, MODEL_NAME, OPENROUTER_API_KEY, OPENROUTER_BASE_URL
# from app.services.vector_store import VectorStoreManager


# # ── Prompt template ───────────────────────────────────────────────────────────

# SYSTEM_PROMPT = """You are a knowledgeable assistant that answers questions \
# based on the user's personal knowledge base.

# Guidelines:
# - Answer ONLY from the provided context. If the context does not contain \
# enough information, say so clearly rather than guessing.
# - Be concise but thorough.
# - When referencing information, naturally mention the source document name \
# (e.g. "According to report.pdf…").
# - For follow-up questions, use the conversation history to maintain context.
# - If asked something outside the documents, politely say the documents don't \
# cover that topic.
# """

# CONTEXT_TEMPLATE = """--- Retrieved Context ---
# {context}
# --- End of Context ---"""


# def _build_context_block(chunks: List[Dict[str, Any]]) -> str:
#     """Format retrieved chunks into a readable context block."""
#     if not chunks:
#         return "No relevant context found in the knowledge base."

#     parts: List[str] = []
#     for chunk in chunks:
#         meta = chunk["metadata"]
#         filename = meta.get("filename", "unknown")
#         page = meta.get("page_number", -1)
#         page_str = f" (page {page})" if page and page > 0 else ""
#         score = chunk.get("score", 0)
#         parts.append(
#             f"[Source: {filename}{page_str} | relevance: {score:.2f}]\n{chunk['text']}"
#         )

#     return "\n\n".join(parts)


# def _build_source_refs(chunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
#     """Convert raw chunks into the SourceRef schema dicts."""
#     refs = []
#     for chunk in chunks:
#         meta = chunk["metadata"]
#         refs.append(
#             {
#                 "document_id": meta.get("document_id", ""),
#                 "filename": meta.get("filename", "unknown"),
#                 "chunk_index": meta.get("chunk_index", 0),
#                 "excerpt": chunk["text"][:220] + ("…" if len(chunk["text"]) > 220 else ""),
#                 "score": round(chunk.get("score", 0), 4),
#                 "page_number": meta.get("page_number") if meta.get("page_number", -1) > 0 else None,
#             }
#         )
#     return refs


# # ── Agent class ───────────────────────────────────────────────────────────────

# class RAGAgent:
#     _instance: "RAGAgent | None" = None

#     def __init__(self) -> None:
#         self.vs = VectorStoreManager.get()
#         self.llm = ChatOpenAI(
#             model=MODEL_NAME,
#             openai_api_key=OPENROUTER_API_KEY,
#             openai_api_base=OPENROUTER_BASE_URL,
#             streaming=True,          # enables token-by-token streaming
#             temperature=0.2,
#             max_tokens=1024,
#             default_headers={
#                 "HTTP-Referer": "https://rag-knowledge-agent",
#                 "X-Title": "Personal Knowledge Base Agent",
#             },
#         )
#         print(f"[RAGAgent] LLM ready: {MODEL_NAME} via OpenRouter ✓")

#     @classmethod
#     def get(cls) -> "RAGAgent":
#         if cls._instance is None:
#             cls._instance = cls()
#         return cls._instance

#     # ── History helpers ───────────────────────────────────────────────────────

#     def _build_lc_history(
#         self, history: List[Dict[str, str]]
#     ) -> List[HumanMessage | AIMessage]:
#         """Convert stored message dicts to LangChain message objects."""
#         messages = []
#         for m in history:
#             if m["role"] == "user":
#                 messages.append(HumanMessage(content=m["content"]))
#             elif m["role"] == "assistant":
#                 messages.append(AIMessage(content=m["content"]))
#         return messages

#     # ── Core streaming method ─────────────────────────────────────────────────

#     async def stream_answer(
#         self,
#         collection_id: str,
#         question: str,
#         history: List[Dict[str, str]],
#         n_chunks: int = MAX_CHUNKS_RETRIEVED,
#     ) -> AsyncGenerator[Dict[str, Any], None]:
#         """
#         Async generator that yields dicts:
#           {"type": "source",  "data": <SourceRef dict>}   — emitted first
#           {"type": "token",   "data": "<text fragment>"}  — streamed tokens
#           {"type": "done",    "data": ""}                 — final signal
#           {"type": "error",   "data": "<message>"}        — on failure
#         """
#         # 1. Retrieve relevant chunks
#         try:
#             chunks = self.vs.search(collection_id, question, n_results=n_chunks)
#         except Exception as exc:
#             yield {"type": "error", "data": f"Retrieval failed: {exc}"}
#             return

#         source_refs = _build_source_refs(chunks)

#         # 2. Emit source refs upfront so the UI can show them immediately
#         for ref in source_refs:
#             yield {"type": "source", "data": ref}

#         # 3. Build messages list for LangChain
#         context_text = _build_context_block(chunks)
#         context_block = CONTEXT_TEMPLATE.format(context=context_text)

#         lc_messages = [SystemMessage(content=SYSTEM_PROMPT + "\n\n" + context_block)]
#         lc_messages += self._build_lc_history(history)
#         lc_messages.append(HumanMessage(content=question))

#         # 4. Stream from LLM
#         try:
#             async for chunk in self.llm.astream(lc_messages):
#                 token = chunk.content
#                 if token:
#                     yield {"type": "token", "data": token}
#         except Exception as exc:
#             yield {"type": "error", "data": f"LLM error: {exc}"}
#             return

#         yield {"type": "done", "data": ""}

#     # ── Non-streaming convenience method ──────────────────────────────────────

#     async def answer(
#         self,
#         collection_id: str,
#         question: str,
#         history: List[Dict[str, str]],
#         n_chunks: int = MAX_CHUNKS_RETRIEVED,
#     ) -> Dict[str, Any]:
#         """
#         Collect the full streamed response and return:
#           {"answer": str, "sources": List[SourceRef dict]}
#         Useful for the CLI and eval scripts.
#         """
#         full_text = ""
#         sources = []

#         async for event in self.stream_answer(collection_id, question, history, n_chunks):
#             if event["type"] == "token":
#                 full_text += event["data"]
#             elif event["type"] == "source":
#                 sources.append(event["data"])
#             elif event["type"] == "error":
#                 raise RuntimeError(event["data"])

#         return {"answer": full_text, "sources": sources}