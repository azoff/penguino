.PHONY: everything git

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

everything: conf apts flatpaks snaps dev

# developer tools
dev: nodenv python3 golang open zoom-launcher macos docker

kubectl:
	sudo apt install -y kubectl

docker:
	sudo apt install -y docker-ce docker-ce-cli containerd.io
	sudo setfacl --modify user:$(USER):rw /var/run/docker.sock 

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
conf: dconf gdm3 deepsleep ssh gpg x11 wayland-fractional

wayland-fractional:
	gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

x11:
	sudo ln -svf $(ROOT_DIR)/conf/etc/X11/xorg.conf.d/20-intel.conf /etc/X11/xorg.conf.d/20-intel.conf 

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
apts: apt-setup snapd dropbox 1password copyq zoom zsh git guake chrome-gnome-shell

chrome-gnome-shell:
	sudo apt install chrome-gnome-shell

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
# peek:
#		sudo add-apt-repository -y ppa:peek-developers/stable # missing release file!
# 	sudo apt -y install peek

# gets apt ready to go
apt-setup:
	sudo add-apt-repository -y ppa:hluk/copyq
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
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
snaps: spt vscode mailspring whatsapp-for-linux thunderbird

# mail and calendar (lightning)
thunderbird:
	sudo snap install thunderbird

whatsapp-for-linux:
	sudo snap install whatsapp-for-linux

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
