import numpy as np
import pytest

from app.services.landmarks import LandmarkExtractor

cv2 = pytest.importorskip("cv2")


def jpeg(color=128):
    ok, buf = cv2.imencode(".jpg", np.full((60, 80, 3), color, np.uint8))
    assert ok
    return buf.tobytes()


def test_left_then_right_layout(monkeypatch):
    ex = LandmarkExtractor()
    left = [[0.1, 0.2, 0.0]] * 21
    right = [[0.7, 0.8, 0.1]] * 21
    monkeypatch.setattr(ex, "_detect", lambda rgb: [("Right", right), ("Left", left)])
    v = ex.from_jpeg(jpeg())
    assert v.shape == (126,) and v.dtype == np.float32
    assert np.allclose(v[:3], [0.1, 0.2, 0.0]) and np.allclose(v[63:66], [0.7, 0.8, 0.1])


def test_no_hand_gives_zeros_and_bad_image_errors(monkeypatch):
    ex = LandmarkExtractor()
    monkeypatch.setattr(ex, "_detect", lambda rgb: [])
    assert not ex.from_jpeg(jpeg()).any()
    with pytest.raises(ValueError):
        ex.from_jpeg(b"not an image")


def test_status_is_a_known_value():
    assert LandmarkExtractor().status() in {"not_installed", "model_file_missing", "ready"}
