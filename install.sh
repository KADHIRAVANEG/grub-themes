#!/usr/bin/env bash
# Gorgeous GRUB — interactive theme installer
#
# Usage:
#   sudo ./install.sh              # interactive dropdown
#   sudo ./install.sh <theme>      # install a specific theme by slug
#   sudo ./install.sh -t 15        # set boot timeout in seconds (default: 15)
#   sudo ./install.sh -t 10 miku    # set timeout AND install specific theme
#   sudo ./install.sh -l           # list available themes
#   sudo ./install.sh -u           # uninstall (restore backup of /etc/default/grub)
#   sudo ./install.sh -u --purge   # uninstall AND delete theme assets from /boot
#   sudo ./install.sh -r <theme>   # install rEFInd companion theme (native horizontal dock)
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

die()  { printf "%b %s\n" "${c_red}error:${c_rst}" "$*" >&2; exit 1; }
info() { printf "%b %s\n" "${c_cya}::${c_rst}" "$*"; }
ok()   { printf "%b %s\n" "${c_grn}✓${c_rst}" "$*"; }
warn() { printf "%b %s\n" "${c_ylw}!${c_rst}" "$*"; }

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "must be run as root — try: sudo $0"
}

# ── Cleanup trap ─────────────────────────────────────────────────────────────
# If the script aborts mid-copy, remove the partially-written theme dir so
# /boot is never left in a broken state.

_INSTALL_DST=""
_INSTALL_NEW=""
_INSTALL_OLD=""
_INSTALL_SWAPPED=0
_GRUB_CONFIG_SNAPSHOT=""
_GRUB_CFG_SNAPSHOT=""
_cleanup() {
  local ec=$?
  if [[ $ec -ne 0 && -n "$_INSTALL_DST" ]]; then
    warn "install failed — rolling back theme files and configuration"
    [[ -n "$_INSTALL_NEW" && -e "$_INSTALL_NEW" ]] && rm -rf -- "$_INSTALL_NEW"
    if (( _INSTALL_SWAPPED == 1 )); then
      [[ -e "$_INSTALL_DST" ]] && rm -rf -- "$_INSTALL_DST"
      if [[ -n "$_INSTALL_OLD" && -e "$_INSTALL_OLD" ]]; then
        mv -- "$_INSTALL_OLD" "$_INSTALL_DST"
      fi
    fi
    if [[ -n "$_GRUB_CONFIG_SNAPSHOT" && -f "$_GRUB_CONFIG_SNAPSHOT" ]]; then
      cp -a -- "$_GRUB_CONFIG_SNAPSHOT" "$GRUB_DEFAULTS"
      rm -f -- "$_GRUB_CONFIG_SNAPSHOT"
    fi
    if [[ -n "$_GRUB_CFG_SNAPSHOT" && -f "$_GRUB_CFG_SNAPSHOT" ]]; then
      cp -a -- "$_GRUB_CFG_SNAPSHOT" "$GRUB_CFG"
      rm -f -- "$_GRUB_CFG_SNAPSHOT"
    fi
  fi
  [[ -n "${_GRUB_CONFIG_SNAPSHOT:-}" && -f "$_GRUB_CONFIG_SNAPSHOT" ]] && rm -f -- "$_GRUB_CONFIG_SNAPSHOT"
  [[ -n "${_GRUB_CFG_SNAPSHOT:-}" && -f "$_GRUB_CFG_SNAPSHOT" ]] && rm -f -- "$_GRUB_CFG_SNAPSHOT"
}
trap _cleanup EXIT

# ── Theme discovery ──────────────────────────────────────────────────────────

