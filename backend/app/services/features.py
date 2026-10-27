"""Feature preparation. MUST stay identical to the preprocessing used when training the model in Colab
(hands only: 2 hands x 21 points x (x, y, z) = 126 numbers per frame, + 4 wrist x/y numbers = 130)."""
import numpy as np

FRAME_DIM = 126
FEATURE_DIM = 130
WINDOW = 48


def has_hand(vec) -> bool:
    return bool(np.any(np.abs(np.asarray(vec, dtype=np.float32)) > 0))


def normalize(x) -> np.ndarray:
    """(T, 126) raw landmarks -> (T, 130): wrist at origin, scaled by hand size, plus wrist positions."""
    x = np.asarray(x, dtype=np.float32).reshape(-1, 2, 21, 3).copy()
    pos = x[:, :, 0, :2].reshape(-1, 4).copy()
    for h in range(2):
        hand = x[:, h]
        present = np.abs(hand).sum(axis=(1, 2)) > 0
        hand = hand - hand[:, :1, :]
        size = np.linalg.norm(hand[:, 9, :], axis=1)[:, None, None] + 1e-6
        hand = hand / size
        hand[~present] = 0
        x[:, h] = hand
    return np.concatenate([x.reshape(-1, FRAME_DIM), pos], axis=1)


def resample(x: np.ndarray, length: int = WINDOW) -> np.ndarray:
    idx = np.linspace(0, len(x) - 1, length).round().astype(int)
    return x[idx]


def prepare(frames) -> np.ndarray:
    """list/array of (126,) frames -> (1, 48, 130) float32 model input."""
    return resample(normalize(np.asarray(frames, dtype=np.float32)))[None].astype(np.float32)
