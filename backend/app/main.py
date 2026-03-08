from fastapi import FastAPI

from app.api.routes import router as api_router
from app.core.model_registry import load_blip_model

app = FastAPI(title="Caption API", version="2.0")


@app.on_event("startup")
def startup_event():
    load_blip_model()


app.include_router(api_router)