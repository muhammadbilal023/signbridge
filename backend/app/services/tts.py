"""Text-to-speech with Meta MMS (Urdu / English). Optional. MMS models are CC-BY-NC (fine for an academic project)."""
import io

from ..config import get_settings
from .landmarks import Unavailable

MODELS = {"ur": "facebook/mms-tts-urd-script_arabic", "en": "facebook/mms-tts-eng"}


class TtsService:
    _cache: dict = {}

    def synthesize(self, text: str, language: str = "ur") -> bytes:
        if not get_settings().enable_tts:
            raise Unavailable("Text-to-speech is off. Set ENABLE_TTS=true and install requirements-ml.txt.")
        import scipy.io.wavfile as wav  # pragma: no cover - heavy
        import torch
        from transformers import AutoTokenizer, VitsModel

        if language not in self._cache:  # pragma: no cover
            name = MODELS[language]
            self._cache[language] = (VitsModel.from_pretrained(name), AutoTokenizer.from_pretrained(name))
        model, tok = self._cache[language]  # pragma: no cover
        with torch.no_grad():  # pragma: no cover
            w = model(**tok(text, return_tensors="pt")).waveform[0]
        buf = io.BytesIO()  # pragma: no cover
        wav.write(buf, model.config.sampling_rate, w.numpy())  # pragma: no cover
        return buf.getvalue()  # pragma: no cover


tts_service = TtsService()
