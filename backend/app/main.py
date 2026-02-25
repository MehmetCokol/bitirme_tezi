from fastapi import FastAPI
from app.api.routes import router as api_router

app = FastAPI(title="Caption API", version="1.0")
app.include_router(api_router)