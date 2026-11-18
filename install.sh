#!/usr/bin/env bash
# Usage:
#   HOSTNAME=desktop USERNAME=haadi GPU=nvidia DOTFILES=owner/repo ./install.sh
# Vars: HOSTNAME USERNAME GPU(amd|nvidia) [DOTFILES=owner/repo|url] [NVIDIA_OPEN=true|false]
#       [BOOT_DISK=/dev/sdX (BIOS only)] [STATE_VERSION=26.05] [MODE=install|switch] [MNT=/mnt]
#       [YES=1 skip prompt] [DRY_RUN=1 only generate files]
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true
cd "$(dirname "$(readlink -f "$0")")"
REPO=$PWD

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

H=${HOSTNAME:-}; U=${USERNAME:-}; GPU=${GPU:-}; DOTFILES=${DOTFILES:-}
MODE=${MODE:-auto}; MNT=${MNT:-/mnt}; STATE_VERSION=${STATE_VERSION:-26.05}
NVIDIA_OPEN=${NVIDIA_OPEN:-true}; BOOT_DISK=${BOOT_DISK:-}; DRY_RUN=${DRY_RUN:-0}; YES=${YES:-0}

[[ $H =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || die "set HOSTNAME=<name>"
[[ $U =~ ^[a-z_][a-z0-9_-]*$ && $U != root ]] || die "set USERNAME=<lowercase user>"
[[ $GPU == amd || $GPU == nvidia ]] || die "set GPU=amd or GPU=nvidia"

if [[ $MODE == auto ]]; then
  if mountpoint -q "$MNT" 2>/dev/null; then MODE=install; else MODE=switch; fi
fi
[[ $MODE == install || $MODE == switch ]] || die "MODE must be install or switch"
if [[ $MODE == install && $DRY_RUN != 1 ]]; then
  mountpoint -q "$MNT" || die "$MNT is not mounted (mount root at $MNT and ESP at $MNT/boot first)"
  command -v nixos-install >/dev/null || die "nixos-install not found (run from the NixOS ISO)"
fi

# dotfiles location + repo location (as seen on the final system)
if [[ $MODE == install ]]; then REPO_DIR=/home/$U/nixos-dots; else REPO_DIR=$REPO; fi
if [[ -n $DOTFILES ]]; then
  [[ $DOTFILES =~ ^[^/:]+/[^/:]+$ ]] && DOTFILES_URL=https://github.com/$DOTFILES.git || DOTFILES_URL=$DOTFILES
  DOTFILES_DIR=/home/$U/.dotfiles
else
  DOTFILES_URL=
  DOTFILES_DIR=$REPO_DIR/dotfiles
fi

# per-host extras (BIOS boot, NVIDIA open modules)
EXTRA=""
if [[ ! -d /sys/firmware/efi && $MODE == install || ( $MODE == switch && ! -d /sys/firmware/efi ) ]]; then
  [[ -n $BOOT_DISK ]] || die "legacy BIOS detected: set BOOT_DISK=/dev/sdX"
  EXTRA+="        boot.loader.systemd-boot.enable = lib.mkForce false;
        boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
        boot.loader.grub = { enable = true; device = \"$BOOT_DISK\"; };
"
fi
[[ $GPU == nvidia && $NVIDIA_OPEN == false ]] && EXTRA+="        my.nvidia.open = false;
"

cat <<MSG
host=$H user=$U gpu=$GPU mode=$MODE
repo on disk: $REPO_DIR
dotfiles:     $DOTFILES_DIR ${DOTFILES_URL:+(cloned from $DOTFILES_URL)}
MSG
if [[ $YES != 1 && $DRY_RUN != 1 ]]; then
  read -rp "Continue? [y/N] " a; [[ $a == [yY]* ]] || exit 1
fi

# ---- generate host file ----
say "writing modules/hosts/$H.nix"
tpl=$(<templates/host.nix)
tpl=${tpl//@HOSTNAME@/$H}; tpl=${tpl//@USERNAME@/$U}; tpl=${tpl//@GPU_MODULE@/gpu-$GPU}
tpl=${tpl//@STATE_VERSION@/$STATE_VERSION}; tpl=${tpl//@DOTFILES_DIR@/$DOTFILES_DIR}
tpl=${tpl//@REPO_DIR@/$REPO_DIR}; tpl=${tpl//@EXTRA@/${EXTRA%$'\n'}}
printf '%s\n' "$tpl" > "modules/hosts/$H.nix"

# ---- hardware config ----
HW=modules/hosts/_hardware-$H.nix
if [[ $DRY_RUN == 1 ]] || ! command -v nixos-generate-config >/dev/null; then
  say "no nixos-generate-config / dry run: writing placeholder $HW"
  printf '{ ... }: { }\n' > "$HW"
elif [[ $MODE == install ]]; then
  say "generating hardware config from $MNT"
  nixos-generate-config --root "$MNT" --show-hardware-config > "$HW"
else
  say "generating hardware config for this machine"
  nixos-generate-config --show-hardware-config > "$HW"
fi

[[ $DRY_RUN == 1 ]] && { say "dry run done"; exit 0; }

# ---- git (flakes only see tracked files) ----
[[ -d .git ]] || git init -q -b main
git add -A

# ---- dotfiles repo ----
if [[ -n $DOTFILES_URL ]]; then
  target=$DOTFILES_DIR; [[ $MODE == install ]] && target=$MNT$DOTFILES_DIR
  if [[ -d $target/.git ]]; then say "dotfiles already at $target"; else
    say "cloning $DOTFILES_URL"; mkdir -p "$(dirname "$target")"; git clone "$DOTFILES_URL" "$target"
  fi
fi

export NIX_CONFIG="experimental-features = nix-command flakes"
say "evaluating (catches errors before building)"
nix eval --raw ".#nixosConfigurations.\"$H\".config.system.build.toplevel.drvPath" >/dev/null

if [[ $MODE == install ]]; then
  say "nixos-install (it will ask for a ROOT password)"
  nixos-install --root "$MNT" --flake ".#$H"
  say "setting password for $U"
  nixos-enter --root "$MNT" -c "passwd $U"
  say "copying repo to $MNT$REPO_DIR"
  mkdir -p "$MNT$REPO_DIR"; cp -a "$REPO"/. "$MNT$REPO_DIR"/
  nixos-enter --root "$MNT" -c "chown -R $U:users /home/$U" || true
  say "done -- reboot"
else
  say "nixos-rebuild switch"
  if [[ $EUID -eq 0 ]]; then r=""; elif command -v doas >/dev/null; then r=doas; else r=sudo; fi
  $r nixos-rebuild switch --flake ".#$H"
  say "done"
fi
