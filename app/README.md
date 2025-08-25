# Document Summary Demo

A web application that uses Llama 3.2 (1B parameter) local model to automatically summarize uploaded documents. Built with FastAPI backend, MariaDB database, and Ollama for local LLM inference.

## Features

- Upload documents (PDF, HTML, TXT, MD)
- Automatic text extraction and summarization using Llama 3.2:1b
- User authentication with bcrypt password hashing
- Document management and re-summarization
- Web interface for file upload and viewing summaries

## Quick Start

### Prerequisites
- Docker and Docker Compose
- At least 2GB RAM for the Llama model

### Running the Application

1. Start all services:
```bash
docker compose up -d
```

2. The application will:
   - Pull the Llama 3.2:1b model (first run only, ~1.3GB download)
   - Initialize MariaDB with demo schema
   - Start the API server on port 8000

3. Access the web interface at: http://localhost:8000

### Services

- **API**: FastAPI application (port 8000)
- **Database**: MariaDB 11.4.5 with demo user/database
- **Ollama**: Local LLM inference server (port 11434)
- **Model**: Llama 3.2:1b automatically pulled on first run

### Development

To view logs:
```bash
docker compose logs -f
```

To rebuild after code changes:
```bash
docker compose up --build
```

To stop all services:
```bash
docker compose down
```