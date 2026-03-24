"""
/collections/{collection_id}/chat  +  /conversations  endpoints

SSE streaming flow
──────────────────
POST /collections/{id}/chat
  → creates / resumes a conversation
  → streams SSE events:
       data: {"type": "source",  "data": {...}}
       data: {"type": "token",   "data": "..."}
       data: {"type": "done",    "data": ""}
       data: {"type": "error",   "data": "..."}
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.db.database import Collection as CollectionModel
from app.db.database import Conversation as ConversationModel
from app.db.database import Message as MessageModel
from app.db.database import get_db
from app.models.schemas import ChatRequest, ConversationOut, MessageOut, SourceRef
from app.services.rag_agent import RAGAgent

router = APIRouter(tags=["Chat"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_collection_or_404(collection_id: str, db: Session) -> CollectionModel:
    col = db.get(CollectionModel, collection_id)
    if not col:
        raise HTTPException(404, "Collection not found")
    return col


def _get_history(conversation_id: str, db: Session) -> List[dict]:
    """Return messages as plain dicts for the agent."""
    messages = (
        db.query(MessageModel)
        .filter(MessageModel.conversation_id == conversation_id)
        .order_by(MessageModel.created_at)
        .all()
    )
    return [{"role": m.role, "content": m.content} for m in messages]


# ── Chat (SSE) ────────────────────────────────────────────────────────────────

@router.post("/collections/{collection_id}/chat")
async def chat(
    collection_id: str,
    payload: ChatRequest,
    db: Session = Depends(get_db),
):
    col = _get_collection_or_404(collection_id, db)

    if not col.is_indexed:
        raise HTTPException(400, "Collection has no indexed documents. Please upload documents first.")

    # Resolve or create conversation
    if payload.conversation_id:
        convo = db.get(ConversationModel, payload.conversation_id)
        if not convo or convo.collection_id != collection_id:
            raise HTTPException(404, "Conversation not found in this collection")
    else:
        # Auto-title from first 60 chars of the question
        title = payload.message[:60] + ("…" if len(payload.message) > 60 else "")
        convo = ConversationModel(
            id=str(uuid.uuid4()),
            collection_id=collection_id,
            title=title,
        )
        db.add(convo)
        db.commit()
        db.refresh(convo)

    # Persist user message
    user_msg = MessageModel(
        id=str(uuid.uuid4()),
        conversation_id=convo.id,
        role="user",
        content=payload.message,
        sources="[]",
    )
    db.add(user_msg)
    db.commit()

    # Load history (includes the message we just saved)
    history = _get_history(convo.id, db)
    # The last item is the user turn we just added — strip it so the agent
    # receives history *before* the current question.
    history_before = history[:-1]

    agent = RAGAgent.get()

    # ── SSE generator ─────────────────────────────────────────────────────────
    async def event_stream():
        full_answer = ""
        sources_collected = []
 
        try:
            # Always emit conversation_id first
            yield f"data: {json.dumps({'type': 'conversation_id', 'data': convo.id})}\n\n"
 
            async for event in agent.stream_answer(
                collection_id=collection_id,
                question=payload.message,
                history=history_before,
            ):
                yield f"data: {json.dumps(event)}\n\n"
 
                if event["type"] == "token":
                    full_answer += event["data"]
                elif event["type"] == "source":
                    sources_collected.append(event["data"])
 
        except Exception as exc:
            # Surface as SSE error event instead of crashing with 500
            error_event = json.dumps({"type": "error", "data": str(exc)})
            yield f"data: {error_event}\n\n"
            print(f"[Chat] SSE stream error: {exc}")
 
        finally:
            # Always persist whatever was assembled, even on partial error
            if full_answer or sources_collected:
                try:
                    assistant_msg = MessageModel(
                        id=str(uuid.uuid4()),
                        conversation_id=convo.id,
                        role="assistant",
                        content=full_answer,
                        sources=json.dumps(sources_collected),
                    )
                    db.add(assistant_msg)
                    convo.updated_at = datetime.utcnow()
                    db.commit()
                except Exception as db_exc:
                    print(f"[Chat] Failed to persist assistant message: {db_exc}")
 
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Access-Control-Allow-Origin": "*",
            "X-Conversation-Id": convo.id,
        },
    )


# ── Conversations ─────────────────────────────────────────────────────────────

@router.get(
    "/collections/{collection_id}/conversations",
    response_model=List[ConversationOut],
)
def list_conversations(collection_id: str, db: Session = Depends(get_db)):
    _get_collection_or_404(collection_id, db)
    return (
        db.query(ConversationModel)
        .filter(ConversationModel.collection_id == collection_id)
        .order_by(ConversationModel.updated_at.desc())
        .all()
    )


@router.get("/conversations/{conversation_id}", response_model=List[MessageOut])
def get_conversation_messages(conversation_id: str, db: Session = Depends(get_db)):
    convo = db.get(ConversationModel, conversation_id)
    if not convo:
        raise HTTPException(404, "Conversation not found")

    messages = (
        db.query(MessageModel)
        .filter(MessageModel.conversation_id == conversation_id)
        .order_by(MessageModel.created_at)
        .all()
    )

    # Deserialise sources JSON → list of SourceRef dicts
    result = []
    for m in messages:
        try:
            sources = [SourceRef(**s) for s in json.loads(m.sources or "[]")]
        except Exception:
            sources = []
        result.append(
            MessageOut(
                id=m.id,
                conversation_id=m.conversation_id,
                role=m.role,
                content=m.content,
                sources=sources,
                created_at=m.created_at,
            )
        )

    return result


@router.delete("/conversations/{conversation_id}", status_code=204)
def delete_conversation(conversation_id: str, db: Session = Depends(get_db)):
    convo = db.get(ConversationModel, conversation_id)
    if not convo:
        raise HTTPException(404, "Conversation not found")
    db.delete(convo)
    db.commit()