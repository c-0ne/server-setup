# proove if sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

sudo apt update
sudo apt install -y ncdu htop git curl ranger nano micro restic rsync fish tmux wget fd-find
sudo curl https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh
chsh -s /usr/bin/fish

# ask to install docker
read -p "Do you want to install docker? (y/n) " -n 1 -r
echo    # move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

