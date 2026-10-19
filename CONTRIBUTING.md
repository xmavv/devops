# Environment setup

After cloning the repository, create a Python 3.14 virtual environment:

```sh
python3.14 -m venv .venv
source .venv/bin/activate
```

On Windows, use `py -3.14 -m venv .venv` and activate the environment in
PowerShell with `.venv\Scripts\Activate.ps1`.

Install dependencies and enable commit checks:

```sh
python -m pip install -r requirements.txt
python scripts/install-hooks/install_hooks.py
```

The script works on macOS, Linux, and Windows. It installs the `pre-commit`
and `commit-msg` hooks using the active Python interpreter. Run it again after
recreating `.venv`. The first check requires internet access to download tools.

## Adding a dependency

Install new packages in the project's active virtual environment, then update
`requirements.txt` before committing:

```sh
python -m pip install <package-name>
python scripts/update_requirements.py
git diff -- requirements.txt
git add requirements.txt
```

Commit the updated `requirements.txt` together with the code that uses the new
package. Run the update script after upgrading or removing packages as well.
The script records installed versions of top-level packages reported by pip;
it does not create a complete dependency lock file. Use a virtual environment
dedicated to this project and review the diff for unrelated packages or removals
of dependencies that the project still imports directly.

## Creating a commit

```sh
git add <files>
cz commit
```

Both `cz commit` and `git commit` automatically run:

- YAML validation, trailing whitespace checks, and end-of-file fixes;
- Ruff linting with automatic fixes and code formatting;
- Commitizen commit message validation.

Checks run on staged files. If a hook modifies files, the commit is stopped.
Review the changes with `git diff`, stage the updated files with `git add`,
and run `cz commit` again.

## Checks before opening a pull request

```sh
pre-commit run --all-files --show-diff-on-failure
```

Shared configuration and tool versions are defined in `.pre-commit-config.yaml`.
Git does not enable hooks automatically after cloning. Each contributor must
run the installation script once. Files in `.git/hooks` remain local.
