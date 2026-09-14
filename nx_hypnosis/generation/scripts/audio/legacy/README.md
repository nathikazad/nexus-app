> Historical experiments. The approved generation workflows are described in `generation/skills/`.

# First voice test

A gentle relaxation opening followed by a short story about Arun creating opportunities through curiosity,
service, and collaboration. This test evaluates the narration before app development.

Uses Python 3 with no third-party dependencies. Start in this folder:

```sh
cd /Users/nathikazad/Projects/Nexus/mobile/nx_hypnosis/generation
python3 scripts/audio/legacy/generate_voice.py --dry-run
```

Put your token in the local `.env` file as `ELEVENLABS_API_KEY=your_token`, or set
the `ELEVENLABS_API_KEY` environment variable. The local `.env` and generated
`outputs/legacy/` directory are ignored by Git. The script never prints the token.

Generate the sample:

```sh
python3 scripts/audio/legacy/generate_voice.py
```

The script saves a timestamped MP3 under `outputs/legacy/` and prints its full path.
Each generation submits the story to ElevenLabs and uses account credits.
It does not automatically retry failed requests.

## Starting voice settings

- Voice: Hypnotizer (`iI1BlqMaaIkiLuGRhtpA`), your custom hypnosis narrator.
- Model: `eleven_multilingual_v2`, chosen for consistent narrative delivery.
- Speed: `0.7`, for a slower read, with explicit pauses in the relaxation opening.
- Stability: `0.65`, similarity: `0.75`, style: `0`, speaker boost enabled.

Hypnotizer was selected from your saved voices. Use `--voice-id` to compare
another voice. No alternative is silently selected.

```sh
python3 scripts/audio/legacy/generate_voice.py --speed 0.8 --stability 0.7
python3 scripts/audio/legacy/generate_voice.py --voice-id YOUR_VOICE_ID
python3 scripts/audio/legacy/generate_voice.py --text-file another_story.txt --output outputs/legacy/alternate.mp3
```

Edit `stories/abundance/legacy/story.txt` to change the story. No separate story-generation service is needed.
Listen for warmth, comfortable pacing, natural pauses, and whether the delivery
feels immersive without becoming flat or theatrical. These settings are a starting
point; audio quality has not been validated until a live sample is generated and heard.

References: [speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert),
[voice settings](https://elevenlabs.io/docs/api-reference/voices/settings/get),
[default voices](https://elevenlabs.io/docs/help-center/product/voices/my-voices/what-are-default-voices).

## Slower copy with longer pauses

Keep the exact existing narration and lower its tempo without changing pitch:

```sh
python3 scripts/audio/legacy/slow_recording.py outputs/legacy/hypnotizer_abundance_creator.mp3 \
  outputs/legacy/hypnotizer_abundance_creator_075x_pauses.mp3 --tempo 0.75 --minimum-pause 2.5
```

Requires FFmpeg. This extends existing quiet gaps of at least 0.7 seconds to
at least 2.5 seconds after slowing, and adds opening/closing silence. It does
not regenerate the voice or spend API credits. A JSON sidecar records the
render settings and duration. Use a new output filename for each variation.

## Headphone refinement

`refine_recording.py` starts from the original narration, applies a gentle 75 Hz
high-pass and a −4.5 dB bass shelf at 180 Hz, and preserves the 0.75 tempo.
Only long existing quiet gaps (at least 1.95 seconds after slowing) are extended
to four seconds. Insertions occur in the middle of those gaps with 80 ms cosine
fades to and from zero, avoiding the earlier hard splice at silence endings.
The script verifies zero-valued join endpoints and unclipped PCM, and writes a
settings sidecar. Preview on headphones before replacing production audio.

```sh
python3 scripts/audio/legacy/refine_recording.py outputs/legacy/hypnotizer_abundance_creator.mp3 \
  outputs/legacy/hypnotizer_abundance_creator_075x_soft_pauses_light_bass.mp3
```
