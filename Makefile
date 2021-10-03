.PHONY: everything git

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

everything: conf apts flatpaks snaps dev

# developer tools
dev: vscode gh nvm rbenv python3 open docker bun rust

kubectl:
	sudo apt install -y kubectl

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
apts: apt-setup snapd dropbox 1password zsh git openssh-server awscli spotify

awscli:
	sudo apt install -y awscli

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
	curl -L 'https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2024.04.17_amd64.deb' > /tmp/dropbox.deb
	sudo apt install -y python3-gpg /tmp/dropbox.deb

# complete, installable apps for pop_os
flatpaks: slack copyq vivaldi whatsapp zoom

zoom:
	flatpak install -y us.zoom.Zoom

copyq:
	flatpak install -y com.github.hluk.copyq

vivaldi:
	flatpak install -y org.chromium.Chromium
	
slack:
	flatpak install -y com.slack.Slack

whatsapp:
	flatpak install -y io.github.mimbrero.WhatsAppDesktop

# complete, installable apps for ubuntu
snaps: mailspring kubectl

kubectl:
	sudo snap install kubectl --classic

# email
mailspring:
	sudo snap install mailspring

spotify:
	curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
	echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
	sudo apt-get update && sudo apt-get install -y spotify-client
