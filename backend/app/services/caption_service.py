import io
import time
from PIL import Image
import torch

from app.core import model_registry

def generate_caption(image_bytes: bytes):
    if not model_registry.is_loaded:
        raise RuntimeError("BLIP model is not loaded.")

    start_pre = time.time()
    
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    
    inputs = model_registry.processor(images=image, return_tensors="pt")
    inputs = {k: v.to(model_registry.device, dtype=torch.float16 if k == "pixel_values" else None) for k, v in inputs.items()}

    preprocess_time = int((time.time() - start_pre) * 1000)
    
    start_gen = time.time()

    with torch.no_grad():
        output = model_registry.model.generate(
            **inputs, 
            max_new_tokens=40,
            num_beams=3
        )
    
    caption = model_registry.processor.decode(output[0], skip_special_tokens=True)
    
    generate_time = int((time.time() - start_gen) * 1000)

    return {
        "caption_en": caption,
        "timings_ms": {
            "preprocess": preprocess_time,
            "generate": generate_time,
        },
    }