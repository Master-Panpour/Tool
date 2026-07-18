#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DRY_RUN=0
UPDATE_INDEX=0

usage() {
  cat <<'EOF'
Usage: ./required_perms.sh [--dry-run] [--git-index]

Sets executable permissions on IronCrypt Aegiscope shell entry points.
It never downloads, replaces, or executes remote code. Use
'bin/aegiscope update --check' for a check-only Git update comparison.

  --dry-run     Show changes without applying them
  --git-index   Also record executable bits in the Git index
EOF
}

while (($#)); do
  case "$1" in
    --dry | --dry-run | -n) DRY_RUN=1 ;;
    --git-index) UPDATE_INDEX=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

mapfile -t scripts < <(find "$ROOT/bin" "$ROOT/lib" -type f \( -name '*.sh' -o -name aegiscope \) -print | sort)
scripts+=("$ROOT/aegiscope" "$ROOT/required_perms.sh")

changed=0
for file in "${scripts[@]}"; do
  if [[ -x "$file" ]]; then
    printf 'Already executable: %s\n' "${file#"$ROOT"/}"
    continue
  fi
  printf 'Making executable: %s\n' "${file#"$ROOT"/}"
  if ((DRY_RUN == 0)); then chmod +x "$file"; fi
  ((changed += 1))
done

if ((UPDATE_INDEX == 1)); then
  [[ -d "$ROOT/.git" ]] || {
    printf 'Not a Git checkout; cannot update index.\n' >&2
    exit 1
  }
  for file in "${scripts[@]}"; do
    relative="${file#"$ROOT"/}"
    if ((DRY_RUN == 1)); then
      printf 'DRYRUN: git update-index --chmod=+x -- %s\n' "$relative"
    else
      git -C "$ROOT" update-index --chmod=+x -- "$relative"
    fi
  done
fi

printf 'Summary: changed=%d dry_run=%d git_index=%d\n' "$changed" "$DRY_RUN" "$UPDATE_INDEX"
