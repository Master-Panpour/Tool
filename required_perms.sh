#!/usr/bin/env bash
# required_perms.sh - set executable perms for IronCrypt scripts
# Adds a safe auto-update step before applying perms (git preferred, raw fallback optional)
# Single-line comments only

# -----------------------
# Auto-update configuration (change via env vars if you want)
# -----------------------
AUTO_UPDATE="${AUTO_UPDATE:-0}"                      # set 1 to enable auto-update checks
AUTO_UPDATE_ALLOW_DOWNLOAD="${AUTO_UPDATE_ALLOW_DOWNLOAD:-0}"  # set 1 to allow raw-download fallback (risky)
AUTO_UPDATE_GITHUB_REPO="${AUTO_UPDATE_GITHUB_REPO:-Master-Panpour/Tool}"  # default repo for raw fallback
AUTO_UPDATE_BRANCH="${AUTO_UPDATE_BRANCH:-main}"    # branch used for raw fallback
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${AUTO_UPDATE_GITHUB_REPO}/${AUTO_UPDATE_BRANCH}"

# -----------------------
# helper functions
# -----------------------
ewarn() { printf "%s\n" "$*" >&2; }                   # print to stderr
info()  { printf "%s\n" "$*"; }                       # print info
require_cmd() { command -v "$1" >/dev/null 2>&1 || { ewarn "Required command not found: $1"; return 1; } }

# -----------------------
# auto-update function: use git if present, otherwise optional raw download
# -----------------------
auto_update() {
  if [ "${AUTO_UPDATE}" != "1" ]; then
    return 0
  fi

  info "Auto-update: checking for updates (AUTO_UPDATE=1)."

  # prefer git-based update when in a git repo
  if [ -d .git ]; then
    if ! require_cmd git; then
      ewarn "git not available; skipping git auto-update."
      return 0
    fi

    # get branch name robustly
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
      ewarn "Auto-update: unable to determine current branch; skipping git auto-update."
      return 0
    fi

    # fetch remote refs
    if ! git fetch --all --prune --quiet; then
      ewarn "Auto-update: git fetch failed (network?). Skipping."
      return 0
    fi

    # avoid overwriting local uncommitted work
    if ! git diff --quiet --ignore-submodules --; then
      ewarn "Auto-update: local uncommitted changes detected. Please commit or stash before auto-updating."
      ewarn "  git status --porcelain"
      return 0
    fi

    # verify remote ref exists
    remote_ref="origin/${branch}"
    if ! git rev-parse --verify "${remote_ref}" >/dev/null 2>&1; then
      ewarn "Auto-update: remote branch ${remote_ref} not found. Skipping."
      return 0
    fi

    # compare local HEAD to remote
    local_rev="$(git rev-parse @ 2>/dev/null || true)"
    remote_rev="$(git rev-parse --verify "${remote_ref}" 2>/dev/null || true)"
    if [ -z "$local_rev" ] || [ -z "$remote_rev" ]; then
      ewarn "Auto-update: unable to resolve revisions; skipping."
      return 0
    fi

    if [ "$local_rev" = "$remote_rev" ]; then
      info "Auto-update: already up-to-date (branch ${branch})."
      return 0
    fi

    # remote has new commits
    info "Auto-update: remote has new commits on origin/${branch}."
    read -rp "Auto-update: run 'git pull --ff-only origin ${branch}' now? [y/N]: " ans
    case "$ans" in
      [Yy]*)
        # perform fast-forward only pull to avoid merge commits
        if git pull --ff-only origin "${branch}"; then
          info "Auto-update: pulled updates successfully."
          info "Auto-update: restarting script to use updated code..."
          exec "$0" "$@"   # exec replaces current process with updated script
          ewarn "Auto-update: exec failed after pull; continuing current instance."
        else
          ewarn "Auto-update: git pull --ff-only failed. Please update manually."
        fi
        ;;
      *)
        info "Auto-update: user declined. Continuing without updating."
        ;;
    esac

    return 0
  fi

  # if not a git repo, optionally allow raw file download fallback (user must enable)
  if [ "${AUTO_UPDATE_ALLOW_DOWNLOAD}" = "1" ]; then
    if ! require_cmd curl && ! require_cmd wget; then
      ewarn "Auto-update: neither curl nor wget found; cannot download fallback. Skipping."
      return 0
    fi

    RAW_URL="${GITHUB_RAW_BASE}/required_perms.sh"
    info "Auto-update: not a git repo. Will attempt to download updated script from:"
    info "  ${RAW_URL}"
    read -rp "Auto-update: download and replace local script? [y/N]: " ans2
    case "$ans2" in
      [Yy]*)
        TMP="$(mktemp "/tmp/ironcrypt_required_perms.XXXXXX")" || { ewarn "Auto-update: mktemp failed"; return 0; }
        if command -v curl >/dev/null 2>&1; then
          if ! curl -fsSL "$RAW_URL" -o "$TMP"; then ewarn "Auto-update: curl download failed"; rm -f "$TMP"; return 0; fi
        else
          if ! wget -qO "$TMP" "$RAW_URL"; then ewarn "Auto-update: wget download failed"; rm -f "$TMP"; return 0; fi
        fi

        # show diff if available
        if command -v diff >/dev/null 2>&1; then
          info "Auto-update: showing diff (local -> downloaded):"
          diff -u "$0" "$TMP" || true
        fi

        read -rp "Replace current script with downloaded version? [y/N]: " ans3
        case "$ans3" in
          [Yy]*)
            if mv "$TMP" "$0"; then
              chmod +x "$0" 2>/dev/null || true
              info "Auto-update: replaced $0 with downloaded version. Restarting..."
              exec "$0" "$@"
            else
              ewarn "Auto-update: failed to replace $0"
              rm -f "$TMP"
            fi
            ;;
          *)
            info "Auto-update: cancelled by user. Removing tmp file."
            rm -f "$TMP"
            ;;
        esac
        ;;
      *)
        info "Auto-update: user declined download. Continuing."
        ;;
    esac
    return 0
  fi

  info "Auto-update: not a git repo and raw-download fallback is disabled. Skipping auto-update."
  return 0
}

