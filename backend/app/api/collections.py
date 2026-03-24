"""
/collections  endpoints
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.database import Collection as CollectionModel
from app.models.schemas import CollectionCreate, CollectionOut
from app.services.vectorstore import VectorStoreManager

router = APIRouter(tags=["Collections"])


@router.post("/collections", response_model=CollectionOut, status_code=201)
def create_collection(payload: CollectionCreate, db: Session = Depends(get_db)):
    """Create a new knowledge-base collection."""
    col = CollectionModel(
        id=str(uuid.uuid4()),
        name=payload.name,
        description=payload.description or "",
    )
    db.add(col)
    db.commit()
    db.refresh(col)
    return col


@router.get("/collections", response_model=List[CollectionOut])
def list_collections(db: Session = Depends(get_db)):
    """List all collections."""
    return db.query(CollectionModel).order_by(CollectionModel.created_at.desc()).all()


@router.get("/collections/{collection_id}", response_model=CollectionOut)
def get_collection(collection_id: str, db: Session = Depends(get_db)):
    """Get a single collection by ID."""
    col = db.get(CollectionModel, collection_id)
    if not col:
        raise HTTPException(404, "Collection not found")
    return col


@router.patch("/collections/{collection_id}", response_model=CollectionOut)
def update_collection(collection_id: str, payload: CollectionCreate, db: Session = Depends(get_db)):
    """Update a collection's name or description."""
    col = db.get(CollectionModel, collection_id)
    if not col:
        raise HTTPException(404, "Collection not found")
    col.name = payload.name
    col.description = payload.description or col.description
    col.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(col)
    return col


@router.delete("/collections/{collection_id}", status_code=204)
def delete_collection(collection_id: str, db: Session = Depends(get_db)):
    """Delete a collection and all its data."""
    col = db.get(CollectionModel, collection_id)
    if not col:
        raise HTTPException(404, "Collection not found")
    VectorStoreManager.get().delete_collection(collection_id)
    db.delete(col)
    db.commit()