#!/usr/bin/env bash

set -euo pipefail

GRAPH_PATH=${1:-db.sqlite}
BASE_COMMIT=${2:-HEAD^}
PAGE_DROP_THRESHOLD=${PAGE_DROP_THRESHOLD:-3}
BLOCK_DROP_THRESHOLD=${BLOCK_DROP_THRESHOLD:-3}

if ! command -v logseq >/dev/null 2>&1; then
  echo "logseq CLI is required on PATH (npm install -g @logseq/cli)" >&2
  exit 1
fi

strip_ansi() {
  python - "$@" <<'PY'
import re
import sys

text = sys.stdin.read()
text = re.sub(r'\x1B\[[0-?]*[ -/]*[@-~]', '', text)
sys.stdout.write(text)
PY
}

parse_counts_file() {
  local file=$1
  python - "$file" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    raw = fh.read()

text = re.sub(r'\x1B\[[0-?]*[ -/]*[@-~]', '', raw)
match = re.search(r'counts:?\s*(\{[^}]*\})', text, flags=re.IGNORECASE | re.DOTALL)
if not match:
    snippet = text.strip().splitlines()[:10]
    sys.stderr.write("Unable to find counts map in logseq output. First lines:\n")
    for line in snippet:
        sys.stderr.write(line + "\n")
    sys.exit(1)

counts = match.group(1)
def grab(key):
    m = re.search(rf':{key}\s+(\d+)', counts)
    if not m:
        sys.exit(f"Missing :{key} in counts map.")
    return int(m.group(1))

pages = grab("pages")
blocks = grab("blocks")
print(f"{pages} {blocks}")
PY
}

run_validate() {
  local graph_file=$1
  local label=${2:-current}
  local log_file=$3
  echo "Running logseq validate on ${label} graph at ${graph_file}..."

  set +e
  logseq validate -g "$graph_file" >"$log_file" 2>&1
  local status=$?
  set -e

  echo "--- First 10 lines of ${label} validate output ---"
  head -n 10 "$log_file"
  echo "--------------------------------------------------"

  if [[ $status -ne 0 ]]; then
    echo "logseq validate exited with ${status} on ${label} graph; continuing to read counts." >&2
  fi
}

current_log=$(mktemp)
base_log=$(mktemp)
tmp_base_db=$(mktemp)
cleanup() { rm -f "$current_log" "$base_log" "$tmp_base_db"; }
trap cleanup EXIT

run_validate "$GRAPH_PATH" "current" "$current_log"

base_sha=$(git rev-parse --verify "${BASE_COMMIT}" 2>/dev/null || true)
if [[ -z "$base_sha" ]]; then
  echo "Base commit ${BASE_COMMIT} not found; skipping page/block comparison."
  exit 0
fi

if ! git show "${base_sha}:${GRAPH_PATH}" >"$tmp_base_db" 2>/dev/null; then
  echo "Graph ${GRAPH_PATH} not found at ${base_sha}; skipping page/block comparison."
  exit 0
fi

run_validate "$tmp_base_db" "base ${base_sha}" "$base_log"

if ! current_counts=$(parse_counts_file "$current_log"); then
  echo "Failed to parse counts from current graph validate output." >&2
  exit 1
fi

if ! base_counts=$(parse_counts_file "$base_log"); then
  echo "Failed to parse counts from base graph (${base_sha}) validate output." >&2
  exit 1
fi

read -r current_pages current_blocks <<<"$current_counts"
read -r base_pages base_blocks <<<"$base_counts"

echo "Current counts: pages=${current_pages}, blocks=${current_blocks}"
echo "Base counts:    pages=${base_pages}, blocks=${base_blocks}"
echo "Allowed decreases: pages=${PAGE_DROP_THRESHOLD}, blocks=${BLOCK_DROP_THRESHOLD}"

fail=0
page_drop=$((base_pages - current_pages))
block_drop=$((base_blocks - current_blocks))

if (( page_drop > 0 )); then
  echo "Page count decreased: base ${base_pages} -> current ${current_pages} (drop ${page_drop}, allowed ${PAGE_DROP_THRESHOLD})"
  if (( page_drop > PAGE_DROP_THRESHOLD )); then
    fail=1
  fi
fi

if (( block_drop > 0 )); then
  echo "Block count decreased: base ${base_blocks} -> current ${current_blocks} (drop ${block_drop}, allowed ${BLOCK_DROP_THRESHOLD})"
  if (( block_drop > BLOCK_DROP_THRESHOLD )); then
    fail=1
  fi
fi

if (( fail )); then
  echo "Graph validation failed: page/block decreases exceeded allowed thresholds."
  exit 1
fi

echo "Graph counts OK: pages ${current_pages} (base ${base_pages}), blocks ${current_blocks} (base ${base_blocks})."
