---
name: nx-hypnosis-voice-gen
description: Generate NX Hypnosis narration from a transcript using the approved ElevenLabs female voice, with spacious phrase pauses and locally saved audio. Use for creating or regenerating hypnosis recordings.
---

For multi-character Inworld stories, use [the story skill and its approved pacing](../construct-story/SKILL.md#approved-story-pacing). The approved Roger v5 preview uses short narrative beats, explicit pauses, and native speed 0.90. Read that guidance before rendering; the ElevenLabs settings below belong to the single-voice workflow.

Use `scripts/audio/generate.py` relative to the generation folder. It accepts a UTF-8 transcript and writes MP3 audio, the raw take, transcript, and settings into the generation folder's Git-ignored `outputs/` directory. Python 3.9+, FFmpeg and ffprobe are required.

```sh
python3 scripts/audio/generate.py /absolute/path/transcript.txt
```

Run from the generation folder or use the script's absolute path; output location is independent of the working directory. `--name abundance` supplies an output stem. Existing outputs are never overwritten.

## Approved sound

- Voice: `Njn5qkKYqadqLJNsoRoL`; model: `eleven_multilingual_v2`.
- Generation speed 0.7, stability 0.85, similarity 0.65, style 0, speaker boost off.
- Preserve generated speech speed and pitch. Extend existing quiet phrase gaps to about 1.65 seconds, with 40 ms fades at insertion points to prevent clicks. Preserve longer existing pauses.
- No time stretching, bass reduction, compression, volume leveling, or reverb. The user rejected those processed versions.
- Preserve the supplied wording. Existing SSML break tags are passed through; do not automatically add many tags or rewrite the narration.

Default length follows transcript length. For the previously approved six-minute format, use `--seconds 366`. This allocates time to pauses, not slower speech. If the source is already too long, no suitable gaps exist, or the target requires pauses longer than four seconds, processing stops and retains the raw take. Do not force a duration with excessive silence or change the voice silently.

## Credentials and execution

The generator reads `ELEVENLABS_API_KEY` from the environment, then `generation/.env`. Never display or commit the key. `.env` and all outputs are ignored by Git. Use `--output-group <story>/<version>` to group takes without changing their names.

Use `--dry-run` to validate inputs without spending credits. A user request to generate narration authorizes that generation; this skill does not itself authorize purchasing credits or publishing audio. It makes one API request and does not retry automatically. On quota failure, report that credits may be exhausted; HTTP 401 can also indicate a quota problem. After a timeout, check ElevenLabs history before retrying because the request may already have consumed credits.

To adjust pauses or recover from a postprocessing failure without paying for a new take:

```sh
python3 scripts/audio/generate.py /absolute/path/transcript.txt \
  --from-audio /absolute/path/saved.raw.mp3 --name revised --seconds 366
```

The existing raw take must correspond to the supplied transcript. `--pause-seconds` changes default phrase spacing when no target duration is supplied.

After success, present the final MP3 using an absolute-path audio embed. State its duration and retain the raw take and JSON settings for repeatability. Listen/preview feedback determines whether the sound is acceptable; decoding checks do not establish perceived quality. Database uploads and replacement of a production tape require a user request and are outside this skill.

## Related skills

- [Write or revise a hypnosis transcript](../construct-transcript/SKILL.md).
- [Create a database tape or replace its recording](../publish-tape/SKILL.md).

- [Construct character stories and render an Inworld cast](../construct-story/SKILL.md). Use this for multi-character stories; the ElevenLabs defaults above remain for the previously approved single-voice workflow.
