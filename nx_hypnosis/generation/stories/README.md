# Inworld story scripts

`roger/v1/script.json` contains the full Roger story and approved cast. `roger/v1/story.md` preserves the original prose for comparison. Edward plays Roger; Arthur remains Rick.

The revised faith-focused draft is `roger/v2/story.md`, with matching `roger/v2/script.json`. It deepens Roger’s helplessness, trust in God’s limitless abundance, and remembrance in ordinary actions. Version 2 is the currently published 39:50 recording; version 1 preserves the original 28:57 recording.

## Format

The JSON file has:

- `version`: currently `1`.
- `title`: a human-readable title; never spoken.
- `cast`: character names mapped to exact Inworld voice IDs.
- `speaking_rate`: native generation speed, currently `0.95`.
- `delivery_mode`: `BALANCED` allows more expression than `STABLE`.
- `speaker_instructions`: default performance direction for each character; never spoken.
- `turns`: the performance in order. Each has a unique `id`, a `scene`, a `speaker` matching the cast, spoken `text`, and `pause` (seconds of added silence after the turn). Optional `instruction` overrides that character's default for this turn.

Example:

```json
{
  "version": 1,
  "title": "Roger sample",
  "cast": {"Narrator": "Harold", "Roger": "Edward"},
  "speaking_rate": 0.95,
  "delivery_mode": "BALANCED",
  "speaker_instructions": {
    "Narrator": "Warm, grounded storytelling.",
    "Roger": "Humble, courageous and expressive. Natural conversation."
  },
  "turns": [
    {"id": "turn-001", "scene": 1, "speaker": "Narrator", "text": "Roger tried to smile with them.", "pause": 0.5},
    {"id": "turn-002", "scene": 1, "speaker": "Roger", "text": "I want to try,", "instruction": "Nervous but quietly determined.", "pause": 0.18},
    {"id": "turn-003", "scene": 1, "speaker": "Narrator", "text": "he said.", "pause": 0.5}
  ]
}
```

Keep narrative tags such as “he said” in narrator turns. Dialogue quotation marks, Markdown dividers, and italic markers are removed from spoken text. Unquoted written notes and the incidental passerby's one line remain with the narrator. Scene breaks use a longer pause. Pauses add silence to any natural pauses already produced by the model.

## Validate or render

Run from `mobile/nx_hypnosis/generation`:

```sh
python3 scripts/audio/inworld_dialogue.py stories/roger/v1/script.json --validate-only
python3 scripts/audio/inworld_dialogue.py stories/roger/v1/script.json --name roger-v1 --output-group roger/v1
```

Validation requires no key and makes no network calls. Rendering is a paid API operation and requires `INWORLD_API_KEY` in the environment or this folder's ignored `.env`, plus `ffmpeg` installed locally. Each turn must be at most 2,000 characters; split longer narration at paragraph boundaries.

Rendering sends each turn to Inworld TTS-2 with the selected voice and recent text context, saves the original WAV and request metadata, adds the requested pauses and 5ms edge ramps, and encodes the joined recording once to MP3. It does not apply bass reduction, loudness processing, or time stretching.

Everything generated goes into ignored `outputs/`: `<name>.mp3`, `<name>.wav`, `<name>.json`, and `<name>/` containing individual turns. Matching cached requests are reused. If text, voices, or directions change, use a new output name. A failed or timed-out request is not automatically retried; check provider usage before retrying an uncertain request. This script does not upload to the database.

To resume or rebuild the current faith revision from its preserved segments, use:

```sh
python3 scripts/audio/inworld_dialogue.py stories/roger/v2/script.json --name roger-faith-v2 --output-group roger/v2
```

`--output-group` is relative to `generation/outputs`; paths outside that folder are rejected. The published faith revision is version 2; its production receipt is in `generation/receipts/`.

## Playback timeline

Every Inworld render now writes `<name>.timeline.json` alongside the audio. It contains the audio filename and SHA-256, script SHA-256, sample rate, total duration, and ordered turns with their original ID, scene, speaker, voice ID, text, and timings.

- `start_seconds`: where the generated turn begins in the joined recording.
- `audio_end_seconds`: end of that generated clip (including its natural silence).
- `end_seconds`: end of the inserted pause following the turn.
- The corresponding `*_sample` fields preserve exact integer offsets before MP3 encoding.

For later auto-scroll, select the turn with `start_seconds <= playback_position < end_seconds`. Keep that turn selected during its following pause. Before the first turn, select the first item; after completion, keep the last item. Recompute the selection after seeking. Check the audio checksum before using a timeline. These are turn-level boundaries, not word-level forced alignment; long narration turns will scroll as a unit. No app scrolling behavior has been added yet.

Roger v3 introduces the church encounter and a concrete first action before the factory ridicule. Its source is `roger/v3/story.md`, with `roger/v3/script.json`; render to `--output-group roger/v3 --name roger-faith-v3`. The existing Roger tape now uses v3, with its matching timeline stored in audio.timeline.segments.

Roger v4 preserves v3's exact wording and cast, changes native speaking rate from 0.95 to 0.90, and restores v1's narrator direction to match the original listening pace. Source: `roger/v4/script.json`; output group: `roger/v4`; name: `roger-pace-v4`. Its timeline must be used only with its own audio. This render does not replace the production tape automatically.
