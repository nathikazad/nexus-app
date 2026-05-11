# nx_people

Flutter implementation of the People reference prototype.

The app mirrors the `nx_notes` shape where it is useful: app/router entry
points, a small domain/data layer, Riverpod shell state, desktop/mobile shells,
and focused widget plus layering tests.

Run locally:

```sh
flutter pub get
flutter run -d web-server
```

Verify:

```sh
flutter analyze
flutter test
```
