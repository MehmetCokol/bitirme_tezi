import os
import time
from typing import Optional

import httpx
from dotenv import load_dotenv

from app.utils.logger import get_logger

load_dotenv()

logger = get_logger("translation_service")

DEEPL_API_KEY = os.getenv("DEEPL_API_KEY")
DEEPL_API_URL = os.getenv("DEEPL_API_URL", "https://api-free.deepl.com/v2/translate")


async def translate_to_turkish(text: str, request_id: Optional[str] = None) -> dict:
    """
    Translates English caption text to Turkish using DeepL API.

    Returns:
        {
            "caption_tr": str | None,
            "translation_provider": "deepl" | "deepl_failed" | "deepl_not_configured",
            "translation_ms": int
        }
    """

    start_time = time.time()

    if not text or not text.strip():
        return {
            "caption_tr": None,
            "translation_provider": "empty_text",
            "translation_ms": 0,
        }

    if not DEEPL_API_KEY:
        logger.warning(f"[{request_id}] DeepL API key is not configured")

        return {
            "caption_tr": None,
            "translation_provider": "deepl_not_configured",
            "translation_ms": int((time.time() - start_time) * 1000),
        }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                DEEPL_API_URL,
                headers={
                    "Authorization": f"DeepL-Auth-Key {DEEPL_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "text": [text],
                    "source_lang": "EN",
                    "target_lang": "TR",
                },
            )

        response.raise_for_status()
        data = response.json()

        translated_text = data["translations"][0]["text"]

        translation_ms = int((time.time() - start_time) * 1000)

        logger.info(
            f"[{request_id}] translation completed | provider=deepl | translation_ms={translation_ms} | caption_tr={translated_text}"
        )

        return {
            "caption_tr": translated_text,
            "translation_provider": "deepl",
            "translation_ms": translation_ms,
        }

    except httpx.HTTPStatusError as e:
        translation_ms = int((time.time() - start_time) * 1000)

        logger.warning(
            f"[{request_id}] DeepL HTTP error | status_code={e.response.status_code} | response={e.response.text}"
        )

        return {
            "caption_tr": None,
            "translation_provider": "deepl_failed",
            "translation_ms": translation_ms,
        }

    except Exception as e:
        translation_ms = int((time.time() - start_time) * 1000)

        logger.exception(f"[{request_id}] DeepL translation failed: {e}")

        return {
            "caption_tr": None,
            "translation_provider": "deepl_failed",
            "translation_ms": translation_ms,
        }