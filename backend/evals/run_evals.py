"""
evals/run_evals.py
──────────────────
Automated evaluation of the RAG agent against 5 ground-truth Q&A pairs.

Setup
-----
1. Start the backend:  uvicorn main:app --port 8000
2. Create a collection and ingest your test documents via the API or CLI.
3. Copy the collection_id into COLLECTION_ID below (or pass via --collection).
4. Run:  python evals/run_evals.py --collection <id>

The script scores each answer on:
  • Keyword recall  - do the expected keywords appear in the answer?
  • Source cited    - did the agent return at least one source reference?
  • Pass / Fail     - keyword recall ≥ threshold AND source cited

Adjust EVAL_CASES to match your actual uploaded documents.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional
import re

import httpx
from rich.console import Console
from rich.table import Table

console = Console()

# ── Configuration ─────────────────────────────────────────────────────────────
BASE_URL = "http://localhost:8000"
KEYWORD_THRESHOLD = 0.5   # fraction of expected keywords that must appear

# ── Evaluation cases ──────────────────────────────────────────────────────────
# Edit these to match the documents you upload for the demo.
# 'expected_keywords' are lowercase strings that must appear in the answer.
EVAL_CASES = [
    {
        "id": "Q1",
        "question": "What is the main topic of the uploaded documents?",
        "expected_keywords": ['power', 'oppression', 'students', 'lived experience'],
        "description": "Broad overview question",
    },
    {
        "id": "Q2",
        "question": "Summarise the key findings or conclusions.",
        "expected_keywords": ['experience', 'service users', 'student engagement','power','oppression'],
        "description": "Summarisation",
    },
    {
        "id": "Q3",
        "question": "What specific data, numbers, or statistics are mentioned?",
        "expected_keywords": ['ethical consideration', 'analysis approach', 'group composition'],
        "description": "Factual extraction",
    },
    {
        "id": "Q4",
        "question": "Who are the main people, organisations, or entities discussed?",
        "expected_keywords": ['researcher', 'module leader', 'lecturer', 'stakeholder groups'],
        "description": "Entity recognition",
    },
    {
        "id": "Q5",
        "question": "What recommendations or next steps are suggested in the documents?",
        "expected_keywords": ['experiential expertise', 'evidence base', 'impact', 'service user',],
        "description": "Recommendation extraction",
    },
]


# ── Eval runner ───────────────────────────────────────────────────────────────

@dataclass
class EvalResult:
    case_id: str
    question: str
    description: str
    answer: str
    sources: List[dict]
    keyword_score: float
    source_cited: bool
    passed: bool
    error: Optional[str] = None


async def run_single(
    client: httpx.AsyncClient,
    collection_id: str,
    case: dict,
) -> EvalResult:
    """Run one eval case via the SSE chat endpoint."""
    payload = {"message": case["question"]}
    answer_parts: List[str] = []
    sources: List[dict] = []
    error: Optional[str] = None

    try:
        async with client.stream(
            "POST",
            f"{BASE_URL}/collections/{collection_id}/chat",
            json=payload,
            timeout=120,
        ) as resp:
            resp.raise_for_status()
            async for line in resp.aiter_lines():
                if not line.startswith("data:"):
                    continue
                raw = line[5:].strip()
                if not raw:
                    continue
                try:
                    event = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                if event["type"] == "token":
                    answer_parts.append(event["data"])
                elif event["type"] == "source":
                    sources.append(event["data"])
                elif event["type"] == "error":
                    error = event["data"]
                    break

    except Exception as exc:
        error = str(exc)

    answer = "".join(answer_parts)

    # Score
    keywords = case.get("expected_keywords", [])
    if keywords:
        answer_lower = answer.lower()
        hits = sum(1 for kw in keywords if kw.lower() in answer_lower)
        keyword_score = hits / len(keywords)
    else:
        # No expected keywords → score 1.0 if answer is non-empty
        keyword_score = 1.0 if answer.strip() else 0.0

    source_cited = len(sources) > 0
    passed = (keyword_score >= KEYWORD_THRESHOLD) and source_cited and not error

    return EvalResult(
        case_id=case["id"],
        question=case["question"],
        description=case["description"],
        answer=answer,
        sources=sources,
        keyword_score=keyword_score,
        source_cited=source_cited,
        passed=passed,
        error=error,
    )


async def run_all(collection_id: str) -> List[EvalResult]:
    async with httpx.AsyncClient() as client:
        tasks = [run_single(client, collection_id, c) for c in EVAL_CASES]
        results = await asyncio.gather(*tasks)
    return list(results)


# ── Report ─────────────────────────────────────────────────────────────────────

def print_report(results: List[EvalResult]) -> None:
    passed = sum(1 for r in results if r.passed)
    total = len(results)

    console.print(f"\n[bold]RAG Agent Evaluation Report[/bold]  –  {passed}/{total} passed\n")

    table = Table(show_lines=True)
    table.add_column("ID", style="cyan")
    table.add_column("Description")
    table.add_column("KW Score", justify="right")
    table.add_column("Source", justify="center")
    table.add_column("Result", justify="center")

    for r in results:
        kw_str = f"{r.keyword_score:.0%}"
        src_str = "✅" if r.source_cited else "❌"
        result_str = "[green]PASS[/green]" if r.passed else "[red]FAIL[/red]"
        table.add_row(r.case_id, r.description, kw_str, src_str, result_str)

    console.print(table)

    # Detailed view
    for r in results:
        status = "[green]✅ PASS[/green]" if r.passed else "[red]❌ FAIL[/red]"
        console.print(f"\n[bold]{r.case_id}[/bold]  {status}")
        console.print(f"[dim]Q:[/dim] {r.question}")
        if r.error:
            console.print(f"[red]Error: {r.error}[/red]")
        else:
            excerpt = r.answer[:300] + ("…" if len(r.answer) > 300 else "")
            console.print(f"[dim]A:[/dim] {excerpt}")
            if r.sources:
                src_names = ", ".join(s["filename"] for s in r.sources[:3])
                console.print(f"[dim]Sources:[/dim] {src_names}")


# ── CLI ────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RAG Agent Evaluation Runner")
    parser.add_argument("--collection", "-c", required=True, help="Collection ID to evaluate against")
    parser.add_argument("--base-url", default=BASE_URL, help=f"API base URL (default: {BASE_URL})")
    args = parser.parse_args()

    BASE_URL = args.base_url.rstrip("/")

    console.print(f"[bold cyan]Running evals against collection:[/bold cyan] {args.collection}")
    console.print(f"[dim]API: {BASE_URL}[/dim]\n")

    results = asyncio.run(run_all(args.collection))
    print_report(results)

    passed = sum(1 for r in results if r.passed)
    sys.exit(0 if passed == len(results) else 1)