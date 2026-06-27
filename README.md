# JOKER53's Grub

> A curated collection of GRUB2 boot-menu themes for Linux, with a one-command interactive installer.

[![ShellCheck](https://github.com/KADHIRAVANEG/grub-themes/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/KADHIRAVANEG/grub-themes/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

**Preview every theme before touching your bootloader →** [kadhiravaneg.github.io/grub-themes](https://kadhiravaneg.github.io/grub-themes/)

```bash
git clone https://github.com/KADHIRAVANEG/grub-themes.git gorgeous-grub
cd gorgeous-grub
sudo ./install.sh
```

Pick a theme from the dropdown, reboot, enjoy.

---

## What you get

Each theme ships its own `background.{png,jpg,gif}` and a hand-written `theme.txt` with a distinct layout, palette, and typography:

| #  | Slug          | Vibe                                                        |
| -- | ------------- | ----------------------------------------------------------- |
| 01 | `miku`        | Centered cyan hologram panel, vocaloid energy               |
| 02 | `penguin`     | ASCII Tux terminal, classic GNU/Linux feel                  |
| 03 | `nes`         | 8-bit cartridge select screen, PRESS START                  |
| 04 | `nimbus`      | macOS-style bottom dock under a soft animated sky           |
| 05 | `street`      | Cyberpunk right-rail terminal, magenta neon glitch          |
| 06 | `gas_station` | Retro pump display, warm lo-fi sunset strip                 |
| 07 | `bmw`         | Cinematic automotive HUD, telemetry bars and throttle       |
| 08 | `celebrate`   | Hand-drawn line catalog, every OS a different hat           |
| 09 | `ben`         | Ben 10 Omnitrix dial selector, green plasma core            |
| 10 | `noir`        | Spider-Noir comic panel, halftone rain, hard-boiled menu    |

Run `sudo ./install.sh -l` to print the live list from your local clone.

---

## How it works

`install.sh`:

1. Detects your GRUB layout (`/boot/grub` on Debian/Ubuntu/Arch, `/boot/grub2` on Fedora/RHEL).
2. Runs pre-flight checks — verifies GRUB is installed, `theme.txt` exists and is non-empty, and `/boot` has enough free space before writing anything.
3. Backs up `/etc/default/grub` → `/etc/default/grub.gorgeous.bak` **on first run only**, so your original config is always preserved across re-installs.
4. Copies the chosen theme into `/boot/grub/themes/<slug>/`. If the copy fails for any reason, the partial files are automatically cleaned up.
5. Upserts these keys in `/etc/default/grub`:
   - `GRUB_THEME=/boot/grub/themes/<slug>/theme.txt`
   - `GRUB_TIMEOUT=5`
   - `GRUB_GFXMODE=auto`
   - `GRUB_GFXPAYLOAD_LINUX=keep`
   - `GRUB_TERMINAL_OUTPUT=gfxterm` _(required — themes don't render in text mode)_
6. Regenerates the GRUB config with `update-grub`, or `grub[2]-mkconfig -o <cfg>` if `update-grub` is unavailable.

### Commands

```bash
sudo ./install.sh              # interactive dropdown — pick from the numbered list
sudo ./install.sh miku         # install a specific theme by slug
sudo ./install.sh -l           # list all installable themes
sudo ./install.sh -u           # restore /etc/default/grub from backup
sudo ./install.sh -u --purge   # restore config AND delete theme files from /boot
sudo ./install.sh -h           # help
```

### Requirements

- A working GRUB2 install (`update-grub`, `grub-mkconfig`, or `grub2-mkconfig` on `$PATH`).
- `bash` 4+, `sed`, `find`, `cp`, `install`, `df`, `du` (all default on every mainstream distro).
- Root — the script writes to `/etc/default/grub` and `/boot/`.

### Tested on

Debian, Ubuntu, Arch, Manjaro, Fedora.

> If your distro patches GRUB heavily (some immutable/atomic distros like openSUSE MicroOS or Fedora Silverblue), the regenerate step may need extra flags — open an issue.

---

## Troubleshooting

**Theme looks pixelated or the screen goes blank**
The installer sets `GRUB_GFXMODE=auto`, which works on most systems but can fall back to a low-resolution mode on some NVIDIA cards or older BIOSes. Fix it by editing `/etc/default/grub`:
```
GRUB_GFXMODE=1920x1080x32
```
Replace `1920x1080` with your actual screen resolution, then run `sudo update-grub`.

**Windows or other OS entries disappeared from the menu**
Check that `GRUB_DISABLE_OS_PROBER=true` is not set (or is commented out) in `/etc/default/grub`. Many distros ship this disabled by default. Remove or comment the line, then run `sudo update-grub`. You may also need `os-prober` installed:
```bash
# Debian/Ubuntu
sudo apt install os-prober

# Arch
sudo pacman -S os-prober

# Fedora
sudo dnf install os-prober
```

**Theme doesn't appear with Secure Boot enabled**
Graphical GRUB themes require `gfxterm`, which can conflict with Secure Boot on some systems. See your distro's documentation on GRUB + Secure Boot configuration.

**"no themes found" error when running install.sh**
Make sure you are running the script from the cloned repo root:
```bash
cd gorgeous-grub
sudo ./install.sh
```
The installer looks for theme folders (`miku/`, `penguin/`, etc.) next to itself.

**"/boot has insufficient space" error**
The installer checks disk space before copying. If `/boot` is full, clean up old kernels first:
```bash
# Debian/Ubuntu
sudo apt autoremove

# Arch
sudo pacman -Sc

# Fedora
sudo dnf autoremove
```

---

## Browse before you install

The repo root is a self-contained static site (vanilla HTML/CSS/JS). It's served directly via GitHub Pages so you can see every theme before touching your bootloader.

Run it locally:

```bash
python3 -m http.server 8000
# open http://localhost:8000
```

---

## Add your own theme

```bash
mkdir my-theme
cp penguin/theme.txt my-theme/theme.txt
# drop a background.png (1920×1080 looks best) into the folder
```

Edit `theme.txt` — the [GRUB Theme Reference](https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html) documents every property (`title-text`, `boot_menu`, `progress_bar`, fonts, colors).

Then register it in the gallery by appending an entry to `themes.json`:

```jsonc
{
  "slug": "my-theme",
  "title": "My Theme",
  "tagline": "What it feels like in one line.",
  "background": "./my-theme/background.png",
  "palette": ["#0a0d14", "#ff7a18", "#ffb86b", "#e6ecf3"],
  "layout": "centered",       // centered | leftrail | rightcol | bottomdock | arcade | strip
  "layoutLabel": "Centered panel",
  "font": "Unifont",
  "tags": ["minimal", "tux"],
  "menu": {
    "title": "boot",
    "timeout": "5s",
    "entries": ["Linux", "Advanced", "Memtest86+", "Firmware"],
    "selected": 0
  }
}
```

Install it the same way as the bundled themes:

```bash
sudo ./install.sh my-theme
```

---

## Undo

```bash
# Restore /etc/default/grub from the automatic backup and regenerate GRUB config
sudo ./install.sh -u

# Same as above, and also delete theme files from /boot/grub/themes/
sudo ./install.sh -u --purge
```

---

## Repo layout

```
.
├── install.sh        # interactive installer — run as root from this directory
├── README.md
├── LICENSE
├── index.html        # GitHub Pages gallery site
├── styles.css
├── app.js
├── themes.json       # gallery manifest — one entry per theme
├── miku/             # theme folders — each contains theme.txt + background.*
├── penguin/
├── nes/
├── nimbus/
├── street/
├── gas_station/
├── bmw/
├── celebrate/
├── ben/
└── noir/
```

---

## License

MIT for the code (`install.sh`, the static site). See [LICENSE](./LICENSE).  
Background artwork belongs to its respective artists — see each theme folder for attribution.  
PRs welcome.
