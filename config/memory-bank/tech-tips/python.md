# Python — Tips & Gotchas

## Environment
- Use `python3` not `python` on macOS (system Python is different)
- Never hardcode secrets — use `os.environ` or `.env` files with python-dotenv

## pandas / Data
- `pd.read_csv()` with `parse_dates` is faster than post-hoc `pd.to_datetime()`
- Use `.loc[]` for label-based, `.iloc[]` for position-based — avoid chained indexing (`df[col][row]`)
- `SettingWithCopyWarning` means you're modifying a view, not a copy — use `.copy()` or `.loc[]`

## LightGBM / ML
- Version-suffix all model files (`trail_stop_v7.py` not `trail_stop.py`) to prevent `sys.modules` collisions
- Walk-forward training: quarterly models, never train on test period (2025-01-01+)
- Model artifacts: joblib + manifest.json (quarter, train_end, threshold, n_features, method)
- Feature bridge MUST be the ONLY code that computes features — same path for training and inference

## FastAPI
- Use `async def` for I/O-bound endpoints, plain `def` for CPU-bound (FastAPI runs sync in threadpool)
- Pydantic V2: use `model_validator` not `validator`, `model_dump()` not `.dict()`

## General
- `if __name__ == "__main__":` guard on all scripts
- Use early returns / guard clauses over nested if-else
- `pathlib.Path` over `os.path.join` for path manipulation
