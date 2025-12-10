#!/bin/bash
################################################################################
# Simple parallel transcoder
# Reads a two-column list file and transcodes in parallel
#
# Usage: ./batch-transcode.sh [--gpu] [list-file] [parallel-jobs]
#   --gpu: Use GPU hardware encoder (optional)
#   list-file: Text file with "source_path|dest_path" per line
#   parallel-jobs: Number of parallel transcodes (default: 2)
################################################################################

set -euo pipefail

# Check for GPU flag
GPU_FLAG=""
if [[ "${1:-}" == "--gpu" ]]; then
    GPU_FLAG="--gpu"
    shift
fi

# Configuration
LIST_FILE="${1:-transcode-list.txt}"
PARALLEL_JOBS="${2:-2}"
LOG_FILE="transcode.log"

# Force 1 job when using GPU to avoid GPU contention
if [[ -n "$GPU_FLAG" ]]; then
    PARALLEL_JOBS=1
fi

# Validate inputs
if [[ ! -f "$LIST_FILE" ]]; then
    echo "Error: List file not found: $LIST_FILE"
    echo ""
    echo "Usage: $0 [--gpu] [list-file] [parallel-jobs]"
    echo "  --gpu: Use GPU hardware encoder (optional)"
    echo "  list-file: Two-column file with source|destination paths"
    echo "  parallel-jobs: Number of parallel jobs (default: 2)"
    exit 1
fi

if ! command -v parallel &> /dev/null; then
    echo "Error: GNU parallel not found"
    exit 1
fi

if ! command -v jellyfin-optimize.sh &> /dev/null; then
    echo "Error: jellyfin-optimize.sh not found"
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

    if [[ "$GPU_MODE" == "1" ]]; then
        jellyfin-optimize.sh --gpu "$source" "$dest" >> "$LOG_FILE" 2>&1
    else
        jellyfin-optimize.sh "$source" "$dest" >> "$LOG_FILE" 2>&1
    fi

    if [[ $? -eq 0 ]]; then
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
# Export GPU_FLAG as a simple flag value, not the string "--gpu"
export GPU_MODE="${GPU_FLAG:+1}"

# Start transcoding
echo "========================================="
echo "Jellyfin Batch Transcoder"
echo "========================================="
echo "List file: $LIST_FILE"
echo "Parallel jobs: $PARALLEL_JOBS"
if [[ -n "$GPU_FLAG" ]]; then
    echo "GPU mode: enabled (parallel jobs forced to 1)"
else
    echo "GPU mode: disabled"
fi
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
