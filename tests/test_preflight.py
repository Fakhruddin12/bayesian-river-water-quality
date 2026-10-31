import hashlib
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("preflight", Path(__file__).parents[1] / "scripts/check_inputs.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def test_saved_split_does_not_imply_final_model_is_available(tmp_path):
    split = tmp_path / "data/processed/model_data_split.rds"
    split.parent.mkdir(parents=True)
    split.write_bytes(b"test fixture")
    assert module.inspect_inputs(tmp_path, "archived")["available"]
    assert not module.inspect_inputs(tmp_path, "final")["available"]


def test_final_manifest_checks_both_inputs_and_detects_changed_data(tmp_path):
    split = tmp_path / "data/processed/model_data_split.rds"
    code = tmp_path / "analysis/final_model.R"
    manifest = tmp_path / "artifacts/final_reproduction.json"
    for path in [split, code, manifest]:
        path.parent.mkdir(parents=True, exist_ok=True)
    split.write_bytes(b"frozen test fixture")
    code.write_text("# test fixture, not an actual model")
    manifest.write_text(json.dumps({key: {"path": str(path.relative_to(tmp_path)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                                  for key, path in [("frozen_split", split), ("final_model_code", code)]}))
    assert module.inspect_inputs(tmp_path)["available"]
    split.write_bytes(b"changed fixture")
    assert not module.inspect_inputs(tmp_path)["available"]


def test_manifest_cannot_point_outside_repository(tmp_path):
    target = tmp_path / "artifacts/final_reproduction.json"
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps({"frozen_split": {"path": "../outside", "sha256": "invalid"}}))
    assert not module.inspect_inputs(tmp_path)["available"]
