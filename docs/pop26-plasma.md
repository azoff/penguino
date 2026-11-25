# Clean install of Pop!_OS 26.04 with KDE Plasma 6

Written 2026-11-25 against this machine (Framework 13 AMD, Pop!_OS 24.04,
DisplayLink dock). All `make` commands run from this repo, as your user (not
via sudo). The repo assumes Pop!_OS 26.04 + Plasma from here on; the COSMIC
setup is in git history.

## Status of this guide

Checked on 2026-11-25:

- Pop!_OS 26.04 was released on 2026-11-24, and System76 recommends a fresh
  install for now.
- Ubuntu 26.04 ships Plasma **6.6.7** (`kde-plasma-desktop`, Wayland session).
  Pop's 26.04 repo does not override any Plasma package.
- The DisplayLink driver comes from Synaptics' own apt repo, which is not
  tied to an Ubuntu version.
- Tested here on 24.04: `pop26-snapshot`, `pop26-backup` and
  `pop26-backup-verify` (against a small fake home), `app-profile`.

Not tested, because it needs 26.04 and Plasma 6: the install itself, the
restore, `make plasma`, `plasma-dm`, `plasma-shortcuts`, `konsole`. Expect to
adjust those on first contact.

## Part 1: Back up

A clean install erases the whole disk, home included. After step 4 below the
USB drive is the only copy of everything, including your SSH keys and GPG
keyring (they live in `conf/.ssh` and `conf/.gnupg`, which git ignores).

### 1. Commit and push penguino

The working tree has a lot of uncommitted changes.

### 2. Prepare the USB drive

- **Size.** Home is 577 GB; the backup is **38 GB** (measured with
  `make pop26-backup-size SKIP_DROPBOX=yes LEAN=yes`). What is left out:
  - always: caches, the trash, rootless docker data, flatpak app binaries,
    and `~/docker-volumes` (a root-owned 2023 database volume);
  - `SKIP_DROPBOX=yes`: `~/Dropbox` (245 GB including the macOS archive
    moved there on 2026-11-25) and its link state. It re-syncs from the
    cloud. **Wait for `dropbox status` to say "Up to date" before wiping**:
    the 50.6 GB archive `Code Archive/azoff-macos.1.0.0.tar` has to finish
    uploading first.
  - `LEAN=yes`: IMAP mail copies, Android SDK/emulators/firmware, Spotify's
    offline cache, Claude desktop's VM bundle, npm/yarn/gradle/nodenv/rustup/
    Cypress, VS Code extensions, `node_modules`, Python venvs, and the
    profiles of three browsers that are no longer installed (Flatpak Vivaldi,
    Flatpak Chromium, snap Chromium).
- **The stick.** The 128 GB SanDisk is an Ubuntu Server installer with a
  116.5 GB data partition (`sda4`). It gets reformatted as password-protected
  ext4, because the backup holds your private keys and browser profile and
  FAT-type filesystems cannot store permissions or symlinks. Check with
  `lsblk` that the stick is still the WDC/SanDisk 119 GB device, then:
  ```
  STICK=/dev/disk/by-id/usb-WDC_SDINDDH4-128G_DD56419883935-0:0-part4
  sudo cryptsetup luksFormat $STICK          # type YES, then choose a password
  sudo cryptsetup open $STICK pop26backup
  sudo mkfs.ext4 -L pop26backup -m 0 /dev/mapper/pop26backup
  sudo mkdir -p /mnt/pop26backup
  sudo mount /dev/mapper/pop26backup /mnt/pop26backup
  sudo mkdir /mnt/pop26backup/home
  sudo chown $USER: /mnt/pop26backup/home
  ```
  This erases whatever is on `sda4`; the installer partitions on the stick
  are untouched.
- **You need a second USB stick for the Pop!_OS installer.** This one holds
  Ubuntu Server, and writing the Pop ISO to it would erase the backup.

### 3. Snapshot and copy

```
make pop26-snapshot
make pop26-backup DEST=/mnt/pop26backup/home SKIP_DROPBOX=yes LEAN=yes
```

- `pop26-snapshot` writes `~/pop26-upgrade/`: lists of manually installed
  packages, apt sources, flatpaks, snaps, `/opt` and `/usr/local` contents
  and saved network names. It lives in home, so it travels with the backup
  and becomes your reinstall checklist.
