# Identity and use of the brand

## Name

**jog-bridge** (lowercase, with the hyphen). The name evokes the jog wheels of DJ controllers
and cites no trademark: the project is not tied to a single model. See
[ADR 0008](adr/0008-project-name-and-third-party-trademarks.md).

## Texts

| Use | Text |
|---|---|
| Tagline | USB-to-MIDI bridge for DJ controllers on macOS |
| GitHub description | USB-to-MIDI bridge for DJ controllers on macOS. Exposes the Hercules DJ Control MP3 e2 as a CoreMIDI device, LEDs included. |
| GitHub topics | `dj`, `midi`, `coremidi`, `macos`, `usb`, `libusb`, `swift`, `dj-controller`, `hercules`, `launchagent` |

## Non-affiliation notice

> jog-bridge is an independent project, not affiliated with Guillemot Corporation or Hercules,
> and neither approved nor sponsored by them. Hercules is a trademark of Guillemot Corporation.

Reuse it verbatim in the README, the release notes and any presentation page.

## Rules for using third-party trademarks

- Citing "Hercules DJ Control MP3 e2" to **describe compatibility** (supported hardware, MIDI
  port names, mapping file): yes.
- Naming the repository, the binary, the package or the logo after the trademark: no.
- Reusing a third party's logo, image or product photo: no.
- Suggesting a partnership or an endorsement: no.

The `hercules` topic is used for discovery (supported hardware); it can be removed if
Guillemot asks. This is not legal advice.

## Visual elements

All in `assets/branding/`; they are original and published under the project's licence.

| File | Use |
|---|---|
| `logo.svg` / `logo.png` (512×512) | Project icon |
| `banner.svg` | README header |
| `social-preview.svg` / `social-preview.png` (1280×640) | GitHub social preview image |
| `AppIcon.icns` | Icon of the `Jog Bridge.app` bundle, shown in System Settings → Login Items ([ADR 0011](adr/0011-app-bundle-for-the-launch-agent.md)) |

The logo shows a jog-wheel platter (cyan ring, magenta marker) crossed by a bridge arch linking
two dots: USB on one side, MIDI on the other.

### Palette

| Role | Colour |
|---|---|
| Background | `#0B1220` (gradient towards `#12223D`) |
| Platter | `#111C33` |
| Main accent | `#22D3EE` |
| Marker | `#F472B6` |
| Text | `#F8FAFC`, secondary `#CBD5E1` / `#94A3B8` |

The SVGs use a system font stack; text rendering varies slightly between platforms. The PNGs are
reference renders.

### Regenerating the PNGs

After changing an SVG, render at the exact size with an AppKit script (macOS):

```sh
swift scripts/render-svg.swift assets/branding/social-preview.svg assets/branding/social-preview.png 1280 640
swift scripts/render-svg.swift assets/branding/logo.svg assets/branding/logo.png 512 512
make icon        # regenerates assets/branding/AppIcon.icns from logo.svg
```

`scripts/render-svg.swift` loads the SVG into an `NSImage`, draws it into an `NSBitmapImageRep`
of the wanted size and writes the PNG. (`qlmanage -t` is not suitable: it produces cropped
square thumbnails.) The `.icns` is committed, so building the package does not need to render
anything.

## Configuring the GitHub repository

```sh
gh repo edit --description "USB-to-MIDI bridge for DJ controllers on macOS. Exposes the Hercules DJ Control MP3 e2 as a CoreMIDI device, LEDs included." \
  --add-topic dj --add-topic midi --add-topic coremidi --add-topic macos --add-topic usb \
  --add-topic libusb --add-topic swift --add-topic dj-controller --add-topic hercules \
  --add-topic launchagent
```

The social preview image cannot be set through the API: *Settings → General → Social preview →
Upload an image* with `assets/branding/social-preview.png`.
