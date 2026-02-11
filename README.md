# transcribe-audio

A Claude Code plugin that transcribes audio files locally using on-device AI. Drop an audio file into a conversation, ask for a transcript, and get a clean Markdown file with timestamps.

Works on macOS (Apple Silicon + Intel), Windows, and Linux. Everything runs on-device — nothing is sent to the cloud.

## How it works

1. Detects your platform and picks the best transcription engine
2. Transcribes audio/video to raw text with timestamps
3. Claude cleans up the transcript — fixes errors, removes filler words, adds structure
4. Saves a `.md` file next to the original audio

| Platform | Engine | Speed (per hour of audio) |
|----------|--------|--------------------------|
| macOS Apple Silicon | [parakeet-mlx](https://github.com/senstella/parakeet-mlx) (Parakeet-TDT-0.6b-v3) | ~1 minute |
| macOS Intel | [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (Whisper large-v3) | ~5-10 minutes |
| Windows/Linux (NVIDIA GPU) | faster-whisper | ~2-3 minutes |
| Windows/Linux (CPU only) | faster-whisper | ~5-10 minutes |

## Setup

### macOS (Apple Silicon)

```bash
brew install ffmpeg
uv tool install parakeet-mlx
```

### macOS (Intel), Windows, or Linux

```bash
uv tool install faster-whisper
```

Also install ffmpeg if you don't have it:
- **macOS/Linux:** `brew install ffmpeg`
- **Windows:** Download from [ffmpeg.org](https://ffmpeg.org/download.html) or `winget install ffmpeg`

### Install the plugin

**Option A — Clone and symlink (recommended, stays up to date):**

```bash
git clone https://github.com/GDDNEW/transcribe-audio.git ~/transcribe-audio
mkdir -p ~/.claude/skills
ln -sf ~/transcribe-audio/skills/transcribe-audio ~/.claude/skills/transcribe-audio
```

**Option B — Copy the skill file directly:**

```bash
mkdir -p ~/.claude/skills/transcribe-audio
curl -o ~/.claude/skills/transcribe-audio/SKILL.md https://raw.githubusercontent.com/GDDNEW/transcribe-audio/main/skills/transcribe-audio/SKILL.md
```

### First-run model download

The first transcription downloads the AI model (~2.5 GB). This takes 2-3 minutes on a fast connection and only happens once. Claude will tell you when this is happening and show progress.

After that, all transcriptions start instantly.

**Where the model lives:**

| Platform | Model path |
|----------|-----------|
| macOS (Apple Silicon) | `~/.cache/huggingface/hub/models--mlx-community--parakeet-tdt-0.6b-v3/` |
| Windows/Linux/Intel Mac | `~/.cache/huggingface/hub/models--Systran--faster-whisper-large-v3/` |

This is the standard Hugging Face cache directory. The CLI tools download here automatically and read from here on every run. To force a re-download, delete the model directory and transcribe again.

### Verify

```bash
# macOS Apple Silicon
parakeet-mlx --help

# Everyone else
faster-whisper --help
```

## Usage

In Claude Code, just reference an audio file and ask for a transcript:

```
transcribe meeting-recording.m4a
```

```
Can you transcribe this? /path/to/lecture.mp3
```

```
What's in this audio file? interview.wav
```

Claude shows a progress checklist as it works through each phase: checking dependencies, transcribing, reading output, cleaning up, and saving.

### Output

The transcript is saved as a `.md` file next to the original audio:

- `meeting.mp3` → `meeting.md`

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

- **No speaker diarization** — doesn't identify who's speaking
- **No real-time transcription** — file-based only
- **Language support** — Parakeet: English + 25 European languages. Whisper: 99 languages.
- **Memory (macOS)** — files under 1 hour work on 8 GB Macs; 2+ hours need 16 GB+

## License

MIT
