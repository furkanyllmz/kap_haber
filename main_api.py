import asyncio
import os
import signal
import subprocess
from enum import Enum
from typing import Dict, Optional, Any

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel

import midas  # Import the new module

app = FastAPI(title="KAP Bot Manager API")

@app.on_event("startup")
async def startup_event():
    # Start the Midas background task
    asyncio.create_task(midas.fetch_loop())

# --- Configuration ---
# Scripts and their default arguments
SCRIPTS = {
    "pipeline": {"cmd": ["python3", "daily_kap_pipeline.py"], "log_file": "pipeline.log"},
    "analyzer": {"cmd": ["python3", "news_analyze.py"], "log_file": "analyzer.log"},
    "twitterbot": {"cmd": ["python3", "twitterbot.py"], "log_file": "twitterbot.log"},
    "financials": {"cmd": ["python3", "fetch_financials.py"], "log_file": "financials.log"},
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
