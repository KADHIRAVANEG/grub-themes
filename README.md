# Gorgeous GRUB

> A curated collection of GRUB2 boot-menu themes for Linux, with a one-command interactive installer. 

For Reference visit the web  ![grub-themes](https://kadhiravaneg.github.io/grub-themes/)

**Preview every theme:** open the live gallery on GitHub Pages → _set this in `Settings → Pages → Branch: main / folder: /grub-themes`_, then drop the URL here.

```
git clone https://github.com/<you>/gorgeous-grub.git
cd gorgeous-grub
sudo ./install.sh
```

That's it. Pick a theme from the dropdown, reboot, enjoy.

---

## What you get

Each theme ships its own `background.{png,jpg,gif}` and a hand-written `theme.txt` with a distinct layout, palette, and typography:

| #  | Slug          | Vibe                                            |
| -- | ------------- | ----------------------------------------------- |
| 01 | `miku`        | Centered cyan boot panel, vocaloid energy      |
| 02 | `penguin`     | Left rail menu, Tux orange accents             |
| 03 | `nes`         | 8-bit centered cartridge, PRESS START          |
| 04 | `nimbus`      | Bottom dock menu, soft animated sky            |
| 05 | `street`      | Right-aligned neon, cyberpunk magenta          |
| 06 | `gas_station` | Wide bottom strip, warm lo-fi sunset           |

Run `sudo ./install.sh -l` to print the up-to-date list.

---

## How it works

`install.sh`:

1. Detects your GRUB layout (`/boot/grub` on Debian/Ubuntu/Arch, `/boot/grub2` on Fedora/RHEL).
2. Backs up `/etc/default/grub` → `/etc/default/grub.gorgeous.bak` (only on the first run, so your original is preserved across re-installs).
3. Copies the chosen theme into `/boot/grub/themes/<slug>/`.
4. Upserts these keys in `/etc/default/grub`:
   - `GRUB_THEME=/boot/grub/themes/<slug>/theme.txt`
   - `GRUB_TIMEOUT=5`
   - `GRUB_GFXMODE=auto`
   - `GRUB_GFXPAYLOAD_LINUX=keep`
   - `GRUB_TERMINAL_OUTPUT=gfxterm` _(required — themes don't render in text mode)_
5. Regenerates the GRUB config with `update-grub`, or `grub[2]-mkconfig -o <cfg>` if `update-grub` is unavailable.

### Commands

```bash
sudo ./install.sh              # interactive dropdown
sudo ./install.sh miku         # install a specific theme by slug
sudo ./install.sh -l           # list installable themes
sudo ./install.sh -u           # restore /etc/default/grub from backup
sudo ./install.sh -h           # help
```

### Requirements

- A working GRUB2 install (`update-grub`, `grub-mkconfig`, or `grub2-mkconfig` on `$PATH`).
- `bash` 4+, `sed`, `find`, `cp`, `install` (all default on every mainstream distro).
- Root (the script touches `/etc/default/grub` and `/boot/`).

### Tested on

Debian, Ubuntu, Arch, Manjaro, Fedora. If your distro patches GRUB heavily (some immutable / atomic distros) the regenerate step may need extra flags — open an issue.

---

## Browse before you install

The `grub-themes/` folder is a self-contained static site (vanilla HTML/CSS/JS). Host it on GitHub Pages so users can see every theme **before** they touch their bootloader:

1. Push the repo.
2. **Settings → Pages →** _Source: Deploy from a branch_, _Branch: `main`_, _Folder: `/grub-themes`_.
3. Wait ~30s, then visit the published URL.

Run it locally too:

```bash
cd grub-themes
python3 -m http.server 8000
# open http://localhost:8000
```

---

## Add your own theme

```bash
mkdir grub-themes/my-theme
cp grub-themes/penguin/theme.txt grub-themes/my-theme/theme.txt
# drop a background.png (1920×1080 looks best) into the folder
```

Edit `theme.txt` — the [GRUB Theme Reference](https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html) documents every property (`title-text`, `boot_menu`, `progress_bar`, fonts, colors).

Then register it in the website gallery:

```jsonc
// grub-themes/themes.json  — append an entry
{
  "slug": "my-theme",
  "title": "My Theme",
  "tagline": "What it feels like in one line.",
  "background": "./my-theme/background.png",
  "palette": ["#0a0d14", "#ff7a18", "#ffb86b", "#e6ecf3"],
  "layout": "centered",        // centered | leftrail | rightcol | bottomdock | arcade | strip
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

Install it the same way as the bundled ones:

```bash
sudo ./install.sh my-theme
```

---

## Undo

```bash
sudo ./install.sh -u   # restores /etc/default/grub from .gorgeous.bak and re-runs update-grub
```

The copied theme assets stay in `/boot/grub/themes/<slug>/` — delete them by hand if you want a clean slate.

---

## Layout

```
.
├── install.sh              # interactive installer (run from repo root)
├── README.md
└── grub-themes/            # self-contained GitHub Pages site + theme assets
    ├── index.html
    ├── styles.css
    ├── app.js
    ├── themes.json         # gallery manifest
    ├── miku/               # one folder per theme
    │   ├── background.png
    │   └── theme.txt
    ├── penguin/
    ├── nes/
    ├── nimbus/
    ├── street/
    └── gas_station/
```

---

## License

MIT for the code (`install.sh`, the static site).
Background artwork belongs to its respective artists — see each theme folder for attribution.
PRs welcome.
