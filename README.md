# jellyfin-transcode

A set of bash scripts to optimize your personal media library for Jellyfin streaming. These tools transcode video files to a consistent 1080p format with stereo audio, reducing bandwidth requirements and ensuring smooth playback across devices.

## Features

- **Optimized encoding**: Converts videos to 1080p using x264 codec with CRF 28 for excellent quality/size balance
- **Audio downmixing**: Intelligently downmixes surround sound to stereo (useful for mobile devices and bandwidth savings)
- **Test mode**: Encode a 30-second sample from the middle of the video to verify quality before full encode
- **Parallel processing**: Batch process multiple files simultaneously with GNU parallel
- **Smart skipping**: Automatically skips files that already exist at the destination
- **Detailed logging**: Tracks all operations with timestamps and elapsed time

## Requirements

- `ffmpeg` with libx264 and AAC support
- `ffprobe` (typically included with ffmpeg)
- GNU `parallel` (for batch processing)
- `bc` (for test mode calculations)

### Installation

On Ubuntu/Debian:
```bash
sudo apt install ffmpeg parallel bc
```

On Arch Linux:
```bash
sudo pacman -S ffmpeg parallel bc
```

On macOS:
```bash
brew install ffmpeg parallel bc
```

## Usage

### Single File Optimization

The `jellyfin-optimize.sh` script transcodes individual video files.

**Basic usage:**
```bash
./jellyfin-optimize.sh input.mkv
```
This creates `input_optimized.mkv` in the same directory.

**Specify output path:**
```bash
./jellyfin-optimize.sh input.mkv /path/to/output.mkv
```

**Test mode (30-second sample):**
```bash
./jellyfin-optimize.sh --test input.mkv
```
This creates `test_input.mkv` with a 30-second clip from the middle of the video, perfect for checking quality settings before committing to a full encode.

### Batch Processing

The `batch-transcode.sh` script processes multiple files in parallel using a list file.

**Create a list file** (`transcode-list.txt`):
```
/path/to/source/movie1.mkv|/path/to/dest/movie1.mkv
/path/to/source/movie2.mkv|/path/to/dest/movie2.mkv
/path/to/source/show/s01e01.mkv|/path/to/dest/show/s01e01.mkv
# Lines starting with # are ignored
```

**Run batch transcode:**
```bash
./batch-transcode.sh transcode-list.txt 4
```
This processes files from `transcode-list.txt` using 4 parallel jobs.

**Default usage** (2 parallel jobs):
```bash
./batch-transcode.sh
```
Looks for `transcode-list.txt` in the current directory and uses 2 parallel jobs.

## Technical Details

### Video Encoding
- Codec: H.264 (libx264)
- Resolution: 1080p (1920x1080, maintains aspect ratio)
- Quality: CRF 28 (visually lossless for most content)
- Preset: `veryslow` for full encodes (best compression), `fast` for test mode
- Threads: Automatically capped at 16 for optimal x264 efficiency

### Audio Encoding
- Codec: AAC
- Bitrate: 192 kbps
- Channels: 2 (stereo)
- Downmix formula: `FL=FL+0.707*FC+0.5*BL+0.5*SL | FR=FR+0.707*FC+0.5*BR+0.5*SR`
  - Properly centers dialogue and balances surround channels

### Subtitles
- All subtitle tracks are copied without re-encoding

## Output Examples

Single file optimization:
```
[START: 2025-12-06 14:30:15]
Full encode mode
Optimizing: movie.mkv -> movie_optimized.mkv
Using 16 threads with veryslow preset
[OK: 2025-12-06 15:45:22 | Elapsed: 01:15:07]
✓ Successfully created: movie_optimized.mkv
```

Batch processing:
```
=========================================
Jellyfin Batch Transcoder
=========================================
List file: transcode-list.txt
Parallel jobs: 4
Log file: transcode.log
=========================================

Files to process: 12

[START] movie1.mkv
[START] movie2.mkv
[OK] movie1.mkv
[START] movie3.mkv
[OK] movie2.mkv
...
=========================================
Batch complete!
=========================================
```

## Tips

1. **Test first**: Always use `--test` mode on a sample file to verify the quality meets your needs before batch processing
2. **Monitor system load**: Start with fewer parallel jobs (2-3) and increase based on your system's capabilities
3. **Disk space**: Ensure you have sufficient free space; 1080p encodes at CRF 28 typically use 2-4 GB per hour of video
4. **Check logs**: Review `transcode.log` for detailed ffmpeg output and error messages

## License
GPLv3 ♥️
