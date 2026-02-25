from fastapi import APIRouter, UploadFile, File, HTTPException
import time
import uuid

from app.utils.logger import get_logger

router = APIRouter()
logger = get_logger()


@router.get("/health")
def health():
    return {"status": "ok"}


@router.post("/caption")
async def caption(file: UploadFile = File(...)):

    request_id = str(uuid.uuid4())
    start_total = time.time()

    # Content-type kontrolü
    if not file.content_type.startswith("image/"):
        logger.warning(f"request_id={request_id} status=invalid_file")
        raise HTTPException(status_code=400, detail="Invalid image file")

    # Simulated preprocess
    start_pre = time.time()
    await file.read()
    preprocess_time = int((time.time() - start_pre) * 1000)

    # Simulated generation
    start_gen = time.time()
    time.sleep(0.05)
    generate_time = int((time.time() - start_gen) * 1000)

    total_time = int((time.time() - start_total) * 1000)

    # Log satırı
    logger.info(
        f"request_id={request_id} "
        f"preprocess_ms={preprocess_time} "
        f"generate_ms={generate_time} "
        f"total_ms={total_time} "
        f"status=success"
    )

    return {
        "caption_en": "A dummy caption for testing.",
        "model_name": "baseline-dummy",
        "device": "cpu",
        "timings_ms": {
            "preprocess": preprocess_time,
            "generate": generate_time,
            "total": total_time
        },
        "request_id": request_id
    }