#!/usr/bin/env bash
set -euo pipefail

GH="gh"

case "${OSTYPE:-}" in
  linux*) platform="Linux" ;;
  darwin*) platform="macOS" ;;
  msys*|cygwin*|win32*) platform="Windows" ;;
  *) platform="${OS:-Unknown}" ;;
esac

echo "[INFO] Detected system: $platform."

error() {
  echo "[ERROR] $*" >&2
}

install_hint() {
  local tool="$1"
  case "$platform" in
    Windows)
      case "$tool" in
        git) echo "Install Git for Windows (including Git Bash) and add Git to PATH." ;;
        gh) echo "Install GitHub CLI for Windows and add gh.exe to PATH." ;;
        fzf) echo "Install fzf for Windows and add the folder containing fzf.exe to PATH." ;;
      esac
      ;;
    macOS)
      if command -v brew >/dev/null 2>&1; then
        echo "Install it with Homebrew: brew install $tool."
      elif [ "$tool" = git ]; then
        echo "Install Apple's Command Line Tools: xcode-select --install, or install Git with Homebrew."
      else
        echo "Install Homebrew, then run: brew install $tool."
      fi
      ;;
    Linux)
      if [ "$tool" = gh ]; then
        echo "Install GitHub CLI (gh) for your distribution; you may need to configure its package repository."
      else
        echo "Install the $tool package using your distribution's package manager (such as apt, dnf, or pacman)."
      fi
      echo "Make sure $tool is available in this Linux environment's PATH (also when using WSL)."
      ;;
    *) echo "Install $tool for your system and add it to PATH." ;;
  esac
}

missing=0
if ! command -v git >/dev/null 2>&1; then
  error "Git not found. $(install_hint git)"
  missing=1
fi
if ! command -v "$GH" >/dev/null 2>&1; then
  error "GitHub CLI (gh) not found. $(install_hint gh)"
  missing=1
fi
if [ "$#" -eq 0 ] && ! command -v fzf >/dev/null 2>&1; then
  error "fzf is required for interactive selection. $(install_hint fzf)"
  error "Alternatively, provide issue numbers to skip fzf: python manage.py start_issue 12 34."
  missing=1
fi
if [ "$missing" -ne 0 ]; then
  if [ "$platform" = Windows ]; then
    error "After installation, reopen your terminal or IDE so it picks up PATH changes, then try again."
  else
    error "After installation, make sure the tools are in PATH in the terminal running this command, then try again."
  fi
  exit 1
fi

for number in "$@"; do
  if [[ ! "$number" =~ ^[0-9]+$ || ! "$number" =~ [1-9] ]]; then
    error "Invalid issue number: $number. Use positive integers without the # prefix."
    exit 1
  fi
done

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  error "Not inside a Git repository. Run the script from the project directory."
  exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  error "Remote origin not found. Configure it with: git remote add origin <repository-url>."
  exit 1
fi
if ! "$GH" issue develop --help >/dev/null 2>&1; then
  error "GitHub CLI does not support gh issue develop. Update GitHub CLI using the installer or package manager used on $platform."
  exit 1
fi
if ! "$GH" auth status; then
  error "Could not verify GitHub CLI authentication. Check the message above; sign in with gh auth login."
  exit 1
fi

if [ "$#" -gt 0 ]; then
  issue_numbers=("$@")
else
  if ! issues=$("$GH" api --paginate \
    'repos/{owner}/{repo}/issues?state=open&per_page=100' \
    --jq '.[] | select(has("pull_request") | not) | "\(.number)\t\(.title)"'); then
    error "Could not fetch issues. Check your connection, repository access, and whether issues are enabled."
    exit 1
  fi
  if [ -z "$issues" ]; then
    error "No open issues found in this repository."
    exit 1
  fi
  if ! selection=$(printf '%s\n' "$issues" | fzf --multi \
          --delimiter=$'\t' \
          --with-nth=2.. \
          --prompt="Pick issue(s) (Tab = select multiple) > "); then
    error "No issue selected or selection was interrupted. Try again or provide issue numbers as arguments."
    exit 1
  fi

  if [ -z "$selection" ]; then
    echo "No issue selected." >&2
    exit 1
  fi

  issue_numbers=()
  while IFS=$'\t' read -r number _; do
    issue_numbers+=("$number")
  done <<<"$selection"
fi

base_branch="${BASE_BRANCH:-master}"
case "$base_branch" in
  master) fallback_branch="main" ;;
  main) fallback_branch="master" ;;
  *)
    error "Unsupported BASE_BRANCH: $base_branch. Use master or main."
    exit 1
    ;;
esac

if ! remote_branches=$(git ls-remote --heads origin refs/heads/master refs/heads/main); then
  error "Could not check branches on origin. Check your connection and Git permissions. For HTTPS, you can use gh auth setup-git."
  exit 1
fi

preferred_exists=0
fallback_exists=0
while read -r commit ref; do
  if [ "$ref" = "refs/heads/$base_branch" ]; then
    preferred_exists=1
  elif [ "$ref" = "refs/heads/$fallback_branch" ]; then
    fallback_exists=1
  fi
done <<<"$remote_branches"

if [ "$preferred_exists" -eq 0 ]; then
  if [ "$fallback_exists" -eq 0 ]; then
    error "Neither master nor main exists on origin. Create a base branch before running this script."
    exit 1
  fi
  echo "[INFO] origin/$base_branch not found. Falling back to origin/$fallback_branch."
  base_branch="$fallback_branch"
fi

echo "Fetching origin/$base_branch..."
if ! git fetch origin "$base_branch"; then
  error "Could not fetch origin/$base_branch. Check your connection and Git permissions. For HTTPS, you can use gh auth setup-git."
  exit 1
fi

if [ "${#issue_numbers[@]}" -eq 1 ]; then
  issue_number="${issue_numbers[0]}"
  echo "Creating and linking a branch for issue #$issue_number..."
  "$GH" issue develop "$issue_number" --base "$base_branch" --checkout
  "$GH" issue edit "$issue_number" --add-assignee @me
else
  primary="${issue_numbers[0]}"
  others=("${issue_numbers[@]:1}")

  echo "Creating a shared branch, linked to issue #$primary..."
  "$GH" issue develop "$primary" --base "$base_branch" --checkout
  branch="$(git branch --show-current)"
  "$GH" issue edit "$primary" --add-assignee @me

  for issue_number in "${others[@]}"; do
    echo "Assigning yourself to issue #$issue_number and linking it to the shared branch..."
    "$GH" issue edit "$issue_number" --add-assignee @me
    "$GH" issue comment "$issue_number" \
      --body "Working on this together with #$primary on branch \`$branch\`."
  done
fi

echo
echo "Ready on branch: $(git branch --show-current)"
