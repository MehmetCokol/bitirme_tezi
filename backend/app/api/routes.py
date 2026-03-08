import time
import uuid

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.utils.logger import get_logger
from app.services.caption_service import generate_caption
from app.core import model_registry

router = APIRouter()
logger = get_logger("caption_service")


@router.get("/health")
def health():
    return {"durum": "ok program calisiyor kardes"}


@router.post("/caption")
async def caption(file: UploadFile = File(...)):
    request_id = str(uuid.uuid4())

    logger.info(f"[{request_id}] /caption request received")

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid image file")

    try:
        start_total = time.time()

        image_bytes = await file.read()
        read_time = int((time.time() - start_total) * 1000)

        result = generate_caption(image_bytes)

        total_time = int((time.time() - start_total) * 1000)

        response = {
            "caption_en": result["caption_en"],
            "model_name": model_registry.MODEL_NAME,
            "device": model_registry.device,
            "timings_ms": {
                "read": read_time,
                **result["timings_ms"],
                "total": total_time,
            },
            "request_id": request_id,
        }

        logger.info(f"[{request_id}] caption generated: {response['caption_en']}")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"[{request_id}] caption failed: {e}")
        raise HTTPException(status_code=500, detail="Caption generation failed")