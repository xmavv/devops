import importlib.util
import subprocess
import sys
from pathlib import Path


def main():
    if importlib.util.find_spec("pre_commit") is None:
        print(
            "Install dependencies first: python -m pip install -r requirements.txt",
            file=sys.stderr,
        )
        return 1

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "pre_commit",
            "install",
            "--hook-type",
            "pre-commit",
            "--hook-type",
            "commit-msg",
        ],
        cwd=Path(__file__).resolve().parents[1],
        check=False,
    )
    if result.returncode == 0:
        print("Git hooks installed. Checks will run on cz commit and git commit.")
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
