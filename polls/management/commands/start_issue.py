import os
from pathlib import Path
import platform
import shutil
import subprocess

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = (
        "Create a branch from master or main and assign GitHub issues to yourself. "
        "Set BASE_BRANCH=main to prefer main; defaults to master."
    )
    requires_system_checks = []

    def add_arguments(self, parser):
        parser.add_argument(
            "issue_numbers",
            nargs="*",
            type=int,
            help="Issue numbers; omit to select from all open issues.",
        )

    def handle(self, *args, **options):
        numbers = options["issue_numbers"]
        if any(number <= 0 for number in numbers):
            raise CommandError("Issue numbers must be positive integers.")

        system = platform.system()
        bash_hint = {
            "Windows": (
                "Install Git for Windows (including Git Bash), add its bin "
                "directory to PATH, and reopen your terminal or IDE."
            ),
            "Darwin": (
                "On macOS, check that /bin/bash is available and /bin is in PATH, "
                "or install Bash with Homebrew: brew install bash."
            ),
            "Linux": (
                "Install the bash package using your distribution's package "
                "manager and add it to PATH in this Linux environment "
                "(also when using WSL)."
            ),
        }.get(system, "Install Bash for your system and add it to PATH.")

        bash = shutil.which("bash")
        if os.name == "nt":
            git = shutil.which("git")
            candidates = []
            if git:
                candidates.append(Path(git).resolve().parent.parent / "bin/bash.exe")
            for variable in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"):
                directory = os.environ.get(variable)
                if directory:
                    candidates.append(Path(directory) / "Git/bin/bash.exe")
            bash = next((str(path) for path in candidates if path.is_file()), bash)

        if not bash:
            raise CommandError("Bash not found. " + bash_hint)

        script = Path(settings.BASE_DIR) / "scripts/start-issue/start-issue.sh"
        if not script.is_file():
            raise CommandError(
                "File not found: %s. Restore the script in the project directory."
                % script
            )

        try:
            subprocess.run(
                [bash, "scripts/start-issue/start-issue.sh", *map(str, numbers)],
                cwd=settings.BASE_DIR,
                check=True,
            )
        except OSError as exc:
            raise CommandError(
                "Could not launch Bash. %s Check access to the project directory. "
                "Details: %s" % (bash_hint, exc)
            ) from exc
        except subprocess.CalledProcessError as exc:
            raise CommandError(
                "The script exited with code %s. See the error details above."
                % exc.returncode
            ) from exc
