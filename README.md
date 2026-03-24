# RAG Knowledge Agent

A full-stack personal knowledge base AI agent. Upload your documents, ask questions in natural language, and receive answers grounded in your own files — with source references and token-by-token streaming.

**Built with:** LangChain · FastAPI · ChromaDB · Flutter · OpenRouter · HuggingFace Embeddings

---

## Repository Structure

```
rag-knowledge-agent/
├── backend/                  ← FastAPI + LangChain RAG backend
│   ├── app/
│   │   ├── api/              ← Route handlers (collections, documents, chat, health)
│   │   ├── core/             ← Config, environment variables
│   │   ├── db/               ← SQLite models and database init
│   │   ├── models/           ← Pydantic schemas
│   │   └── services/         ← Embeddings, vector store, ingestion, RAG agent
│   ├── evals/
│   │   └── run_evals.py      ← Automated evaluation script (5 Q&A pairs)
│   ├── data/                 ← Uploaded files (created at runtime, git-ignored)
│   ├── chroma_data/          ← ChromaDB persistence (created at runtime, git-ignored)
│   ├── main.py               ← FastAPI entry point
│   ├── cli.py                ← Command-line interface (bonus)
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
├── frontend/
│   └── flutter_app/          ← Flutter mobile application (Android)
│       ├── lib/
│       │   ├── core/         ← Config, Dio client, theme, exceptions
│       │   ├── models/       ← Data models
│       │   ├── providers/    ← Riverpod state management
│       │   ├── repositories/ ← API call layer
│       │   ├── screens/      ← UI screens
│       │   ├── widgets/      ← Reusable UI components
│       │   └── main.dart
│       ├── android/
│       └── pubspec.yaml
├── docker-compose.yml        ← Run entire backend with one command
├── .gitignore
└── README.md                 ← This file
```

---

## Prerequisites

### Backend
Choose **one** of these two approaches:

**Option A — Docker (Recommended, zero system setup)**
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

**Option B — Manual Python**
- Python 3.11 or higher
- pip
- System packages for OCR support (optional — only needed for scanned PDFs and images):
  ```bash
  # Ubuntu / Debian / WSL
  sudo apt-get install tesseract-ocr tesseract-ocr-eng poppler-utils

  # macOS
  brew install tesseract poppler
  ```
  > If you skip OCR packages, the app still works for all text-based PDFs, TXT, and MD files. Only scanned image documents require Tesseract.

### Frontend
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.0 or higher
- Android Studio (recommended) or VS Code with Flutter extension
- Android emulator or physical Android device
- USB debugging enabled (for physical device)

---

## Backend Setup and Running

