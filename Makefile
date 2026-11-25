.PHONY: everything git

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# assumes Pop!_OS 26.04 with KDE Plasma 6 as the desktop
# desktop goes before apts so Plasma exists when copyq binds its shortcuts
everything: conf desktop apts flatpaks snaps dev

# ---------------------------------------------------------------------------
# Moving to Pop!_OS 26.04 by clean install (docs/pop26-plasma.md): snapshot
# and back up here, wipe, restore home, then `make everything`.
# ---------------------------------------------------------------------------
POP26_DIR := $(HOME)/pop26-upgrade
THIRD_PARTY_PKGS := vivaldi-stable 1password copyq displaylink-driver evdi claude-desktop code dropbox

# record what is installed (lands in home, so it travels with the backup):
# a checklist of what to reinstall afterwards
pop26-snapshot:
	mkdir -p $(POP26_DIR)/sources.list.d
	cp -a /etc/apt/sources.list.d/. $(POP26_DIR)/sources.list.d/
	apt-mark showmanual | sort > $(POP26_DIR)/apt-manual.txt
	dpkg-query -W -f='$${Package} $${Version}\n' $(THIRD_PARTY_PKGS) > $(POP26_DIR)/third-party.txt 2>/dev/null || true
	flatpak list --app --columns=application,installation > $(POP26_DIR)/flatpaks.txt 2>/dev/null || true
	snap list > $(POP26_DIR)/snaps.txt 2>/dev/null || true
	ls /opt /usr/local/bin /usr/local/sbin > $(POP26_DIR)/opt-and-usr-local.txt 2>/dev/null || true
	nmcli -t -f NAME,TYPE connection show > $(POP26_DIR)/network-connections.txt 2>/dev/null || true
	@echo "snapshot written to $(POP26_DIR)"

# Copy $HOME to an external drive: make pop26-backup DEST=/media/$(USER)/<drive>/home
# Skips what a reinstall recreates: caches, the trash, rootless docker data
# and user-scope flatpak apps (app *data* in ~/.var is kept). SKIP_DROPBOX=yes
# also skips ~/Dropbox and its link state, for a clean re-sync from the cloud
# (never restore the link state without the folder: Dropbox would treat the
# missing files as deletions). Never deletes anything already in DEST.
#
# LEAN=yes also skips everything that re-downloads or rebuilds itself: IMAP
# mail copies, the Android SDK/emulators/firmware images, Spotify's offline
# cache, Claude desktop's VM bundle, package-manager caches and toolchains
# (npm, yarn, gradle, nodenv, rustup, Cypress), VS Code extensions,
# node_modules and Python venvs. EXTRA='--exclude=/some/path/' adds your own.
BACKUP_LEAN := \
	--exclude=/.var/app/eu.betterbird.Betterbird/.thunderbird/*/ImapMail/ --exclude=/.var/app/*/cache/ \
	--exclude=/Android/Sdk/ --exclude=/.android/avd/ --exclude=/Code/android-root/ --exclude=/Code/android-studio/ \
	--exclude=/snap/spotify/common/.cache/ \
	--exclude=/.config/Claude/vm_bundles/ --exclude=/.config/Claude/Cache/ \
	--exclude=/.npm/ --exclude=/.yarn/ --exclude=/.gradle/ --exclude=/.nodenv/ --exclude=/.rustup/ --exclude=/.config/Cypress/ \
	--exclude=/.vscode/extensions/ --exclude=node_modules/ --exclude=.venv/ \
	--exclude=/.var/app/com.vivaldi.Vivaldi/ --exclude=/.var/app/org.chromium.Chromium/ --exclude=/snap/chromium/
# the last line above is data of browsers that are no longer installed
# (dropped on purpose, 2026-11-25). ~/docker-volumes is a root-owned 2023
# database volume a normal copy cannot read; skipped on purpose as well.
BACKUP_EXCLUDES := --exclude=/.cache/ --exclude=/.local/share/Trash/ --exclude=/.local/share/docker/ --exclude=/.local/share/flatpak/ \
	--exclude=/docker-volumes/ \
	$(if $(filter yes,$(SKIP_DROPBOX)),--exclude=/Dropbox/ --exclude=/.dropbox/ --exclude=/.dropbox-dist/) \
	$(if $(filter yes,$(LEAN)),$(BACKUP_LEAN)) $(EXTRA)

