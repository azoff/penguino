.PHONY: everything git

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

everything: conf apts flatpaks snaps dev

# one-time repair for the 22.04 -> 24.04 upgrade, which disabled third-party
# apt repos and removed/downgraded their packages (also rerun `make docker`
# separately -- it drops into an interactive newgrp shell)
popos24: vivaldi 1password copyq displaylink zoom cosmic-wm

# window session save/restore for COSMIC (replaces GNOME's Another Window
# Session Manager extension); profiles live in conf/
cosmic-wm:
	sudo apt install -y python3-venv
	git clone https://github.com/Izume01/cosmic-ext-wm-manager $(HOME)/Code/Izume01/cosmic-ext-wm-manager 2>/dev/null || true
	cd $(HOME)/Code/Izume01/cosmic-ext-wm-manager && ./install.sh -y
	mkdir -p $(HOME)/.config/cosmic-wm-manager/sessions
	rm -rf $(HOME)/.config/cosmic-wm-manager/profiles
	ln -svf $(ROOT_DIR)/conf/.config/cosmic-wm-manager/profiles $(HOME)/.config/cosmic-wm-manager/profiles
	$(HOME)/.local/bin/cosmic-wm autostart --enable

# developer tools
dev: vscode gh nvm rbenv python3 open docker bun rust kubectl pyenv starship nerd-fonts claude oh-my-zsh

starship:
	curl -sS https://starship.rs/install.sh | sh
	ln -s $(ROOT_DIR)/conf/.config/starship.toml $(HOME)/.config/starship.toml

nerd-fonts:
	curl -L 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip' > ~/Downloads/0xProto.zip
	unzip ~/Downloads/0xProto.zip -d ~/.local/share/fonts
	fc-cache -fv

claude:
	curl -fsSL https://claude.ai/install.sh | bash

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
conf: ssh gpg autostart

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

# global shortcuts live in the compositor on COSMIC/Wayland (apps can't grab keys)
copyq: cosmic-shortcuts
	sudo add-apt-repository -y ppa:hluk/copyq
	sudo apt update
	sudo apt install -y copyq

# COSMIC custom keybindings (Super+Alt+V copyq menu, Super+V copyq toggle)
cosmic-shortcuts:
	mkdir -p $(HOME)/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1
	ln -svf $(ROOT_DIR)/conf/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom $(HOME)/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom

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
# video1) during getUserMedia -- hide them from user apps via udev
uvc-metadata-fix:
	sudo ln -svf $(ROOT_DIR)/conf/camera/60-uvc-metadata-hide.rules /etc/udev/rules.d/60-uvc-metadata-hide.rules
	sudo udevadm control --reload
	sudo udevadm trigger --subsystem-match=video4linux

# PWAs run in a separate vivaldi instance (~/.config/vivaldi-apps) so launch
# order can't disable main-browser extensions; this wires up the link-out
# extension so external links clicked in a PWA open in main Vivaldi instead
# of a vanilla window of the apps instance
vivaldi-pwa-linkout:
	chmod +x $(ROOT_DIR)/conf/vivaldi/linkout-host $(ROOT_DIR)/conf/vivaldi/install-linkout.sh
	$(ROOT_DIR)/conf/vivaldi/install-linkout.sh

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

# complete, installable apps for pop_os
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


