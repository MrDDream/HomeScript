#!/bin/bash

# Check if the user is root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root or with sudo." # User message in English
  exit 1
fi

# --- New Interactive Dependency Check ---
echo "Checking for required basic dependencies..." # User message in English

required_packages=("sudo" "curl" "lsb-release" "gnupg" "ca-certificates")
missing_packages=()
packages_to_check_cmds=("sudo" "curl" "lsb_release" "gpg") # Corresponding commands to check
package_map_cmds=("sudo" "curl" "lsb-release" "gnupg") # Packages for those commands

# Check command-based packages
for i in "${!packages_to_check_cmds[@]}"; do
    cmd="${packages_to_check_cmds[$i]}"
    pkg="${package_map_cmds[$i]}"
    if ! command -v "$cmd" &> /dev/null; then
        # Double check with dpkg if command -v fails, as dpkg is more definitive for package status
        if ! dpkg -s "$pkg" &> /dev/null; then
            if [[ ! " ${missing_packages[*]} " =~ " ${pkg} " ]]; then # Avoid duplicates
                missing_packages+=("$pkg")
            fi
        fi
    fi
done

# Specifically check ca-certificates using dpkg as it doesn't have a simple command to check
if ! dpkg -s "ca-certificates" &> /dev/null; then
    if [[ ! " ${missing_packages[*]} " =~ " ca-certificates " ]]; then # Avoid duplicates
         missing_packages+=("ca-certificates")
    fi
fi


if [ ${#missing_packages[@]} -gt 0 ]; then
    echo ""
    echo "The following required packages are missing or not fully configured:" # User message in English
    for pkg_name in "${missing_packages[@]}"; do
        echo "  - $pkg_name"
    done
    echo ""
    read -r -p "Do you want to attempt to install them now? (yes/no): " user_consent # Prompt in English

    if [[ "$user_consent" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then # Accept 'yes', 'y'
        echo "Updating package lists..." # User message in English
        apt-get update
        echo "Installing missing packages: ${missing_packages[*]}" # User message in English
        if apt-get install -y "${missing_packages[@]}"; then
            echo "Dependencies installed successfully." # User message in English
        else
            echo "Failed to install some dependencies. Please install them manually and try again." # User message in English
            exit 1
        fi
    else
        echo "Installation of dependencies declined. These packages are required to continue. Exiting." # User message in English
        exit 1
    fi
else
    echo "All required basic dependencies are already installed." # User message in English
fi
echo "---------------------------------------------------------------------"
# --- End of New Interactive Dependency Check ---


# Define a variable to run commands with sudo if the user is not root
# If the user IS root, sudo is omitted.
SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
  # This should not happen because we check at the beginning, but as a safeguard:
  if ! command -v sudo &> /dev/null; then # Check if sudo command itself is available
    echo "ERROR: sudo is required but not found, and the script is not run as root."
    exit 1
  fi
  SUDO_CMD="sudo"
fi

# Update packages and install necessary dependencies to add repositories
echo "updating packages (again, to be sure after any potential installs)..."
$SUDO_CMD apt-get update
echo "installing main dependencies for Docker (if not already present from previous step)..."
$SUDO_CMD apt-get install -y \
    ca-certificates \
    gnupg # curl and lsb-release should have been covered by the interactive check

# Add Docker's official GPG key for Debian
echo "adding Docker's GPG key for Debian..."
$SUDO_CMD install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO_CMD gpg --dearmor -o /etc/apt/keyrings/docker.gpg
$SUDO_CMD chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker's repository for Debian
echo "setting up Docker's repository for Debian..."
# Using $(lsb_release -cs) to get the Debian version codename (e.g., bookworm, bullseye)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null

# Display the content of the repository file for verification
echo "Content of /etc/apt/sources.list.d/docker.list:"
$SUDO_CMD cat /etc/apt/sources.list.d/docker.list

# Update the package list after adding the new repository
echo "updating package list after adding Docker repository..."
$SUDO_CMD apt-get update

# Install Docker Engine
echo "installing Docker Engine..."
# Note the exact packages recommended by Docker
$SUDO_CMD apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Verify Docker installation
echo "verifying Docker installation..."
if $SUDO_CMD docker run hello-world; then
    echo "Docker installed successfully."
else
    echo "Error during Docker installation. Please check the messages above."
    echo "Check the output of 'apt-get update' and ensure the Docker repository was added correctly and without errors."
    exit 1
fi

# Install Docker Compose (latest version)
echo "installing the latest version of Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$DOCKER_COMPOSE_VERSION" ]; then
    echo "Could not fetch the latest Docker Compose version. Installing v2.27.0 by default." # You might want to update this default periodically
    DOCKER_COMPOSE_VERSION="v2.27.0" # Fallback version
fi
echo "Installing Docker Compose version $DOCKER_COMPOSE_VERSION"

$SUDO_CMD mkdir -p /usr/local/bin # Ensure the directory exists
$SUDO_CMD curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
$SUDO_CMD chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose installation
echo "verifying Docker Compose installation..."
# Docker Compose can be a plugin 'docker compose' or a standalone binary 'docker-compose'
if $SUDO_CMD docker compose version >/dev/null 2>&1; then
    echo "Docker Compose (plugin) installed and functional."
    echo $($SUDO_CMD docker compose version)
elif docker-compose --version >/dev/null 2>&1; then
    echo "Docker Compose (standalone binary) installed successfully."
    docker-compose --version
else
    echo "Error: Docker Compose could not be verified."
    echo "Attempting to install the docker-compose plugin via apt..."
    $SUDO_CMD apt-get install -y docker-compose-plugin
    if $SUDO_CMD docker compose version >/dev/null 2>&1; then
        echo "Docker Compose (plugin) successfully installed via apt."
        echo $($SUDO_CMD docker compose version)
    else
        echo "Failed to install Docker Compose via the apt plugin."
        # No 'exit 1' here to allow Portainer to try to install anyway
    fi
fi

# Create a volume for Portainer persistent data
echo "creating Portainer volume..."
$SUDO_CMD docker volume create portainer_data

# Install and start Portainer CE
echo "installing and starting Portainer CE..."
$SUDO_CMD docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

echo ""
echo "---------------------------------------------------------------------"
echo "Installation finished!"
echo "Portainer CE should be accessible at https://<YOUR_SERVER_IP_ADDRESS>:9443"
echo "or https://localhost:9443 if running locally."
# Attempt to retrieve the local IP to display it
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -n "$LOCAL_IP" ]; then
  echo "Try: https://${LOCAL_IP}:9443"
fi
echo "On first access, Portainer will ask you to create an administrator account."
echo "---------------------------------------------------------------------"