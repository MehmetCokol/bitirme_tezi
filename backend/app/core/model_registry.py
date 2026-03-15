import torch
from transformers import BlipProcessor, BlipForConditionalGeneration

from app.utils.logger import get_logger

logger = get_logger("model_registry")

MODEL_NAME = "Salesforce/blip-image-captioning-large"

processor = None
model = None
device = None
is_loaded = False


def load_blip_model():
    global processor, model, device, is_loaded

    if is_loaded:
        logger.info(
            f"Model already loaded | model_name={MODEL_NAME} | device={device}"
        )
        return

    logger.info(f"Model loading started | model_name={MODEL_NAME}")

    device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Device selected | device={device}")

    processor = BlipProcessor.from_pretrained(MODEL_NAME)
    model = BlipForConditionalGeneration.from_pretrained(MODEL_NAME)
    model.to(device)
    model.eval()

    is_loaded = True

    logger.info(
        f"Model loading completed | model_name={MODEL_NAME} | device={device} | loaded={is_loaded}"
    )
    print(f"BLIP device: {device}")

