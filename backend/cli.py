"""
cli.py  –  Personal Knowledge Base Agent CLI
────────────────────────────────────
Usage examples:

  # Create a new knowledge-base collection
  python cli.py new-collection "My Research"

  # List all collections
  python cli.py list-collections

  # Upload documents into a collection
  python cli.py ingest <collection_id> path/to/file.pdf path/to/notes.md

  # Ask a question (new conversation)
  python cli.py ask <collection_id> "What are the main findings?"

  # Ask a follow-up in an existing conversation
  python cli.py ask <collection_id> "Can you elaborate?" --conversation <conv_id>

  # List conversations for a collection
  python cli.py list-conversations <collection_id>

  # View messages in a conversation
  python cli.py show-conversation <conversation_id>
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.table import Table
from rich import print as rprint

# Ensure the backend package is importable when running from repo root
sys.path.insert(0, str(Path(__file__).parent))

import dotenv
dotenv.load_dotenv()

from app.db.database import (
    SessionLocal,
    init_db,
    Collection as CollectionModel,
    Conversation as ConversationModel,
    Message as MessageModel,
)
from app.services.ingestion import IngestionService, save_upload
from app.services.rag_agent import RAGAgent
from app.db.database import Document as DocumentModel
import uuid
from datetime import datetime

app_cli = typer.Typer(
    name="rag-agent",
    help="Personal Knowledge Base Agent CLI",
    add_completion=False,
)
console = Console()

# ── Bootstrap ─────────────────────────────────────────────────────────────────
init_db()


# ── Helpers ───────────────────────────────────────────────────────────────────

def _db():
    return SessionLocal()


def _get_collection(db, collection_id: str) -> CollectionModel:
    col = db.get(CollectionModel, collection_id)
    if not col:
        console.print(f"[red]Collection '{collection_id}' not found.[/red]")
        raise typer.Exit(1)
    return col


# ── Commands ──────────────────────────────────────────────────────────────────

@app_cli.command("new-collection")
def new_collection(
    name: str = typer.Argument(..., help="Name for the new knowledge-base collection"),
    description: str = typer.Option("", "--desc", "-d", help="Optional description"),
):
    """Create a new knowledge-base collection."""
    db = _db()
    col = CollectionModel(
        id=str(uuid.uuid4()),
        name=name,
        description=description,
    )
    db.add(col)
    db.commit()
    db.refresh(col)
    console.print(Panel(
        f"[bold green]Collection created![/bold green]\n"
        f"ID:   [cyan]{col.id}[/cyan]\n"
        f"Name: {col.name}",
        title="✅ New Collection",
    ))
    db.close()


@app_cli.command("list-collections")
def list_collections():
    """List all knowledge-base collections."""
    db = _db()
    cols = db.query(CollectionModel).order_by(CollectionModel.created_at.desc()).all()
    db.close()

    if not cols:
        console.print("[yellow]No collections found. Create one with 'new-collection'.[/yellow]")
        return

    table = Table(title="Knowledge-Base Collections", show_lines=True)
    table.add_column("ID", style="cyan", no_wrap=True, max_width=36)
    table.add_column("Name", style="bold")
    table.add_column("Docs", justify="right")
    table.add_column("Chunks", justify="right")
    table.add_column("Indexed")
    table.add_column("Created")

    for c in cols:
        table.add_row(
            c.id,
            c.name,
            str(c.document_count),
            str(c.chunk_count),
            "✅" if c.is_indexed else "❌",
            c.created_at.strftime("%Y-%m-%d %H:%M"),
        )

    console.print(table)


@app_cli.command("ingest")
def ingest(
    collection_id: str = typer.Argument(..., help="Collection ID"),
    files: list[Path] = typer.Argument(..., help="Files to ingest"),
):
    """Upload and index one or more documents into a collection."""
    db = _db()
    col = _get_collection(db, collection_id)
    ingestor = IngestionService()

    for fp in files:
        if not fp.exists():
            console.print(f"[red]File not found: {fp}[/red]")
            continue

        content = fp.read_bytes()
        doc_id = str(uuid.uuid4())

        with console.status(f"Ingesting [bold]{fp.name}[/bold]…"):
            try:
                file_path = save_upload(collection_id, doc_id, fp.name, content)
                chunk_count = ingestor.ingest_file(collection_id, doc_id, fp.name, content)
            except Exception as exc:
                console.print(f"[red]Failed: {exc}[/red]")
                continue

        ext = fp.suffix.lstrip(".").lower()
        doc = DocumentModel(
            id=doc_id,
            collection_id=collection_id,
            filename=f"{doc_id}_{fp.name}",
            original_filename=fp.name,
            file_type=ext,
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

        console.print(f"[green]✅ {fp.name}[/green] → {chunk_count} chunks")

    db.close()


@app_cli.command("ask")
def ask(
    collection_id: str = typer.Argument(..., help="Collection ID"),
    question: str = typer.Argument(..., help="Your question"),
    conversation_id: Optional[str] = typer.Option(None, "--conversation", "-c", help="Resume a conversation"),
):
    """Ask a question against a collection (supports follow-ups)."""
    db = _db()
    col = _get_collection(db, collection_id)

    if not col.is_indexed:
        console.print("[red]Collection has no indexed documents. Run 'ingest' first.[/red]")
        db.close()
        raise typer.Exit(1)

    # Resolve / create conversation
    if conversation_id:
        convo = db.get(ConversationModel, conversation_id)
        if not convo:
            console.print(f"[red]Conversation '{conversation_id}' not found.[/red]")
            db.close()
            raise typer.Exit(1)
    else:
        title = question[:60] + ("…" if len(question) > 60 else "")
        convo = ConversationModel(
            id=str(uuid.uuid4()),
            collection_id=collection_id,
            title=title,
        )
        db.add(convo)
        db.commit()
        db.refresh(convo)
        console.print(f"[dim]New conversation: {convo.id}[/dim]")

    # Save user message
    db.add(MessageModel(
        id=str(uuid.uuid4()),
        conversation_id=convo.id,
        role="user",
        content=question,
        sources="[]",
    ))
    db.commit()

    # Build history (minus the question we just saved)
    history = [
        {"role": m.role, "content": m.content}
        for m in db.query(MessageModel)
        .filter(MessageModel.conversation_id == convo.id)
        .order_by(MessageModel.created_at)
        .all()[:-1]  # exclude current question
    ]

    agent = RAGAgent.get()

    async def _run():
        full_answer = ""
        sources = []
        console.print(f"\n[bold cyan]Q:[/bold cyan] {question}\n")
        console.print("[bold green]A:[/bold green] ", end="")

        async for event in agent.stream_answer(collection_id, question, history):
            if event["type"] == "token":
                print(event["data"], end="", flush=True)
                full_answer += event["data"]
            elif event["type"] == "source":
                sources.append(event["data"])
            elif event["type"] == "error":
                console.print(f"\n[red]Error: {event['data']}[/red]")

        print()  # newline after streamed answer

        # Show sources
        if sources:
            console.print("\n[dim]── Sources ──────────────────────────────[/dim]")
            for s in sources:
                page = f" p.{s['page_number']}" if s.get("page_number") else ""
                console.print(
                    f"  [cyan]{s['filename']}{page}[/cyan]  "
                    f"[dim](score {s['score']:.3f})[/dim]"
                )
                console.print(f"  [dim]…{s['excerpt'][:120]}…[/dim]\n")

        # Persist assistant message
        db.add(MessageModel(
            id=str(uuid.uuid4()),
            conversation_id=convo.id,
            role="assistant",
            content=full_answer,
            sources=json.dumps(sources),
        ))
        convo.updated_at = datetime.utcnow()
        db.commit()

        console.print(f"\n[dim]Conversation ID: {convo.id}[/dim]")

    asyncio.run(_run())
    db.close()


@app_cli.command("list-conversations")
def list_conversations(
    collection_id: str = typer.Argument(..., help="Collection ID"),
):
    """List all conversations for a collection."""
    db = _db()
    _get_collection(db, collection_id)
    convos = (
        db.query(ConversationModel)
        .filter(ConversationModel.collection_id == collection_id)
        .order_by(ConversationModel.updated_at.desc())
        .all()
    )
    db.close()

    if not convos:
        console.print("[yellow]No conversations yet.[/yellow]")
        return

    table = Table(title="Conversations", show_lines=True)
    table.add_column("ID", style="cyan", max_width=36)
    table.add_column("Title")
    table.add_column("Updated")

    for c in convos:
        table.add_row(c.id, c.title, c.updated_at.strftime("%Y-%m-%d %H:%M"))

    console.print(table)


@app_cli.command("show-conversation")
def show_conversation(
    conversation_id: str = typer.Argument(..., help="Conversation ID"),
):
    """Print all messages in a conversation."""
    db = _db()
    convo = db.get(ConversationModel, conversation_id)
    if not convo:
        console.print(f"[red]Conversation '{conversation_id}' not found.[/red]")
        db.close()
        raise typer.Exit(1)

    messages = (
        db.query(MessageModel)
        .filter(MessageModel.conversation_id == conversation_id)
        .order_by(MessageModel.created_at)
        .all()
    )
    db.close()

    console.print(Panel(f"[bold]{convo.title}[/bold]\nID: {convo.id}", title="Conversation"))

    for m in messages:
        role_label = "[bold cyan]You[/bold cyan]" if m.role == "user" else "[bold green]Agent[/bold green]"
        console.print(f"\n{role_label}  [dim]{m.created_at.strftime('%H:%M')}[/dim]")
        console.print(Markdown(m.content))

        sources = json.loads(m.sources or "[]")
        if sources:
            console.print("[dim]  Sources: " + ", ".join(s["filename"] for s in sources) + "[/dim]")


if __name__ == "__main__":
    app_cli()