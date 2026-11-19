#!/usr/bin/env bash
# Usage:
#   HOSTNAME=desktop USERNAME=haadi GPU=nvidia ./install.sh
# Vars: HOSTNAME USERNAME GPU(amd|nvidia|virtualbox|qemu) [NVIDIA_OPEN=true|false]
#       [STATE_VERSION=26.05] [MODE=install|switch] [MNT=/mnt]
#       [YES=1 skip prompt] [DRY_RUN=1 only generate files]
set -eEuo pipefail
shopt -u patsub_replacement 2>/dev/null || true
cd "$(dirname "$(readlink -f "$0")")"
REPO=$PWD

STAGE=start
fail() {
  local rc=$? ; trap - ERR
  cat >&2 <<MSG

!! install failed at stage: $STAGE (exit $rc)
Nothing is half-finished that a re-run can't fix. Re-run the SAME command after fixing:
  cd $REPO && HOSTNAME=$H USERNAME=$U GPU=$GPU ./install.sh

MSG
  case $STAGE in
    mount) cat >&2 <<'G'
Fix: mount your disks first (example, adjust devices):
  mkfs.ext4 -L nixos /dev/sdX4 ; mkfs.fat -F32 /dev/sdX1 ; mkswap /dev/sdX2
  mount /dev/disk/by-label/nixos /mnt ; mkdir -p /mnt/boot ; mount /dev/sdX1 /mnt/boot ; swapon /dev/sdX2
G
    ;;
    hardware) cat >&2 <<'G'
Fix: check `findmnt /mnt` shows root + /boot, then re-run. Manual: nixos-generate-config --root /mnt --show-hardware-config > modules/hosts/_hardware-HOST.nix
G
    ;;
    eval) cat >&2 <<'G'
Fix: it's a config error, not your machine. Read the error above (add --show-trace for detail:
  nix eval --show-trace .#nixosConfigurations.HOST.config.system.build.toplevel.drvPath )
Edit the file it names, `git add -A`, re-run. A "path ... does not exist"/missing option error usually means an untracked file: git add -A.
G
    ;;
    build) cat >&2 <<'G'
Fix: usually network or space. Check `ping -c1 cache.nixos.org` and `df -h /mnt /`. On the ISO the live
store is RAM-backed: add swap (swapon) or mount more space, then re-run (finished downloads are kept).
Offline/flaky DNS: nmcli / wpa_supplicant first.
G
    ;;
    bootloader) cat >&2 <<'G'
Fix: system built but bootloader failed. Check /mnt/boot is the FAT ESP and `ls /sys/firmware/efi` exists (UEFI),
then:  nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'
Not booted in UEFI mode? Enable EFI in firmware/VM settings and reboot the ISO.
G
    ;;
    password) cat >&2 <<'G'
Fix: the system is installed; just set the password:
  nixos-enter --root /mnt -c 'passwd USER'     (and `passwd root` if you want a root password)
G
    ;;
    switch) cat >&2 <<'G'
Fix: your running system is unchanged. Read the error, retry with --show-trace:
  nixos-rebuild switch --flake .#HOST --show-trace
Back out of a bad switch:  nixos-rebuild switch --rollback   (or pick an older generation at boot)
G
    ;;
  esac
  echo "Still stuck? Paste the full output of the failing step." >&2
  exit "$rc"
}
trap fail ERR

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

H=${HOSTNAME:-}; U=${USERNAME:-}; GPU=${GPU:-}
MODE=${MODE:-auto}; MNT=${MNT:-/mnt}; STATE_VERSION=${STATE_VERSION:-26.05}
NVIDIA_OPEN=${NVIDIA_OPEN:-true}; DRY_RUN=${DRY_RUN:-0}; YES=${YES:-0}

