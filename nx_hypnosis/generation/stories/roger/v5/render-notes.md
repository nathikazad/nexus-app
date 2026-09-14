# Roger v5 recording

Full story with the approved v5 opening pacing: 6,686 spoken words in 554 turns, using the saved Inworld cast, native speed 0.90, BALANCED delivery. The first 70 turns reuse the approved opening requests and audio; remaining narration is grouped into short complete beats with explicit pauses. Dialogue tags stay connected, and scene transitions retain longer rests.

Spoken words and order match v4. Only grouping and silence change. No EQ, compression, reverb, or time stretching.

Run from `generation`:
```sh
python3 scripts/audio/inworld_dialogue.py stories/roger/v5/script.json --name roger-beats-v5 --output-group roger/v5
```

Outputs, exact request receipts, and the sample-derived playback timeline are in ignored `outputs/roger/v5/`. Publication targets the existing Roger tape, preserving its title, desire, prompt, and story. Audio and its new timeline are replaced together.

Measured duration: **60:12** (3,612.203917 seconds). Verified full MP3 decoding, all 554 contiguous timing intervals, source/audio checksums, and exact waveform equality with the approved first 9:37.