# call auto_update early; it may exec updated copy and not return
auto_update "$@"

# -----------------------
# original required_perms.sh behavior below
# -----------------------
DRY_RUN=0
if [ "$1" = "--dry" ] || [ "$1" = "-n" ]; then DRY_RUN=1; fi

SCRIPT_GLOBS=(
  "bin/*.sh"
  "bin/portscans/*.sh"
  "bin/web_enum/*.sh"
  "bin/target_recon/*.sh"
)

run_cmd() { if [ "$DRY_RUN" -eq 1 ]; then printf "DRYRUN: %s\n" "$*"; else eval "$@"; fi }

GIT_REPO=0
if [ -d .git ]; then GIT_REPO=1; fi

changed=0; skipped=0; failed=0

printf "IronCrypt: setting executable permissions (dry-run=%s)\n" "$DRY_RUN"

for glob in "${SCRIPT_GLOBS[@]}"; do
  for f in $glob; do
    if [ ! -e "$f" ]; then continue; fi
    if [ ! -f "$f" ]; then printf "Skipping (not a file): %s\n" "$f"; skipped=$((skipped+1)); continue; fi
    if [ -x "$f" ]; then printf "Already executable: %s\n" "$f"; skipped=$((skipped+1)); else
      printf "Making executable: %s\n" "$f"
      run_cmd "chmod +x \"$f\"" || { printf "Failed to chmod: %s\n" "$f"; failed=$((failed+1)); continue; }
      changed=$((changed+1))
      if [ "$GIT_REPO" -eq 1 ]; then
        printf "Setting git index executable bit for: %s\n" "$f"
        if [ "$DRY_RUN" -eq 1 ]; then printf "DRYRUN: git update-index --chmod=+x -- \"%s\"\n" "$f"; else
          git update-index --chmod=+x -- "$f" || printf "Warning: git update-index failed for %s\n" "$f"
        fi
      fi
    fi
  done
done

printf "\nSummary: changed=%d skipped=%d failed=%d\n\n" "$changed" "$skipped" "$failed"

if [ "$GIT_REPO" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  printf "Note: files with changed modes are staged in the index (mode change tracked).\n"
  printf "To commit the mode changes:\n"
  printf "  git add -A\n"
  printf "  git commit -m \"Mark scripts executable\"\n"
fi

printf "\nTips:\n"
printf " - Run in Git Bash / WSL on Windows to get chmod semantics.\n"
printf " - To enable auto-update for this run: AUTO_UPDATE=1 ./required_perms.sh\n"
printf " - To allow raw fallback (not recommended): AUTO_UPDATE=1 AUTO_UPDATE_ALLOW_DOWNLOAD=1 ./required_perms.sh\n"
printf " - To preview actions without changes: ./required_perms.sh --dry\n"

exit 0
