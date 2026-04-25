import time
import uuid

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.utils.logger import get_logger
from app.services.caption_service import generate_caption
from app.services.translation_service import translate_to_turkish
from app.core import model_registry

router = APIRouter()
logger = get_logger("caption_service")


@router.get("/health")
def health():
    logger.info(
        f"/health check | model_name={model_registry.MODEL_NAME} | device={model_registry.device} | loaded={model_registry.is_loaded}"
    )

    return {
        "status": "ok program çalisiyor",
        "service": "Caption Servisi",
        "model_name": model_registry.MODEL_NAME,
        "device": model_registry.device,
        "loaded": model_registry.is_loaded,
    }


@router.post("/caption")
async def caption(file: UploadFile = File(...)):
    request_id = str(uuid.uuid4())

    logger.info(
        f"[{request_id}] /caption request received | filename={file.filename} | content_type={file.content_type}"
    )

    if not file.content_type or not file.content_type.startswith("image/"):
        logger.warning(
            f"[{request_id}] invalid file type | filename={file.filename} | content_type={file.content_type}"
        )
        raise HTTPException(status_code=400, detail="Invalid image file")

    try:
        start_total = time.time()

        image_bytes = await file.read()
        read_time = int((time.time() - start_total) * 1000)
        file_size = len(image_bytes)

        logger.info(
            f"[{request_id}] file read completed | size_bytes={file_size} | read_ms={read_time}"
        )

        result = generate_caption(image_bytes)

        translation_result = await translate_to_turkish(
            result["caption_en"],
            request_id=request_id
        )

        total_time = int((time.time() - start_total) * 1000)

        response = {
            "caption_en": result["caption_en"],
            "caption_tr": translation_result["caption_tr"],
            "translation_provider": translation_result["translation_provider"],
            "model_name": model_registry.MODEL_NAME,
            "device": model_registry.device,
            "timings_ms": {
                "read": read_time,
                **result["timings_ms"],
                "translation": translation_result["translation_ms"],
                "total": total_time,
            },
            "request_id": request_id,
        }

        logger.info(
            f"[{request_id}] caption completed | "
            f"model_name={model_registry.MODEL_NAME} | "
            f"device={model_registry.device} | "
            f"translation_provider={response['translation_provider']} | "
            f"total_ms={total_time} | "
            f"caption_en={response['caption_en']} | "
            f"caption_tr={response['caption_tr']}"
        )

        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"[{request_id}] caption failed: {e}")
        raise HTTPException(status_code=500, detail="Caption generation failed")