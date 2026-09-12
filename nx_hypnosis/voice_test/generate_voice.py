#!/usr/bin/env python3
"""Generate an ElevenLabs narration using only Python's standard library."""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

BASE = Path(__file__).resolve().parent
DEFAULT_VOICE = "iI1BlqMaaIkiLuGRhtpA"  # Hypnotizer


def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    env_file = BASE / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            name, separator, value = line.strip().partition("=")
            if separator and name.strip() == "ELEVENLABS_API_KEY":
                return value.strip().strip("\"'")
    return ""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--voice-id", default=DEFAULT_VOICE)
    parser.add_argument("--speed", type=float, default=0.7)
    parser.add_argument("--stability", type=float, default=0.65)
    parser.add_argument("--text-file", type=Path, default=BASE / "story.txt")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--dry-run", action="store_true",
                        help="Validate and show the request without a key or API call.")
    args = parser.parse_args()
    if not 0.7 <= args.speed <= 1.2:
        parser.error("--speed must be between 0.7 and 1.2")
    if not 0 <= args.stability <= 1:
        parser.error("--stability must be between 0 and 1")
    if not args.voice_id.strip():
        parser.error("--voice-id cannot be empty")
    text = args.text_file.read_text(encoding="utf-8").strip()
    if not text or len(text) > 10000:
        parser.error("Story must contain between 1 and 10,000 characters")
    payload = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": args.stability,
            "similarity_boost": 0.75,
            "style": 0.0,
            "use_speaker_boost": True,
            "speed": args.speed,
        },
    }
    if args.dry_run:
        print(json.dumps({"voice_id": args.voice_id, **payload}, indent=2))
        print(f"Validated {len(text)} characters. No API request made.")
        return 0
    key = api_key()
    if not key:
        parser.error("Set ELEVENLABS_API_KEY or put it in voice_test/.env first")
    output = args.output or BASE / "output" / (
        "abundance_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f") + ".mp3"
    )
    if output.exists():
        parser.error("Output already exists; choose a new --output path")
    output.parent.mkdir(parents=True, exist_ok=True)
    url = (
        "https://api.elevenlabs.io/v1/text-to-speech/"
        + quote(args.voice_id, safe="") + "?output_format=mp3_44100_128"
    )
    request = Request(url, data=json.dumps(payload).encode("utf-8"), headers={
        "xi-api-key": key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }, method="POST")
    print(f"Generating {len(text)} characters at speed {args.speed}...")
    try:
        with urlopen(request, timeout=120) as response:
            if "audio/" not in response.headers.get("Content-Type", ""):
                raise ValueError("ElevenLabs returned a non-audio response")
            audio = response.read()
        if not audio:
            raise ValueError("ElevenLabs returned empty audio")
    except HTTPError as error:
        # Do not echo response bodies or request headers containing credentials.
        hints = {
            401: "Check your API key.",
            402: "Check available credits and your plan.",
            403: "Check key permissions and access to this voice.",
            404: "Voice unavailable; supply another --voice-id.",
            422: "Check the voice ID and speech settings.",
            429: "Rate or quota limit reached; check your account before retrying.",
        }
        print(f"ElevenLabs HTTP {error.code}. " + hints.get(
            error.code, "Check ElevenLabs status and account settings."
        ), file=sys.stderr)
        return 1
    except (URLError, TimeoutError):
        print("Connection failed or timed out. Check ElevenLabs history before "
              "retrying; generation may already have used credits.", file=sys.stderr)
        return 1
    with output.open("xb") as file:
        file.write(audio)
    print(f"Saved: {output.resolve()}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
