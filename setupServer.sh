#!/bin/bash
set -Eeuo pipefail

trap 'echo "Setup failed at line $LINENO." >&2' ERR

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

is_selected() {
	[[ " $SELECTIONS " == *"\"$1\""* ]]
}

has_apt_package_selection() {
	local package
	for package in docker cockpit ncdu htop git curl ranger nano micro restic rsync fish tmux wget fd-find zoxide; do
		is_selected "$package" && return 0
	done
	return 1
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
	"zoxide" "Smarter directory navigation (z)" "ON"
	"cockpit" "Web-based server management UI (includes pcp, network, packagekit)" "ON"
	"---CONFIGS---" "---(Select configurations to apply)---" "OFF"
	"fish_shell_change" "Set Fish as the default shell" "ON"
	"tmux_mouse" "Enable mouse support in Tmux" "ON"
	"docker_usermod" "Add user to the 'docker' group" "ON"
)

# ------------------------------------------------------------------------------
# DISPLAY TUI AND CAPTURE SELECTIONS
# ------------------------------------------------------------------------------

if ! SELECTIONS=$(dialog --title "Server Setup Configuration" \
	--checklist "Use Spacebar to select/deselect options. Press Enter when done." \
	28 85 20 \
	"${OPTIONS[@]}" \
	2>&1 >/dev/tty); then
	clear
	echo "User cancelled setup. No changes were made."
	exit 0
fi

clear
echo "Starting setup with selected options..."

# Array to hold summary of actions
SUMMARY=()

# ------------------------------------------------------------------------------
# EXECUTE SELECTED TASKS
# ------------------------------------------------------------------------------

# --- System Update ---
if is_selected system_update; then
	echo "Updating and upgrading system..."
	apt-get update
	apt-get upgrade -y
	SUMMARY+=("System updated and upgraded.")
else
	# Still run update if any packages are to be installed, but quietly
	if has_apt_package_selection; then
		apt-get update >/dev/null
	fi
fi

# --- Package Installation ---
PACKAGES_TO_INSTALL=()
# Special handling for cockpit
if is_selected cockpit; then
    PACKAGES_TO_INSTALL+=("cockpit" "cockpit-pcp" "cockpit-network" "cockpit-packagekit")
fi


while IFS= read -r ITEM; do
    # Skip separators and installers handled outside apt.
    if [[ "$ITEM" == *"---"* ]] || [[ "$ITEM" == "cockpit" ]] || [[ "$ITEM" == "fresh" ]]; then continue; fi
    # Add package to the list if it was selected
    if is_selected "$ITEM"; then
        PACKAGES_TO_INSTALL+=("$ITEM")
    fi
done < <(printf '%s\n' "${OPTIONS[@]}" | awk 'NR % 3 == 1')


# If docker was selected but is already installed, don't try to install it
if is_docker_installed && is_selected docker; then
	echo "Docker is already installed, skipping installation."
	for i in "${!PACKAGES_TO_INSTALL[@]}"; do
		[ "${PACKAGES_TO_INSTALL[i]}" = docker ] && unset 'PACKAGES_TO_INSTALL[i]'
	done
	PACKAGES_TO_INSTALL=("${PACKAGES_TO_INSTALL[@]}")
fi

# Install all selected packages at once
if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
	# Special handling for Docker installation
	if [[ "${PACKAGES_TO_INSTALL[*]}" =~ "docker" ]]; then
		echo "Installing Docker..."
		DOCKER_INSTALLER=$(mktemp)
		curl -fsSL https://get.docker.com -o "$DOCKER_INSTALLER"
		sh "$DOCKER_INSTALLER"
		rm -f "$DOCKER_INSTALLER"
		SUMMARY+=("Installed Docker.")
		# Remove docker from the list to not pass it to apt
		for i in "${!PACKAGES_TO_INSTALL[@]}"; do
			[ "${PACKAGES_TO_INSTALL[i]}" = docker ] && unset 'PACKAGES_TO_INSTALL[i]'
		done
		PACKAGES_TO_INSTALL=("${PACKAGES_TO_INSTALL[@]}")
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
if is_selected fresh; then
	if command -v fresh &>/dev/null; then
		echo "Fresh is already installed, skipping installation."
	else
		echo "Installing fresh..."
		curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh
        SUMMARY+=("Installed 'fresh' text editor.")
	fi
fi

# Change default shell to fish
if is_selected fish_shell_change; then
	if command -v fish &>/dev/null; then
		FISH_PATH=$(command -v fish)
		if [ "$(getent passwd "$REAL_USER" | cut -d: -f7)" = "$FISH_PATH" ]; then
			echo "Fish is already the default shell for '$REAL_USER'."
		else
			echo "Changing default shell to fish for user '$REAL_USER'..."
			chsh -s "$FISH_PATH" "$REAL_USER"
            SUMMARY+=("Set Fish as default shell for '$REAL_USER'.")
		fi
	else
		echo "Skipping shell change: 'fish' is not installed or wasn't selected."
	fi
fi

# Configure zoxide for Fish without replacing cd.
if is_selected zoxide && command -v zoxide &>/dev/null; then
	FISH_CONF_DIR="$(getent passwd "$REAL_USER" | cut -d: -f6)/.config/fish/conf.d"
	install -d -o "$REAL_USER" -g "$(id -gn "$REAL_USER")" "$FISH_CONF_DIR"
	printf '%s\n' 'zoxide init fish | source' >"$FISH_CONF_DIR/zoxide.fish"
	chown "$REAL_USER:$(id -gn "$REAL_USER")" "$FISH_CONF_DIR/zoxide.fish"
	SUMMARY+=("Configured zoxide for Fish (z command).")
fi

# Enable tmux mouse support
if is_selected tmux_mouse; then
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
if is_selected fd-find; then
    if command -v fdfind &>/dev/null; then
        echo "Creating 'fd' symlink for 'fdfind'..."
		if [ ! -e /usr/local/bin/fd ] && [ ! -L /usr/local/bin/fd ]; then
			ln -s "$(command -v fdfind)" /usr/local/bin/fd
            SUMMARY+=("Created 'fd' symlink for 'fdfind'.")
		elif [ "$(readlink -f /usr/local/bin/fd)" != "$(readlink -f "$(command -v fdfind)")" ]; then
			echo "Skipping fd symlink: /usr/local/bin/fd already points elsewhere." >&2
		fi
    fi
fi


# Add user to docker group
if is_selected docker_usermod; then
	if command -v docker &>/dev/null; then
		if id -nG "$REAL_USER" | tr ' ' '\n' | grep -qx docker; then
			echo "User '$REAL_USER' is already in the docker group."
		else
			echo "Adding user '$REAL_USER' to the docker group..."
			usermod -aG docker "$REAL_USER"
            SUMMARY+=("Added user '$REAL_USER' to the 'docker' group.")
		fi
	else
		echo "Skipping docker group modification: 'docker' is not installed or wasn't selected."
	fi
fi

# Enable cockpit service if cockpit was installed
if is_selected cockpit; then
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
