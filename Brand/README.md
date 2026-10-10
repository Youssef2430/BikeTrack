# BikeTrack icon

A bold ink bicycle on a lime background, matching the app's workout accent color. The main symbol stays within the Watch's circular crop; no lettering or fine details are needed to recognize it.

The bicycle geometry is the **bicycle-bold** icon from [Phosphor Icons](https://github.com/phosphor-icons/core/blob/2b75f3ad12b420c9504ef05df8d2564a28f8500e/assets/bold/bicycle-bold.svg), vendored at commit `2b75f3ad12b420c9504ef05df8d2564a28f8500e`. Its [MIT license](PHOSPHOR-LICENSE.txt) is included. BikeTrack adds the colors, background, and placement.

Regenerate everything on macOS from the project root:

```sh
swift tools/generate-icon.swift
```

- `Brand/bicycle-bold.svg`: original licensed geometry.
- `Brand/AppIcon.svg`: generated square master artwork.
- `WatchApp/Assets.xcassets/AppIcon.appiconset/*.png`: all sizes declared by the asset catalog, including the opaque 1024 px marketing icon. watchOS applies the circular mask.
- `favicon.svg`: scalable project icon with rounded corners.
- `favicon.png`: 256 px fallback.
- `favicon.ico`: 16, 32, 48, 64, 128, and 256 px entries.
- `WatchApp/Resources/Phosphor-LICENSE.txt`: the attribution notice included in the built app.

The generator uses macOS's SVG renderer and reads sizes from `Contents.json`, so no image-processing package is required. The project favicon is configured through the project's `faviconPath` setting in T3 Code.