- `SKIP_DROPBOX=yes` skips the folder and Dropbox's link state together.
  Never restore one without the other: with the link state but no folder,
  Dropbox treats the missing files as deletions.
- It is safe to interrupt and re-run.

### 4. Verify, then wipe

`pop26-backup` ends by running the check below; run it again right before
installing, since files keep changing:

```
make pop26-backup-verify DEST=/mnt/pop26backup/home SKIP_DROPBOX=yes LEAN=yes
```

It lists files that are missing or differ, and fails if any of these is not
on the drive: the SSH key, the GPG keyring, this repo, the Vivaldi profile,
1Password's data and the login keyring. Then detach it
(`sudo umount /mnt/pop26backup && sudo cryptsetup close pop26backup`),
unplug the stick, plug it back in, unlock it with its password and open a
file from it. Only then install.

### Do you need anything outside home?

No. Everything system-level that matters is either reinstallable or
recreated by this repo. Two conveniences are lost unless you save them:

- **Saved Wi-Fi networks and passwords** (72 connections). To keep them:
  ```
  sudo tar -czf /mnt/pop26backup/network-connections.tar.gz /etc/NetworkManager/system-connections
  ```
- **Fingerprint enrollments.** Re-enroll after installing.

Nothing else was found: no crontabs, no databases, nothing in `/srv`. `/opt`
holds only reinstallable apps (1Password, Vivaldi, DisplayLink, ExpressVPN,
PureVPN, VisualVM).

## Part 2: Disk encryption and not getting locked out

- **The old encrypted volume cannot lock you out of the install.** Clean
  Install deletes the old LUKS container without opening it; the old disk
  password is never asked for. It also cannot be recovered afterwards, which
  is why Part 1 ends with a verification.
- **The new disk password has no reset.** You choose it in the installer.
  Pick one you can type on the built-in keyboard at boot, and store it
  somewhere that is not this laptop (1Password on your phone).
- **Use the same username (`azoff`) and the same login password as today.**
  The restored login keyring is encrypted with the login password; with a
  different one it will not unlock, and Vivaldi's stored logins depend on it.
- **Before wiping, confirm you can get into 1Password without this laptop**
  (phone app signed in, or the Emergency Kit with the Secret Key). Everything
  else can be recovered through it.
- **The stick's password** is a third one to remember; do not store it only
  on this laptop.
- The disk is 1.8 TB but only 931 GB of it is partitioned today. Clean
  Install uses the whole disk.

## Part 3: Install and restore

1. Write the Pop!_OS 26.04 ISO (AMD/Intel build) to a second USB stick, boot
   it (F12 at the Framework logo), choose **Clean Install**, enable disk
   encryption, create user `azoff` with your current login password.
2. Log in once, then log out. Restore from a text console so no desktop is
   running on top of the files being replaced: Ctrl+Alt+F3, log in, then
   ```
   lsblk                                   # find the stick's 116.5G partition, e.g. sda4
   sudo cryptsetup open /dev/sda4 backup
   sudo mount /dev/mapper/backup /mnt
   rsync -aHAX --info=progress2 /mnt/home/ ~/
   sudo umount /mnt && sudo cryptsetup close backup
   sudo reboot
   ```
3. Log in. Then:
   ```
   sudo apt update && sudo apt install -y make git
   cd ~/Code/azoff/penguino
   make desktop        # Plasma, shortcuts, Konsole, app-profile
   make apts           # Vivaldi, 1Password, CopyQ, DisplayLink, Dropbox, zsh, ...
   make flatpaks snaps
   ```
   `make plasma` (part of `desktop`) asks for the default display manager:
   **choose `sddm`**. If you missed it, `make plasma-dm`.
4. Reinstall the remaining flatpak apps from the snapshot (their data came
   back with home):
   ```
   awk -F'\t' '$2=="user"{print $1}' ~/pop26-upgrade/flatpaks.txt | xargs flatpak install --user -y flathub
   ```
5. Developer tools: run the `dev` targets you need one at a time (`make
   vscode`, `make docker`, ...). Several are interactive, and the group has
   not been run end to end in a long time.
6. Machine-specific fixes: apply each only if its problem shows up again on
   26.04: `fingerprint-pam`, `zoom-p4-audio`, `dock-audio-off`,
   `wifi-backend`, `wifi-resume-fix`, `uvc-metadata-fix`, `vivaldi-policy`.
   Skip `alsa-hda-fix`; it removes a stale file a fresh install does not have.
