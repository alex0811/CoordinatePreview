# Coordinate Preview

**English** | [简体中文](README.zh-CN.md)

![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-000000?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![AppKit](https://img.shields.io/badge/UI-AppKit-147EFB)

**Inspect any image down to the exact source pixel.**

Coordinate Preview is a lightweight, native macOS image viewer for designers,
developers, and QA workflows. Hover over an image to read its original pixel
coordinates, inspect a nearest-neighbor magnified sample, and navigate large or
long images without losing context.

## Highlights

- **Pixel-accurate coordinates** — coordinates are calculated from the decoded
  source image after applying its EXIF orientation, independently of window size
  and Retina scaling.
- **Built-in pixel loupe** — crosshair guides, a nearest-neighbor preview, and a
  yellow outline make the current pixel easy to identify. Choose `6×`, `8×`,
  `12×`, or `16×` magnification; the default is `12×`.
- **Precise keyboard inspection** — after hovering, use the arrow keys to move
  the selected point one source pixel at a time.
- **Zoom and pan made for long images** — use toolbar steps or continuous
  trackpad pinch-to-zoom. The normal fit-relative range is `0.25×–20×`, with
  additional levels generated automatically for very tall images.
- **Interactive minimap** — when an image extends beyond the canvas, a minimap
  shows the visible region and supports click or drag navigation.
- **Jump directly to a row** — press `⌘L`, enter an original-image `y`
  coordinate, and the app centers that pixel row whenever possible.
- **Native macOS workflow** — open images from the app, Finder, or drag and drop.
  Multiple files open in separate windows.
- **Local and dependency-free** — image decoding and inspection happen entirely
  on the Mac using AppKit, ImageIO, and Core Graphics.

## Requirements

- macOS 13.0 or later
- Xcode 16 or later, including its command-line tools, to build from source

## Quick start

Clone the repository and run the install script:

```sh
git clone https://github.com/alex0811/CoordinatePreview.git
cd CoordinatePreview
./scripts/build-and-install.sh
```

The script builds the `Release` configuration, applies a local ad-hoc signature,
installs the latest app at `~/Applications/CoordinatePreview.app`, and refreshes
its Finder “Open With” registration.

To make Coordinate Preview the default viewer for a file type, select an image
in Finder, open **Get Info**, choose Coordinate Preview under **Open with**, and
click **Change All…**. Future script runs replace the app at the same location,
so the association remains stable. Stale Launch Services registrations for the
same bundle identifier are removed, but app files in other locations are not.

Build and install a debug configuration with:

```sh
CONFIGURATION=Debug ./scripts/build-and-install.sh
```

You can also open `CoordinatePreview.xcodeproj` in Xcode and run or archive the
shared `CoordinatePreview` scheme.

## Controls

| Action | Control |
| --- | --- |
| Open image(s) | `⌘O`, Finder “Open With”, or drag and drop |
| Inspect a pixel | Hover over the image |
| Move by one source pixel | Arrow keys after hovering |
| Zoom | Toolbar controls or two-finger pinch |
| Reset to fit | Click the current zoom value in the toolbar |
| Pan a zoomed image | Two-finger scroll; direction follows the macOS setting |
| Navigate with the minimap | Click the thumbnail or drag its yellow viewport |
| Jump to an original `y` coordinate | `⌘L`, enter a row, then press Return |
| Cancel coordinate entry | `Esc` |
| Change loupe magnification | `显示 (View) > 放大镜倍率 (Magnifier Scale)` |

## Coordinate model

- The origin is the image's top-left pixel: `(0, 0)`.
- `x` increases to the right; `y` increases downward.
- Coordinates refer to the decoded, EXIF-oriented source pixels—not display
  points—so resizing the window or using a Retina display does not change them.
- Guides and the loupe appear only while the selected point is inside the image.
- Jump-to-row keeps the most recently hovered `x` coordinate. If none exists,
  it uses the horizontal center of the currently visible image.

## Verify the project

Run the geometry test suite:

```sh
swift test
```

Build the app from the command line without code signing:

```sh
xcodebuild -project CoordinatePreview.xcodeproj \
  -scheme CoordinatePreview \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/CoordinatePreviewDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

## Project structure

- `CoordinatePreview/` — the AppKit application and image interaction UI
- `CoordinatePreviewCore/` — reusable coordinate and viewport geometry
- `CoordinatePreviewCoreTests/` — Swift Testing coverage for geometry behavior
- `scripts/build-and-install.sh` — local build, signing, installation, and Finder
  registration

## Why a standalone app?

macOS Preview does not expose a third-party extension point for this kind of
pointer-driven pixel inspection. Coordinate Preview is therefore a small,
standalone viewer that can be registered as the default app for image files.
