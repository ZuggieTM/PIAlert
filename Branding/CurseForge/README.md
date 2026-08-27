# PIAlert CurseForge gallery

This folder contains the reusable assets and build script for the PIAlert CurseForge gallery.

## Build

The script expects the five original World of Warcraft screenshots in the local retail screenshot folder. It deliberately composites the real addon interface instead of recreating UI text with generative tools.

```powershell
$env:NODE_PATH = "C:\Users\jband\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules"
& "C:\Users\jband\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" .\Branding\CurseForge\build-gallery.js
```

Final 2048×1152 JPEGs are written to `Branding/CurseForge/gallery`.

## Source screenshots

- `WoWScrnShot_082726_170152.jpg` — live PI alert
- `WoWScrnShot_082726_170024.jpg` — Alerts
- `WoWScrnShot_082726_170021.jpg` — Requests
- `WoWScrnShot_082726_170044.jpg` — Spells
- `WoWScrnShot_082726_170047.jpg` — Macros

The 5120×1440 source screenshots remain in the World of Warcraft screenshot folder and are not committed to keep the repository lightweight.

## Generated backdrops

`gallery-background.png` is the original framed composition. The gallery currently uses
`gallery-background-frameless.png`, which preserves the same atmosphere without the
ornamental frame so the build script can place a clean teal border around each screenshot.

The active abstract background was generated with the built-in image-generation tool using this direction:

> Remove the entire ornamental frame and reconstruct those areas as a seamless continuation of the existing dark charcoal, midnight-indigo, violet-energy backdrop. Preserve the palette, lighting, sparse gold sparks, calm headline area, and premium game-interface mood. Do not add a replacement frame, border, panel, UI, text, logo, or watermark.
