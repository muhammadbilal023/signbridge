"""Facial emotion. Needs models/emotion.onnx (FER2013-style CNN, input (1,1,48,48) in [0,1], 7 classes) + OpenCV.
Without the model it answers in DEMO mode ("neutral") so the app can be wired up first."""
from collections import Counter, deque
from functools import lru_cache
from pathlib import Path

import numpy as np

from ..config import get_settings
from .landmarks import Unavailable

LABELS = ["angry", "disgust", "fear", "happy", "sad", "surprise", "neutral"]


class EmotionService:
    def __init__(self, models_dir: str):
        self.mode, self.session = "demo", None
        path = Path(models_dir) / "emotion.onnx"
        if path.exists():
            try:
                import onnxruntime as ort
            except ImportError as e:
                raise RuntimeError("models/emotion.onnx found but onnxruntime is not installed: pip install onnxruntime") from e

            self.session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
            self.input_name = self.session.get_inputs()[0].name
            self.mode = "model"

    def classify_jpeg(self, data: bytes) -> tuple[str | None, float]:
        """Returns (label, confidence) or (None, 0) when no face is found."""
        if self.mode == "demo":
            return "neutral", 0.5
        try:  # pragma: no cover - needs opencv + model
            import cv2
        except ImportError as e:
            raise Unavailable("Emotion detection needs opencv: pip install -r requirements-ml.txt") from e
        img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_GRAYSCALE)  # pragma: no cover
        if img is None:  # pragma: no cover
            raise ValueError("Could not decode image")
        cascade = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")  # pragma: no cover
        faces = cascade.detectMultiScale(img, 1.2, 5, minSize=(48, 48))  # pragma: no cover
        if len(faces) == 0:  # pragma: no cover
            return None, 0.0
        x, y, w, h = max(faces, key=lambda f: f[2] * f[3])  # pragma: no cover
        face = cv2.resize(img[y:y + h, x:x + w], (48, 48)).astype(np.float32) / 255.0  # pragma: no cover
        logits = self.session.run(None, {self.input_name: face[None, None]})[0][0].astype(np.float64)  # pragma: no cover
        p = np.exp(logits - logits.max())  # pragma: no cover
        p /= p.sum()  # pragma: no cover
        i = int(p.argmax())  # pragma: no cover
        return LABELS[i], float(p[i])  # pragma: no cover


class Smoother:
    """Majority vote over the last N results so the badge does not flicker."""

    def __init__(self, n: int = 5):
        self.buf: deque[str] = deque(maxlen=n)
        self.current: str | None = None

    def push(self, label: str | None) -> tuple[str | None, bool]:
        if label:
            self.buf.append(label)
        if not self.buf:
            return self.current, False
        top = Counter(self.buf).most_common(1)[0][0]
        changed = top != self.current
        self.current = top
        return top, changed


@lru_cache
def get_emotion_service() -> EmotionService:
    return EmotionService(get_settings().models_dir)
