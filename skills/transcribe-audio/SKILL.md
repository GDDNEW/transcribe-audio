---
name: transcribe-audio
description: Transcribe audio and video files to text using local on-device AI. Use when the user provides an audio file (mp3, wav, m4a, mp4, etc.) and wants a transcript, meeting notes, or text version of spoken content.
---

# Audio Transcription

Transcribe audio/video files locally using on-device AI. Uses Parakeet on Apple Silicon Macs, or Whisper on Windows/Linux. All processing happens on-device — nothing is sent to the cloud.

## When to use

Activate when the user:
- Provides an audio or video file and asks for a transcript
- Mentions "transcribe", "transcription", "meeting notes from audio", or similar
- Drops a .mp3, .wav, .m4a, .mp4, .webm, .ogg, .flac file and asks what's in it

## Progress tracking

Before starting, detect the platform and whether the model is downloaded. Then create a todo list using TodoWrite and print a status message before each phase.

**Base todo list (model already downloaded):**

| # | Task | activeForm |
|---|------|------------|
| 1 | Check dependencies and platform | Checking dependencies and platform |
| 2 | Transcribe audio | Transcribing audio |
| 3 | Read raw transcript | Reading raw transcript |
| 4 | Clean up and format as Markdown | Cleaning up and formatting as Markdown |
| 5 | Save final transcript | Saving final transcript |

**If the model has NOT been downloaded yet, insert an extra item after #1:**

| # | Task | activeForm |
|---|------|------------|
| 2 | Download transcription model (~2.5 GB) | Downloading transcription model (~2.5 GB) |

This shifts all subsequent items down by one. Build the todo list dynamically after the dependency check.

## Step 1: Check dependencies and platform

Mark todo #1 as `in_progress`. Tell the user: "Checking dependencies and platform..."

### Detect platform

```bash
uname -s
```

- **`Darwin`** = macOS → use `parakeet-mlx`
- **Anything else** (Linux, MINGW, MSYS, CYGWIN) → use `faster-whisper`

### Check transcription tool

**macOS:**
```bash
which parakeet-mlx && echo "TOOL_OK" || echo "TOOL_MISSING"
```

If missing, tell the user:
> Install parakeet-mlx:
> ```
> brew install ffmpeg
> uv tool install parakeet-mlx
> ```

**Windows/Linux:**
```bash
which faster-whisper && echo "TOOL_OK" || echo "TOOL_MISSING"
```

If missing, tell the user:
> Install faster-whisper:
> ```
> uv tool install faster-whisper
> ```
> Also ensure ffmpeg is installed (`brew install ffmpeg` on Linux, or download from ffmpeg.org on Windows).

### Check if model is downloaded

**macOS (Parakeet):**
```bash
ls ~/.cache/huggingface/hub/models--mlx-community--parakeet-tdt-0.6b-v3/snapshots 2>/dev/null && echo "MODEL_READY" || echo "MODEL_MISSING"
```

**Windows/Linux (Whisper):**
```bash
ls ~/.cache/huggingface/hub/models--Systran--faster-whisper-large-v3/snapshots 2>/dev/null && echo "MODEL_READY" || echo "MODEL_MISSING"
```

If `MODEL_MISSING`, tell the user: **"First-time setup: the transcription model (~2.5 GB) will download automatically. This takes 2-3 minutes on a fast connection and only happens once."**

Now create the TodoWrite list — include the "Download transcription model" step only if `MODEL_MISSING`.

Mark todo #1 as `completed`.

## Step 2: Transcribe (includes model download if needed)

If the model needs downloading, mark the download todo as `in_progress` first. Tell the user: "Downloading transcription model (~2.5 GB) — one-time download..."

The model downloads automatically when the transcription command runs. Once the command completes, mark the download todo as `completed` and then mark the transcription todo as `completed`.

If the model is already downloaded, just mark the transcription todo as `in_progress`. Tell the user the estimated duration (e.g., "Transcribing ~57 minutes of audio — should take about a minute...").

First, clean and create the output directory:

```bash
rm -rf /tmp/transcribe-output && mkdir -p /tmp/transcribe-output
```

Then run the transcription:

**macOS:**
```bash
parakeet-mlx "<filepath>" --output-format srt --output-dir /tmp/transcribe-output
```

For files over 2 hours, add `--local-attention` to reduce memory usage.

**Windows/Linux:**
```bash
faster-whisper "<filepath>" --output_format srt --output_dir /tmp/transcribe-output --model large-v3
```

For NVIDIA GPU acceleration, faster-whisper uses CUDA automatically if available. CPU works but is slower.

