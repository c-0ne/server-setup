#!/bin/bash

# ==============================================================================
#                      SETUP SCRIPT WITH TUI INTERFACE
# ==============================================================================

# ------------------------------------------------------------------------------
# PRE-FLIGHT CHECKS
# ------------------------------------------------------------------------------

# Check if running as root
if [ "$EUID" -ne 0 ]; then
	echo "Please run this script with sudo or as root."
	exit 1
fi

# Get the real user who invoked sudo
REAL_USER="${SUDO_USER:-$USER}"

# ------------------------------------------------------------------------------
# TUI SETUP AND DEPENDENCY INSTALLATION
# ------------------------------------------------------------------------------

# Install 'dialog' if it's not available
if ! command -v dialog &>/dev/null; then
	echo "The 'dialog' utility is required for the TUI. Installing it now..."
	apt-get update >/dev/null
	apt-get install -y dialog
	clear
fi

# ------------------------------------------------------------------------------
# DEFINE TUI OPTIONS
# ------------------------------------------------------------------------------

# Define a function to check if Docker is already installed
is_docker_installed() {
	command -v docker &>/dev/null
}

# Set docker option state based on whether it's already installed
DOCKER_CHOICE="ON"
DOCKER_DESC="Container runtime"
if is_docker_installed; then
	DOCKER_CHOICE="OFF"
	DOCKER_DESC="Container runtime (already installed)"
fi

# Options for the dialog checklist
# Format: <tag> <description> <status>
OPTIONS=(
	"system_update" "Update & Upgrade system (apt)" "ON"
	"---PACKAGES---" "---(Select software to install)---" "OFF"
	"docker" "$DOCKER_DESC" "$DOCKER_CHOICE"
	"ncdu" "Disk usage analyzer" "ON"
	"htop" "Interactive process viewer" "ON"
	"git" "Version control system" "ON"
	"curl" "HTTP client for transferring data" "ON"
	"ranger" "Terminal file manager" "ON"
	"nano" "Simple text editor" "ON"
	"micro" "Modern terminal text editor" "ON"
	"fresh" "Another modern Text-Editor" "ON"
	"restic" "Fast, secure, efficient backup tool" "ON"
	"rsync" "File synchronization and transfer" "ON"
	"fish" "Friendly interactive shell" "ON"
	"tmux" "Terminal multiplexer" "ON"
	"wget" "File downloader" "ON"
	"fd-find" "Fast and user-friendly 'find' alternative" "ON"
	"cockpit" "Web-based server management UI (includes pcp, network, packagekit)" "ON"
	"---CONFIGS---" "---(Select configurations to apply)---" "OFF"
	"fish_shell_change" "Set Fish as the default shell" "ON"
	"tmux_mouse" "Enable mouse support in Tmux" "ON"
	"docker_usermod" "Add user to the 'docker' group" "ON"
)

# ------------------------------------------------------------------------------
# DISPLAY TUI AND CAPTURE SELECTIONS
# ------------------------------------------------------------------------------

SELECTIONS=$(dialog --title "Server Setup Configuration" \
	--checklist "Use Spacebar to select/deselect options. Press Enter when done." \
	28 85 20 \
	"${OPTIONS[@]}" \
	2>&1 >/dev/tty)

# Exit if user presses 'Cancel'
if [ $? -ne 0 ]; then
	clear
	echo "User cancelled setup. No changes were made."
	exit
fi

clear
echo "Starting setup with selected options..."

# Array to hold summary of actions
SUMMARY=()

# ------------------------------------------------------------------------------
# EXECUTE SELECTED TASKS
# ------------------------------------------------------------------------------

# --- System Update ---
if [[ "$SELECTIONS" == *"system_update"* ]]; then
	echo "Updating and upgrading system..."
	apt-get update
	apt-get upgrade -y
	SUMMARY+=("System updated and upgraded.")
else
	# Still run update if any packages are to be installed, but quietly
	if [[ "$SELECTIONS" == *"---PACKAGES---"* ]]; then
		apt-get update >/dev/null
	fi
fi

# --- Package Installation ---
PACKAGES_TO_INSTALL=()
# Special handling for cockpit
if [[ "$SELECTIONS" == *"cockpit"* ]]; then
    PACKAGES_TO_INSTALL+=("cockpit" "cockpit-pcp" "cockpit-network" "cockpit-packagekit")
fi


while IFS= read -r ITEM; do
    # Skip separators and cockpit (already handled)
    if [[ "$ITEM" == *"---"* ]] || [[ "$ITEM" == "cockpit" ]]; then continue; fi
    # Add package to the list if it was selected
    if [[ "$SELECTIONS" == *"$ITEM"* ]]; then
        PACKAGES_TO_INSTALL+=("$ITEM")
    fi