list_themes() {
  [[ -d "$THEMES_SRC" ]] || die "themes source dir not found: $THEMES_SRC"
  local dir
  for dir in "$THEMES_SRC"/*; do
    if [[ -d "$dir" && -f "$dir/theme.txt" ]]; then
      basename "$dir"
    fi
  done | sort
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
  if grep -qE "^[[:space:]]*${key}=" "$file"; then
    sed -i -E "0,/^[[:space:]]*${key}=.*/s|^[[:space:]]*${key}=.*|${key}=\"${esc}\"|" "$file"
  elif grep -qE "^[[:space:]]*#[[:space:]]*${key}=" "$file"; then
    sed -i -E "0,/^[[:space:]]*#[[:space:]]*${key}=.*/s|^[[:space:]]*#[[:space:]]*${key}=.*|${key}=\"${esc}\"|" "$file"
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

  # Detect this before changing files rather than failing at the final step.
  detect_update_cmd

  # 3. Disk space — compare theme folder size vs free space on /boot
  local required_kb available_kb
  required_kb=$(du -sk "$src_dir" | cut -f1)
  # df -k -P on the destination parent (create it temporarily if needed)
  mkdir -p "$THEMES_DST"
  available_kb=$(df -k -P "$THEMES_DST" | awk 'NR==2{print $4}')
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

  [[ "$theme" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die "invalid theme name: '$theme'"
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

  # Stage alongside the destination and retain the old copy until grub-mkconfig
  # succeeds, so an interrupted reinstall can be rolled back.
  local dst="$THEMES_DST/$theme"
  local new_dst old_dst
  new_dst=$(mktemp -d "${THEMES_DST}/.gorgeous-${theme}.new.XXXXXX")
  old_dst=$(mktemp -u "${THEMES_DST}/.gorgeous-${theme}.old.XXXXXX")
  _INSTALL_DST="$dst"
  _INSTALL_NEW="$new_dst"
  _INSTALL_OLD=""
  _INSTALL_SWAPPED=0

  install -d -m 0755 "$new_dst"
  cp -rL "$src_dir/." "$new_dst/"
  chown -R root:root "$new_dst"
  chmod -R u=rwX,go=rX "$new_dst"
  [[ -s "$new_dst/theme.txt" ]] || die "copied theme failed validation"
  if [[ -e "$dst" ]]; then
    mv -- "$dst" "$old_dst"
    _INSTALL_OLD="$old_dst"
  fi
  mv -- "$new_dst" "$dst"
  _INSTALL_NEW=""
  _INSTALL_SWAPPED=1
  ok "installed theme assets → $dst"

  # Update /etc/default/grub with transaction snapshot
  _GRUB_CONFIG_SNAPSHOT=$(mktemp "${GRUB_DEFAULTS}.gorgeous.snapshot.XXXXXX")
  cp -a -- "$GRUB_DEFAULTS" "$_GRUB_CONFIG_SNAPSHOT"

  # Snapshot existing grub.cfg in case grub-mkconfig fails
  if [[ -f "$GRUB_CFG" ]]; then
    _GRUB_CFG_SNAPSHOT=$(mktemp "${GRUB_DIR}/.gorgeous-grub-cfg.snapshot.XXXXXX")
    cp -a -- "$GRUB_CFG" "$_GRUB_CFG_SNAPSHOT"
  fi

  set_grub_var GRUB_THEME            "$dst/theme.txt" "$GRUB_DEFAULTS"
  if [[ -n "${BOOT_TIMEOUT:-}" ]]; then
    set_grub_var GRUB_TIMEOUT        "$BOOT_TIMEOUT"  "$GRUB_DEFAULTS"
  fi
  set_grub_var GRUB_TIMEOUT_STYLE    "menu"           "$GRUB_DEFAULTS"
  set_grub_var GRUB_GFXMODE         "auto"            "$GRUB_DEFAULTS"
  set_grub_var GRUB_GFXPAYLOAD_LINUX "keep"           "$GRUB_DEFAULTS"
  set_grub_var GRUB_TERMINAL_OUTPUT  "gfxterm"        "$GRUB_DEFAULTS"

  if grep -qE '^[[:space:]]*GRUB_TERMINAL(=.*console|.*"console")' "$GRUB_DEFAULTS"; then
    sed -i -E 's|^[[:space:]]*(GRUB_TERMINAL=.*console.*)|# \1 # disabled by Gorgeous GRUB for gfxterm|' "$GRUB_DEFAULTS"
    info "commented out conflicting GRUB_TERMINAL=console in $GRUB_DEFAULTS"
  fi
  ok "updated $GRUB_DEFAULTS"

  warn "GRUB_GFXMODE is set to 'auto'."
  warn "If the theme looks pixelated or blank, edit $GRUB_DEFAULTS and set"
  warn "  GRUB_GFXMODE=1920x1080x32   (replace with your actual resolution)"
  warn "then run: sudo update-grub"

  run_update_grub
  [[ -n "$_INSTALL_OLD" && -e "$_INSTALL_OLD" ]] && rm -rf -- "$_INSTALL_OLD"
  rm -f -- "$_GRUB_CONFIG_SNAPSHOT"
  [[ -n "$_GRUB_CFG_SNAPSHOT" && -f "$_GRUB_CFG_SNAPSHOT" ]] && rm -f -- "$_GRUB_CFG_SNAPSHOT"
  _INSTALL_DST=""
  _INSTALL_OLD=""
  _INSTALL_SWAPPED=0
  _GRUB_CONFIG_SNAPSHOT=""
  _GRUB_CFG_SNAPSHOT=""
  ok "theme '$theme' is active — reboot to see it!"
}

# ── Uninstall ─────────────────────────────────────────────────────────────────

uninstall() {
  local purge="${1:-}"
  require_root

  if [[ -f "$BACKUP" ]]; then
    cp -a "$BACKUP" "$GRUB_DEFAULTS"
    ok "restored $GRUB_DEFAULTS from backup"
  else
    warn "no backup found at $BACKUP — surgically disabling Gorgeous GRUB settings"
    if grep -qE "^[[:space:]]*GRUB_THEME=" "$GRUB_DEFAULTS"; then
      sed -i -E 's|^[[:space:]]*(GRUB_THEME=.*)|# \1 # disabled by Gorgeous GRUB|' "$GRUB_DEFAULTS"
      ok "disabled GRUB_THEME in $GRUB_DEFAULTS"
    fi
  fi

  if [[ "$purge" == "--purge" ]]; then
    local theme removed=0
    while IFS= read -r theme; do
      if [[ -d "$THEMES_DST/$theme" ]]; then
        rm -rf -- "${THEMES_DST:?}/${theme:?}"
        ok "removed $THEMES_DST/$theme"
        removed=1
      fi
    done < <(list_themes)
    (( removed == 1 )) || info "no Gorgeous GRUB theme files found — nothing to purge"
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

  printf "\n%bGorgeous GRUB%b — pick a theme:\n" "$c_cya" "$c_rst"
  printf "%bPreview every theme at: https://kadhiravaneg.github.io/grub-themes/%b\n\n" "$c_dim" "$c_rst"

  local i=1
  for t in "${themes[@]}"; do
    printf "  %b%2d%b)  %s\n" "$c_ylw" "$i" "$c_rst" "$t"
    (( i++ ))
  done
  printf "  %b q%b)  quit\n\n" "$c_ylw" "$c_rst"

  local choice
  read -rp "  selection [1-${#themes[@]}]: " choice

  [[ "$choice" =~ ^[Qq]$ ]] && { info "cancelled."; exit 0; }
  [[ "$choice" =~ ^[0-9]+$ ]] || die "invalid selection: '$choice'"
  (( choice >= 1 && choice <= ${#themes[@]} )) || die "out of range: $choice"

  install_theme "${themes[$((choice-1))]}"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
}

install_refind() {
  local theme="${1:-nimbus}"
  local src_dir="$THEMES_SRC/$theme"
  require_root

  [[ -d "$src_dir" ]] || die "unknown theme: '$theme'"
  [[ -d "$src_dir/refind" ]] || die "theme '$theme' does not have a rEFInd companion configuration"

  local refind_dir=""
  local cand
  for cand in /boot/efi/EFI/refind /boot/EFI/refind /efi/EFI/refind; do
    if [[ -d "$cand" ]]; then
      refind_dir="$cand"
      break
    fi
  done

  [[ -n "$refind_dir" ]] || die "rEFInd installation not found in /boot/efi/EFI/refind or /efi/EFI/refind"

  local target_theme_dir="$refind_dir/themes/$theme"
  install -d -m 0755 "$target_theme_dir"
  cp -rL "$src_dir/." "$target_theme_dir/"
  chown -R root:root "$target_theme_dir"
  chmod -R u=rwX,go=rX "$target_theme_dir"

  local conf="$refind_dir/refind.conf"
  if [[ -f "$conf" ]]; then
    if ! grep -qE "include[[:space:]]+themes/${theme}/" "$conf"; then
      printf '\n# Gorgeous rEFInd Theme\ninclude themes/%s/refind/theme.conf\n' "$theme" >> "$conf"
      ok "added include directive to $conf"
    fi
  fi
  ok "rEFInd companion theme '$theme' installed to $target_theme_dir"
}

# ── Entry point ───────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
    -t|--timeout)
        [[ -n "${2:-}" ]] || die "-t requires a number (e.g. sudo $0 -t 10)"
        [[ "$2" =~ ^[0-9]+$ ]] || die "timeout must be a number, got: $2"
        BOOT_TIMEOUT="$2"
        shift 2
        # remaining arg is theme name or empty for interactive
        if [[ -n "${1:-}" ]]; then
          install_theme "$1"
        else
          interactive_pick
        fi
        ;;
    -l|--list)      list_themes ;;
    -r|--refind)    install_refind "${2:-nimbus}" ;;
    -u|--uninstall) uninstall "${2:-}" ;;
    -h|--help)      usage ;;
    "")             interactive_pick ;;
    -*)             die "unknown option: $1  (try -h)" ;;
    *)              install_theme "$1" ;;
  esac
}

main "$@"
