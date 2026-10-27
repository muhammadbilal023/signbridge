"""JPEG frame -> 126 hand landmarks (left hand 63 + right hand 63). Needs: pip install mediapipe opencv-python-headless
Works with the new MediaPipe Tasks API (needs models/hand_landmarker.task, downloaded automatically on first use)
and with older MediaPipe versions that still have mp.solutions."""
import importlib.util
import threading
from pathlib import Path

import numpy as np

from ..config import get_settings

MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"


class Unavailable(RuntimeError):
    pass


class LandmarkExtractor:
    def __init__(self):
        self._impl = None          # ("legacy", hands) or ("tasks", landmarker)
        self._lock = threading.Lock()

    # ---- status (cheap, no heavy imports) ----
    def installed(self) -> bool:
        return importlib.util.find_spec("mediapipe") is not None and importlib.util.find_spec("cv2") is not None

    def model_path(self) -> Path:
        return Path(get_settings().models_dir) / "hand_landmarker.task"

    def status(self) -> str:
        if not self.installed():
            return "not_installed"
        return "ready" if (self._impl or self.model_path().exists()) else "model_file_missing"

    def ensure_model(self) -> Path:
        path = self.model_path()
        if path.exists():
            return path
        import httpx

        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with httpx.stream("GET", MODEL_URL, timeout=90, follow_redirects=True) as r:
                r.raise_for_status()
                tmp = path.with_suffix(".part")
                with open(tmp, "wb") as f:
                    for chunk in r.iter_bytes():
                        f.write(chunk)
                tmp.replace(path)
        except Exception as e:
            raise Unavailable(f"Could not download the hand model. Download {MODEL_URL} and put it in {path}") from e
        return path

    # ---- loading ----
    def _load(self):
        if self._impl is not None:
            return self._impl
        try:
            import cv2  # noqa: F401
            import mediapipe as mp
        except ImportError as e:
            raise Unavailable("Hand tracking needs: pip install mediapipe opencv-python-headless (Python 3.12 or older)") from e
        if hasattr(mp, "solutions"):  # older MediaPipe
            hands = mp.solutions.hands.Hands(static_image_mode=False, max_num_hands=2, min_detection_confidence=0.5)
            self._impl = ("legacy", hands)
        else:  # MediaPipe Tasks API
            from mediapipe.tasks import python as mpp
            from mediapipe.tasks.python import vision

            opts = vision.HandLandmarkerOptions(base_options=mpp.BaseOptions(model_asset_path=str(self.ensure_model())),
                                                running_mode=vision.RunningMode.IMAGE, num_hands=2,
                                                min_hand_detection_confidence=0.5)
            self._impl = ("tasks", vision.HandLandmarker.create_from_options(opts))
        return self._impl

    # ---- detection ----
    def _detect(self, rgb: np.ndarray) -> list[tuple[str, list[list[float]]]]:  # pragma: no cover - needs mediapipe
        """Returns [(label 'Left'|'Right', [[x,y,z] x 21])]."""
        import mediapipe as mp

        kind, obj = self._load()
        found = []
        if kind == "legacy":
            res = obj.process(rgb)
            for lm, hd in zip(res.multi_hand_landmarks or [], res.multi_handedness or []):
                found.append((hd.classification[0].label, [[p.x, p.y, p.z] for p in lm.landmark]))
        else:
            res = obj.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb)))
            for lm, hd in zip(res.hand_landmarks, res.handedness):
                found.append((hd[0].category_name, [[p.x, p.y, p.z] for p in lm]))
        return found

    def from_jpeg(self, data: bytes) -> np.ndarray:
        try:
            import cv2
        except ImportError as e:
            raise Unavailable("Hand tracking needs: pip install mediapipe opencv-python-headless") from e
        img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Could not decode image")
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        with self._lock:
            found = self._detect(rgb)
        out = np.zeros((2, 21, 3), dtype=np.float32)
        for label, pts in found:
            out[0 if label == "Left" else 1] = pts
        return out.reshape(-1)


extractor = LandmarkExtractor()
