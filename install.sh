#!/usr/bin/env bash
# Gorgeous GRUB — interactive theme installer.
#
# Usage:
#   sudo ./install.sh              # interactive dropdown
#   sudo ./install.sh <theme>      # install a specific theme by slug
#   sudo ./install.sh -l           # list available themes
#   sudo ./install.sh -u           # uninstall (restore backup of /etc/default/grub)
#   sudo ./install.sh -h           # show this help
#
# Run from the cloned repo root so it can find ./grub-themes/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_SRC="$SCRIPT_DIR/grub-themes"
GRUB_DEFAULTS="/etc/default/grub"
BACKUP="$GRUB_DEFAULTS.gorgeous.bak"

# Resolve target dirs (Debian/Ubuntu/Arch use /boot/grub, Fedora/RHEL use /boot/grub2)
if   [ -d /boot/grub  ]; then GRUB_DIR="/boot/grub";  GRUB_CFG="/boot/grub/grub.cfg"
elif [ -d /boot/grub2 ]; then GRUB_DIR="/boot/grub2"; GRUB_CFG="/boot/grub2/grub.cfg"
else GRUB_DIR="/boot/grub"; GRUB_CFG="/boot/grub/grub.cfg"
fi
THEMES_DST="$GRUB_DIR/themes"

c_red='\033[1;31m'; c_grn='\033[1;32m'; c_ylw='\033[1;33m'
c_cya='\033[1;36m'; c_dim='\033[2m';   c_rst='\033[0m'
# Disable colors if stdout is not a tty
if [ ! -t 1 ]; then c_red=; c_grn=; c_ylw=; c_cya=; c_dim=; c_rst=; fi

die()  { printf "${c_red}error:${c_rst} %s\n" "$*" >&2; exit 1; }
info() { printf "${c_cya}::${c_rst} %s\n" "$*"; }
ok()   { printf "${c_grn}✓${c_rst} %s\n" "$*"; }
warn() { printf "${c_ylw}!${c_rst} %s\n" "$*"; }

require_root() {
  [ "$(id -u)" -eq 0 ] || die "must be run as root (try: sudo $0 $*)"
}

list_themes() {
  [ -d "$THEMES_SRC" ] || die "themes dir not found: $THEMES_SRC"
  find "$THEMES_SRC" -mindepth 2 -maxdepth 2 -name theme.txt -printf '%h\n' \
    | xargs -I{} basename {} | sort -u
}

detect_update_cmd() {
  if   command -v update-grub      >/dev/null 2>&1; then echo "update-grub"
  elif command -v grub-mkconfig    >/dev/null 2>&1; then echo "grub-mkconfig -o $GRUB_CFG"
  elif command -v grub2-mkconfig   >/dev/null 2>&1; then echo "grub2-mkconfig -o $GRUB_CFG"
  else die "no grub config tool found (need update-grub, grub-mkconfig, or grub2-mkconfig)"
  fi
}

# set_grub_var KEY VALUE FILE — upsert KEY="VALUE" in a shell-style defaults file.
set_grub_var() {
  local key="$1" value="$2" file="$3"
  # escape sed replacement specials in value
  local esc; esc=$(printf '%s' "$value" | sed -e 's/[\\&|]/\\&/g')
  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$file"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}=.*|${key}=\"${esc}\"|" "$file"
  else
    printf '\n%s="%s"\n' "$key" "$value" >> "$file"
  fi
}

install_theme() {
  local theme="$1"
  local src_dir="$THEMES_SRC/$theme"
  [ -d "$src_dir" ] || die "unknown theme: '$theme' (try: sudo $0 -l)"
  [ -f "$src_dir/theme.txt" ] || die "missing theme.txt in $src_dir"

  require_root
  [ -f "$GRUB_DEFAULTS" ] || die "$GRUB_DEFAULTS not found — is GRUB installed?"
  [ -d "$GRUB_DIR" ] || die "$GRUB_DIR not found — is GRUB installed?"

  local update_cmd; update_cmd=$(detect_update_cmd)

  if [ ! -f "$BACKUP" ]; then
    cp -a "$GRUB_DEFAULTS" "$BACKUP"
    ok "backed up $GRUB_DEFAULTS → $BACKUP"
  else
    info "backup already exists: $BACKUP (left untouched)"
  fi

  install -d -m 0755 "$THEMES_DST/$theme"
  cp -af "$src_dir/." "$THEMES_DST/$theme/"
  ok "installed assets → $THEMES_DST/$theme"

  set_grub_var GRUB_THEME             "$THEMES_DST/$theme/theme.txt" "$GRUB_DEFAULTS"
  set_grub_var GRUB_TIMEOUT           "5"                            "$GRUB_DEFAULTS"
  set_grub_var GRUB_GFXMODE           "auto"                         "$GRUB_DEFAULTS"
  set_grub_var GRUB_GFXPAYLOAD_LINUX  "keep"                         "$GRUB_DEFAULTS"
  set_grub_var GRUB_TERMINAL_OUTPUT   "gfxterm"                      "$GRUB_DEFAULTS"
  ok "updated $GRUB_DEFAULTS"

  info "regenerating grub config: $update_cmd"
  eval "$update_cmd"
  ok "theme '$theme' is active — reboot to see it"
}

uninstall() {
  require_root
  [ -f "$BACKUP" ] || die "no backup found at $BACKUP — nothing to restore"
  cp -a "$BACKUP" "$GRUB_DEFAULTS"
  ok "restored $GRUB_DEFAULTS from backup"
  local update_cmd; update_cmd=$(detect_update_cmd)
  info "regenerating grub config: $update_cmd"
  eval "$update_cmd"
  ok "grub config regenerated (themes left in $THEMES_DST for manual cleanup)"
}

interactive_pick() {
  local themes=()
  while IFS= read -r line; do themes+=("$line"); done < <(list_themes)
  [ "${#themes[@]}" -gt 0 ] || die "no themes found in $THEMES_SRC"

  printf "\n${c_cya}Gorgeous GRUB${c_rst} — pick a theme:\n"
  printf "${c_dim}(preview every theme at the project's GitHub Pages site)${c_rst}\n\n"
  local i=1
  for t in "${themes[@]}"; do
    printf "  ${c_ylw}%2d${c_rst}) %s\n" "$i" "$t"
    i=$((i+1))
  done
  printf "  ${c_ylw} q${c_rst}) quit\n\n"

  local choice
  read -rp "  selection [1-${#themes[@]}]: " choice
  [[ "$choice" =~ ^[Qq]$ ]] && { info "cancelled"; exit 0; }
  [[ "$choice" =~ ^[0-9]+$ ]] || die "invalid selection: $choice"
  [ "$choice" -ge 1 ] && [ "$choice" -le "${#themes[@]}" ] || die "out of range: $choice"

  install_theme "${themes[$((choice-1))]}"
}

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
}

main() {
  case "${1:-}" in
    -l|--list)      list_themes ;;
    -u|--uninstall) uninstall ;;
    -h|--help)      usage ;;
    "")             require_root; interactive_pick ;;
    -*)             die "unknown option: $1 (try -h)" ;;
    *)              install_theme "$1" ;;
  esac
}

main "$@"
