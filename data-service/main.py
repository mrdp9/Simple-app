import asyncio
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.startup_complete = False
    app.state.ready = False

    async def initialize_service():
        startup_delay = float(os.getenv("DATA_SERVICE_STARTUP_DELAY_SECONDS", "0"))
        readiness_delay = float(os.getenv("DATA_SERVICE_READINESS_DELAY_SECONDS", "0"))
        await asyncio.sleep(startup_delay)
        app.state.startup_complete = True
        await asyncio.sleep(readiness_delay)
        app.state.ready = True

    asyncio.create_task(initialize_service())
    yield


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return [{"name": "Tony Stark"}, {"name": "Bruce Banner"}, {"name": "Natasha Romanoff"}]

@app.get("/endpoints", summary="List service endpoints")
def list_endpoints():
    return {
        "docs": "/docs",
        "endpoints": [
            {"path": "/", "purpose": "Returns sample data"},
            {"path": "/health", "purpose": "Liveness check"},
            {"path": "/startup", "purpose": "Startup probe check"},
            {"path": "/ready", "purpose": "Readiness probe check"},
        ],
    }


@app.get("/health", summary="Check whether the service is running")
def health():
    return {"status": "Backend service running"}


@app.get("/startup", summary="Check whether service initialization is complete")
def startup():
    if not app.state.startup_complete:
        raise HTTPException(status_code=503, detail="Service is starting")
    return {"status": "Startup complete"}


@app.get("/ready", summary="Check whether the service can receive traffic")
def ready():
    if not app.state.ready:
        raise HTTPException(status_code=503, detail="Service is not ready")
    return {"status": "Service is ready"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)