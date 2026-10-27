"""Word recognizer. Loads models/word_model.onnx + models/labels.json (exported from the Colab notebook).
If they are missing it runs in DEMO mode so the app can be built and tested before the model is trained."""
import json
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import numpy as np

from ..config import get_settings
from .features import prepare

DEMO_WORDS = ["hello", "help", "water", "doctor", "thank you"]


@dataclass
class Prediction:
    word: str
    confidence: float
    top: list[tuple[str, float]] = field(default_factory=list)


class Recognizer:
    def __init__(self, models_dir: str):
        self.mode = "demo"
        self.labels: list[str] = []
        self.session = None
        self._demo_i = 0
        onnx_path, labels_path = Path(models_dir) / "word_model.onnx", Path(models_dir) / "labels.json"
        if onnx_path.exists() and labels_path.exists():
            try:
                import onnxruntime as ort
            except ImportError as e:
                raise RuntimeError("models/word_model.onnx found but onnxruntime is not installed: pip install onnxruntime "
                                   "(needs Python 3.12 or older)") from e

            self.labels = json.loads(labels_path.read_text(encoding="utf-8"))
            self.session = ort.InferenceSession(str(onnx_path), providers=["CPUExecutionProvider"])
            inp = self.session.get_inputs()[0]
            self.input_name = inp.name
            n_out = self.session.get_outputs()[0].shape[-1]
            if isinstance(n_out, int) and n_out != len(self.labels):
                raise RuntimeError(f"labels.json has {len(self.labels)} labels but the model outputs {n_out} classes")
            self.mode = "model"

    def predict(self, frames: np.ndarray) -> Prediction:
        if self.mode == "demo":
            word = DEMO_WORDS[self._demo_i % len(DEMO_WORDS)]
            self._demo_i += 1
            return Prediction(word, 0.9, [(word, 0.9)])
        logits = self.session.run(None, {self.input_name: prepare(frames)})[0][0].astype(np.float64)
        e = np.exp(logits - logits.max())
        probs = e / e.sum()
        order = np.argsort(-probs)[:3]
        top = [(self.labels[i], float(probs[i])) for i in order]
        return Prediction(top[0][0], top[0][1], top)


@lru_cache
def get_recognizer() -> Recognizer:
    return Recognizer(get_settings().models_dir)
