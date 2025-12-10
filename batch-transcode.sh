#!/bin/bash
################################################################################
# Simple parallel transcoder
# Reads a two-column list file and transcodes in parallel
#
# Usage: ./batch-transcode.sh [list-file] [parallel-jobs]
#   list-file: Text file with "source_path|dest_path" per line
#   parallel-jobs: Number of parallel transcodes (default: 2)
################################################################################

set -euo pipefail

# Configuration
LIST_FILE="${1:-transcode-list.txt}"
PARALLEL_JOBS="${2:-2}"
LOG_FILE="transcode.log"

# Validate inputs
if [[ ! -f "$LIST_FILE" ]]; then
    echo "Error: List file not found: $LIST_FILE"
    echo ""
    echo "Usage: $0 [list-file] [parallel-jobs]"
    echo "  list-file: Two-column file with source|destination paths"
    echo "  parallel-jobs: Number of parallel jobs (default: 2)"
    exit 1
fi

if ! command -v parallel &> /dev/null; then
    echo "Error: GNU parallel not found"
    exit 1
fi

if ! command -v jellyfin-optimize &> /dev/null; then
    echo "Error: jellyfin-optimize not found"
    exit 1
fi

# Transcode function - takes full line and parses it
transcode_file() {
    local line="$1"
    local source="${line%%|*}"
    local dest="${line#*|}"

    # Skip if destination exists
    if [[ -f "$dest" ]]; then
        echo "[SKIP] $dest (already exists)"
        return 0
    fi

    # Skip if source doesn't exist
    if [[ ! -f "$source" ]]; then
        echo "[ERROR] Source not found: $source"
        return 1
    fi

    # Create destination directory
    mkdir -p "$(dirname "$dest")"

    echo "[START] $(basename "$dest")"

    if jellyfin-optimize "$source" "$dest" >> "$LOG_FILE" 2>&1; then
        echo "[OK] $(basename "$dest")"
        return 0
    else
        echo "[FAIL] $(basename "$dest")"
        # Remove partial file
        [[ -f "$dest" ]] && rm -f "$dest"
        return 1
    fi
}

export -f transcode_file
export LOG_FILE

# Start transcoding
echo "========================================="
echo "Jellyfin Batch Transcoder"
echo "========================================="
echo "List file: $LIST_FILE"
echo "Parallel jobs: $PARALLEL_JOBS"
echo "Log file: $LOG_FILE"
echo "========================================="
echo ""

# Count active lines (non-empty, non-comment)
TOTAL=$(grep -v '^[[:space:]]*#' "$LIST_FILE" | grep -v '^[[:space:]]*$' | wc -l)
echo "Files to process: $TOTAL"
echo ""

# Initialize log
echo "=== Transcode session started: $(date) ===" >> "$LOG_FILE"

# Process files with GNU parallel
grep -v '^[[:space:]]*#' "$LIST_FILE" | \
    grep -v '^[[:space:]]*$' | \
    parallel --jobs "$PARALLEL_JOBS" \
             --line-buffer \
             transcode_file {}

EXIT_CODE=$?

echo ""
echo "========================================="
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Batch complete!"
else
    echo "Batch completed with errors (see $LOG_FILE)"
fi
echo "========================================="

exit $EXIT_CODE
