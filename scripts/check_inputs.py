"""Check input availability separately for archived and final model revisions.

A successful preflight checks files and hashes only; it never establishes
convergence or reproduces a dissertation score.
"""
import argparse
import hashlib
import json
from pathlib import Path


def inspect_inputs(root, scope="final"):
    root = Path(root)
    split = root / "data/processed/model_data_split.rds"
    issues = []
    if not split.is_file():
        issues.append("Missing frozen split: data/processed/model_data_split.rds")
    if scope == "final":
        manifest_path = root / "artifacts/final_reproduction.json"
        if not manifest_path.is_file():
            issues.append("Missing final restoration manifest: artifacts/final_reproduction.json")
        else:
            try:
                manifest = json.loads(manifest_path.read_text())
                for key in ["frozen_split", "final_model_code"]:
                    entry = manifest[key]
                    relative = Path(entry["path"])
                    path = (root / relative).resolve()
                    if relative.is_absolute() or not path.is_relative_to(root.resolve()):
                        raise ValueError("Manifest paths must stay inside the repository")
                    if key == "frozen_split" and path != split.resolve():
                        raise ValueError("Frozen split path must be data/processed/model_data_split.rds")
                    if not path.is_file():
                        issues.append("Missing final input: " + str(relative))
                    elif hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
                        issues.append("SHA-256 mismatch: " + str(relative))
            except (KeyError, TypeError, ValueError, OSError) as error:
                issues.append("Invalid final manifest: " + str(error))
    return {"scope": scope, "available": not issues, "issues": issues,
            "meaning": "Input-file availability only. No model fit, metric reproduction or convergence check was run."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scope", choices=["archived", "final"], default="final")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    result = inspect_inputs(args.root, args.scope)
    print(json.dumps(result, indent=2))
    return 0 if result["available"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
