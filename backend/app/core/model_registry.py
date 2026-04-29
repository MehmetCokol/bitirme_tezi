import torch
from transformers import BlipProcessor, BlipForConditionalGeneration
from peft import PeftModel
import os

from app.utils.logger import get_logger

logger = get_logger("model_registry")

MODEL_NAME = "Salesforce/blip-image-captioning-large"
LORA_WEIGHTS_PATH = "./app/models/checkpoint-43935" 

processor = None
model = None
device = None
is_loaded = False

def load_blip_model():
    global processor, model, device, is_loaded

    if is_loaded:
        logger.info(f"Model already loaded | model_name={MODEL_NAME} | device={device}")
        return

    logger.info(f"Model loading started | model_name={MODEL_NAME}")

    device = "cuda" if torch.cuda.is_available() else "cpu"
    logger.info(f"Device selected | device={device}")

    processor = BlipProcessor.from_pretrained(MODEL_NAME)
    
    base_model = BlipForConditionalGeneration.from_pretrained(
        MODEL_NAME,
        torch_dtype=torch.float16 if device == "cuda" else torch.float32
    )

    # QLoRA
    if os.path.exists(LORA_WEIGHTS_PATH):
        logger.info(f"LoRA weights found at {LORA_WEIGHTS_PATH}. Applying adapters...")
        model = PeftModel.from_pretrained(base_model, LORA_WEIGHTS_PATH)
    else:
        logger.error(f"LoRA weights NOT FOUND at {LORA_WEIGHTS_PATH}! Falling back to base model.")
        model = base_model

    model.to(device)
    model.eval()

    is_loaded = True

    logger.info(f"Model loading completed | model_name={MODEL_NAME} | device={device} | loaded={is_loaded}")
    print(f"BLIP device: {device} (QLoRA weights applied)")