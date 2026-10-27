"""Cuts a live stream of hand frames into word segments (sign, short pause, next sign)."""
import numpy as np

from .features import has_hand


class Segmenter:
    def __init__(self, word_gap: float, min_frames: int, max_frames: int = 150):
        self.word_gap, self.min_frames, self.max_frames = word_gap, min_frames, max_frames
        self.cur: list[np.ndarray] = []
        self.last_hand: float | None = None

    def push(self, vec: np.ndarray, t: float) -> tuple[np.ndarray | None, float]:
        """Returns (finished_segment_or_None, seconds_since_hands_were_last_seen)."""
        if has_hand(vec):
            self.cur.append(vec)
            self.last_hand = t
            if len(self.cur) >= self.max_frames:
                return self._take(), 0.0
            return None, 0.0
        if self.last_hand is None:
            return None, 0.0
        idle = t - self.last_hand
        seg = self._take() if (self.cur and idle >= self.word_gap) else None
        return seg, idle

    def flush(self) -> np.ndarray | None:
        return self._take() if self.cur else None

    def reset_idle(self) -> None:
        self.last_hand = None

    def _take(self) -> np.ndarray | None:
        seg = np.stack(self.cur)
        self.cur = []
        return seg if len(seg) >= self.min_frames else None
