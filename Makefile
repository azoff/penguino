.PHONY: everything git

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

everything: conf apts flatpaks snaps 

# system settings
conf: dconf gdm3 deepsleep ssh gpg

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
apts: apt-setup snapd dropbox franz 1password copyq zoom zsh git

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

# gets apt ready to go
apt-setup:
	sudo add-apt-repository -y ppa:hluk/copyq
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
snaps: spt vscode

# installs vscode, also makes it the default
vscode:
	sudo snap install --classic code
	xdg-mime default code.desktop text/plain
	sudo update-alternatives --install /usr/bin/editor editor $(shell which code) 10
	sudo update-alternatives --set editor $(shell which code)

# spotify for terminal
spt:
	snap install spt
	[[ ! -f $(ROOT_DIR)/conf/snap/spt/current/.config/spotify-tui/client.yml ]] || ln -svf $(ROOT_DIR)/conf/snap/spt/current/.config/spotify-tui/client.yml $(HOME)/snap/spt/current/.config/spotify-tui/client.yml