# how big would the backup be with these options? (copies nothing)
pop26-backup-size:
	@mkdir -p $(POP26_DIR)/.size-probe
	@rsync -aHAXn --stats $(BACKUP_EXCLUDES) $(HOME)/ $(POP26_DIR)/.size-probe/ | awk -F': ' '/^Total file size/{gsub(/[^0-9]/,"",$$2); printf "backup would be %.1f GB\n", $$2/1e9}'
BACKUP_MUST_HAVE := Code/azoff/penguino/conf/.ssh/id_rsa Code/azoff/penguino/conf/.gnupg/pubring.kbx Code/azoff/penguino/Makefile \
	.config/vivaldi .config/1Password .local/share/keyrings/login.keyring Documents
pop26-backup:
	@test -n "$(DEST)" || { echo "usage: make pop26-backup DEST=/media/$(USER)/<drive>/home [SKIP_DROPBOX=yes]"; exit 1; }
	@test -d "$(DEST)" || { echo "$(DEST) is not a directory (is the drive mounted? mkdir it first)"; exit 1; }
	@fs=$$(findmnt -no FSTYPE -T "$(DEST)"); case "$$fs" in vfat|exfat|ntfs*|fuseblk|msdos) echo "$(DEST) is on $$fs, which cannot store permissions or symlinks -- reformat the drive as ext4 (see docs/pop26-plasma.md)"; exit 1;; esac
	rsync -aHAX --info=progress2 $(BACKUP_EXCLUDES) $(HOME)/ $(DEST)/
	@$(MAKE) --no-print-directory pop26-backup-verify DEST="$(DEST)" SKIP_DROPBOX="$(SKIP_DROPBOX)" LEAN="$(LEAN)" EXTRA="$(EXTRA)"

# compare the backup against home (changes nothing) and check the files that
# exist nowhere else. Run it again right before wiping the disk.
pop26-backup-verify:
	@test -d "$(DEST)" || { echo "usage: make pop26-backup-verify DEST=/media/$(USER)/<drive>/home"; exit 1; }
	@echo "--- files missing or different in the backup (only files changed since the copy should appear)"
	@rsync -aHAXn --itemize-changes $(BACKUP_EXCLUDES) $(HOME)/ $(DEST)/ | grep -v '^\.d' | head -40 | sed 's/^/  /'
	@echo "--- must-have paths"
	@fail=0; for p in $(BACKUP_MUST_HAVE); do if [ -e "$(DEST)/$$p" ]; then echo "  ok       $$p"; else echo "  MISSING  $$p"; fail=1; fi; done; \
		[ $$fail -eq 0 ] || { echo "!! do not wipe the disk until nothing above is MISSING"; exit 1; }
	@echo "--- backup size: $$(du -sh "$(DEST)" 2>/dev/null | cut -f1)"

# ---------------------------------------------------------------------------
# KDE Plasma 6 desktop (Ubuntu 26.04 packages; Pop's repo does not override
# them). Every target below is a no-op until `make plasma` has been run.
# ---------------------------------------------------------------------------
desktop: plasma plasma-shortcuts konsole app-profiles

# installs Plasma. sddm (Plasma's login screen) comes along and debconf asks
# which display manager to use: choose sddm.
plasma:
	@echo ">> if asked for the default display manager, choose sddm"
	sudo apt update
	sudo apt install -y kde-plasma-desktop plasma-nm plasma-pa kscreen kwalletmanager kde-config-sddm sddm-theme-breeze

# make SDDM the display manager if the install prompt was missed; reboot to apply
plasma-dm:
	sudo dpkg-reconfigure sddm
	@echo "display manager is now: $$(cat /etc/X11/default-display-manager) -- reboot to apply"

