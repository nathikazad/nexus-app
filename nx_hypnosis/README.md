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
- Audio is fetched with the authenticated HTTP client. Native platforms retain
  recordings in account-scoped durable storage and play those files directly.
  Web plays downloaded bytes. Playback supports seeking and speed control.
- Original import sources remain in `assets/` for provenance, but are no longer
  bundled into the application. `generation/` holds story sources, audio tools, skills, and private outputs.

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

## iPhone releases

Shorebird app `63b1569e-58ac-47a7-86af-fcc92ff4cf72` is initialized.
Create a development-signed base with
`scripts/shorebird_apps.sh release nx_hypnosis --export-method development --flutter-version 3.44.4`.
Install the exported application with Xcode device tools. Subsequent compatible
Dart-only changes can use `scripts/shorebird_apps.sh patch nx_hypnosis`.

## Offline storage

Native apps reuse `nx_offline`'s `FileLibrary`, immutable content files,
`BinaryContentFiles`, cached sessions, `SyncSupervisor`, and `OfflineLifecycle`.
After the first successful online load, desires and story transcripts open from
local storage while authentication and refresh run in the background. A completed
sign-out or rejected session clears the saved-session shortcut. Storage is scoped
to the logical Nexus server and user; switching network routes retains the cache.

Recordings download automatically in the background, two at a time. Concurrent
play/prefetch requests share one download. Files are streamed to staging and only
published after the complete download is finalized. A checksum detects corruption;
a failed download can be retried without exposing a partial recording. Audio
metadata versions distinguish regenerated recordings that use the same URL.

The collection and recording count show sync/download status and support manual
retry. Refresh also runs on startup, app resume, and reconnection. Unchanged
collection snapshots are not rewritten. Invalid or incomplete responses preserve
the previous saved library. Playback and closing the player do not delete cached
audio. Downloads must finish before a recording can be played offline.

Creating, editing, and deleting records still use the existing online API; they
are not queued offline. Successful responses update the local collection.
Web retains its online storage behavior. Native SQLite/connectivity dependencies
require a new Shorebird release for physical iOS installation, rather than a patch.

Validation: `flutter analyze`, `flutter test`, and
`flutter build ios --release --no-codesign`. Cache tests cover offline restarts,
account separation, duplicate-download suppression, regenerated and corrupt audio,
interrupted downloads, failed refresh preservation, and saved-session rejection.

## Background playback

Hypnosis uses `NxBackgroundAudioPlayer` from `nx_voice/background_audio.dart`.
The shared module configures spoken-audio sessions, connects player state to the
existing `NxStoredAudioRemoteControls`, and publishes the tape title, position,
duration and speed. Lock-screen/headset controls support play/pause and seeking,
including 15-second skips. The controls are shared with the existing stored-note
player; no separate audio module is introduced.

The iOS target declares `UIBackgroundModes: audio`. Android uses
`AudioServiceActivity`, the media playback foreground service, a media-button
receiver, and the wake-lock/foreground-service permissions. Cached recordings
remain owned by offline storage when playback stops. Backgrounding does not
dispose the player; closing the player or signing out stops playback and clears
system controls. `just_audio` handles interruptions and disconnected headphones
through the shared spoken-audio session.

## Playback-following transcript

When `audio.timeline` has version 1, a checksum matching the recording, and valid ordered segments, the story page displays that recording's text and highlights the active turn. Playback, seeking, and repeat update the selection. Manual scrolling pauses following; the floating “Follow audio” button resumes it. Tapes without valid timing keep the original story view. The recorded text is kept separate from editable story prose so old timings cannot highlight the wrong revision. Following uses the playback position, so speed changes do not require scaling timestamps.
