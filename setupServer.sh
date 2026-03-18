#!/bin/bash

# check if sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

apt-get update
apt-get upgrade -y
apt-get install -y ncdu htop git curl ranger nano micro restic rsync fish tmux wget fd-find cockpit cockpit-pcp cockpit-networkmanager cockpit-packagekit

# fd-find installs as 'fdfind' on Debian/Ubuntu — create symlink
if [ ! -f /usr/local/bin/fd ]; then
  ln -s "$(which fdfind)" /usr/local/bin/fd
fi

# install fresh
curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh

# change shell to fish for the invoking user (not just root)
REAL_USER="${SUDO_USER:-$USER}"
chsh -s /usr/bin/fish "$REAL_USER"

# tmux: enable mouse support
TMUX_CONF="/etc/tmux.conf"
if ! grep -q "mouse on" "$TMUX_CONF" 2>/dev/null; then
  echo "set -g mouse on" >> "$TMUX_CONF"
fi

# ask to install docker
read -p "Do you want to install docker? (y/n) " -n 1 -r
echo    # move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# enable cockpit service
systemctl enable --now cockpit.socket

# cleanup
apt-get autoremove -y
apt-get clean