# Plasma global shortcuts for CopyQ (Meta+V toggle, Meta+Alt+V menu). Meta+V
# is Klipper's by default, so that binding is cleared. Log out and back in to
# apply; if a shortcut does not take, set it in System Settings > Shortcuts.
plasma-shortcuts:
	@if ! command -v kwriteconfig6 >/dev/null; then echo "Plasma is not installed (make plasma) -- skipping shortcuts"; else \
		mkdir -p $(HOME)/.local/share/applications; \
		for f in $(ROOT_DIR)/conf/.local/share/applications/copyq-*.desktop; do ln -svf $$f $(HOME)/.local/share/applications/; done; \
		update-desktop-database $(HOME)/.local/share/applications 2>/dev/null || true; \
		kwriteconfig6 --file kglobalshortcutsrc --group services --group copyq-toggle.desktop --key _launch "Meta+V"; \
		kwriteconfig6 --file kglobalshortcutsrc --group services --group copyq-menu.desktop --key _launch "Meta+Alt+V"; \
		kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key show-on-mouse-pos "none,Meta+V,Show Clipboard Items at Mouse Position"; \
		echo "shortcuts written -- log out and back in to apply"; \
	fi

# Konsole profile (font)
konsole: iosevka
	mkdir -p $(HOME)/.local/share/konsole
	ln -svf $(ROOT_DIR)/conf/.local/share/konsole/penguino.profile $(HOME)/.local/share/konsole/penguino.profile
	@if command -v kwriteconfig6 >/dev/null; then kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile penguino.profile; else echo "Plasma is not installed (make plasma) -- profile linked but not set as default"; fi

# bulk app launch on command: `app-profile work`, `app-profile --list`
# (plain-text profiles in conf/.config/app-profiles)
app-profiles:
	mkdir -p $(HOME)/.local/bin $(HOME)/.config
	ln -svf $(ROOT_DIR)/conf/bin/app-profile $(HOME)/.local/bin/app-profile
	ln -svfn $(ROOT_DIR)/conf/.config/app-profiles $(HOME)/.config/app-profiles

# developer tools
dev: vscode gh nvm rbenv python3 open docker bun rust kubectl pyenv starship nerd-fonts konsole claude oh-my-zsh

starship:
	curl -sS https://starship.rs/install.sh | sh
	ln -s $(ROOT_DIR)/conf/.config/starship.toml $(HOME)/.config/starship.toml

nerd-fonts:
	curl -L 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip' > ~/Downloads/0xProto.zip
	unzip ~/Downloads/0xProto.zip -d ~/.local/share/fonts
	fc-cache -fv

# Iosevka Term (Nerd Font patched so starship/eza glyphs keep working); only the
# weights a terminal uses, the full archive is ~350M of TTFs
iosevka:
	mkdir -p $(HOME)/.local/share/fonts/IosevkaTerm
	curl -L 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/IosevkaTerm.tar.xz' | \
	  tar -xJ -C $(HOME)/.local/share/fonts/IosevkaTerm --wildcards \
	  'IosevkaTermNerdFontMono-Regular.ttf' 'IosevkaTermNerdFontMono-Italic.ttf' \
	  'IosevkaTermNerdFontMono-Bold.ttf' 'IosevkaTermNerdFontMono-BoldItalic.ttf' \
	  'IosevkaTermNerdFontMono-Medium.ttf' 'IosevkaTermNerdFontMono-MediumItalic.ttf' \
	  'IosevkaTermNerdFontMono-SemiBold.ttf' 'IosevkaTermNerdFontMono-SemiBoldItalic.ttf' \
	  'IosevkaTermNerdFontMono-Light.ttf' 'IosevkaTermNerdFontMono-LightItalic.ttf'
	fc-cache -f

claude:
	curl -fsSL https://claude.ai/install.sh | bash

# official Claude desktop app (replaced the claude.ai Vivaldi PWA, 2026-09-29);
# desktop id / Wayland app_id is com.anthropic.Claude. The download endpoint
# sits behind a Cloudflare JS challenge (403 for curl/wget), so grab the deb
# in a browser first; the app self-updates after that.
CLAUDE_DESKTOP_URL := https://claude.ai/api/desktop/linux/x64/deb/latest/redirect
claude-desktop:
	@test -f ~/Downloads/claude-desktop_amd64.deb || { echo "download $(CLAUDE_DESKTOP_URL) in a browser to ~/Downloads first"; exit 1; }
	sudo apt install -y ~/Downloads/claude-desktop_amd64.deb

pyenv:
	curl https://pyenv.run | bash

