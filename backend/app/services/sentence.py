"""Words -> one natural sentence using any OpenAI-compatible chat API (Grok/xAI, Qwen, Groq...). Always has a safe fallback."""
import json
import re

import httpx

from ..config import get_settings

SYSTEM = "You turn recognised sign-language words into one short natural sentence. Never add facts."


class SentenceService:
    @property
    def configured(self) -> bool:
        s = get_settings()
        return bool(s.llm_base_url and s.llm_api_key and s.llm_model)

    async def _post(self, payload: dict) -> dict:
        s = get_settings()
        async with httpx.AsyncClient(timeout=s.llm_timeout) as client:
            r = await client.post(s.llm_base_url.rstrip("/") + "/chat/completions", json=payload,
                                  headers={"Authorization": f"Bearer {s.llm_api_key}"})
            r.raise_for_status()
            return r.json()

    @staticmethod
    def _valid(sentence: str, words: list[str]) -> bool:
        if not sentence or len(sentence) > 200 or len(sentence.split()) > len(words) * 3 + 6:
            return False
        allowed = set(re.findall(r"\d+", " ".join(words)))
        return set(re.findall(r"\d+", sentence)) <= allowed  # no invented numbers

    async def build(self, words: list[str], language: str = "en") -> tuple[str, str]:
        words = [w.strip() for w in words if w and w.strip()]
        fallback = " ".join(words)
        if len(words) < 2 or not self.configured:
            return fallback, "fallback"
        lang = "Urdu" if language == "ur" else "English"
        prompt = (f"These words were recognised from sign language, in order: {words}. "
                  f"Write ONE short, natural {lang} sentence that uses only their meaning. "
                  "Do not add names, numbers or facts. If they cannot form a sentence, return the words unchanged. "
                  'Reply only as JSON: {"sentence": "..."}')
        payload = {"model": get_settings().llm_model, "temperature": 0,
                   "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": prompt}]}
        try:
            data = await self._post(payload)
            content = data["choices"][0]["message"]["content"].strip()
            content = re.sub(r"^```(?:json)?|```$", "", content, flags=re.M).strip()
            sentence = str(json.loads(content)["sentence"]).strip()
            if self._valid(sentence, words):
                return sentence, "llm"
        except Exception:  # network error, bad JSON, timeout...
            pass
        return fallback, "fallback"


sentence_service = SentenceService()
