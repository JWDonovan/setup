#!/usr/bin/env bash
set -euo pipefail

repo="git@github.com:jwdonovan/dotfiles.git"
host="vm"
disk="/dev/vda"
bw_item="dotfiles-bootstrap-deploy-key"
bw_email=""
bw_server=""
ssh_key_path="/root/.ssh/id_ed25519"
worktree=""

usage() {
  cat <<'EOF'
Usage: bootstrap-vm [--repo git@github.com:jwdonovan/dotfiles.git] [--host vm] [--disk /dev/vda] [--bw-item dotfiles-bootstrap-deploy-key]

This bootstrap script is intended to run from the NixOS installer
environment. It logs into Bitwarden if needed, retrieves an SSH deploy key
from a Bitwarden Secure Note, clones the private dotfiles repository over
SSH, and hands off to the host installer inside that repository.
EOF
}

cleanup() {
  if [[ -n "${worktree}" ]]; then
    rm -rf "${worktree}"
  fi

  if [[ -f "${ssh_key_path}" ]]; then
    rm -f "${ssh_key_path}"
  fi

  unset BW_SESSION
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
    --bw-item)
      bw_item="$2"
      shift 2
      ;;
    --bw-email)
      bw_email="$2"
      shift 2
      ;;
    --bw-server)
      bw_server="$2"
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

trap cleanup EXIT

export NIX_CONFIG="experimental-features = nix-command flakes"

if [[ -n "${bw_server}" ]]; then
  bw config server "${bw_server}" >/dev/null
fi

if bw status 2>/dev/null | grep -q '"status"[[:space:]]*:[[:space:]]*"unauthenticated"'; then
  echo "Bitwarden login is required."
  if [[ -n "${bw_email}" ]]; then
    bw login "${bw_email}"
  else
    bw login
  fi
fi

echo "Unlocking Bitwarden."
BW_SESSION="$(bw unlock --raw)"
export BW_SESSION

echo "Syncing Bitwarden vault."
bw sync --session "${BW_SESSION}" >/dev/null

install -d -m 0700 /root/.ssh
touch /root/.ssh/known_hosts
ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true

echo "Retrieving SSH deploy key from Bitwarden item '${bw_item}'."
bw list items --search "${bw_item}" --session "${BW_SESSION}" \
  | jq -er --arg name "${bw_item}" '
      map(select(.name == $name)) |
      if length == 1 then .[0].notes
      elif length == 0 then error("No Bitwarden item named \($name) was found.")
      else error("Multiple Bitwarden items named \($name) were found.")
      end
    ' \
  | sed 's/\r$//' > "${ssh_key_path}"

chmod 600 "${ssh_key_path}"

if ! grep -q "BEGIN OPENSSH PRIVATE KEY" "${ssh_key_path}"; then
  echo "Bitwarden item '${bw_item}' did not contain an OpenSSH private key in its Notes field." >&2
  exit 1
fi

worktree="$(mktemp -d /tmp/dotfiles.XXXXXX)"

GIT_SSH_COMMAND="ssh -i ${ssh_key_path} -o IdentitiesOnly=yes -o UserKnownHostsFile=/root/.ssh/known_hosts" \
  git clone "${repo}" "${worktree}"

rm -f "${ssh_key_path}"

"${worktree}/hosts/${host}/install.sh" --disk "${disk}" --host "${host}"