# in case of kernel issues, update grub: 
# https://github.com/docker/cli/issues/2104#issuecomment-1702319587 
docker:
	curl -fsSL https://get.docker.com | sudo sh
	sudo groupadd docker
	sudo usermod -aG docker $(USER)
	newgrp docker
	docker run --rm hello-world

bun:
	curl -fsSL https://bun.sh/install | bash

rust:
	curl https://sh.rustup.rs -sSf | sh

open:
	$(shell "[[ -f /usr/bin/open ]] && sudo mv -v /usr/bin/open /usr/bin/open-perl")
	sudo ln -fsv $(shell which xdg-open) /usr/bin/open

gh:
	sudo apt install xclip gh

vscode:
	curl -L 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64' > ~/Downloads/vscode.deb
	sudo dpkg -i ~/Downloads/vscode.deb 
	xdg-mime default code.desktop text/plain
	sudo update-alternatives --set editor /usr/bin/code
	sudo update-alternatives --install /usr/bin/editor editor /usr/bin/code 10

# https://community.frame.work/t/fingerprint-scanner-compatibility-with-linux-ubuntu-fedora-etc/1501/18
fprintd:
	sudo apt install fprintd libpam-fprintd gettext gtk-doc-tools libfprint-2-dev libgirepository1.0-dev libgusb-dev libpam-wrapper libpam0g-dev libpamtest0-dev libpolkit-gobject-1-dev libsystemd-dev libdbus-1-dev libxml2-utils python3-pypamtest
	pip install ninja gobject python-dbusmock meson
	sudo pam-auth-update
	sudo ln -svf $(ROOT_DIR)/conf/fingerprint/60-goodix-no-autosuspend.rules /etc/udev/rules.d/60-goodix-no-autosuspend.rules
	sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=27c6

# fingerprint at lock screen + sudo only, never at initial login (keyring)
fingerprint-pam:
	sudo sh $(ROOT_DIR)/conf/fingerprint/install-fingerprint-pam.sh

python3:
	sudo apt install -y python3
	curl -L https://bootstrap.pypa.io/get-pip.py | python3

# allows for multiple node versions on the system
nvm:
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash

# allows for multiple ruby versions on the system
rbenv:
	curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# system settings
conf: ssh gpg autostart vivaldi-pwa