### Step 1 — Get your OpenRouter API key
1. Go to [https://openrouter.ai/keys](https://openrouter.ai/keys)
2. Sign up and create a free API key
3. Copy the key — you will need it in Step 3

### Step 2 — Clone and navigate
```bash
git clone https://github.com/YOUR_USERNAME/rag-knowledge-agent.git
cd rag-knowledge-agent
```

### Step 3 — Create your environment file
```bash
cd backend
cp .env.example .env
```

Open `backend/.env` in any text editor and fill in your values:
```env
OPENROUTER_API_KEY=sk-or-your-key-here
MODEL_NAME=openai/gpt-4o-mini
```

All other values have sensible defaults and do not need to be changed.

**Recommended free/cheap models on OpenRouter:**
| Model | Notes |
|---|---|
| `openai/gpt-4o-mini` | Best quality, very cheap |
| `mistralai/mistral-7b-instruct:free` | Free tier |
| `google/gemma-2-9b-it:free` | Free tier |
| `anthropic/claude-3-haiku` | Fast, low cost |

---

### Option A — Run with Docker (Recommended)

Docker automatically installs Tesseract, Poppler, and all Python dependencies inside the container. You do not need to install anything else.

```bash
# From the repository root
cd ..   # make sure you are in rag-knowledge-agent/ (repo root)

docker-compose up --build
```

The backend will be available at: **http://localhost:8000**

To stop: press `Ctrl+C`, then run `docker-compose down`

To restart without rebuilding: `docker-compose up`

---

### Option B — Run Manually (Local Python)

```bash
# Make sure you are inside the backend/ directory
cd backend

# Create and activate a virtual environment
python3 -m venv venv

# Activate — Linux / macOS
source venv/bin/activate

# Activate — Windows
venv\Scripts\activate

# Install all Python dependencies
pip install -r requirements.txt

# Start the backend server
uvicorn main:app --reload
```

The backend will be available at: **http://127.0.0.1:8000**

> **Important:** Always run `uvicorn` from inside the `backend/` directory, not from the repo root. The command must be run with the virtual environment activated.

---

### Verify the backend is running

Open your browser and go to:
- **http://127.0.0.1:8000/health** — should return `{"status": "ok", ...}`
- **http://127.0.0.1:8000/docs** — Swagger UI with all API endpoints

> **Note on first startup:** The HuggingFace embedding model (`all-MiniLM-L6-v2`, ~90MB) is downloaded automatically on first run and cached locally. This takes 1–3 minutes on the first start only. Subsequent starts are fast.

---

## Flutter Frontend Setup and Running

### Step 1 — Navigate to the Flutter project
```bash
cd frontend/flutter_app
```

### Step 2 — Install Flutter dependencies
```bash
flutter pub get
```

### Step 3 — Start an emulator or connect a device

**Android emulator (via Android Studio):**
1. Open Android Studio
2. Go to `Device Manager` (right sidebar or `Tools > Device Manager`)
3. Click the play button next to any available emulator
4. Wait for it to fully boot

**Physical Android device:**
1. Enable `Developer Options` on your device (tap `Build Number` 7 times in Settings > About Phone)
2. Enable `USB Debugging` in Developer Options
3. Connect via USB
4. Accept the "Allow USB debugging" prompt on your device

### Step 4 — Confirm your device is detected
```bash
flutter devices
```
You should see your emulator or device listed.

### Step 5 — Configure the backend URL

Open `frontend/flutter_app/lib/core/config.dart`:

```dart
// For Android emulator (default — no change needed)
static const String defaultBaseUrl = 'http://10.0.2.2:8000';

// For a physical device on the same WiFi network, change to your machine's local IP:
static const String defaultBaseUrl = 'http://192.168.1.YOUR_IP:8000';

// For Railway deployment, change to your Railway URL:
static const String defaultBaseUrl = 'https://your-app.railway.app';
```

> `10.0.2.2` is the Android emulator's special alias for the host machine's `localhost`. If using the Android emulator with the backend running locally, the default value works without any change.

> To find your machine's local IP on Windows: run `ipconfig` in Command Prompt and look for `IPv4 Address`. On macOS/Linux: run `ifconfig` or `ip addr`.

## ⚠️ Web (Browser) Usage Notice

This application is **primarily built for mobile (Android/iOS)** and is not fully supported on web browsers (e.g., Chrome).

### If you run the app on web:

- Update the API base URL in settings:
  - Replace `10.0.2.2` with `localhost`  
    Example: `http://localhost:8000`
  - This allows the frontend to communicate with the backend when running locally

### Limitations on Web

- ❌ **File uploads are not supported**
  - The `file_picker` package behaves differently on web
  - It returns **file bytes instead of file paths**, which is incompatible with the current upload implementation

### Summary

- ✅ Chat functionality may work (after updating base URL)
- ❌ Document upload will not work

> For full functionality, please run the app on an Android or iOS device/emulator.

### Step 6 — Run the app
```bash
flutter run
```

The app will build and launch on your connected device or emulator.

**Alternative — Run from Android Studio:**
1. Open `frontend/flutter_app/` as a project in Android Studio
2. Select your device from the device dropdown at the top
3. Click the green Run button (▶)

---

## Using the App

### Full workflow:

1. **Create a knowledge base** — tap `New Collection`, enter a name (e.g. "Research Papers"), tap Create
2. **Upload documents** — you are taken directly to the document screen. Tap the upload area to pick files from your device (PDF, TXT, MD, PNG, JPG supported)
3. **Wait for indexing** — documents are chunked, embedded, and stored in ChromaDB. A progress indicator shows upload status
4. **Start chatting** — tap the back arrow to return to the collection, tap it to open the chat screen
5. **Ask questions** — type your question and press Enter (or tap the send button). The answer streams token by token with source references shown below
6. **Follow-up questions** — just keep typing. The agent maintains full conversation context
7. **View conversation history** — tap the history icon (🕐) in the top-right to see and resume past conversations
8. **Switch collections** — tap the back arrow to return to the collections list and select a different knowledge base

### Theme toggle:
Tap the sun/moon icon in the top-right of the collections screen to switch between light and dark theme.

### Change backend URL:
Tap the settings icon (⚙) in the top-right of the collections screen and update the Backend URL field.

---

## API Reference (Backend)

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `POST` | `/collections` | Create a new collection |
| `GET` | `/collections` | List all collections |
| `GET` | `/collections/{id}` | Get a single collection |
| `DELETE` | `/collections/{id}` | Delete a collection and all its data |
| `POST` | `/collections/{id}/documents` | Upload a document (single file) |
| `POST` | `/collections/{id}/documents/batch` | Upload multiple files |
| `GET` | `/collections/{id}/documents` | List documents in a collection |
| `DELETE` | `/collections/{id}/documents/{doc_id}` | Delete a document |
| `POST` | `/collections/{id}/reindex` | Re-embed all documents |
| `POST` | `/collections/{id}/chat` | Chat — streams SSE response |
| `GET` | `/collections/{id}/conversations` | List conversations |
| `GET` | `/conversations/{conv_id}` | Get all messages in a conversation |
| `DELETE` | `/conversations/{conv_id}` | Delete a conversation |

Full interactive documentation: **http://localhost:8000/docs**

---

## CLI Usage (Bonus Feature)

The backend includes a full command-line interface. With the virtual environment activated:

```bash
cd backend
source venv/bin/activate   # or venv\Scripts\activate on Windows

# Create a new collection
python cli.py new-collection "My Research Papers" --desc "Academic articles"

# List all collections
python cli.py list-collections

# Ingest documents (outputs the collection ID you will need)
python cli.py ingest <collection_id> path/to/document.pdf path/to/notes.md

# Ask a question (streams the answer in the terminal)
python cli.py ask <collection_id> "What are the main findings?"

# Ask a follow-up in the same conversation
python cli.py ask <collection_id> "Can you elaborate?" --conversation <conversation_id>

# List all conversations for a collection
python cli.py list-conversations <collection_id>

# View full message history of a conversation
python cli.py show-conversation <conversation_id>
```

---

## Running the Evaluation Suite

The evaluation suite tests the RAG agent against 5 ground-truth Q&A pairs and reports a pass/fail score.

### Step 1 — Make sure the backend is running
```bash
# In one terminal:
cd backend
source venv/bin/activate
uvicorn main:app --port 8000
```

### Step 2 — Create a collection and upload your test documents
You can do this via the Flutter app, the Swagger UI at `http://localhost:8000/docs`, or the CLI:
```bash
python cli.py new-collection "Eval Test"
python cli.py ingest <collection_id> path/to/your/test_document.pdf
```

### Step 3 — Get your collection ID
```bash
python cli.py list-collections
# Copy the ID column value for your collection
```

### Step 4 — Configure the evaluation questions

Open `backend/evals/run_evals.py` and update the `EVAL_CASES` list with questions and expected keywords that match your uploaded test documents:

```python
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
```

> `expected_keywords` are lowercase strings that must appear in the agent's answer for the question to pass. Leave the list empty (`[]`) and the eval will pass as long as the answer is non-empty and includes a source citation.

### Step 5 — Run the evaluation
```bash
cd backend
source venv/bin/activate   # or venv\Scripts\activate on Windows

python evals/run_evals.py --collection <your_collection_id>
```

**Sample output:**
```
Running evals against collection: ae16cd52-...
API: http://localhost:8000

RAG Agent Evaluation Report  —  5/5 passed

┌─────┬──────────────────────────────┬──────────┬────────┬────────┐
│ ID  │ Description                  │ KW Score │ Source │ Result │
├─────┼──────────────────────────────┼──────────┼────────┼────────┤
│ Q1  │ Broad overview question      │  100%    │  ✅    │  PASS  │
│ Q2  │ Key findings extraction      │  100%    │  ✅    │  PASS  │
│ Q3  │ Factual extraction           │  80%     │  ✅    │  PASS  │
│ Q4  │ Entity recognition           │  100%    │  ✅    │  PASS  │
│ Q5  │ Recommendation extraction    │  60%     │  ✅    │  PASS  │
└─────┴──────────────────────────────┴──────────┴────────┴────────┘
```

**Run against a deployed backend:**
```bash
python evals/run_evals.py --collection <id> --base-url https://your-app.railway.app
```

### Scoring criteria
Each question is scored on two criteria:
- **Keyword recall** — the fraction of `expected_keywords` that appear in the answer (must be ≥ 50% to pass)
- **Source cited** — the agent must return at least one source document reference

A question **passes** when both criteria are met.

---

## Deploying to Railway (Production)

Railway is the recommended hosting platform for the backend.

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# From the backend directory
cd backend
railway init
railway up
```

**Required Railway settings:**
1. Set **Root Directory** to `backend/`
2. Add environment variables in the Railway dashboard:
   - `OPENROUTER_API_KEY` = your key
   - `MODEL_NAME` = `openai/gpt-4o-mini`
3. Add a **Volume** mounted at `/app/chroma_data` — this persists your vector database across deployments
4. Add a **Volume** mounted at `/app/data` — this persists uploaded files

Once deployed, update `frontend/flutter_app/lib/core/config.dart` with your Railway URL and rebuild the Flutter app.

---

## Environment Variables Reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENROUTER_API_KEY` | ✅ Yes | — | Your OpenRouter API key |
| `MODEL_NAME` | ✅ Yes | `openai/gpt-4o-mini` | LLM model name on OpenRouter |
| `EMBED_MODEL_NAME` | No | `sentence-transformers/all-MiniLM-L6-v2` | HuggingFace embedding model |
| `CHROMA_PERSIST_DIRECTORY` | No | `./chroma_data` | ChromaDB storage path |
| `SQLITE_DB_PATH` | No | `./data/rag.db` | SQLite database path |
| `RAG_DATA_DIR` | No | `./data/uploads` | Uploaded files directory |
| `CHUNK_SIZE` | No | `500` | Characters per text chunk |
| `CHUNK_OVERLAP` | No | `50` | Overlap between chunks |
| `MAX_CHUNKS_RETRIEVED` | No | `5` | Chunks retrieved per query |
| `PORT` | No | `8000` | Server port |

---

## Troubleshooting

**`Error loading ASGI app. Could not import module "main"`**
You are running `uvicorn` from the wrong directory. Always run it from inside `backend/`:
```bash
cd backend
uvicorn main:app --reload
```

**`Connection refused` in the Flutter app**
- Confirm the backend is running: visit `http://localhost:8000/health` in your browser
- If using an Android emulator, the URL must be `http://10.0.2.2:8000` (not `localhost`)
- If using a physical device, use your machine's local IP address (find it with `ipconfig` on Windows or `ifconfig` on Mac/Linux)
- Check the backend URL in the app settings (⚙ icon on the collections screen)

**`Collection not found` when using Swagger**
Do not type a name into the `collection_id` field. You must first create a collection via `POST /collections`, then copy the UUID from the response and paste it into subsequent requests. Call `GET /collections` at any time to retrieve all existing collection IDs.

**HuggingFace model download is very slow**
The embedding model (~90MB) downloads once on first startup. Wait 2–5 minutes. It will not download again on subsequent runs.

**`ChromaDB` errors after changing `EMBED_MODEL_NAME`**
The existing vectors are incompatible with a different embedding model. Delete the old data and re-ingest:
```bash
rm -rf backend/chroma_data/
```
Then restart the server and re-upload your documents.

**OCR not working on scanned PDFs**
Install the system-level dependencies:
```bash
# Ubuntu/Debian/WSL
sudo apt-get install tesseract-ocr tesseract-ocr-eng poppler-utils

# macOS
brew install tesseract poppler
```
Or use Docker (Option A) which includes these automatically.

**`flutter pub get` fails**
Ensure Flutter SDK is correctly installed and `flutter` is in your PATH:
```bash
flutter doctor
```
Fix any issues reported by `flutter doctor` before proceeding.

---

## Tech Stack Summary

| Component | Technology |
|---|---|
| Backend framework | FastAPI |
| Agent framework | LangChain |
| LLM provider | OpenRouter (any model) |
| Embeddings | HuggingFace `all-MiniLM-L6-v2` (local, no API key needed) |
| Vector store | ChromaDB (persistent) |
| Metadata database | SQLite via SQLAlchemy |
| Text chunking | LangChain `RecursiveCharacterTextSplitter` |
| PDF parsing | PyMuPDF |
| OCR | Tesseract + pytesseract |
| Streaming | Server-Sent Events (SSE) |
| Frontend | Flutter (Android) |
| State management | Riverpod |
| HTTP client | Dio |
| Containerisation | Docker + docker-compose |