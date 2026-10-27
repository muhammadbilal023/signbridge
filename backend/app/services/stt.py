"""Speech-to-text with faster-whisper (optional)."""
import tempfile

from ..config import get_settings
from .landmarks import Unavailable


class SttService:
    _model = None

    def transcribe(self, data: bytes, language: str | None = None) -> str:
        s = get_settings()
        if not s.enable_stt:
            raise Unavailable("Speech-to-text is off. Set ENABLE_STT=true and install requirements-ml.txt.")
        if self._model is None:  # pragma: no cover - heavy
            from faster_whisper import WhisperModel

            SttService._model = WhisperModel(s.whisper_model, compute_type="int8")
        with tempfile.NamedTemporaryFile(suffix=".audio") as f:  # pragma: no cover - heavy
            f.write(data)
            f.flush()
            segments, _ = self._model.transcribe(f.name, language=language, vad_filter=True)
            return " ".join(seg.text.strip() for seg in segments).strip()


stt_service = SttService()
