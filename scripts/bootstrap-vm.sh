#!/usr/bin/env bash
set -euo pipefail

repo="git@github.com:jwdonovan/dotfiles.git"
host="vm"
disk="/dev/vda"
worktree=""

usage() {
  cat <<'EOF'
Usage: bootstrap-vm [--repo git@github.com:jwdonovan/dotfiles.git] [--host vm] [--disk /dev/vda]

This bootstrap script is intended to run from the NixOS installer
environment. It authenticates to GitHub with gh if needed, clones the
private dotfiles repository over SSH, and hands off to the host installer
inside that repository.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --host)
      host="$2"
      shift 2
      ;;
    --disk)
      disk="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this bootstrap as root from the installer environment." >&2
  exit 1
fi

export NIX_CONFIG="experimental-features = nix-command flakes"

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub authentication is required to clone ${repo}."
  gh auth login --hostname github.com --git-protocol ssh
fi

install -d -m 0700 /root/.ssh
touch /root/.ssh/known_hosts
ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true

worktree="$(mktemp -d /tmp/dotfiles.XXXXXX)"
trap 'rm -rf "${worktree}"' EXIT

git clone "${repo}" "${worktree}"

"${worktree}/hosts/${host}/install.sh" --disk "${disk}" --host "${host}"
