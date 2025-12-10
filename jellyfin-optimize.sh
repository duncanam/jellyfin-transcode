#!/bin/bash
# Check for flags
test_mode=false
gpu_mode=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            test_mode=true
            shift
            ;;
        --gpu)
            gpu_mode=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "Usage: jellyfin-optimize [--test] [--gpu] input.mkv [output.mkv]"
    echo "Creates a 1080p streaming-optimized copy with stereo audio"
    echo ""
    echo "Options:"
    echo "  --test    Encode 30 seconds from the middle for testing"
    echo "  --gpu     Use GPU hardware encoder (VAAPI) - much faster"
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

# Set encoder options based on GPU mode
if [ "$gpu_mode" = true ]; then
    encoder="h264_vaapi"
    echo "Using GPU encoder: VAAPI (AMD)"
else
    encoder="libx264"
    if [ "$test_mode" = true ]; then
        encoder_opts="-preset fast -crf 28 -threads $threads"
    else
        encoder_opts="-preset veryslow -crf 28 -threads $threads"
    fi
    echo "Using CPU encoder: libx264"
fi

# Get duration and calculate middle point for test mode
if [ "$test_mode" = true ]; then
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input")
    middle=$(echo "$duration / 2" | bc)
    echo "Test mode: Encoding 30 seconds from middle of file (${middle}s)"

    if [ "$gpu_mode" = true ]; then
        ffmpeg -ss "$middle" -t 30 \
            -init_hw_device vaapi=va:/dev/dri/renderD128 \
            -i "$input" \
            -vf 'format=nv12,hwupload,scale_vaapi=-2:1080' \
            -c:v $encoder -qp 28 \
            -af "pan=stereo|FL=FL+0.707*FC+0.5*BL+0.5*SL|FR=FR+0.707*FC+0.5*BR+0.5*SR" \
            -c:a aac -b:a 192k -ac 2 \
            -c:s copy \
            "$output"
    else
        ffmpeg -ss "$middle" -i "$input" -t 30 \
            -c:v $encoder $encoder_opts \
            -vf scale=-2:1080 \
            -af "pan=stereo|FL=FL+0.707*FC+0.5*BL+0.5*SL|FR=FR+0.707*FC+0.5*BR+0.5*SR" \
            -c:a aac -b:a 192k -ac 2 \
            -c:s copy \
            "$output"
    fi
else
    echo "Full encode mode"
    echo "Optimizing: $input -> $output"
    if [ "$gpu_mode" = false ]; then
        echo "Using $threads threads with veryslow preset"
    fi

    if [ "$gpu_mode" = true ]; then
        ffmpeg \
            -init_hw_device vaapi=va:/dev/dri/renderD128 \
            -i "$input" \
            -vf 'format=nv12,hwupload,scale_vaapi=-2:1080' \
            -c:v $encoder -qp 28 \
            -af "pan=stereo|FL=FL+0.707*FC+0.5*BL+0.5*SL|FR=FR+0.707*FC+0.5*BR+0.5*SR" \
            -c:a aac -b:a 192k -ac 2 \
            -c:s copy \
            "$output"
    else
        ffmpeg -i "$input" \
            -c:v $encoder $encoder_opts \
            -vf scale=-2:1080 \
            -af "pan=stereo|FL=FL+0.707*FC+0.5*BL+0.5*SL|FR=FR+0.707*FC+0.5*BR+0.5*SR" \
            -c:a aac -b:a 192k -ac 2 \
            -c:s copy \
            "$output"
    fi
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
