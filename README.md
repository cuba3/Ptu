# Ptu

**Ptu** is a modern, native macOS image editor built from the ground up in Swift, SwiftUI, and Metal. It provides a layered, non-destructive editing workflow comparable to professional raster editors, fully optimized for Apple Silicon and macOS Sequoia.

- **Platform:** macOS 15.0+ (Sequoia)
- **Language:** Swift 5
- **Rendering:** Metal (GPU-accelerated canvas & tile compositing)
- **License:** Apache License 2.0

---

## Feature List

### Canvas & Viewport
- Metal-accelerated canvas with tile-based rendering for smooth interaction on large images.
- Documents up to **16,000 × 16,000 px** at resolutions from **1 to 2400 PPI**.
- Zoom (in / out / actual size / fit to screen) and pan with the Hand tool.
- Rulers, guides (add horizontal / vertical, clear), grid overlay, and snapping.
- Transparent or solid-white canvas background.

### Layers
- Pixel layers, **adjustment layers**, and **nested group layers**.
- Full layer control: add, delete, duplicate, reorder (bring forward / send backward), rename, show / hide.
- Per-layer **opacity** and **12 blend modes**: Normal, Multiply, Screen, Overlay, Darken, Lighten, Color Dodge, Color Burn, Soft Light, Hard Light, Difference, Exclusion.
- **Layer masks** — reveal / conceal, invert, enable / disable, paint and edit masks.
- **Clipping masks** to clip one layer to another.
- **Layer effects**: Stroke, Drop Shadow, Color Overlay, Inner Shadow, Outer Glow, Inner Glow.

### Adjustments (non-destructive)
- Levels, Curves, Hue / Saturation, Exposure, Black & White, Color Balance, Gradient Map, Grain, Invert.
- Each can be added as a live **adjustment layer**; many also expose a "bake" action that writes pixels directly.
- **Camera Raw** adjustment for raw photo grading.

### Filters
- Gaussian Blur, Motion Blur, Add Noise, Vignette, Bloom / Glow, Tonal Contrast, Dither, Lens Correction.

### Selection & Masking
- Tools: Rectangular Marquee, Lasso (freehand), Magic Wand, Object Selection, Color Range.
- Smart operations: **Select Subject**, **Remove Background**, **Content-Aware Fill**, Guided Matte, Subject Removal.
- Selection editing: Select All, Deselect, Inverse, Feather, copy / cut / paste, float selection, selection clipboard.

### Retouch & Painting
- Brush, Clone Stamp, Healing / Spot Heal, Blur, Smudge.
- Eyedropper for color sampling and an in-app color picker.

### Geometry & Transform
- Crop, Free Transform, Distort, Flip Horizontal / Vertical, Flip Canvas, Rotate 90° CW / CCW, Rotate 180°, Image Size, Canvas Size, Trim.

### Vector, Text & Fill
- Type tool, Shape tool, Gradient tool, and a color palette.

### Import & Export
- **Import Adobe Photoshop** `.psd` and large-document `.psb` (8-bit RGB). Unsupported features (text, vectors, layer masks, live adjustments) are detected and reported rather than silently dropped.
- **RAW development** (Camera Raw) to bring RAW photos into the editor.
- **Export PNG** and **Export JPEG**.
- Native **`.ptu`** document format for saving and reopening projects; recent-files list and reload support.

### Productivity
- **Command Palette** — search and run any command by name.
- **Fully customizable keyboard shortcuts** with conflict / validation checks, persisted across launches.
- **Multi-document tabs** for working on several files at once.
- Complete **Undo / Redo** history.
- **Settings** with UI language selection.
- **Localized UI**: English, Simplified Chinese (简体中文), Traditional Chinese (繁體中文), Japanese (日本語), plus system default.

---

## Tech Stack

| Area        | Choice                                                  |
|-------------|---------------------------------------------------------|
| Language    | Swift 5 (Concurrency: minimal strict concurrency)       |
| UI          | SwiftUI + AppKit (`NSDocument`, `NSApplicationDelegate`)|
| Rendering   | Metal (GPU-accelerated canvas & tile compositing)       |
| Minimum OS  | macOS 15.0 (Sequoia)                                    |
| Build       | XcodeGen (`project.yml`)                                |

## Getting Started

### Requirements
- macOS 15.0 or later
- Xcode 16 (or a compatible toolchain)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed (`brew install xcodegen`) to regenerate the Xcode project

### Build & Run
```bash
# Regenerate the Xcode project from project.yml
xcodegen generate

# Open and run
open Ptu.xcodeproj
# or build from the command line
xcodebuild -scheme Ptu -configuration Debug build
```

The app registers as the editor for its native `.ptu` documents and as a viewer for PNG and JPEG files.

## Project Structure
```
Ptu/
├── App/            App entry, document type, menu commands
├── Model/          Document model, compositor, layers, filters, adjustments,
│                   selections, masks, PSD reader, RAW importer, pixel math
├── Features/       Editor, Canvas (Metal), Layers, Tools, Adjustments,
│                   Effects, Import, Settings, Command Palette, New Canvas
├── Design/         Theme & visual constants
├── Localization/   Localized strings (en, zh-Hans, zh-Hant, ja)
├── Session/        Document sessions & editor request handling
└── Resources/      Assets, app icon, localized strings catalog
PtuTests/           Unit tests
scripts/            Build / utility scripts
```

## Known Limitations
- PSD / PSB import supports **8-bit RGB** only; text, vector shapes, layer masks, and live adjustment layers are recognized and reported but not reconstructed as editable objects.
- RAW development depends on the bundled Camera Raw pipeline.
- Maximum canvas dimension is 16,000 px per side.

## License
Released under the **Apache License 2.0**. See `LICENSE` for details.
