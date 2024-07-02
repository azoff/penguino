.PHONY: everything git

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

everything: conf apts flatpaks snaps dev

# developer tools
dev: nodenv rbenv python3 open docker bun rust

kubectl:
	sudo apt install -y kubectl

docker:
	sudo apt install -y docker-ce docker-ce-cli containerd.io
	sudo setfacl --modify user:$(USER):rw /var/run/docker.sock 

bun:
	curl -fsSL https://bun.sh/install | bash

rust:
	curl https://sh.rustup.rs -sSf | sh

open:
	$(shell "[[ -f /usr/bin/open ]] && sudo mv -v /usr/bin/open /usr/bin/open-perl")
	sudo ln -fsv $(shell which xdg-open) /usr/bin/open

# https://community.frame.work/t/fingerprint-scanner-compatibility-with-linux-ubuntu-fedora-etc/1501/18
fprintd:
	sudo apt install fprintd libpam-fprintd gettext gtk-doc-tools libfprint-2-dev libgirepository1.0-dev libgusb-dev libpam-wrapper libpam0g-dev libpamtest0-dev libpolkit-gobject-1-dev libsystemd-dev libdbus-1-dev libxml2-utils python3-pypamtest
	pip install ninja gobject python-dbusmock meson
	sudo pam-auth-update

python3:
	sudo apt install -y python3
	curl -L https://bootstrap.pypa.io/get-pip.py | python3

# allows for multiple node versions on the system
nodenv:
	curl -fsSL https://raw.githubusercontent.com/nodenv/nodenv-installer/master/bin/nodenv-installer | bash

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
apts: apt-setup snapd dropbox 1password zsh git

# git vcs config
git:
	sudo apt install -y git git-lfs
	ln -svf $(ROOT_DIR)/git/.gitconfig $(HOME)/.gitconfig

# a more modern shell
zsh:
	sudo apt install -y zsh
	chsh -s $(which zsh)
	ln -fs $(ROOT_DIR)/zsh/.zshrc ~/.zshrc
	ln -fs $(ROOT_DIR)/zsh/.zcompdump ~/.zcompdump


1password:
	curl -L https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb > /tmp/1password.deb
	sudo apt install -y /tmp/1password.deb

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
	curl -L https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2020.03.04_amd64.deb > /tmp/dropbox.deb
	sudo apt install -y python3-gpg /tmp/dropbox.deb

# complete, installable apps for pop_os
flatpaks: slack vscode copyq vivaldi whatsapp zoom

zoom:
	flatpak install -y us.zoom.Zoom

copyq:
	flatpak install -y com.github.hluk.copyq

vscode:
	flatpak install -y com.visualstudio.code
	sudo update-alternatives --install /usr/bin/editor editor /var/lib/flatpak/exports/com.visualstudio.code 10
	sudo update-alternatives --set editor /var/lib/flatpak/exports/com.visualstudio.code

vivaldi:
	flatpak install -y org.chromium.Chromium
	
slack:
	flatpak install -y com.slack.Slack

whatsapp:
	flatpak install -y io.github.mimbrero.WhatsAppDesktop

# complete, installable apps for ubuntu
snaps: mailspring spotify terminus

# email
mailspring:
	sudo snap install mailspring

spotify:
	sudo snap install spotify

terminus:
	sudo snap install termius-beta
