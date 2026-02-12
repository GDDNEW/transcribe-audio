#!/usr/bin/env bash
# transcribe-progress.sh — Progress sidecar for audio transcription
#
# This script does NOT run the transcription itself. It runs alongside the
# transcription process and writes estimated progress to a file that Claude
# can poll. The transcription runs separately at full CPU priority.
#
# Usage:
#   bash transcribe-progress.sh <input-audio> <output-dir> [backend]
#
# This script:
#   1. Probes audio duration
#   2. Writes progress estimates to <output-dir>/progress.txt every 3 seconds
#   3. Stops when it detects an SRT file in <output-dir> or a done marker
#
# Progress file format:
#   STATUS | ELAPSEDs | EST_TOTALs | PCT% | MESSAGE
#
# Claude starts this sidecar FIRST (in background), then starts the
# transcription (in background via Bash run_in_background), then polls
# progress.txt. When transcription finishes, Claude writes a done marker
# or the sidecar detects the SRT output.

set -uo pipefail

INPUT="$1"
OUTPUT_DIR="$2"
BACKEND="${3:-parakeet-mlx}"

PROGRESS_FILE="$OUTPUT_DIR/progress.txt"
DONE_MARKER="$OUTPUT_DIR/.done"

mkdir -p "$OUTPUT_DIR"
rm -f "$DONE_MARKER"

# Get audio duration
DURATION=$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$INPUT" 2>/dev/null)
DURATION_INT=${DURATION%.*}

if [ -z "$DURATION_INT" ] || [ "$DURATION_INT" -eq 0 ]; then
    echo "FAILED | 0s | 0s | 0% | Could not determine audio duration" > "$PROGRESS_FILE"
    exit 1
fi

# Estimate total time
# These run as background processes so macOS deprioritizes them.
# Measured data points (parakeet-mlx, Apple Silicon M-series):
#   58s audio  → 10s wall clock  (ratio ~6x)
#   3452s audio → 1175s wall clock (ratio ~3x)
# Short files process faster per-second; long files get throttled more.
if [ "$BACKEND" = "parakeet-mlx" ]; then
    if [ "$DURATION_INT" -lt 300 ]; then
        # Short files (<5 min): ~6 sec audio per 1 sec wall + overhead
        EST_TOTAL=$(( DURATION_INT / 6 + 8 ))
    else
        # Long files (5+ min): ~3 sec audio per 1 sec wall + overhead
        EST_TOTAL=$(( DURATION_INT / 3 + 15 ))
    fi
else
    EST_TOTAL=$(( DURATION_INT / 2 + 20 ))
fi
[ "$EST_TOTAL" -lt 12 ] && EST_TOTAL=12

DURATION_MIN=$(( DURATION_INT / 60 ))
DURATION_SEC=$(( DURATION_INT % 60 ))
DURATION_HUMAN="${DURATION_MIN}m${DURATION_SEC}s"
NUM_CHUNKS=$(( (DURATION_INT + 119) / 120 ))

echo "STARTING | 0s | ${EST_TOTAL}s | 0% | Preparing to transcribe ${DURATION_HUMAN} of audio (~${NUM_CHUNKS} chunks, est ~${EST_TOTAL}s)" > "$PROGRESS_FILE"

START_TIME=$(date +%s)

# Progress loop — runs until SRT appears or done marker is set
while true; do
    sleep 3

    # Check if transcription finished (SRT file exists or done marker)
    if [ -f "$DONE_MARKER" ]; then
        NOW=$(date +%s)
        ELAPSED=$(( NOW - START_TIME ))
        SRT_FILE=$(ls "$OUTPUT_DIR"/*.srt 2>/dev/null | head -1)
        if [ -n "$SRT_FILE" ]; then
            SRT_LINES=$(wc -l < "$SRT_FILE" | tr -d ' ')
            echo "DONE | ${ELAPSED}s | ${EST_TOTAL}s | 100% | Complete in ${ELAPSED}s — ${SRT_LINES} lines" > "$PROGRESS_FILE"
        else
            echo "DONE | ${ELAPSED}s | ${EST_TOTAL}s | 100% | Complete in ${ELAPSED}s" > "$PROGRESS_FILE"
        fi
        exit 0
    fi

    # Also check if SRT appeared (transcription wrote output)
    SRT_CHECK=$(ls "$OUTPUT_DIR"/*.srt 2>/dev/null | head -1)
    if [ -n "$SRT_CHECK" ]; then
        NOW=$(date +%s)
        ELAPSED=$(( NOW - START_TIME ))
        SRT_LINES=$(wc -l < "$SRT_CHECK" | tr -d ' ')
        echo "DONE | ${ELAPSED}s | ${EST_TOTAL}s | 100% | Complete in ${ELAPSED}s — ${SRT_LINES} lines" > "$PROGRESS_FILE"
        exit 0
    fi

    NOW=$(date +%s)
    ELAPSED=$(( NOW - START_TIME ))

    # Percentage from elapsed vs estimate
    if [ "$EST_TOTAL" -gt 0 ]; then
        PCT=$(( ELAPSED * 100 / EST_TOTAL ))
    else
        PCT=50
    fi
    [ "$PCT" -gt 95 ] && PCT=95

    # Chunk estimate
    if [ "$NUM_CHUNKS" -gt 1 ] && [ "$EST_TOTAL" -gt 0 ]; then
        CHUNK_EST=$(( ELAPSED * NUM_CHUNKS / EST_TOTAL + 1 ))
        [ "$CHUNK_EST" -gt "$NUM_CHUNKS" ] && CHUNK_EST=$NUM_CHUNKS
        CHUNK_MSG="chunk ~${CHUNK_EST}/${NUM_CHUNKS}"
    else
        CHUNK_MSG="processing"
    fi

    # Time remaining
    REMAINING=$(( EST_TOTAL - ELAPSED ))
    [ "$REMAINING" -lt 0 ] && REMAINING=0
    if [ "$REMAINING" -gt 60 ]; then
        TIME_LEFT="~$(( REMAINING / 60 ))m$(( REMAINING % 60 ))s left"
    elif [ "$REMAINING" -gt 0 ]; then
        TIME_LEFT="~${REMAINING}s left"
    else
        TIME_LEFT="almost done..."
    fi

    echo "RUNNING | ${ELAPSED}s | ${EST_TOTAL}s | ${PCT}% | ${DURATION_HUMAN} audio — ${CHUNK_MSG}, ${TIME_LEFT}" > "$PROGRESS_FILE"
done