7. Reboot. SDDM is the login screen; pick **Plasma (Wayland)**.
8. Remove the last COSMIC config from this repo (left in place until now
   because the running COSMIC session read it through symlinks):
   ```
   git rm -r conf/.config/cosmic
   ```
   plus the untracked `conf/.config/cosmic/com.system76.CosmicTerm` folder,
   `~/.config/cosmic-wm-manager` and `~/.local/bin/cosmic-wm` by hand.

COSMIC's packages stay installed. `pop-desktop` requires them and Pop marks
it protected, so removing COSMIC means overriding an apt guardrail; there is
no target for that.

### First Plasma login: check Vivaldi

Chromium-based browsers pick their encryption store by desktop, and in Plasma
that is KWallet instead of the GNOME keyring. Cookies and saved passwords
written under COSMIC may not decrypt, so sites can look logged out. Open
Vivaldi once and check. If it is logged out, close it without signing in
again and try launching with `--password-store=gnome-libsecret`; if that fixes
it, add the flag to the `vivaldi-*.desktop` launchers in
`conf/.local/share/applications`. 1Password is unaffected.

## Part 4: Set up Plasma for how you work

- **Displays.** System Settings → Display & Monitor. Plasma stores a separate
  arrangement for each set of connected monitors. Make the LG DualUp
  (`DVI-I-1` through the dock) primary. `call_mode on|off` in `zsh/local.zsh`
  calls `kscreen-doctor`.
- **Snapping.** Meta+Left/Right for halves, Meta+PgUp to maximize, or drag a
  window to a screen edge (top edge maximizes).
- **Per-app placement.** Right-click a title bar → More Actions → Configure
  Special Application Settings to pin an app's position, size and screen.
- **Bulk app launch:**
  ```
  app-profile --list
  app-profile -n dual-screen     # show what would start
  app-profile dual-screen
  ```
  Profiles are plain text in `conf/.config/app-profiles/`. It starts
  everything listed and does not check what is already open, so on a session
  that already has those apps you get second windows.
- **Do not also enable** System Settings → Session → "Restore previous
  session" while using `app-profile` at login, or apps start twice.
- **Fingerprint.** Plasma's lock screen handles fingerprint itself; SDDM's
  login goes through `common-auth`, which `make fingerprint-pam` keeps
  fingerprint-free.

### Still to build: per-window memory by monitor set

The reason for this move. First see how far Plasma gets on its own: dock and
undock a few times and note which windows return to their monitor and size.
Whatever is still missing becomes a KWin script (records each window's
geometry per set of connected monitors, replays it on monitor change and
window open), added here as `conf/kwin/` plus a `make` target. It is not
written yet; it needs a running Plasma 6 to develop against.

## If something goes wrong

- **The installer fails partway:** nothing is lost that the stick does not
  have. Boot the installer again and repeat Clean Install.
- **SDDM or Plasma will not start:** Ctrl+Alt+F3, log in, read
  `journalctl -b -p err`. COSMIC is still installed:
  `sudo dpkg-reconfigure cosmic-greeter` and a reboot bring its login screen
  back.
- **The keyring asks for a password at login:** the login password differs
  from the old one. Enter the old password when asked, or change the login
  password to match.

## Make targets

| Target | What it does |
|---|---|
| `pop26-snapshot` | Record what is installed to `~/pop26-upgrade/` |
| `pop26-backup-size [SKIP_DROPBOX=yes] [LEAN=yes]` | How big the backup would be; copies nothing |
| `pop26-backup DEST=… [SKIP_DROPBOX=yes] [LEAN=yes]` | Copy home to an ext4 drive, then verify |
| `pop26-backup-verify DEST=…` | Compare backup against home; fail if a must-have path is missing |
| `plasma` | Install Plasma 6 |
| `plasma-dm` | Make SDDM the login screen |
| `plasma-shortcuts` | CopyQ shortcuts in Plasma (`copyq` depends on it) |
| `konsole` | Konsole font profile (part of `dev`) |
| `app-profiles` | Install `app-profile` and its profiles |
| `desktop` | `plasma plasma-shortcuts konsole app-profiles`; part of `everything` |
