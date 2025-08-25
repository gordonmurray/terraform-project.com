import os, io, uuid, re, time, logging, json, boto3
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Depends
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pypdf import PdfReader
from bs4 import BeautifulSoup
import mysql.connector as mysql
from mysql.connector import Error as MySQLError
import requests
from passlib.context import CryptContext

crypt_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_db_config():
    """Retrieves DB configuration from AWS Secrets Manager."""
    secret_name = "rds_admin_password"
    region_name = "eu-west-1"

    try:
        session = boto3.session.Session()
        client = session.client(
            service_name='secretsmanager',
            region_name=region_name
        )
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
        secret = json.loads(get_secret_value_response['SecretString'])

        return dict(
            host=secret['host'],
            port=int(secret['port']),
            user=secret['username'],
            password=secret['password'],
            database=secret['dbname'],
        )
    except Exception as e:
        logging.error(f"Error retrieving secret '{secret_name}' from Secrets Manager in region {region_name}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve database credentials.")

DB_CFG = get_db_config()
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:0.5b-instruct")
MAX_INPUT_CHARS = int(os.getenv("MAX_INPUT_CHARS", "20000"))
UPLOAD_DIR = "/app/data/uploads"

app = FastAPI(title="Doc Summarizer Demo")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

def get_db():
    "Establishes a database connection."
    last_err = None
    for _ in range(30):  # ~30s total
        try:
            conn = mysql.connect(**DB_CFG, connection_timeout=5)
            try:
                yield conn
            finally:
                try:
                    conn.close()
                except Exception:
                    pass
            return
        except MySQLError as e:
            last_err = e
            time.sleep(1)
    logging.error(f"DB not reachable: {last_err}")
    raise HTTPException(status_code=500, detail=f"DB not reachable: {last_err}")

def _clean_text(s: str) -> str:
    """Removes redundant whitespace from a string."""
    return re.sub(r"\s+", " ", s or "").strip()

def extract_text(name: str, content: bytes) -> str:
    """Extracts text from a file based on its extension."""
    ext = name.split(".")[-1].lower() if "." in name else ""
    if ext in ["txt", "md"]:
        return content.decode(errors="ignore")
    if ext in ["html", "htm"]:
        soup = BeautifulSoup(content, "html.parser")
        return soup.get_text(separator=" ")
    if ext == "pdf":
        reader = PdfReader(io.BytesIO(content))
        return " ".join((p.extract_text() or "") for p in reader.pages)
    return content.decode(errors="ignore")

def summarize(text: str) -> str:
    """Summarizes a text using a local LLM."""
    num_thread   = int(os.getenv("OLLAMA_THREADS", "2"))      # t3.large = 2 vCPU
    num_predict  = int(os.getenv("OLLAMA_NUM_PREDICT", "80"))  # cap output tokens
    num_ctx      = int(os.getenv("OLLAMA_NUM_CTX", "1024"))    # small context for speed
    temperature  = float(os.getenv("OLLAMA_TEMPERATURE", "0.2"))
    top_p        = float(os.getenv("OLLAMA_TOP_P", "0.9"))

    prompt = (
        "You are a concise technical summarizer.\n"
        "Return 3-5 short bullets highlighting purpose, key points, metrics, and any actions.\n"
        "Text:\n"
        f"{text[:MAX_INPUT_CHARS]}"
    )

    payload = {
        "model": OLLAMA_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "num_thread":  num_thread,
            "num_predict": num_predict,
            "num_ctx":     num_ctx,
            "temperature": temperature,
            "top_p":       top_p,
        },
    }

    r = requests.post(f"{OLLAMA_URL}/api/generate", json=payload, timeout=120)
    r.raise_for_status()
    return r.json().get("response", "").strip()

@app.post("/api/login")
def login(username: str = Form(...), password: str = Form(...), db=Depends(get_db)):
    """Authenticates a user."""
    cur = db.cursor(dictionary=True)
    cur.execute(
        "SELECT id, username, hashed_password FROM users WHERE username=%s",
        (username,),
    )
    row = cur.fetchone()
    if not row:
        raise HTTPException(401, "Invalid credentials")

    hashed_password_from_db = row["hashed_password"]
    logging.info(f"Hashed password from DB: {hashed_password_from_db}")

    is_valid = crypt_context.verify(password, hashed_password_from_db)
    logging.info(f"Password verification result for user {username}: {is_valid}")

    if not is_valid:
        logging.warning(f"Invalid password for user: {username}")
        raise HTTPException(401, "Invalid credentials")

    return {"ok": True, "user": {"id": row["id"], "username": row["username"]}}

@app.get("/api/documents")
def list_documents(db=Depends(get_db)):
    """Lists all documents in the database."""
    cur = db.cursor(dictionary=True)
    cur.execute(
        "SELECT id, filename, content_type, size_bytes, created_at "
        "FROM documents ORDER BY created_at DESC"
    )
    return {"items": cur.fetchall()}

@app.post("/api/upload")
def upload(file: UploadFile = File(...), db=Depends(get_db)):
    """Uploads a file and returns a summary."""
    content = file.file.read()
    if not content:
        raise HTTPException(400, "Empty file")

    os.makedirs(UPLOAD_DIR, exist_ok=True)
    stored_name = f"{uuid.uuid4()}_{file.filename}"
    path = os.path.join(UPLOAD_DIR, stored_name)
    with open(path, "wb") as f:
        f.write(content)

    cur = db.cursor()
    cur.execute(
        "INSERT INTO documents (filename, content_type, stored_name, size_bytes) "
        "VALUES (%s,%s,%s,%s)",
        (file.filename, file.content_type or "application/octet-stream", stored_name, len(content)),
    )
    db.commit()
    doc_id = cur.lastrowid

    text = _clean_text(extract_text(file.filename, content))
    summary = "(Not enough text extracted to summarize.)" if len(text) < 50 else summarize(text)

    return JSONResponse({"id": doc_id, "filename": file.filename, "summary": summary})

@app.get("/api/document/{doc_id}/summary")
def resummarize(doc_id: int, db=Depends(get_db)):
    """Re-summarizes a document."""
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT stored_name, filename FROM documents WHERE id=%s", (doc_id,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(404, "Not found")
    path = os.path.join(UPLOAD_DIR, row["stored_name"])
    with open(path, "rb") as f:
        content = f.read()
    text = _clean_text(extract_text(row["filename"], content))
    return {"summary": "(Not enough text extracted to summarize.)" if len(text) < 50 else summarize(text)}

@app.delete("/api/document/{doc_id}")
def delete_document(doc_id: int, db=Depends(get_db)):
    """Deletes a document."""
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT stored_name FROM documents WHERE id=%s", (doc_id,))
    row = cur.fetchone()
    if row:
        path = os.path.join(UPLOAD_DIR, row["stored_name"])
        if os.path.exists(path):
            os.remove(path)
        cur.execute("DELETE FROM documents WHERE id=%s", (doc_id,))
        db.commit()
    return {"ok": True}

@app.get("/health")
def health():
    """Returns a health check."""
    return {"status": "healthy", "service": "doc-summarizer-api"}

# This serves / (index.html) and relative assets like /styles.css, /app.js
app.mount("/", StaticFiles(directory="/app/web", html=True), name="static")
