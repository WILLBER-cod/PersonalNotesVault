from fastapi import FastAPI
from datetime import datetime
from .health import router as health_router

app = FastAPI(
    title="Notes Vault Health API",
    description="Легковесный API для проверки здоровья сервиса",
    version="1.0.0"
)

app.include_router(health_router)

@app.get("/")
async def root():
    return {
        "message": "Notes Vault Health API",
        "docs": "/docs"
    }
