#  proove if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

apt update
apt install -y ncdu htop git curl ranger nano micro restic rsync fish tmux wget
curl https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh
chsh -s /usr/bin/fish
