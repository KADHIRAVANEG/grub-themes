#!/usr/bin/env bash
# Gorgeous GRUB — interactive theme installer
#
# Usage:
#   sudo ./install.sh              # interactive dropdown
#   sudo ./install.sh <theme>      # install a specific theme by slug
#   sudo ./install.sh -l           # list available themes
#   sudo ./install.sh -u           # uninstall (restore backup of /etc/default/grub)
#   sudo ./install.sh -u --purge   # uninstall AND delete theme assets from /boot
#   sudo ./install.sh -h           # show this help
#
# Run from the cloned repo root so it can find theme folders alongside this script.

set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Theme folders live alongside install.sh at the repo root (miku/, penguin/, etc.)
THEMES_SRC="$SCRIPT_DIR"

GRUB_DEFAULTS="/etc/default/grub"
BACKUP="$GRUB_DEFAULTS.gorgeous.bak"

# Resolve GRUB boot directory — Debian/Ubuntu/Arch vs Fedora/RHEL
if   [[ -d /boot/grub  ]]; then GRUB_DIR="/boot/grub";  GRUB_CFG="/boot/grub/grub.cfg"
elif [[ -d /boot/grub2 ]]; then GRUB_DIR="/boot/grub2"; GRUB_CFG="/boot/grub2/grub.cfg"
else                             GRUB_DIR="/boot/grub";  GRUB_CFG="/boot/grub/grub.cfg"
fi

THEMES_DST="$GRUB_DIR/themes"

# ── Colours ──────────────────────────────────────────────────────────────────

c_red='\033[1;31m'; c_grn='\033[1;32m'; c_ylw='\033[1;33m'
c_cya='\033[1;36m'; c_dim='\033[2m';    c_rst='\033[0m'

# Disable colours when stdout is not a TTY (e.g. piped, CI)
[[ -t 1 ]] || { c_red=; c_grn=; c_ylw=; c_cya=; c_dim=; c_rst=; }

# ── Helpers ──────────────────────────────────────────────────────────────────

die()  { printf "${c_red}error:${c_rst} %s\n" "$*" >&2; exit 1; }
info() { printf "${c_cya}::${c_rst} %s\n" "$*"; }
ok()   { printf "${c_grn}✓${c_rst} %s\n" "$*"; }
warn() { printf "${c_ylw}!${c_rst} %s\n" "$*"; }

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "must be run as root — try: sudo $0 $*"
}

# ── Cleanup trap ─────────────────────────────────────────────────────────────
# If the script aborts mid-copy, remove the partially-written theme dir so
# /boot is never left in a broken state.

_INSTALL_DST=""   # set just before the copy; cleared on success
_cleanup() {
  local ec=$?
  if [[ $ec -ne 0 && -n "$_INSTALL_DST" ]]; then
    warn "install failed — removing partial files from $_INSTALL_DST"
    rm -rf "$_INSTALL_DST"
  fi
}
trap _cleanup EXIT

# ── Theme discovery ──────────────────────────────────────────────────────────

list_themes() {
  [[ -d "$THEMES_SRC" ]] || die "themes source dir not found: $THEMES_SRC"
  # A valid theme folder is any direct child of THEMES_SRC that contains theme.txt
  # Uses POSIX-compatible find (no -printf) so it works on BusyBox / Alpine too
  find "$THEMES_SRC" -mindepth 2 -maxdepth 2 -name "theme.txt" \
    | sed 's|/theme\.txt$||' \
    | xargs -I{} basename {} \
    | sort -u
}

# ── GRUB config regeneration ─────────────────────────────────────────────────
# Use an array instead of eval to avoid shell-injection on root-owned paths.

_UPDATE_CMD=()
detect_update_cmd() {
  if   command -v update-grub    >/dev/null 2>&1; then _UPDATE_CMD=(update-grub)
  elif command -v grub-mkconfig  >/dev/null 2>&1; then _UPDATE_CMD=(grub-mkconfig  -o "$GRUB_CFG")
  elif command -v grub2-mkconfig >/dev/null 2>&1; then _UPDATE_CMD=(grub2-mkconfig -o "$GRUB_CFG")
  else die "no GRUB config tool found (need update-grub, grub-mkconfig, or grub2-mkconfig)"
  fi
}

run_update_grub() {
  detect_update_cmd
  info "regenerating GRUB config: ${_UPDATE_CMD[*]}"
  "${_UPDATE_CMD[@]}"
}

# ── /etc/default/grub key upsert ─────────────────────────────────────────────
# set_grub_var KEY VALUE FILE — upserts KEY="VALUE".
# Handles commented-out lines (# KEY=...) as well as live ones.

set_grub_var() {
  local key="$1" value="$2" file="$3"
  # Escape sed replacement specials in value string
  local esc; esc=$(printf '%s' "$value" | sed 's|[\\&|]|\\&|g')
  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$file"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}=.*|${key}=\"${esc}\"|" "$file"
  else
    printf '\n%s="%s"\n' "$key" "$value" >> "$file"
  fi
}

# ── Pre-flight checks ─────────────────────────────────────────────────────────

