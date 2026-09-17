# NX application icons

Approved SVG masters live in each app's `design/brand/` directory.
The family generator preserves NX Cards and generates the other concepts:

```sh
python3 design/brand/generate_family.py
python3 scripts/generate_app_icons.py
```

Run from `mobile/`. Requirements: Inkscape on PATH, Python 3, and Pillow.
The second command also accepts app directory names to regenerate a subset.
Native launcher assets do not require Flutter pubspec asset declarations.

| App | iOS | Android | macOS | Web |
| --- | --- | --- | --- | --- |
| Books | yes | yes | yes | yes |
| Cards | yes | yes | yes | yes |
| Cook | yes | — | — | — |
| Docs | yes | yes | yes | yes |
| Expense | yes | — | — | yes |
| Hypnosis | yes | yes | yes | yes |
| Nexus | yes | yes | — | yes |
| People | yes | — | — | yes |
| Post | yes | yes | — | yes |
| Projects | yes | yes | yes | yes |
| Time | yes | — | — | yes |

A dash means the app has no checked-in target for that platform.
There are no Windows or Linux app targets in this collection.

## Generated assets

- iOS: opaque PNGs for every existing AppIcon catalog slot, including the
  1024-pixel App Store icon. The operating system applies the corner mask.
- macOS: every AppIcon catalog slot, 16–1024 pixels, with rounded artwork
  and transparent outer padding for the Dock.
- Android: legacy launcher PNGs for all five densities, plus adaptive
  foreground PNGs and background-color XML. Adaptive artwork is contained
  in the safe circle. Existing manifest references resolve to these resources.
- Web: 192/512 ordinary and maskable icons, a 180-pixel Apple touch icon,
  a 32-pixel PNG favicon, and an SVG favicon. Manifests and HTML link to them.

Validation: all 16 Apple asset catalogs compiled with actool; all seven
Android resource sets compiled with aapt2. All 10 web manifests and HTML icon
references were checked, along with generated PNG dimensions and iOS opacity.
No full application build, device installation, or web deployment was performed.

Native assets require a new build/install (not a Dart-only Shorebird patch).
Web assets require redeployment; browsers may retain cached icons temporarily.