Mark the transcription todo as `completed`.

## Step 3: Read the raw output

Mark the read todo as `in_progress`. Tell the user: "Reading raw transcript..."

**IMPORTANT: Use the Bash tool (not the Read tool) to read the SRT file.** The Read tool has a token limit that forces multi-turn chunked reading on long transcripts. Using Bash reads the entire file in one turn.

```bash
cat /tmp/transcribe-output/*.srt
```

If the file is extremely large and the bash output is truncated, fall back to reading in two halves:

```bash
head -n 2000 /tmp/transcribe-output/*.srt
```
```bash
tail -n +2001 /tmp/transcribe-output/*.srt
```

Mark the read todo as `completed`.

## Step 4: Clean up and format as Markdown

Mark the cleanup todo as `in_progress`. Tell the user: "Cleaning up transcript and formatting as Markdown..."

Take the raw SRT transcript and produce a clean .md file. Apply these cleanup rules:

1. **Fix obvious transcription errors:** Correct clearly wrong words based on surrounding context (e.g., "they're product" → "their product")
2. **Remove filler words:** Strip excessive "um", "uh", "like", "you know" — but keep them if they carry meaning or convey tone
3. **Fix punctuation and capitalization:** Parakeet/Whisper handles this well already, but fix any remaining issues
4. **Preserve timestamps:** Convert SRT timestamps to section headers at natural topic breaks
5. **Add paragraph breaks:** Group related sentences into readable paragraphs
6. **Do NOT change meaning:** Never alter what was said. Only fix how it reads.

### Output format

```markdown
# Transcript: [filename without extension]

**Date transcribed:** [today's date]
**Duration:** [from audio length]
**Source file:** [original filename]

---

## 00:00:00 — [Topic or section title]

[Cleaned transcript text in natural paragraphs...]

## 00:05:23 — [Next topic or section title]

[Next section of transcript...]
```

**Timestamp format rules:**
- Use `## HH:MM:SS — Topic Title` — no brackets around the timestamp
- Place headers at natural topic breaks or roughly every 3-5 minutes, whichever produces more readable output
- Within sections, use regular paragraphs — no bullet points unless the speaker is clearly listing things

Mark the cleanup todo as `completed`.

## Step 5: Save the output

Mark the save todo as `in_progress`. Tell the user: "Saving transcript..."

Save the cleaned markdown file alongside the original audio file with the same name but `.md` extension:

- Input: `meeting-recording.mp3`
- Output: `meeting-recording.md`

If the file already exists, append a number: `meeting-recording-2.md`

Mark the save todo as `completed`. Tell the user the transcript is done and where the file was saved.

## Model location reference

The transcription models are stored in the standard Hugging Face cache directory. This is where the CLI tools download to and read from automatically.

| Platform | Model | Path |
|----------|-------|------|
| macOS (Apple Silicon) | Parakeet-TDT-0.6b-v3 | `~/.cache/huggingface/hub/models--mlx-community--parakeet-tdt-0.6b-v3/` |
| Windows/Linux | Whisper large-v3 | `~/.cache/huggingface/hub/models--Systran--faster-whisper-large-v3/` |

- **Size:** ~2.5 GB on disk
- **Downloaded automatically** on first transcription run
- **Cached permanently** — only downloads once, then reused for all future transcriptions
- **To re-download:** Delete the model directory and run a transcription again
- **To check if present:** Look for a `snapshots/` subdirectory inside the model path

If the user asks where the model is, or if there are issues with the model, reference this table.

## Edge cases

- **Video files:** Works fine — both tools extract audio via ffmpeg automatically
- **Multiple speakers:** Neither Parakeet nor Whisper does speaker diarization. Note this in the output if the audio clearly has multiple speakers: add a note at the top saying *"Note: This transcript does not distinguish between speakers."*
- **Non-English audio:** Parakeet v3 supports English + 25 European languages. Whisper large-v3 supports 99 languages. If on macOS and transcription quality seems poor for a non-European language, suggest the user install faster-whisper instead for broader language support.
- **Very large files (macOS):** For files over 2 hours, use `--local-attention` flag with parakeet-mlx. For files over 4 hours, suggest splitting first.
- **Windows/Linux performance:** faster-whisper is slower than parakeet-mlx. Expect ~5-10 minutes per hour of audio on CPU, ~2-3 minutes with an NVIDIA GPU.
- **macOS Intel:** Uses faster-whisper (same as Windows/Linux). parakeet-mlx requires Apple Silicon (M1+).
