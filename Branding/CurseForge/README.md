# PI Alert CurseForge gallery

This folder contains the reusable assets and build script for the PI Alert CurseForge gallery.

## Build

The script expects the current seven World of Warcraft screenshots in the local retail screenshot folder. It deliberately composites the real addon interface instead of recreating UI text with generative tools.

```bash
cd Branding/CurseForge
npm install
node build-gallery.js
```

Final 2048×1152 JPEGs are written to `Branding/CurseForge/gallery`.

## Source screenshots

- `WoWScrnShot_082726_212445.jpg` — live combat PI alert
- `WoWScrnShot_083126_111855.jpg` — Requests
- `WoWScrnShot_083126_111857.jpg` — Activation
- `WoWScrnShot_083126_111859.jpg` — Alerts
- `WoWScrnShot_083126_111901.jpg` — Spells
- `WoWScrnShot_083126_111903.jpg` — Macros
- `WoWScrnShot_082726_214545.jpg` — right-click controls

The 5120×1440 source screenshots remain in the World of Warcraft screenshot folder and are not committed to keep the repository lightweight.

## Generated backdrops

`gallery-background.png` is the original framed composition. The gallery currently uses
`gallery-background-frameless.png`, which preserves the same atmosphere without the
ornamental frame so the build script can place a clean teal border around each screenshot.

The active abstract background was generated with the built-in image-generation tool using this direction:

> Remove the entire ornamental frame and reconstruct those areas as a seamless continuation of the existing dark charcoal, midnight-indigo, violet-energy backdrop. Preserve the palette, lighting, sparse gold sparks, calm headline area, and premium game-interface mood. Do not add a replacement frame, border, panel, UI, text, logo, or watermark.
