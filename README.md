# transcribe-audio

A Claude Code skill that transcribes audio files locally on Apple Silicon Macs using NVIDIA's Parakeet model. Drop an audio file into a conversation, ask for a transcript, and get a clean Markdown file with timestamps.

Everything runs on-device. Nothing is sent to the cloud.

## What it does

1. Transcribes audio/video using [parakeet-mlx](https://github.com/senstella/parakeet-mlx) (Parakeet-TDT-0.6b-v3)
2. Claude cleans up the raw transcript — fixes errors, removes filler words, adds structure
3. Saves a `.md` file next to the original audio with timestamp headers

**Speed:** ~1 minute per hour of audio on Apple Silicon (M1/M2/M3/M4).

## Setup

### 1. Install dependencies

```bash
brew install ffmpeg
uv tool install parakeet-mlx
```

The first transcription downloads a 2.5 GB model to `~/.cache/huggingface/` (one-time).

### 2. Install the skill

Clone this repo and symlink the skill into your Claude Code skills directory:

```bash
git clone https://github.com/GDDNEW/transcribe-audio.git ~/transcribe-audio
mkdir -p ~/.claude/skills
ln -sf ~/transcribe-audio/skills/transcribe-audio ~/.claude/skills/transcribe-audio
```

Or just copy the skill file directly:

```bash
mkdir -p ~/.claude/skills/transcribe-audio
cp ~/transcribe-audio/skills/transcribe-audio/SKILL.md ~/.claude/skills/transcribe-audio/
```

### 3. Verify

```bash
parakeet-mlx --help
```

If this prints help text, you're set.

## Usage

In Claude Code, just reference an audio file and ask for a transcript:

```
transcribe Recording.m4a
```

```
Can you transcribe this meeting recording? /path/to/meeting.mp3
```

```
What's in this audio file? recording.wav
```

Claude will show progress via a todo list and status messages as it works through each phase.

### Output

The transcript is saved as a `.md` file next to the original audio:

- `meeting.mp3` → `meeting.md`

Format:

```markdown
# Transcript: meeting

**Date transcribed:** 2026-02-11
**Duration:** ~45 minutes
**Source file:** meeting.mp3

---

## 00:00:00 — Introduction

[Cleaned transcript text...]

## 00:05:12 — Project Updates

[Next section...]
```

## Supported formats

mp3, wav, m4a, mp4, webm, ogg, flac — anything ffmpeg can handle.

## Limitations

- **Apple Silicon only** — requires an M1/M2/M3/M4 Mac
- **English-focused** — Parakeet v3 supports 25 European languages but is optimized for English
- **No speaker diarization** — doesn't identify who's speaking
- **No real-time transcription** — file-based only
- **Memory** — files under 1 hour work on 8 GB Macs; 2+ hours need 16 GB+

## License

CC-BY-4.0
