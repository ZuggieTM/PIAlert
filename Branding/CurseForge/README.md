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

## Generated backdrop

The abstract background was generated with the built-in image-generation tool using this direction:

> A premium 16:9 PIAlert gallery backdrop with a deep charcoal and midnight-indigo field, restrained violet magical ribbons, subtle teal edge lighting, warm-gold sparks, a calm dark headline area, and an illuminated screenshot region; no text, characters, logos, spell icons, or watermark.