done <<<"$(printf '%s\n' "${OPTIONS[@]}" | awk 'NR % 3 == 1' | sed 's/"//g')" # Extracts tags


# If docker was selected but is already installed, don't try to install it
if is_docker_installed && [[ "$SELECTIONS" == *"docker"* ]]; then
	echo "Docker is already installed, skipping installation."
	PACKAGES_TO_INSTALL=("${PACKAGES_TO_INSTALL[@]/docker/}") # Remove docker from array
fi

# Install all selected packages at once
if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
	# Special handling for Docker installation
	if [[ "${PACKAGES_TO_INSTALL[*]}" =~ "docker" ]]; then
		echo "Installing Docker..."
		curl -fsSL https://get.docker.com -o get-docker.sh
		sh get-docker.sh
		rm get-docker.sh
		SUMMARY+=("Installed Docker.")
		# Remove docker from the list to not pass it to apt
		PACKAGES_TO_INSTALL=("${PACKAGES_TO_INSTALL[@]/docker/}")
	fi

	if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
        INSTALLED_PACKAGES_LIST=$(IFS=, ; echo "${PACKAGES_TO_INSTALL[*]}")
		echo "Installing selected packages: ${INSTALLED_PACKAGES_LIST}..."
		apt-get install -y "${PACKAGES_TO_INSTALL[@]}"
        SUMMARY+=("Installed packages: ${INSTALLED_PACKAGES_LIST}.")
	fi
fi

# --- Configurations ---

# Install fresh
if [[ "$SELECTIONS" == *"fresh"* ]]; then
	echo "Installing fresh..."
	curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh
    SUMMARY+=("Installed 'fresh' text editor.")
fi

# Change default shell to fish
if [[ "$SELECTIONS" == *"fish_shell_change"* ]]; then
	if command -v fish &>/dev/null; then
		echo "Changing default shell to fish for user '$REAL_USER'..."
		chsh -s "$(which fish)" "$REAL_USER"
        SUMMARY+=("Set Fish as default shell for '$REAL_USER'.")
	else
		echo "Skipping shell change: 'fish' is not installed or wasn't selected."
	fi
fi

# Enable tmux mouse support
if [[ "$SELECTIONS" == *"tmux_mouse"* ]]; then
	if command -v tmux &>/dev/null; then
		echo "Enabling mouse support in tmux..."
		TMUX_CONF="/etc/tmux.conf"
		if ! grep -q "set -g mouse on" "$TMUX_CONF" 2>/dev/null; then
			echo "set -g mouse on" >>"$TMUX_CONF"
		fi
        SUMMARY+=("Enabled mouse support in Tmux.")
	else
		echo "Skipping tmux configuration: 'tmux' is not installed or wasn't selected."
	fi
fi

# Create fd symlink if fd-find was installed
if [[ "$SELECTIONS" == *"fd-find"* ]]; then
    if command -v fdfind &>/dev/null; then
        echo "Creating 'fd' symlink for 'fdfind'..."
        if [ ! -L /usr/local/bin/fd ]; then
            ln -s "$(which fdfind)" /usr/local/bin/fd
            SUMMARY+=("Created 'fd' symlink for 'fdfind'.")
        fi
    fi
fi


# Add user to docker group
if [[ "$SELECTIONS" == *"docker_usermod"* ]]; then
	if command -v docker &>/dev/null; then
		echo "Adding user '$REAL_USER' to the docker group..."
		usermod -aG docker "$REAL_USER"
        SUMMARY+=("Added user '$REAL_USER' to the 'docker' group.")
	else
		echo "Skipping docker group modification: 'docker' is not installed or wasn't selected."
	fi
fi

# Enable cockpit service if cockpit was installed
if [[ "$SELECTIONS" == *"cockpit"* ]]; then
    if command -v cockpit-ws &>/dev/null; then
        echo "Enabling and starting cockpit.socket..."
        systemctl enable --now cockpit.socket
        SUMMARY+=("Enabled and started the Cockpit service.")
    fi
fi

# --- System Cleanup ---
echo "Cleaning up unused packages..."
apt-get autoremove -y
apt-get clean
SUMMARY+=("System cleanup performed.")

# --- Summary ---
echo "----------------------------------------"
echo "         SETUP SUMMARY"
echo "----------------------------------------"
for ITEM in "${SUMMARY[@]}"; do
    echo "- $ITEM"
done
echo "----------------------------------------"


echo "Setup complete!"
