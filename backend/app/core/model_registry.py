import torch
from transformers import BlipProcessor, BlipForConditionalGeneration

MODEL_NAME = "Salesforce/blip-image-captioning-base"

processor = None
model = None
device = None
is_loaded = False


def load_blip_model():
    global processor, model, device, is_loaded

    if is_loaded:
        return

    device = "cuda" if torch.cuda.is_available() else "cpu"

    processor = BlipProcessor.from_pretrained(MODEL_NAME)
    model = BlipForConditionalGeneration.from_pretrained(MODEL_NAME)
    model.to(device)
    model.eval()
    print(f"BLIP device: {device}")

    is_loaded = True