[[ $H =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || die "set HOSTNAME=<name>"
[[ $U =~ ^[a-z_][a-z0-9_-]*$ && $U != root ]] || die "set USERNAME=<lowercase user>"
[[ $GPU == amd || $GPU == nvidia || $GPU == virtualbox || $GPU == qemu ]] || die "set GPU=amd, nvidia, virtualbox or qemu"

STAGE=mount
if [[ $MODE == auto ]]; then
  if mountpoint -q "$MNT" 2>/dev/null; then MODE=install; else MODE=switch; fi
fi
[[ $MODE == install || $MODE == switch ]] || die "MODE must be install or switch"
if [[ $MODE == install && $DRY_RUN != 1 ]]; then
  mountpoint -q "$MNT" || { echo "$MNT is not mounted" >&2; false; }
  command -v nixos-install >/dev/null || die "nixos-install not found (run from the NixOS ISO)"
fi

# repo location (as seen on the final system)
if [[ $MODE == install ]]; then REPO_DIR=/home/$U/nixos-dots; else REPO_DIR=$REPO; fi

# UEFI only (systemd-boot)
[[ -d /sys/firmware/efi || $DRY_RUN == 1 ]] || { echo "not booted in UEFI mode: enable EFI in your firmware/VM settings and reboot the ISO" >&2; STAGE=bootloader; false; }

# per-host extras (NVIDIA open modules)
EXTRA=""
[[ $GPU == nvidia && $NVIDIA_OPEN == false ]] && EXTRA+="        my.nvidia.open = false;
"

cat <<MSG
host=$H user=$U gpu=$GPU mode=$MODE
repo on disk: $REPO_DIR
MSG
if [[ $YES != 1 && $DRY_RUN != 1 ]]; then
  read -rp "Continue? [y/N] " a; [[ $a == [yY]* ]] || exit 1
fi

# ---- generate host file ----
say "writing modules/hosts/$H.nix"
tpl=$(<templates/host.nix)
tpl=${tpl//@HOSTNAME@/$H}; tpl=${tpl//@USERNAME@/$U}; tpl=${tpl//@GPU_MODULE@/gpu-$GPU}
tpl=${tpl//@STATE_VERSION@/$STATE_VERSION};
tpl=${tpl//@REPO_DIR@/$REPO_DIR}; tpl=${tpl//@EXTRA@/${EXTRA%$'\n'}}
printf '%s\n' "$tpl" > "modules/hosts/$H.nix"

# ---- hardware config ----
STAGE=hardware
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

STAGE=eval
export NIX_CONFIG="experimental-features = nix-command flakes"
say "evaluating (catches errors before building)"
nix eval --raw ".#nixosConfigurations.\"$H\".config.system.build.toplevel.drvPath" >/dev/null

if [[ $MODE == install ]]; then
  STAGE=build
  say "nixos-install"
  nixos-install --root "$MNT" --flake ".#$H" --no-root-passwd
  STAGE=password
  ask() { local a; read -rp "$1 [Y/n] " a; [[ ${a:-y} == [yY]* ]]; }
  if ask "Set ROOT password now?"; then nixos-enter --root "$MNT" -c "passwd root"; fi
  say "password for $U (needed to log in)"
  nixos-enter --root "$MNT" -c "passwd $U"
  while ask "Add another user?"; do
    read -rp "  username: " X
    [[ $X =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "  invalid name"; continue; }
    nixos-enter --root "$MNT" -c "useradd -m -G wheel,video,audio,input,networkmanager $X && passwd $X" || echo "  failed, skipping $X"
  done
  say "copying repo to $MNT$REPO_DIR"
  mkdir -p "$MNT$REPO_DIR"; cp -a "$REPO"/. "$MNT$REPO_DIR"/
  nixos-enter --root "$MNT" -c "chown -R $U:users /home/$U" || true
  say "done -- reboot"
else
  STAGE=switch
  say "nixos-rebuild switch"
  if [[ $EUID -eq 0 ]]; then r=""; elif command -v doas >/dev/null; then r=doas; else r=sudo; fi
  $r nixos-rebuild switch --flake ".#$H"
  say "done"
fi
