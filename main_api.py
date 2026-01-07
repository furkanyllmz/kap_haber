import asyncio
import os
import signal
import subprocess
from enum import Enum
from typing import Dict, Optional, Any

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel

import midas  # Import the new module
import json
from pymongo import MongoClient

# MongoDB Setup
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = os.environ.get("MONGO_DB", "kap_news")
TICKERS_COLLECTION = os.environ.get("TICKERS_COLLECTION", "tickers")
FINANCIALS_DIR = os.environ.get("FINANCIALS_DIR", "./daily_data_kap/financials")

def get_mongo_db():
    client = MongoClient(MONGO_URI)
    return client[MONGO_DB]

app = FastAPI(title="KAP Bot Manager API")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    # Start the Midas background task
    asyncio.create_task(midas.fetch_loop())

import sys

# --- Configuration ---
# Scripts and their default arguments
# Use sys.executable to ensure we use the same python interpreter (venv) as the main process
PYTHON_EXEC = sys.executable

SCRIPTS = {
    "pipeline": {"cmd": [PYTHON_EXEC, "daily_kap_pipeline.py"], "log_file": "pipeline.log"},
    "analyzer": {"cmd": [PYTHON_EXEC, "news_analyze.py"], "log_file": "analyzer.log"},
    "twitterbot": {"cmd": [PYTHON_EXEC, "twitterbot.py"], "log_file": "twitterbot.log"},
    "financials": {"cmd": [PYTHON_EXEC, "fetch_financials.py"], "log_file": "financials.log"},
    "fetch_symbols": {"cmd": [PYTHON_EXEC, "fetch_symbols.py"], "log_file": "fetch_symbols.log"},
    "extract_logos": {"cmd": [PYTHON_EXEC, "extract_logos.py"], "log_file": "extract_logos.log"},
}

# Store process objects: name -> subprocess.Popen
processes: Dict[str, subprocess.Popen] = {}

class ServiceStatus(str, Enum):
    RUNNING = "running"
    STOPPED = "stopped"
    UNKNOWN = "unknown"

class ServiceInfo(BaseModel):
    name: str
    status: ServiceStatus
    pid: Optional[int] = None

# --- Helper Functions ---

def get_process_status(name: str) -> ServiceStatus:
    proc = processes.get(name)
    if proc is None:
        return ServiceStatus.STOPPED
    
    poll = proc.poll()
    if poll is None:
        return ServiceStatus.RUNNING
    else:
        # Process finished but object still in dict
        return ServiceStatus.STOPPED

def start_script(name: str):
    if name not in SCRIPTS:
        raise ValueError(f"Unknown script: {name}")
    
    if get_process_status(name) == ServiceStatus.RUNNING:
        return # Already running
    
    config = SCRIPTS[name]
    cmd = config["cmd"]
    log_file = config["log_file"]
    
    # Open log file
    f = open(log_file, "a", encoding="utf-8")
    
    # Start process (unbuffered output)
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    
    proc = subprocess.Popen(
        cmd,
        stdout=f,
        stderr=subprocess.STDOUT,
        env=env,
        cwd=os.getcwd()
    )
    processes[name] = proc

def stop_script(name: str):
    proc = processes.get(name)
    if proc:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
        del processes[name]

def tail_file(filepath: str, n: int = 100) -> str:
    if not os.path.exists(filepath):
        return ""
    try:
        # Use simple tail command for efficiency
        result = subprocess.run(["tail", "-n", str(n), filepath], capture_output=True, text=True)
        return result.stdout
    except Exception as e:
        return f"Error reading log: {e}"

# --- Endpoints ---

@app.get("/company/{symbol}")
def get_company_details(symbol: str):
    """
    Get detailed info for a company:
    - Name (from MongoDB tickers)
    - Financials (from local JSON)
    """
    symbol = symbol.upper().strip()
    
    # 1. Get name from MongoDB
    db = get_mongo_db()
    ticker_doc = db[TICKERS_COLLECTION].find_one({"_id": symbol})
    
    company_name = symbol # Default
    if ticker_doc and "original_text" in ticker_doc:
        company_name = ticker_doc["original_text"]

    # 2. Get financials from JSON file
    financials_path = os.path.join(FINANCIALS_DIR, f"{symbol}, {company_name}_financials.json")
    # Also try simple symbol format in case naming varies
    if not os.path.exists(financials_path):
         financials_path = os.path.join(FINANCIALS_DIR, f"{symbol}_financials.json")
         
    financials_data = {}
    if os.path.exists(financials_path):
        try:
            with open(financials_path, "r", encoding="utf-8") as f:
                financials_data = json.load(f)
        except Exception as e:
            print(f"Error reading financials for {symbol}: {e}")
            
    return {
        "symbol": symbol,
        "name": company_name,
        "financials": financials_data
    }

@app.get("/")
def root():
    return {"message": "KAP Bot Manager API is Running"}

@app.get("/midas")
def get_midas_data():
    """Return the latest fetched Midas data."""
    return midas.get_stored_data()

@app.get("/services", response_model=list[ServiceInfo])
def list_services():
    """List status of all managed services."""
    results = []
    for name in SCRIPTS.keys():
        status = get_process_status(name)
        pid = processes[name].pid if status == ServiceStatus.RUNNING else None
        results.append(ServiceInfo(name=name, status=status, pid=pid))
    return results

@app.post("/services/{name}/start")
def start_service(name: str):
    """Start a specific service."""
    if name not in SCRIPTS:
        raise HTTPException(status_code=404, detail="Service not found")
    try:
        start_script(name)
        return {"status": "started", "name": name}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/services/{name}/stop")
def stop_service(name: str):
    """Stop a specific service."""
    if name not in SCRIPTS:
        raise HTTPException(status_code=404, detail="Service not found")
    try:
        stop_script(name)
        return {"status": "stopped", "name": name}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/services/{name}/logs")
def get_service_logs(name: str, lines: int = 50):
    """Get last N lines of logs for a service."""
    if name not in SCRIPTS:
        raise HTTPException(status_code=404, detail="Service not found")
    
    log_file = SCRIPTS[name]["log_file"]
    content = tail_file(log_file, n=lines)
    return {"name": name, "lines": lines, "content": content}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
