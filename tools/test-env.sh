#!/usr/bin/env bash
# Test & Validation Environment Runner for Gorgeous GRUB
#
# Usage:
#   ./tools/test-env.sh check            # Run static linters & asset validators
#   ./tools/test-env.sh serve [port]     # Start live preview HTTP server (default: 8000)
#   ./tools/test-env.sh snapshot <theme> # Render SVG/PNG layout snapshot to artifacts
#   ./tools/test-env.sh qemu <theme>     # Boot theme in interactive QEMU test VM
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

c_red='\033[1;31m'; c_grn='\033[1;32m'; c_ylw='\033[1;33m'
c_cya='\033[1;36m'; c_rst='\033[0m'
[[ -t 1 ]] || { c_red=; c_grn=; c_ylw=; c_cya=; c_rst=; }

info() { printf "%b %s\n" "${c_cya}::${c_rst}" "$*"; }
ok()   { printf "%b %s\n" "${c_grn}✓${c_rst}" "$*"; }
warn() { printf "%b %s\n" "${c_ylw}!${c_rst}" "$*"; }
die()  { printf "%b %b\n" "${c_red}error:${c_rst}" "$*" >&2; exit 1; }

cmd_check() {
  info "Running ShellCheck..."
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck install.sh tests/validate.sh tools/test-env.sh
    ok "ShellCheck passed with zero warnings."
  else
    warn "shellcheck not found; skipping linter."
  fi

  info "Validating themes and catalog..."
  bash tests/validate.sh
  ok "All static validations passed."
}

cmd_serve() {
  local port="${1:-8000}"
  info "Starting live preview web server at http://localhost:${port}"
  python3 -m http.server "$port"
}

cmd_snapshot() {
  local theme="${1:-}"
  [[ -n "$theme" ]] || die "usage: $0 snapshot <theme-slug>"
  [[ -d "$theme" && -f "$theme/theme.txt" ]] || die "theme '$theme' not found"

  local out_dir="artifacts/snapshots"
  mkdir -p "$out_dir"
  local out_file="$out_dir/${theme}.png"

  info "Generating snapshot for theme '$theme'..."
  local bg
  bg="$(sed -nE 's/^[[:space:]]*desktop-image:[[:space:]]*"([^"]+)".*/\1/p' "$theme/theme.txt")"
  if [[ -f "$theme/$bg" ]]; then
    if [[ -f "$theme/overlay.png" ]] && command -v magick >/dev/null 2>&1; then
      magick "$theme/$bg" "$theme/overlay.png" -composite -resize 1920x1080 "$out_file"
    elif [[ -f "$theme/$bg" ]]; then
      cp "$theme/$bg" "$out_file"
    fi
    ok "Snapshot generated at: $out_file"
  else
    die "Desktop background '$bg' not found in $theme"
  fi
}

cmd_qemu() {
  local theme="${1:-}"
  [[ -n "$theme" ]] || die "usage: $0 qemu <theme-slug>"
  [[ -d "$theme" && -f "$theme/theme.txt" ]] || die "theme '$theme' not found"

  if ! command -v qemu-system-x86_64 >/dev/null 2>&1 || ! command -v xorriso >/dev/null 2>&1; then
    die "VM testing requires QEMU and xorriso. Install them on Arch/CachyOS with:\n  sudo pacman -S qemu-desktop libisoburn"
  fi
  if ! qemu-system-x86_64 -display help 2>&1 | grep -qE "gtk|sdl|cocoa"; then
    die "QEMU graphical display backend (GTK/SDL) not found.\nInstall desktop GUI drivers:\n  Arch / CachyOS:  sudo pacman -S qemu-desktop\n  Debian / Ubuntu: sudo apt install qemu-system-gui\n  Fedora:          sudo dnf install qemu-ui-gtk"
  fi
  command -v grub-mkrescue >/dev/null 2>&1 || die "grub-mkrescue is required"

  local tmp_iso tmp_dir
  tmp_dir=$(mktemp -d)
  tmp_iso=$(mktemp --suffix=.iso)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir' '$tmp_iso'" EXIT

  info "Building standalone GRUB rescue ISO for theme '$theme'..."
  mkdir -p "$tmp_dir/boot/grub/themes/$theme"
  mkdir -p "$tmp_dir/boot/grub/fonts"
  cp -rL "$theme/." "$tmp_dir/boot/grub/themes/$theme/"

  for f in /usr/share/grub/unicode.pf2 /usr/share/grub/*.pf2; do
    if [[ -f "$f" ]]; then
      cp "$f" "$tmp_dir/boot/grub/fonts/unicode.pf2"
      break
    fi
  done

  cat << EOF > "$tmp_dir/boot/grub/grub.cfg"
function load_video {
  if [ x\$feature_all_video_module = xy ]; then
    insmod all_video
  else
    insmod efi_gop
    insmod ieee1275_fb
    insmod vbe
    insmod vga
    insmod video_bochs
    insmod video_cirrus
  fi
}

load_video
insmod gfxterm
insmod png
insmod jpeg
insmod gfxmenu

set gfxmode=1920x1080,1024x768,auto
set gfxpayload=keep

if [ -f /boot/grub/fonts/unicode.pf2 ]; then
  loadfont /boot/grub/fonts/unicode.pf2
fi
EOF

  find "$tmp_dir/boot/grub/themes/$theme" -type f -name "*.pf2" | while read -r font_file; do
    rel_path="${font_file#"$tmp_dir"}"
    echo "loadfont $rel_path" >> "$tmp_dir/boot/grub/grub.cfg"
  done

  cat << EOF >> "$tmp_dir/boot/grub/grub.cfg"
set theme=/boot/grub/themes/$theme/theme.txt
terminal_output gfxterm

set timeout=15
set timeout_style=menu

menuentry "Arch Linux (Test Entry)" {
    echo "Booting Arch Linux..."
}
menuentry "Ubuntu 24.04 LTS" {
    echo "Booting Ubuntu..."
}
menuentry "Fedora Workstation 41" {
    echo "Booting Fedora..."
}
menuentry "Windows Boot Manager" {
    echo "Chainloading Windows..."
}
menuentry "UEFI Firmware Settings" {
    fwsetup
}
EOF

  grub-mkrescue -o "$tmp_iso" "$tmp_dir" >/dev/null 2>&1
  local vga_opt="std"
  if qemu-system-x86_64 -vga help 2>&1 | grep -q "virtio"; then
    vga_opt="virtio"
  fi
  info "Launching QEMU (1920x1080 virtual display, -vga $vga_opt)..."
  qemu-system-x86_64 -m 512M -cdrom "$tmp_iso" -vga "$vga_opt"
}

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  check)    cmd_check ;;
  serve)    cmd_serve "${2:-8000}" ;;
  snapshot) cmd_snapshot "${2:-}" ;;
  qemu)     cmd_qemu "${2:-}" ;;
  -h|--help) usage ;;
  *)        usage; exit 1 ;;
esac
