"""Stop services first. Reset DB and runtime data, or only a Pi's data."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from dotenv import dotenv_values

ROOT = Path(__file__).resolve().parents[1]


def data_paths(agent_only=False):
    paths = [ROOT / "print-agent/storage", ROOT / "print-agent/logs"]
    agent = dotenv_values(ROOT / "print-agent/.env")
    for key in ("STORAGE_ROOT", "LOG_DIR"):
        value = (os.environ.get(key) if agent_only else None) or agent.get(key)
        if value:
            paths.append(ROOT / "print-agent" / value)
    if not agent_only:
        backend = dotenv_values(ROOT / "backend/.env")
        paths += [ROOT / "storage", ROOT / "logs", ROOT / "backend/storage", ROOT / ".runtime"]
        paths.append(ROOT / "backend" / (os.environ.get("STORAGE_ROOT") or backend.get("STORAGE_ROOT") or "storage"))
    return set(p.absolute() for p in paths)


def validate_paths(paths):
    protected = [ROOT.resolve(), Path.home().resolve()]
    for path in paths:
        resolved = path.resolve()
        if resolved == Path(resolved.anchor) or any(resolved == p or resolved in p.parents for p in protected):
            raise RuntimeError(f"Refusing unsafe data directory: {path}")
        if path.is_symlink() or (path.exists() and not path.is_dir()):
            raise RuntimeError(f"Data path must be a real directory: {path}")
        if any(resolved == (ROOT / d).resolve() for d in ("backend", "frontend", "print-agent", "scripts", "docs", "deploy")):
            raise RuntimeError(f"Refusing source directory: {path}")
        if path.exists() and (any(path.rglob(".env")) or any(path.rglob("*.py"))):
            raise RuntimeError(f"Refusing directory containing configuration/source: {path}")


def database_file():
    from sqlalchemy.engine import make_url
    env = dotenv_values(ROOT / "backend/.env")
    url = make_url(os.environ.get("DATABASE_URL") or env.get("DATABASE_URL") or "sqlite:///./print_platform.db")
    if url.get_backend_name() == "sqlite" and url.database and url.database != ':memory:':
        return (ROOT / "backend" / url.database).resolve()
    return None


def clear_path(path, preserved=None):
    # A configured SQLite database may live inside STORAGE_ROOT. Keep the newly
    # recreated admin database while removing every other local data file.
    if preserved is not None and preserved.is_relative_to(path.resolve()):
        for child in path.iterdir():
            if child.resolve() == preserved:
                continue
            if child.is_dir() and not child.is_symlink():
                clear_path(child, preserved)
            else:
                child.unlink()
    else:
        shutil.rmtree(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--yes", required=True, action="store_true", help="Permanent deletion; stop services first.")
    parser.add_argument("--agent-only", action="store_true", help="Pi: clear spool, journal and logs only.")
    args = parser.parse_args()
    paths = data_paths(args.agent_only)
    validate_paths(paths)
    preserved = None if args.agent_only else database_file()
    if not args.agent_only:
        subprocess.run([sys.executable, "-m", "app.db.reset_db", "--yes"], cwd=ROOT / "backend", check=True)
    for path in sorted(paths):
        if path.exists():
            clear_path(path, preserved)
            print(f"Cleared {path}")
    print("Reset complete. Clear browser sessions separately on each client.")


if __name__ == "__main__":
    main()
