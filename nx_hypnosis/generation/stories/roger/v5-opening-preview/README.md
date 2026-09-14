# Opening pacing audition

Local preview of the beginning only. Based on v4, through Roger and his mother planning a small start. Later scenes have not been revised or rendered.

The text is preserved, but narration is regrouped into short beats (generally no more than 27 words), with sentence breaks shown as paragraphs. Explicit pauses are usually 1.05 seconds after narration, 0.8 seconds after dialogue, and 1.6 seconds at selected emotional transitions. Native speaking rate remains 0.90, BALANCED, with the approved Inworld cast and v4 delivery instructions.

This tests structural breathing room, without EQ, time stretching, compression, or reverb. The generator applies only its standard 5 ms join ramps and the scripted silence.

Render:
```sh
python3 scripts/audio/inworld_dialogue.py stories/roger/v5-opening-preview/script.json --name roger-opening-beats --output-group roger/v5-opening-preview
```

Audio, request receipts, and the sample-derived timeline are under ignored `outputs/roger/v5-opening-preview/`. No database publication.
