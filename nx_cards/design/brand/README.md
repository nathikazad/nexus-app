# NX Cards identity: Recall stack

A stack of flashcards with an N and a small subscript x on the front connects Nexus to repeated study.
The warm orange palette is the chosen brand direction. Lettering is based on Georgia Bold Italic, converted to paths. The mark uses only editable
vector paths and rounded rectangles; no fonts are required for the symbol.

- `nx-cards-mark.svg`: transparent color mark.
- `nx-cards-icon.svg`: square, opaque app-icon master. Platform rounding is applied by the operating system.
- `nx-cards-monochrome.svg`: single-color variant (`currentColor`, black by default).
- `nx-cards-presentation.svg`: editable concept board; text uses system sans-serif.
- PNG exports: previews and icon sizes, rendered with Inkscape.

Palette: orange #EA580C, peach #FDBA74, pale cream #FFEDD5,
warm ink #241810, white #FFFFFF.

Open any SVG in Inkscape to edit. Example export:

```sh
inkscape nx-cards-icon.svg --export-filename=nx-cards-icon-1024.png --export-width=1024
```

Launcher assets are wired into each existing platform target. After changing
SVGs, run `python3 scripts/generate_app_icons.py` from mobile/.

Stack geometry: three identical 448 × 560 cards, each with 64-unit corners,
rotated −20°, −10°, and 0° around the shared lower pivot (512, 760).
