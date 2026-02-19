#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_DEFAULT="Build ZeroClaw Binaries"
BRANCH_DEFAULT="main"
BIN_NAME_DEFAULT="zeroclaw"
BIN_DIR_DEFAULT="/usr/local/bin"
FALLBACK_REPO="em108/zeclo"

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage: $0 [options]

Downloads and installs the latest matching zeroclaw build artifact from GitHub Actions.

Options:
  --repo OWNER/REPO   GitHub repository to read artifacts from (default: origin remote or ${FALLBACK_REPO})
  --workflow NAME     Workflow name/file to query (default: ${WORKFLOW_DEFAULT})
  --branch BRANCH     Branch to search for successful runs (default: ${BRANCH_DEFAULT})
  --run-id ID         Use a specific run id instead of auto-selecting latest successful run
  --bin-dir DIR       Install directory (default: ${BIN_DIR_DEFAULT})
  --binary-name NAME  Installed binary name (default: ${BIN_NAME_DEFAULT})
  --no-sudo           Do not attempt sudo for protected directories
  -h, --help          Show this help

Requires:
  gh (authenticated), install, tar
USAGE
}

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

detect_repo_from_git() {
  local remote
  remote="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [[ -z "$remote" ]]; then
    return 1
  fi

  # HTTPS: https://github.com/owner/repo(.git)
  if [[ "$remote" =~ ^https://github\.com/([^/]+)/([^/]+?)(\.git)?$ ]]; then
    printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  # SSH: git@github.com:owner/repo(.git)
  if [[ "$remote" =~ ^git@github\.com:([^/]+)/([^/]+?)(\.git)?$ ]]; then
    printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

detect_target_triple() {
  local os arch key
  os="$(uname -s)"
  arch="$(uname -m)"
  key="${os}:${arch}"

  case "$key" in
    Linux:x86_64|Linux:amd64)
      echo "x86_64-unknown-linux-gnu"
      ;;
    Linux:aarch64|Linux:arm64)
      echo "aarch64-unknown-linux-gnu"
      ;;
    Darwin:x86_64|Darwin:amd64)
      echo "x86_64-apple-darwin"
      ;;
    Darwin:arm64|Darwin:aarch64)
      echo "aarch64-apple-darwin"
      ;;
    MINGW*:x86_64|MSYS*:x86_64|CYGWIN*:x86_64)
      echo "x86_64-pc-windows-msvc"
      ;;
    *)
      fail "unsupported platform for auto-detect: ${key}"
      ;;
  esac
}

resolve_latest_artifact_run_id() {
  local repo_arg="$1"
  local branch_arg="$2"
  local artifact_arg="$3"

  gh api --paginate "repos/${repo_arg}/actions/artifacts?per_page=100" \
    --jq ".artifacts[] | select(.name == \"${artifact_arg}\" and .expired == false and (.workflow_run.head_branch // \"\") == \"${branch_arg}\") | .workflow_run.id" \
    | head -n 1
}

repo="${FALLBACK_REPO}"
workflow="${WORKFLOW_DEFAULT}"
branch="${BRANCH_DEFAULT}"
run_id=""
bin_dir="${BIN_DIR_DEFAULT}"
bin_name="${BIN_NAME_DEFAULT}"
allow_sudo=1

if detected_repo="$(detect_repo_from_git)"; then
  repo="$detected_repo"
fi

while (($#)); do
  case "$1" in
    --repo)
      shift
      [[ $# -gt 0 ]] || fail "missing value for --repo"
      repo="$1"
      ;;
    --workflow)
      shift
      [[ $# -gt 0 ]] || fail "missing value for --workflow"
      workflow="$1"
      ;;
    --branch)
      shift
      [[ $# -gt 0 ]] || fail "missing value for --branch"
      branch="$1"
      ;;
    --run-id)
      shift
      [[ $# -gt 0 ]] || fail "missing value for --run-id"
      run_id="$1"
      ;;
    --bin-dir)
      shift
      [[ $# -gt 0 ]] || fail "missing value for --bin-dir"
      bin_dir="$1"
      ;;
    --binary-name)
      shift
      [[ $# -gt 0 ]] || fail "missing value for --binary-name"
      bin_name="$1"
      ;;
    --no-sudo)
      allow_sudo=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

ensure_cmd gh
ensure_cmd install
ensure_cmd tar

if ! gh auth status >/dev/null 2>&1; then
  fail "gh is not authenticated. Run: gh auth login"
fi

target="$(detect_target_triple)"
artifact_name="zeroclaw-${target}"
expected_binary="$bin_name"
if [[ "$target" == *windows* ]]; then
  expected_binary="${bin_name}.exe"
fi

if [[ -z "$run_id" ]]; then
  run_id="$(resolve_latest_artifact_run_id "$repo" "$branch" "$artifact_name" || true)"
fi

if [[ -z "$run_id" || "$run_id" == "null" ]]; then
  run_id="$(gh run list \
    --repo "$repo" \
    --workflow "$workflow" \
    --branch "$branch" \
    --status success \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId' || true)"
fi

if [[ -z "$run_id" || "$run_id" == "null" ]]; then
  fail "no successful run found for workflow '${workflow}' on branch '${branch}' in ${repo}"
fi

tmp_dir="$(mktemp -d)"
download_dir="${tmp_dir}/download"
extract_dir="${tmp_dir}/extract"
mkdir -p "$download_dir" "$extract_dir"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

log "Using run id: ${run_id}"
log "Looking for artifact: ${artifact_name}"
gh run download "$run_id" --repo "$repo" --name "$artifact_name" --dir "$download_dir"

archive_path="$(find "$download_dir" -type f \( -name "${artifact_name}.tar.gz" -o -name "${artifact_name}.zip" \) | head -n 1 || true)"

if [[ -n "$archive_path" ]]; then
  case "$archive_path" in
    *.tar.gz)
      tar -xzf "$archive_path" -C "$extract_dir"
      ;;
    *.zip)
      ensure_cmd unzip
      unzip -q "$archive_path" -d "$extract_dir"
      ;;
    *)
      fail "unsupported archive type: $archive_path"
      ;;
  esac
else
  # Fallback if artifact is uploaded as raw binary content.
  cp -a "$download_dir"/. "$extract_dir"/
fi

binary_path="$(find "$extract_dir" -type f -name "$expected_binary" | head -n 1 || true)"
if [[ -z "$binary_path" ]]; then
  # Fallback for renamed binaries in artifact archives.
  binary_path="$(find "$extract_dir" -type f -name "$bin_name" | head -n 1 || true)"
fi
[[ -n "$binary_path" ]] || fail "binary not found in downloaded artifact"

install_name="$bin_name"
if [[ "$expected_binary" == *.exe ]]; then
  install_name="$expected_binary"
fi

install_target="${bin_dir}/${install_name}"
mkdir -p "$bin_dir" 2>/dev/null || true

if [[ -w "$bin_dir" ]]; then
  install -m 0755 "$binary_path" "$install_target"
elif [[ "$allow_sudo" -eq 1 ]] && command -v sudo >/dev/null 2>&1; then
  log "Installing to ${install_target} with sudo..."
  sudo install -m 0755 "$binary_path" "$install_target"
else
  fallback_dir="${HOME}/.local/bin"
  mkdir -p "$fallback_dir"
  install_target="${fallback_dir}/${install_name}"
  install -m 0755 "$binary_path" "$install_target"
  log "Installed to ${install_target}"
  log "Add ${fallback_dir} to PATH if needed."
fi

log "Installed ${bin_name} to ${install_target}"
"$install_target" --version || true
