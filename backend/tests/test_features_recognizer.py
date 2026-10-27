import numpy as np
import pytest

from app.services.features import has_hand, normalize, prepare
from app.services.recognizer import Recognizer
from app.services.segmenter import Segmenter


def test_prepare_shape_and_finite():
    frames = np.random.default_rng(1).random((20, 126))
    x = prepare(frames)
    assert x.shape == (1, 48, 130) and x.dtype == np.float32 and np.isfinite(x).all()
    z = prepare(np.zeros((9, 126)))
    assert np.isfinite(z).all() and not z.any()


def test_normalize_is_position_and_scale_invariant():
    rng = np.random.default_rng(2)
    hand = rng.random((5, 126))
    moved = hand.copy()
    moved[:, :63] = moved[:, :63] * 2 + 0.1  # scale + shift the left hand
    a, b = normalize(hand)[:, :63], normalize(moved)[:, :63]
    assert np.allclose(a, b, atol=1e-3)


def test_segmenter_splits_words():
    seg = Segmenter(word_gap=0.5, min_frames=3)
    hand, none = np.ones(126), np.zeros(126)
    out = [seg.push(hand, i * 0.1) for i in range(5)]
    assert all(s is None for s, _ in out)
    seg_out, idle = seg.push(none, 0.4 + 0.6)
    assert seg_out is not None and len(seg_out) == 5 and idle >= 0.5
    # a blip shorter than min_frames is ignored
    seg.push(hand, 2.0)
    assert seg.push(none, 3.0)[0] is None


def test_demo_recognizer(tmp_path):
    r = Recognizer(str(tmp_path))
    assert r.mode == "demo" and r.predict(np.ones((8, 126))).word == "hello"


def test_onnx_model_path(tmp_path):
    pytest.importorskip("onnx")
    pytest.importorskip("onnxruntime")
    from tools.make_dummy_onnx import make

    make(str(tmp_path))
    r = Recognizer(str(tmp_path))
    assert r.mode == "model"
    p = r.predict(np.random.default_rng(3).random((15, 126)))
    assert p.word in r.labels and 0 < p.confidence <= 1 and len(p.top) == 3
    assert has_hand(np.ones(126)) and not has_hand(np.zeros(126))
