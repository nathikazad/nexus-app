# NX Hypnosis

Flutter UI prototype for macOS, Android, iOS, and web, matching
`design/bare_bones/index.html`.

## Run

```sh
flutter pub get
flutter run -d macos
flutter run -d chrome
```

Use `flutter devices` and `flutter run -d <device-id>` for an Android device or
iOS simulator. Physical iOS installations follow the parent repository's
Shorebird installation policy.

## Experience

- Tapes is the home screen, with desire filter chips and a Desires button.
- Desires supports compact cards, add/edit, and deletion with either tape
  reassignment or deletion. Editing and deletion live in the detail overflow menu.
- Story creation uses sample text; it makes no AI requests.
- Tape detail shows only the transcript, desire/voice label, and title-side play.
- The bundled Hypnotizer recording plays offline with pause, seek, 15-second
  skip controls, and speed adjustment. The player remains available across views.
- Drafts without a recording show a disabled play button.

Changes remain in memory and reset on restart. There is no KGQL integration,
login, cloud storage, live ElevenLabs generation, or credential bundled in the app.

## Source

- `lib/app.dart`: app appearance, navigation, tapes, and desire browsing.
- `lib/desires.dart`: demo collection and desire/tape relationships.
- `lib/forms.dart`: desire editing and sample story creation.
- `lib/listening.dart`: audio playback and the persistent player.
- `assets/`: the four sample desires, approved transcript, and recording.

## Validation

```sh
flutter analyze
flutter test
flutter build web
flutter build macos --debug
flutter build apk --debug
flutter build ios --simulator --debug
```

These are development builds. Store distribution/signing, background playback,
and platform-specific app icon design are future work.
