# Generation workspace

Flutter stays at the parent app root. Everything used to author and produce recordings lives here.

- `stories/`: source transcripts and parseable voice scripts, grouped by story and version. Roger v2 is the currently published faith revision.
- `scripts/audio/`: current Inworld and ElevenLabs generators and pause processing.
- `scripts/audio/legacy/`: historical voice experiments, retained for reproducibility; these are not the approved sound defaults.
- `scripts/publishing/legacy/`: historical, tape-specific publishing operations. Do not rerun them as generic upload commands; use the publishing skill to resolve the current target and metadata.
- `skills/`: construct-story, construct-transcript, generate-audio, and publish-tape instructions.
- `outputs/`: ignored audio, segments, auditions, and generation metadata, grouped by story/version or experiment.
- `receipts/`: ignored publication records, cost records, and the reorganization path manifest. Historical receipts retain original source paths for provenance; use the manifest to find moved files.
- `.env`: ignored credentials shared by the generators. `.env.example` documents variable names. Private copies of the previous credential files remain ignored.

Run commands from this folder. See [the script format](stories/README.md) and [the story skill](skills/construct-story/SKILL.md).

```sh
python3 scripts/audio/inworld_dialogue.py stories/roger/v2/script.json --validate-only
python3 scripts/audio/inworld_dialogue.py stories/roger/v2/script.json --name roger-faith-v2 --output-group roger/v2
python3 scripts/audio/generate.py stories/abundance/legacy/abundance_identity.txt --dry-run --output-group abundance
```

Validation and dry runs spend no credits. Rendering uses provider credits unless all matching segments are cached. Reorganization does not publish, regenerate, or change existing database tapes.
