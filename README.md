# JOKER53's GRUB

> A curated collection of source-driven GRUB2 boot-menu themes for Linux, with faithful browser previews and a transactional installer.

[![ShellCheck](https://github.com/KADHIRAVANEG/grub-themes/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/KADHIRAVANEG/grub-themes/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

**Preview every theme before touching your bootloader →** [joker-53.github.io/grub-themes](https://joker-53.github.io/grub-themes/)

```bash
git clone https://github.com/KADHIRAVANEG/grub-themes.git gorgeous-grub
cd gorgeous-grub
sudo ./install.sh
```

Pick a theme from the dropdown, reboot, enjoy.

---

## What you get

Each theme ships its original background image, bundled GRUB font, selection assets, and a hand-written `theme.txt`. Newer themes also use a transparent `overlay.png` so substantial interface artwork can be added without modifying or dimming the supplied background.

| #  | Slug          | Vibe                                                        | Status |
| -- | ------------- | ----------------------------------------------------------- | ------ |
| 01 | `miku`        | Centered cyan hologram panel, vocaloid energy               | ✅ |
| 02 | `penguin`     | ASCII Tux terminal, classic GNU/Linux feel                  | ✅ |
| 03 | `nes`         | 8-bit cartridge select screen, PRESS START                  | ✅ |
| 04 | `street`      | Cyberpunk right-rail terminal, magenta neon glitch          | ✅ |
| 05 | `noir`        | Spider-Noir comic panel, halftone rain, hard-boiled menu    | ✅ |
| 06 | `bmw`         | Cinematic automotive HUD, telemetry bars and throttle       | ✅ |
| 07 | `nimbus`      | Soft-sky concept (static, vertical GRUB menu adaptation)    | 🔧 |
| 08 | `gas_station` | Retro pump display, warm lo-fi sunset strip                 | 🔧 |
| 09 | `celebrate`   | Hand-drawn line catalog, every OS a different hat           | 🔧 |
| 10 | `ben`         | Ben 10 Omnitrix dial selector, green plasma core            | 🔧 |
| 11 | `motorcycle`  | Framed ignition console and road-status instrumentation     | ✅ |
| 12 | `spider`      | Angled right-side hero rail                                 | ✅ |
| 13 | `comic_spider`| Offset comic issue frame and chapter stack                  | ✅ |
| 14 | `bmw_gtr`     | Right telemetry console with a motorsport graph             | ✅ |
| 15 | `money`       | Circular fortune dial and centered editorial composition    | ✅ |
| 16 | `yorha`       | Translucent monochrome system readout                       | ✅ |
| 17 | `batman_signal` | Angular signal-response console                           | ✅ |
| 18 | `whisky`      | Double-bordered vintage reserve card                        | ✅ |
| 19 | `batman_city` | Low cinematic command strip                                 | ✅ |
| 20 | `thugs`       | Full-height afterlife terminal                              | ✅ |

✅ = fully working | 🔧 = in progress

---

## How it works

`install.sh`:

1. Detects your GRUB layout (`/boot/grub` on Debian/Ubuntu/Arch, `/boot/grub2` on Fedora/RHEL).
2. Runs pre-flight checks — verifies GRUB is installed, `theme.txt` exists and is non-empty, and `/boot` has enough free space before writing anything.
3. Backs up `/etc/default/grub` → `/etc/default/grub.gorgeous.bak` **on first run only**.
4. Copies the chosen theme into `/boot/grub/themes/<slug>/`.
5. Upserts these keys in `/etc/default/grub`:
   - `GRUB_THEME=/boot/grub/themes/<slug>/theme.txt`
   - `GRUB_TIMEOUT=15`
   - `GRUB_GFXMODE=auto`
   - `GRUB_GFXPAYLOAD_LINUX=keep`
   - `GRUB_TERMINAL_OUTPUT=gfxterm`
6. Regenerates GRUB config with `update-grub` or `grub[2]-mkconfig`.

---

## Commands

```bash
sudo ./install.sh                  # interactive dropdown
sudo ./install.sh miku             # install specific theme by slug
sudo ./install.sh -t 10            # set boot timeout to 10 seconds
sudo ./install.sh -t 10 miku       # set timeout AND install theme
sudo ./install.sh -l               # list all themes
sudo ./install.sh -u               # restore original /etc/default/grub
sudo ./install.sh -u --purge       # restore config AND delete theme files
sudo ./install.sh -h               # help
```

---

## Requirements

- GRUB2 installed (`update-grub`, `grub-mkconfig`, or `grub2-mkconfig` on `$PATH`)
- `bash` 4+, `sed`, `find`, `cp`, `install`, `df`, `du`
- Root — writes to `/etc/default/grub` and `/boot/`
- Node.js — only needed when regenerating the offline website catalog
- ImageMagick — only needed when authoring or regenerating raster interface assets

## Theme architecture and preview accuracy

The browser does not use a separately designed mock-up. It parses the same `theme.txt` installed by GRUB and renders its desktop image, image layers, labels, boot-menu layers, styled boxes, item spacing, fonts, colors, and timeout bar. `catalog.generated.js` embeds those files so the gallery also works when `index.html` is opened directly with a `file://` URL.

The new themes separate artwork into two layers:

- `background.jpg` or `background.png` is the untouched supplied wallpaper.
- `overlay.png` is a transparent 1920×1080 interface layer referenced by a GRUB `image` component.

GRUB still presents entries as a vertical list. Dramatically different designs are created around that list with interface overlays, styled boxes, multiple menu layers, labels, images, frames, spacing, and selection assets. Standard GRUB themes do not play GIF or video backgrounds.

---

## Tested on

Debian, Ubuntu, Arch, Manjaro, Fedora, CachyOS.

---

## Troubleshooting

**Theme looks pixelated or screen goes blank**
GRUB_GFXMODE=1920x1080x32
Edit `/etc/default/grub`, replace with your resolution, then `sudo update-grub`.

**Windows or other OS entries disappeared**
Make sure `GRUB_DISABLE_OS_PROBER=true` is not set in `/etc/default/grub`.
```bash
sudo pacman -S os-prober        # Arch/CachyOS
sudo apt install os-prober      # Debian/Ubuntu
sudo dnf install os-prober      # Fedora
```

**Theme doesn't appear with Secure Boot enabled**
Graphical GRUB themes require `gfxterm` which can conflict with Secure Boot. See your distro's docs.

**"no themes found" error**
Run from the cloned repo root:
```bash
cd gorgeous-grub
sudo ./install.sh
```

**"/boot has insufficient space"**
```bash
sudo pacman -Sc      # Arch/CachyOS
sudo apt autoremove  # Debian/Ubuntu
sudo dnf autoremove  # Fedora
```

---

## Browse before you install

The repo root is a self-contained static site. It can be opened directly:

```text
file:///path/to/grub-themes/index.html
```

After changing `themes.json` or any `theme.txt`, regenerate the offline catalog:

```bash
node tools/generate-catalog.mjs
```

Alternatively, serve it over HTTP:

Run locally:
```bash
python3 -m http.server 8000
# open http://localhost:8000
```

---

## Add your own theme

```bash
mkdir my-theme
# drop background.png (1920×1080) into the folder
# write theme.txt — see GRUB Theme Reference:
# https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html
```

Register in gallery by adding an entry to `themes.json`, then:
```bash
node tools/generate-catalog.mjs
bash tests/validate.sh
```

See [Theme authoring](docs/THEME-AUTHORING.md) for the supported structure, layered-layout examples, preview contract, asset rules, and checklist.

---

## Undo

```bash
sudo ./install.sh -u               # restore /etc/default/grub
sudo ./install.sh -u --purge       # restore + delete theme files from /boot
```

---

## Repo layout
```
.
├── install.sh # interactive installer
├── README.md
├── LICENSE
├── index.html # GitHub Pages gallery
├── styles.css
├── app.js
├── themes.json # gallery manifest
├── catalog.generated.js # offline catalog generated from themes.json + theme.txt
├── tools/generate-catalog.mjs
├── tests/validate.sh
├── docs/THEME-AUTHORING.md
├── fonts/ # source TTF + converted pf2 fonts
├── miku/ # theme folders
├── penguin/
├── nes/
├── street/
├── noir/
├── bmw/
├── nimbus/
├── gas_station/
├── celebrate/
├── ben/
├── motorcycle/ # newer layered theme folders
├── spider/
└── ...
```
---

## Author

**KADHIRAVANEG** (alias **Kadhiravan E.G.**)
- GitHub: [@KADHIRAVANEG](https://github.com/KADHIRAVANEG)

## License

MIT for the code (`install.sh`, static site). See [LICENSE](./LICENSE).
Background artwork belongs to respective artists — see each theme folder for attribution.
PRs welcome.
