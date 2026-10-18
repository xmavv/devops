import subprocess
import sys
from pathlib import Path


def main():
    if sys.prefix == sys.base_prefix:
        print("Activate your project's venv before running this script.", file=sys.stderr)
        return 1

    requirements_path = Path(__file__).resolve().parents[2] / "requirements.txt"
    try:
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "pip",
                "list",
                "--not-required",
                "--format=freeze",
                "--exclude",
                "pip",
                "--disable-pip-version-check",
            ],
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"Cannot list packages: {exc}", file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError) and exc.stderr:
            print(exc.stderr.strip(), file=sys.stderr)
        return 1

    packages = sorted(
        (line.strip() for line in result.stdout.splitlines() if line.strip()),
        key=str.casefold,
    )
    if not packages:
        print("No packages found; requirements.txt was left unchanged.", file=sys.stderr)
        return 1

    requirements_path.write_text("\n".join(packages) + "\n", encoding="utf-8", newline="\n")
    print(f"Updated {requirements_path} ({len(packages)} packages).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
