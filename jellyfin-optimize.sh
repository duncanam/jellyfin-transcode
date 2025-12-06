#!/bin/bash
# Check for test mode flag
test_mode=false
if [ "$1" = "--test" ]; then
    test_mode=true
    shift
fi
if [ $# -eq 0 ]; then
    echo "Usage: jellyfin-optimize [--test] input.mkv [output.mkv]"
    echo "Creates a 1080p streaming-optimized copy with stereo audio"
    echo ""
    echo "Options:"
    echo "  --test    Encode 30 seconds from the middle for testing"
    exit 1
fi
input="$1"
if [ "$test_mode" = true ]; then
    output="${2:-test_${input%.*}.mkv}"
else
    output="${2:-${input%.*}_optimized.mkv}"
fi
if [ ! -f "$input" ]; then
    echo "Error: Input file '$input' not found"
    exit 1
fi
# Cap threads at 16 for x264 efficiency
threads=$(nproc)
if [ $threads -gt 16 ]; then
    threads=16
fi

# Capture start time
start_time=$(date +%s)
start_display=$(date '+%Y-%m-%d %H:%M:%S')
echo "[START: $start_display]"

# Get duration and calculate middle point for test mode
if [ "$test_mode" = true ]; then
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")
    middle=$(echo "$duration / 2" | bc)
    echo "Test mode: Encoding 30 seconds from middle of file (${middle}s)"
    ffmpeg -ss "$middle" -i "$input" -t 30 \
        -c:v libx264 -preset fast -crf 28 -threads $threads \
        -vf scale=-2:1080 \
        -af "pan=stereo|FL=FL+0.707*FC+0.5*BL+0.5*SL|FR=FR+0.707*FC+0.5*BR+0.5*SR" \
        -c:a aac -b:a 192k -ac 2 \
        -c:s copy \
        "$output"
else
    echo "Full encode mode"
    echo "Optimizing: $input -> $output"
    echo "Using $threads threads with veryslow preset"
    ffmpeg -i "$input" \
        -c:v libx264 -preset veryslow -crf 28 -threads $threads \
        -vf scale=-2:1080 \
        -af "pan=stereo|FL=FL+0.707*FC+0.5*BL+0.5*SL|FR=FR+0.707*FC+0.5*BR+0.5*SR" \
        -c:a aac -b:a 192k -ac 2 \
        -c:s copy \
        "$output"
fi

# Capture end time and calculate elapsed
end_time=$(date +%s)
end_display=$(date '+%Y-%m-%d %H:%M:%S')
elapsed=$((end_time - start_time))
hours=$((elapsed / 3600))
minutes=$(((elapsed % 3600) / 60))
seconds=$((elapsed % 60))

if [ $? -eq 0 ]; then
    printf "[OK: %s | Elapsed: %02d:%02d:%02d]\n" "$end_display" $hours $minutes $seconds
    echo "✓ Successfully created: $output"
    if [ "$test_mode" = true ]; then
        echo "  Test file ready - check audio/video quality before full encode"
    fi
else
    printf "[FAILED: %s | Elapsed: %02d:%02d:%02d]\n" "$end_display" $hours $minutes $seconds
    echo "✗ Error during encoding"
    exit 1
fi
