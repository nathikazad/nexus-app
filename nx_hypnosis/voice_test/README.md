# First voice test

A gentle relaxation opening followed by a short story about Arun creating opportunities through curiosity,
service, and collaboration. This test evaluates the narration before app development.

Uses Python 3 with no third-party dependencies. Start in this folder:

```sh
cd /Users/nathikazad/Projects/NX_Hypnosis/mobile/nx_hypnosis/voice_test
python3 generate_voice.py --dry-run
```

Put your token in the local `.env` file as `ELEVENLABS_API_KEY=your_token`, or set
the `ELEVENLABS_API_KEY` environment variable. The local `.env` and generated
`output/` directory are ignored by Git. The script never prints the token.

Generate the sample:

```sh
python3 generate_voice.py
```

The script saves a timestamped MP3 under `output/` and prints its full path.
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
python3 generate_voice.py --speed 0.8 --stability 0.7
python3 generate_voice.py --voice-id YOUR_VOICE_ID
python3 generate_voice.py --text-file another_story.txt --output output/alternate.mp3
```

Edit `story.txt` to change the story. No separate story-generation service is needed.
Listen for warmth, comfortable pacing, natural pauses, and whether the delivery
feels immersive without becoming flat or theatrical. These settings are a starting
point; audio quality has not been validated until a live sample is generated and heard.

References: [speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert),
[voice settings](https://elevenlabs.io/docs/api-reference/voices/settings/get),
[default voices](https://elevenlabs.io/docs/help-center/product/voices/my-voices/what-are-default-voices).
