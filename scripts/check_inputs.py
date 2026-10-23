"""Report missing historical inputs; do not substitute or fabricate source data."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
helpers = [root / 'import_hde_function.R', root / 'import_wq_function.R']
processed = root / 'data/processed/model_data_split.rds'
if processed.exists():
    print('Saved model split is available; scripts 02–05 can use this input.')
    print('Check its provenance against the dissertation before reproducing claims.')
    sys.exit(0)
missing = [p.name for p in helpers if not p.exists()]
if missing:
    print('Missing original acquisition helpers: ' + ', '.join(missing))
print('Historical model split is absent: data/processed/model_data_split.rds')
print('See REPRODUCIBILITY.md. Full historical reproduction is not yet available.')
sys.exit(1)
