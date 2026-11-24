#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

bash -n install.sh
node --check app.js >/dev/null
jq -e 'type == "array" and length > 0' themes.json >/dev/null
grep -q 'theme.desktopImage' app.js || { printf 'website preview is not bound to theme.txt desktop-image\n' >&2; exit 1; }
grep -q 'menu.selected_item_pixmap_style' app.js || { printf 'website preview is not bound to the GRUB selection asset\n' >&2; exit 1; }
grep -q 'parseComponents(theme.themeText, "label")' app.js || { printf 'website preview is not bound to GRUB labels\n' >&2; exit 1; }
grep -q 'parseComponents(theme.themeText, "boot_menu")' app.js || { printf 'website preview does not support layered GRUB menus\n' >&2; exit 1; }
grep -q 'parseComponents(theme.themeText, "image")' app.js || { printf 'website preview is not bound to GRUB image components\n' >&2; exit 1; }
grep -q 'styledBoxHtml(theme, menu.menu_pixmap_style' app.js || { printf 'website preview is not bound to the GRUB menu frame\n' >&2; exit 1; }

errors=0
generated_catalog="$(mktemp)"
trap 'rm -f "$generated_catalog"' EXIT
node tools/generate-catalog.mjs "$generated_catalog"
cmp -s "$generated_catalog" catalog.generated.js || {
  printf 'catalog.generated.js is stale; run: node tools/generate-catalog.mjs\n' >&2
  errors=1
}

while IFS= read -r theme_file; do
  theme_dir="${theme_file%/theme.txt}"
  background="$(sed -nE 's/^[[:space:]]*desktop-image:[[:space:]]*"([^"]+)".*/\1/p' "$theme_file")"
  if [[ -z "$background" || ! -f "$theme_dir/$background" ]]; then
    printf 'invalid desktop image: %s -> %s\n' "$theme_file" "$background" >&2
    errors=1
  fi
  case "$background" in
    *.png|*.tga|*.jpg|*.jpeg) ;;
    *) printf 'unsupported GRUB background format: %s\n' "$background" >&2; errors=1 ;;
  esac

  while IFS= read -r pattern; do
    for part in c n ne e se s sw w nw; do
      asset="${pattern/\*/$part}"
      if [[ ! -f "$theme_dir/$asset" ]]; then
        printf 'missing styled-box slice: %s -> %s\n' "$theme_file" "$asset" >&2
        errors=1
      fi
    done
  done < <(sed -nE 's/^[[:space:]]*(menu_pixmap_style|item_pixmap_style|selected_item_pixmap_style)[[:space:]]*=[[:space:]]*"([^"]+)".*/\2/p' "$theme_file")

  while IFS= read -r image_file; do
    if [[ ! -f "$theme_dir/$image_file" ]]; then
      printf 'missing GRUB image component: %s -> %s\n' "$theme_file" "$image_file" >&2
      errors=1
    fi
  done < <(sed -nE 's/^[[:space:]]*file[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$theme_file")

  while IFS= read -r font_name; do
    if ! find "$theme_dir/fonts" -type f -name '*.pf2' -exec strings {} \; 2>/dev/null | grep -Fxq "$font_name"; then
      printf 'theme font is not bundled: %s -> %s\n' "$theme_file" "$font_name" >&2
      errors=1
    fi
  done < <(sed -nE 's/^[[:space:]]*(font|item_font|selected_item_font)[[:space:]]*=[[:space:]]*"([^"]+)".*/\2/p' "$theme_file" | sort -u)

  if grep -nE '^[[:space:]]*bottom[[:space:]]*=' "$theme_file" >/dev/null; then
    printf 'unsupported GRUB property "bottom" in %s (GRUB only supports "top")\n' "$theme_file" >&2
    errors=1
  fi
done < <(find . -mindepth 2 -maxdepth 2 -name theme.txt | sort)

while IFS=$'\t' read -r slug status background; do
  [[ -f "$slug/theme.txt" ]] || { printf 'manifest theme missing: %s\n' "$slug" >&2; errors=1; }
  [[ -f "${background#./}" ]] || { printf 'manifest preview missing: %s\n' "$background" >&2; errors=1; }
  [[ "$status" == working || "$status" == maintenance ]] || { printf 'invalid status: %s\n' "$status" >&2; errors=1; }
done < <(jq -r '.[] | [.slug, .status, .background] | @tsv' themes.json)

while IFS= read -r bad_slice; do
  printf 'accidental double extension detected: %s\n' "$bad_slice" >&2
  errors=1
done < <(find . -name "*.png.png" -o -name "*.jpg.jpg" 2>/dev/null)

(( errors == 0 ))
printf 'All static installer, manifest, font, and GRUB theme asset checks passed.\n'
