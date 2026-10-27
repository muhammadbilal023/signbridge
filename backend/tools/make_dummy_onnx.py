"""Creates a tiny RANDOM model with the same input/output shape as the real one, to test the serving path.
    python tools/make_dummy_onnx.py models            # writes models/word_model.onnx + models/labels.json
The real model comes from your Colab training (see MODEL_CONTRACT in README.md)."""
import json
import sys
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

DEFAULT_LABELS = ["hello", "help", "water", "doctor", "thank you", "none"]


def make(out_dir: str, labels=None, seed: int = 0) -> None:
    labels = labels or DEFAULT_LABELS
    n = len(labels)
    rng = np.random.default_rng(seed)
    w = numpy_helper.from_array(rng.normal(size=(130, n)).astype(np.float32), "W")
    b = numpy_helper.from_array(np.zeros(n, np.float32), "B")
    nodes = [
        helper.make_node("ReduceMean", ["x"], ["m"], axes=[1], keepdims=0),
        helper.make_node("MatMul", ["m", "W"], ["mm"]),
        helper.make_node("Add", ["mm", "B"], ["logits"]),
    ]
    graph = helper.make_graph(
        nodes, "dummy_word_model",
        [helper.make_tensor_value_info("x", TensorProto.FLOAT, [1, 48, 130])],
        [helper.make_tensor_value_info("logits", TensorProto.FLOAT, [1, n])], [w, b])
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)])
    model.ir_version = 8
    onnx.checker.check_model(model)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    onnx.save(model, str(out / "word_model.onnx"))
    (out / "labels.json").write_text(json.dumps(labels, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    make(sys.argv[1] if len(sys.argv) > 1 else "models")
    print("dummy model written")