preflight_checks() {
  local src_dir="$1"

  # 1. GRUB installation sanity
  [[ -f "$GRUB_DEFAULTS" ]] || die "$GRUB_DEFAULTS not found — is GRUB installed?"
  [[ -d "$GRUB_DIR"      ]] || die "$GRUB_DIR not found — is GRUB installed?"

  # 2. theme.txt must exist and be non-empty
  [[ -f "$src_dir/theme.txt" ]] || die "missing theme.txt in $src_dir"
  [[ -s "$src_dir/theme.txt" ]] || die "theme.txt is empty in $src_dir — corrupt theme?"

  # 3. Disk space — compare theme folder size vs free space on /boot
  local required_kb available_kb
  required_kb=$(du -sk "$src_dir" | cut -f1)
  # df -k on the destination parent (create it temporarily if needed)
  mkdir -p "$THEMES_DST"
  available_kb=$(df -k "$THEMES_DST" | awk 'NR==2{print $4}')
  if (( required_kb > available_kb )); then
    die "/boot has insufficient space — need ~${required_kb} KB, only ${available_kb} KB free"
  fi

  # 4. os-prober warning (common silent dual-boot breakage)
  if grep -qE "^[[:space:]]*GRUB_DISABLE_OS_PROBER[[:space:]]*=[[:space:]]*true" "$GRUB_DEFAULTS" 2>/dev/null; then
    warn "GRUB_DISABLE_OS_PROBER=true is set in $GRUB_DEFAULTS"
    warn "Windows / other OS entries may disappear after regeneration."
    warn "Remove or comment that line if you need them back."
  fi

  # 5. Secure Boot warning (themes require gfxterm which may conflict)
  if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
      warn "Secure Boot is enabled — graphical GRUB themes may not render."
      warn "See your distro's docs on GRUB + Secure Boot if the theme doesn't appear."
    fi
  fi
}

# ── Core install ──────────────────────────────────────────────────────────────

install_theme() {
  local theme="$1"
  local src_dir="$THEMES_SRC/$theme"

  [[ -d "$src_dir" ]] || die "unknown theme: '$theme'  (try: sudo $0 -l)"

  require_root

  preflight_checks "$src_dir"

  # Backup — only on very first run so the true original is always preserved
  if [[ ! -f "$BACKUP" ]]; then
    cp -a "$GRUB_DEFAULTS" "$BACKUP"
    ok "backed up $GRUB_DEFAULTS → $BACKUP"
  else
    warn "backup already exists ($BACKUP) — left untouched"
    warn "Use 'sudo $0 -u' to restore your original config at any time."
  fi

  # Arm the cleanup trap before we start writing
  local dst="$THEMES_DST/$theme"
  _INSTALL_DST="$dst"

  install -d -m 0755 "$dst"
  cp -af "$src_dir/." "$dst/"
  ok "installed theme assets → $dst"

  # Disarm trap — copy succeeded
  _INSTALL_DST=""

  # Update /etc/default/grub
  set_grub_var GRUB_THEME            "$dst/theme.txt" "$GRUB_DEFAULTS"
  set_grub_var GRUB_TIMEOUT          "5"              "$GRUB_DEFAULTS"
  set_grub_var GRUB_GFXMODE         "auto"            "$GRUB_DEFAULTS"
  set_grub_var GRUB_GFXPAYLOAD_LINUX "keep"           "$GRUB_DEFAULTS"
  set_grub_var GRUB_TERMINAL_OUTPUT  "gfxterm"        "$GRUB_DEFAULTS"
  ok "updated $GRUB_DEFAULTS"

  warn "GRUB_GFXMODE is set to 'auto'."
  warn "If the theme looks pixelated or blank, edit $GRUB_DEFAULTS and set"
  warn "  GRUB_GFXMODE=1920x1080x32   (replace with your actual resolution)"
  warn "then run: sudo update-grub"

  run_update_grub
  ok "theme '$theme' is active — reboot to see it!"
}

# ── Uninstall ─────────────────────────────────────────────────────────────────

uninstall() {
  local purge="${1:-}"
  require_root
  [[ -f "$BACKUP" ]] || die "no backup found at $BACKUP — nothing to restore"

  cp -a "$BACKUP" "$GRUB_DEFAULTS"
  ok "restored $GRUB_DEFAULTS from backup"

  if [[ "$purge" == "--purge" ]]; then
    if [[ -d "$THEMES_DST" ]]; then
      rm -rf "$THEMES_DST"
      ok "removed $THEMES_DST (purge)"
    else
      info "$THEMES_DST not found — nothing to purge"
    fi
  else
    info "theme assets remain in $THEMES_DST — run with '--purge' to delete them too"
    info "  sudo $0 -u --purge"
  fi

  run_update_grub
  ok "GRUB config regenerated."
}

# ── Interactive picker ────────────────────────────────────────────────────────

interactive_pick() {
  require_root   # fail early before showing the menu

  local themes=()
  while IFS= read -r line; do themes+=("$line"); done < <(list_themes)
  [[ "${#themes[@]}" -gt 0 ]] || die "no themes found in $THEMES_SRC"

  printf "\n${c_cya}Gorgeous GRUB${c_rst} — pick a theme:\n"
  printf "${c_dim}Preview every theme at: https://kadhiravaneg.github.io/grub-themes/${c_rst}\n\n"

  local i=1
  for t in "${themes[@]}"; do
    printf "  ${c_ylw}%2d${c_rst})  %s\n" "$i" "$t"
    (( i++ ))
  done
  printf "  ${c_ylw} q${c_rst})  quit\n\n"

  local choice
  read -rp "  selection [1-${#themes[@]}]: " choice

  [[ "$choice" =~ ^[Qq]$ ]] && { info "cancelled."; exit 0; }
  [[ "$choice" =~ ^[0-9]+$ ]] || die "invalid selection: '$choice'"
  (( choice >= 1 && choice <= ${#themes[@]} )) || die "out of range: $choice"

  install_theme "${themes[$((choice-1))]}"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

# ── Entry point ───────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
    -l|--list)      list_themes ;;
    -u|--uninstall) uninstall "${2:-}" ;;
    -h|--help)      usage ;;
    "")             interactive_pick ;;
    -*)             die "unknown option: $1  (try -h)" ;;
    *)              install_theme "$1" ;;
  esac
}

main "$@"