# set up local configs
ssh:
	rm -rvf $(HOME)/.ssh
	ln -svf $(ROOT_DIR)/conf/.ssh $(HOME)/.ssh
	chmod 600 $(HOME)/.ssh/*_rsa

gpg:
	rm -rvf $(HOME)/.gnupg
	ln -svf $(ROOT_DIR)/conf/.gnupg $(HOME)/.gnupg
	chmod 700 $(HOME)/.gnupg

autostart:
	rm -rvf $(HOME)/.config/autostart
	ln -svf $(ROOT_DIR)/conf/.config/autostart $(HOME)/.config/autostart

# debian packages
apts: apt-setup snapd dropbox 1password zsh git openssh-server awscli copyq vivaldi displaylink

# global shortcuts live in the compositor on Wayland (apps can't grab keys),
# so plasma-shortcuts binds them
copyq: plasma-shortcuts
	sudo add-apt-repository -y ppa:hluk/copyq
	sudo apt update
	sudo apt install -y copyq

# DisplayLink driver for USB docking station video (evdi dkms module)
displaylink:
	curl -L 'https://www.synaptics.com/sites/default/files/Ubuntu/pool/stable/main/all/synaptics-repository-keyring.deb' > /tmp/synaptics-keyring.deb
	sudo apt install -y /tmp/synaptics-keyring.deb
	sudo apt update
	sudo apt install -y displaylink-driver

awscli:
	sudo apt install -y awscli

# recover mt7921e wifi + supplicant after s2idle resume (scans stay empty otherwise)
wifi-resume-fix:
	sudo ln -svf $(ROOT_DIR)/conf/wifi/wifi-resume-fix /usr/local/sbin/wifi-resume-fix
	sudo ln -svf $(ROOT_DIR)/conf/wifi/mediatek-wifi-resume /usr/lib/systemd/system-sleep/mediatek-wifi-resume

# gopro-as-webcam script (upstream copy, default resolution patched to 720)
gopro:
	sudo ln -svf $(ROOT_DIR)/conf/gopro/gopro /usr/local/sbin/gopro

# Vivaldi/Chromium segfaults probing uvcvideo *metadata* nodes (laptop camera
# video1) during getUserMedia -- hide them from user apps via udev. The rule
# strips the uaccess tag (>70 so it runs after 70-uaccess.rules); the setfacl
# clears the per-seat ACL logind already granted on existing nodes.
uvc-metadata-fix:
	sudo rm -f /etc/udev/rules.d/60-uvc-metadata-hide.rules
	sudo ln -svf $(ROOT_DIR)/conf/camera/75-uvc-metadata-hide.rules /etc/udev/rules.d/75-uvc-metadata-hide.rules
	sudo udevadm control --reload
	sudo udevadm trigger --subsystem-match=video4linux
	for d in /dev/video*; do \
		if udevadm info $$d | grep -q 'ID_V4L_CAPABILITIES=:$$' && udevadm info $$d | grep -q 'ID_USB_DRIVER=uvcvideo'; then \
			sudo setfacl -b $$d; sudo chmod 000 $$d; sudo chgrp root $$d; \
			echo "hidden: $$d"; \
		fi; \
	done

# PWAs are --app windows of the main Vivaldi instance (one browser, one set
# of extensions; out-of-scope links open natively as tabs in the main window).
# Every launcher carries --load-extension=<pwa-router>,<missive-solo>: the
# router sends Missive links back into the Missive app window and reaps the
# dead tab a custom-scheme launch (Vimcal "v" -> zoommtg://) leaves behind;
# missive-solo auto-picks "In this conversation" on Forward/Reply. The
# vivaldi-stable entry shadows the packaged one for the same reason.
vivaldi-pwa:
	for f in $(ROOT_DIR)/conf/.local/share/applications/vivaldi-*.desktop; do ln -svf $$f $(HOME)/.local/share/applications/; done
	update-desktop-database $(HOME)/.local/share/applications 2>/dev/null || true

# managed policy: no extension runs on the PWA origins except 1Password
vivaldi-policy:
	sudo install -Dm644 $(ROOT_DIR)/conf/vivaldi/policies/pwa-extensions.json /etc/vivaldi/policies/managed/pwa-extensions.json

# Vivaldi's pre-permission media prober segfaults the browser (fd race);
# pre-granting camera/mic to the PWA origins skips that code path.
# Run with Vivaldi stopped.
vivaldi-pwa-media:
	chmod +x $(ROOT_DIR)/conf/vivaldi/preseed-media-permissions
	$(ROOT_DIR)/conf/vivaldi/preseed-media-permissions

# stale Dell-era /etc/modprobe.d/alsa.conf pins snd-hda-intel to ALSA slots
# 0-1, which loses a probe race on docked boots and leaves internal audio
# missing entirely; disable it and reprobe (hda-jack-retask.conf stays -- that
# one is an intentional jack fix)
alsa-hda-fix:
	sudo mv -v /etc/modprobe.d/alsa.conf /etc/modprobe.d/alsa.conf.disabled
	sudo modprobe -r snd_hda_intel || true
	sudo modprobe snd_hda_intel

# force Zoom P4 as default audio sink/source whenever it appears; wireplumber's
# name-based memory misses when the dock re-enumerates the P4 under a suffixed
# node name, so a watcher re-applies the defaults on hotplug events
zoom-p4-audio:
	mkdir -p $(HOME)/.config/wireplumber/wireplumber.conf.d $(HOME)/.config/systemd/user $(HOME)/.local/bin
	ln -svf $(ROOT_DIR)/conf/audio/60-zoom-p4-priority.conf $(HOME)/.config/wireplumber/wireplumber.conf.d/60-zoom-p4-priority.conf
	ln -svf $(ROOT_DIR)/conf/audio/zoom-p4-audio-watch $(HOME)/.local/bin/zoom-p4-audio-watch
	ln -svf $(ROOT_DIR)/conf/audio/zoom-p4-audio.service $(HOME)/.config/systemd/user/zoom-p4-audio.service
	systemctl --user daemon-reload
	systemctl --user enable zoom-p4-audio.service
	systemctl --user restart wireplumber zoom-p4-audio.service

# hide the DisplayLink dock's audio card so docking never steals the default
# output from the laptop/P4 (wireplumber re-picks any device chosen before)
dock-audio-off:
	mkdir -p $(HOME)/.config/wireplumber/wireplumber.conf.d
	ln -svf $(ROOT_DIR)/conf/audio/50-dock-audio-off.conf $(HOME)/.config/wireplumber/wireplumber.conf.d/50-dock-audio-off.conf
	@echo "restart wireplumber when not on a call: systemctl --user restart wireplumber"

# NM wifi backend (wpa_supplicant; see conf/wifi/wifi-backend.conf for history)
# iwd is masked so nothing (dbus activation, stale scripts) can start it and
# fight wpa_supplicant for the interface. `systemctl unmask iwd` if reverting.
wifi-backend:
	sudo ln -svf $(ROOT_DIR)/conf/wifi/wifi-backend.conf /etc/NetworkManager/conf.d/wifi-backend.conf
	sudo systemctl mask --now iwd
	sudo systemctl restart NetworkManager

# openssh server
openssh-server:
	sudo apt install -y openssh-server
	sudo rm -rvf /etc/ssh/sshd_config
	sudo ln -svf $(ROOT_DIR)/conf/openssh/sshd_config /etc/ssh/sshd_config
	sudo systemctl enable ssh
	sudo systemctl start ssh

# git vcs config
git:
	sudo apt install -y git git-lfs
	ln -svf $(ROOT_DIR)/git/.gitconfig $(HOME)/.gitconfig

oh-my-zsh:
	sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
	git clone https://github.com/zsh-users/zsh-autosuggestions $(HOME)/.oh-my-zsh/custom/plugins/zsh-autosuggestions
	git clone https://github.com/zsh-users/zsh-history-substring-search $(HOME)/.oh-my-zsh/custom/plugins/zsh-history-substring-search

# a more modern shell
zsh:
	sudo apt install -y zsh
	chsh -s $(which zsh)
	ln -fs $(ROOT_DIR)/zsh/.zshrc ~/.zshrc
	ln -fs $(ROOT_DIR)/zsh/.zcompdump ~/.zcompdump


1password:
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor | sudo tee /usr/share/keyrings/1password-archive-keyring.gpg > /dev/null
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" | sudo tee /etc/apt/sources.list.d/1password.list
	sudo apt update
	sudo apt install -y 1password
	# trust Vivaldi for browser-extension integration (package upgrades reset this
	# file to the stock all-comments template, which makes the extension spin forever)
	grep -qx vivaldi-bin /etc/1password/custom_allowed_browsers 2>/dev/null || echo vivaldi-bin | sudo tee -a /etc/1password/custom_allowed_browsers > /dev/null

# gets apt ready to go
apt-setup:
	sudo apt update
	sudo apt upgrade -y
	sudo apt autoremove
	sudo apt autoclean

# ubuntu app manager
snapd:
	sudo apt install snapd
	
# dropbox file management
dropbox:
	curl -L 'https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2024.04.17_amd64.deb' > /tmp/dropbox.deb
	sudo apt install -y python3-gpg /tmp/dropbox.deb

# complete, installable apps (flatpak)
# user-scope installs: run make as your user, not via sudo (root has no remotes)
flatpaks: flathub slack whatsapp zoom

flathub:
	flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

zoom: flathub
	flatpak install --user -y flathub us.zoom.Zoom

vivaldi:
	wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor | sudo tee /usr/share/keyrings/vivaldi-browser.gpg > /dev/null
	echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=amd64] https://repo.vivaldi.com/archive/deb/ stable main" | sudo tee /etc/apt/sources.list.d/vivaldi.list
	sudo apt update
	sudo apt install -y vivaldi-stable

slack:
	flatpak install -y com.slack.Slack

whatsapp:
	flatpak install -y io.github.mimbrero.WhatsAppDesktop

# complete, installable apps for ubuntu
snaps: spotify

spotify:
	sudo snap install spotify

kubectl:
	curl -LO "https://dl.k8s.io/release/v1.26.14/bin/linux/amd64/kubectl"
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	rm -f kubectl


