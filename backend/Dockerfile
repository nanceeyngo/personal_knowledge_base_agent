FROM python:3.11-slim

# ── System dependencies (Tesseract OCR + Poppler for pdf2image) ───────────────
# This is why we use Docker — the examiner never needs to run apt-get manually.
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-eng \
    poppler-utils \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create persistent data directories
RUN mkdir -p data/uploads chroma_data

# Expose port
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]