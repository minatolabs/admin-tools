import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel

from .parser import parse_text, check_ollama_health
from .rules import generate_checklist

app = FastAPI(title="AssistAI", description="IT Onboarding Assistant")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

WEB_DIR = os.path.join(os.path.dirname(__file__), "..", "web")


class ParseRequest(BaseModel):
    text: str
    hire_type_override: str | None = None


@app.post("/api/parse")
async def api_parse(req: ParseRequest):
    if not req.text or not req.text.strip():
        raise HTTPException(status_code=400, detail="No text provided")

    parsed = await parse_text(req.text)

    if req.hire_type_override and req.hire_type_override.upper() in ("RNH", "CNH"):
        parsed["hire_type"] = req.hire_type_override.upper()

    checklist = generate_checklist(parsed)
    return checklist


@app.get("/api/health")
async def api_health():
    ollama_ok = await check_ollama_health()
    return {
        "status": "ok",
        "ollama": "connected" if ollama_ok else "unavailable",
    }


app.mount("/static", StaticFiles(directory=WEB_DIR), name="static")


@app.get("/")
async def serve_index():
    return FileResponse(os.path.join(WEB_DIR, "index.html"))


@app.get("/{path:path}")
async def serve_web(path: str):
    file_path = os.path.join(WEB_DIR, path)
    if os.path.isfile(file_path):
        return FileResponse(file_path)
    return FileResponse(os.path.join(WEB_DIR, "index.html"))
