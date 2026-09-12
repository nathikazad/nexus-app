# NX Hypnosis

A personal library of desires and spoken identity narratives, built for macOS,
Android, iOS, and web. The monochrome layout follows `design/bare_bones/index.html`.

## Production data

The app signs in with Nexus and uses `https://nexus.kgql.io/hypnosis/collection`.
The backend resolves the authenticated User → Person → desires → hypnosis_tapes.
Records are private and stored in the user's personal domain. The app uses the
shared `nx_auth` package; no user ID or credentials are compiled into it.

- Desires can be created, edited, and deleted. Linked tapes can be moved to
  another desire or deleted in the same database transaction.
- Creating a tape saves its title, desire, and prompt as a draft. Story/audio
  generation is not connected yet; the approved imported tape has a recording.
- Audio is fetched with the authenticated HTTP client before playback. Web plays
  the downloaded bytes; native platforms use a temporary file removed when the
  player closes. Playback supports seeking and speed control.
- Original import sources remain in `assets/` for provenance, but are no longer
  bundled into the application. `voice_test/` is the separate ElevenLabs prototype.

## Run

```sh
flutter pub get
flutter run -d macos
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8769
```

The web OIDC callback is registered at `http://127.0.0.1:8769/auth.html`.
Use this exact origin for the web preview. A hosted web release needs its own
registered HTTPS callback; do not change the port without updating registration.
Native apps use `nx-hypnosis://oauth/callback`. macOS uses the existing Nexus
Apple development team for Keychain support. Physical iOS releases follow the
parent repository's Shorebird policy.

## Backend

Server source lives in the sibling `servers` repository:
- `nexus/hypnosis/repository.py`: transactional KGQL operations and owner checks.
- `nexus/http/routes/hypnosis.py`: collection and protected recording endpoints.
- `pgdb/core_schema/models/Digital_Nouns/{desires,hypnosis_tapes}.json`: catalog.
- `pgdb/scripts/setup_hypnosis.py`: scoped catalog application and rerunnable import.

Production recordings use the persistent `hypnosis_recordings` data directory,
with filenames `tape-<id>-<checksum>.mp3`. Deleted tape recordings become
inaccessible immediately; physical file cleanup is intentionally deferred.

## Checks

```sh
flutter analyze
flutter test
flutter build web
flutter build macos --debug
flutter build apk --debug
flutter build ios --simulator --debug
```
