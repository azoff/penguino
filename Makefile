.PHONY: everything git

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

everything: conf apts flatpaks snaps dev

# developer tools
dev: nodenv python3 golang open zoom-launcher macos

# https://github.com/foxlet/macOS-Simple-KVM
macos:
	git clone git@github.com:foxlet/macOS-Simple-KVM.git $(HOME)/Code/foxlet/macOS-Simple-KVM
	sudo apt install -y qemu-system qemu-utils

open:
	$(shell "[[ -f /usr/bin/open ]] && sudo mv -v /usr/bin/open /usr/bin/open-perl")
	sudo ln -fsv $(shell which xdg-open) /usr/bin/open

golang:
	sudo apt install golang
	mkdir -p $(GOPATH)

zoom-launcher:
	go get github.com/lowply/zoom-launcher
	rmv .config/google-calendar-api
	ln -fvs $(ROOT_DIR)/conf/.config/google-calendar-api $(HOME)/.config/google-calendar-api

# https://community.frame.work/t/fingerprint-scanner-compatibility-with-linux-ubuntu-fedora-etc/1501/18
fprintd:
	sudo apt install fprintd libpam-fprintd gettext gtk-doc-tools libfprint-2-dev libgirepository1.0-dev libgusb-dev libpam-wrapper libpam0g-dev libpamtest0-dev libpolkit-gobject-1-dev libsystemd-dev libdbus-1-dev libxml2-utils python3-pypamtest
	pip install ninja gobject python-dbusmock meson
	git clone https://gitlab.freedesktop.org/libfprint/libfprint.git $(HOME)/Code/libfprint/libfprint
	git clone https://gitlab.freedesktop.org/libfprint/fprintd.git $(HOME)/Code/libfprint/fprintd
	sudo pam-auth-update

python3:
	sudo apt install -y python3
	curl -L https://bootstrap.pypa.io/get-pip.py | python3

# allows for multiple node versions on the system
nodenv:
	curl -fsSL https://raw.githubusercontent.com/nodenv/nodenv-installer/master/bin/nodenv-installer | bash

# system settings
conf: dconf gdm3 deepsleep ssh gpg x11

x11:
	sudo ln -svf $(ROOT_DIR)/conf/etc/X11/20-intel.conf /etc/X11/20-intel.conf 

# set up local configs
ssh:
	rm -rvf $(HOME)/.ssh
	sudo ln -svf $(ROOT_DIR)/conf/.ssh $(HOME)/.ssh
	chmod 600 $(HOME)/.ssh/*_rsa

gpg:
	rm -rvf $(HOME)/.gnupg
	sudo ln -svf $(ROOT_DIR)/conf/.gnupg $(HOME)/.gnupg
	chmod 700 $(HOME)/.gnupg

# prevents CPU burn on sleep
deepsleep:
	sudo kernelstub -a "mem_sleep_default=deep"

# loads the gnome settings back into dconf
dconf: conf/settings.dconf
	dconf load / < conf/settings.dconf

# saves the gnome settings to the filesystem	
dconf_dump:
	dconf dump / > conf/settings.dconf

# copy over gnome desktop settings (enables Wayland)
gdm3:
	sudo ln -svf $(ROOT_DIR)/conf/etc/gdm3/custom.conf /etc/gdm3/custom.conf

# debian packages
apts: apt-setup snapd dropbox franz 1password copyq zoom zsh git guake

# git vcs config
git:
	sudo apt install -y git git-lfs
	ln -svf $(ROOT_DIR)/git/.gitconfig $(HOME)/.gitconfig

guake:
	sudo apt install -y guake
	sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator $( which guake ) 10

# a more modern shell
zsh:
	sudo apt install -y zsh
	chsh -s $(which zsh)
	ln -fs $(ROOT_DIR)/zsh/.zshrc ~/.zshrc
	ln -fs $(ROOT_DIR)/zsh/.zcompdump ~/.zcompdump

# allows for gnome extensions like clipboard manager
copyq:
	sudo apt install -y copyq

1password:
	curl -L https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb > /tmp/1password.deb
	sudo apt install -y /tmp/1password.deb
	
# video conferencing app
zoom:
	curl -L https://zoom.us/client/latest/zoom_amd64.deb > /tmp/zoom.deb
	sudo apt install -y /tmp/zoom.deb


# screencapture app
peek:
	sudo apt -y install peek


# gets apt ready to go
apt-setup:
	sudo add-apt-repository -y ppa:hluk/copyq
	sudo add-apt-repository -y ppa:peek-developers/stable
	sudo apt update
	sudo apt upgrade -y
	sudo apt dist-upgrade
	sudo apt autoremove
	sudo apt autoclean

# ubuntu app manager
snapd:
	sudo apt install snapd
	
# dropbox file management
dropbox:
	curl -L https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2020.03.04_amd64.deb > /tmp/dropbox.deb
	sudo apt install -y python3-gpg /tmp/dropbox.deb
	
# chat system
franz:
	curl -L https://github.com/meetfranz/franz/releases/download/v5.7.0/franz_5.7.0_amd64.deb > /tmp/franz.deb
	sudo apt install -y /tmp/franz.deb

# complete, installable apps for pop_os
flatpaks: spotify chromium slack vscode

spotify:
	flatpak install -y spotify
	
chromium:
	flatpak install -y flathub org.chromium.Chromium
	ln -svf $(ROOT_DIR)/conf/.var/app/org.chromium.Chromium/config/chromium-flags.conf $(HOME)/.var/app/org.chromium.Chromium/config/chromium-flags.conf
	
slack:
	flatpak install -y flathub com.slack.Slack

# complete, installable apps for ubuntu
snaps: spt vscode mailspring

# installs vscode, also makes it the default
vscode:
	sudo snap install --classic code
	xdg-mime default code.desktop text/plain
	sudo update-alternatives --install /usr/bin/editor editor $(shell which code) 10
	sudo update-alternatives --set editor $(shell which code)

# email client
mailspring:
	sudo snap install mailspring

# spotify for terminal
spt:
	snap install spt
	[[ ! -f $(ROOT_DIR)/conf/snap/spt/current/.config/spotify-tui/client.yml ]] || ln -svf $(ROOT_DIR)/conf/snap/spt/current/.config/spotify-tui/client.yml $(HOME)/snap/spt/current/.config/spotify-tui/client.yml
