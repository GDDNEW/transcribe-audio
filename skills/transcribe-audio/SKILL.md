---
name: transcribe-audio
description: Transcribe audio and video files to text using local on-device AI. Use when the user provides an audio file (mp3, wav, m4a, mp4, etc.) and wants a transcript, meeting notes, or text version of spoken content.
dependencies: parakeet-mlx, ffmpeg
---

# Audio Transcription

Transcribe audio/video files locally using Parakeet (NVIDIA's ASR model running on Apple Silicon via MLX). All processing happens on-device — nothing is sent to the cloud.

## When to use

Activate when the user:
- Provides an audio or video file and asks for a transcript
- Mentions "transcribe", "transcription", "meeting notes from audio", or similar
- Drops a .mp3, .wav, .m4a, .mp4, .webm, .ogg, .flac file and asks what's in it

## Progress tracking

Before starting, create a todo list and print a status message before each phase. Keep the user informed throughout.

**Create this todo list immediately using TodoWrite:**

| # | Task | activeForm |
|---|------|------------|
| 1 | Check dependencies | Checking dependencies |
| 2 | Transcribe audio with Parakeet | Transcribing audio with Parakeet |
| 3 | Read raw transcript | Reading raw transcript |
| 4 | Clean up and format as Markdown | Cleaning up and formatting as Markdown |
| 5 | Save final transcript | Saving final transcript |

Mark each task `in_progress` before starting it. Mark it `completed` when done. Print a short status message to the user before each phase (e.g., "Transcribing ~57 minutes of audio...").

## Step 1: Check dependencies

Mark todo #1 as `in_progress`. Tell the user: "Checking dependencies..."

```bash
which parakeet-mlx && echo "OK" || echo "MISSING"
```

If missing, tell the user:

> To use this skill, you need `parakeet-mlx` installed. Run:
> ```
> brew install ffmpeg
> uv tool install parakeet-mlx
> ```
> The first transcription will download a 2.5 GB model (one-time only).

Mark todo #1 as `completed`.

## Step 2: Transcribe

Mark todo #2 as `in_progress`. Tell the user the estimated duration if known (e.g., "Transcribing ~57 minutes of audio — this should take about a minute...").

First, clean and create the output directory:

```bash
rm -rf /tmp/transcribe-output && mkdir -p /tmp/transcribe-output
```

Then run parakeet-mlx:

```bash
parakeet-mlx "<filepath>" --output-format srt --output-dir /tmp/transcribe-output
```

Notes:
- parakeet-mlx handles mp3, wav, m4a, mp4, and most common formats via ffmpeg
- For very long files (2+ hours), add `--local-attention` to reduce memory usage
- The model auto-downloads on first use to `~/.cache/huggingface/`

Mark todo #2 as `completed`.

## Step 3: Read the raw output

Mark todo #3 as `in_progress`. Tell the user: "Reading raw transcript..."

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

Mark todo #3 as `completed`.

## Step 4: Clean up and format as Markdown

Mark todo #4 as `in_progress`. Tell the user: "Cleaning up transcript and formatting as Markdown..."

Take the raw SRT transcript and produce a clean .md file. Apply these cleanup rules:

1. **Fix obvious transcription errors:** Correct clearly wrong words based on surrounding context (e.g., "they're product" → "their product")
2. **Remove filler words:** Strip excessive "um", "uh", "like", "you know" — but keep them if they carry meaning or convey tone
3. **Fix punctuation and capitalization:** Parakeet handles this well already, but fix any remaining issues
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

Mark todo #4 as `completed`.

## Step 5: Save the output

Mark todo #5 as `in_progress`. Tell the user: "Saving transcript..."

Save the cleaned markdown file alongside the original audio file with the same name but `.md` extension:

- Input: `meeting-recording.mp3`
- Output: `meeting-recording.md`

If the file already exists, append a number: `meeting-recording-2.md`

Mark todo #5 as `completed`. Tell the user the transcript is done and where the file was saved.

## Edge cases

- **Video files:** Works fine — parakeet-mlx / ffmpeg extracts audio automatically
- **Multiple speakers:** Parakeet v3 does not do speaker diarization. Note this in the output if the audio clearly has multiple speakers: add a note at the top saying *"Note: This transcript does not distinguish between speakers."*
- **Non-English audio:** Parakeet v3 supports 25 European languages and auto-detects. If transcription quality seems poor, mention the language limitation to the user.
- **Very large files:** For files over 2 hours, use `--local-attention` flag. For files over 4 hours, suggest splitting first.
