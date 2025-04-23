#!/bin/bash

# Exit on error and undefined variables
set -euo pipefail

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "----------------------------------------------------------"
  echo "ERROR: Please run as root (e.g., sudo $0)"
  echo "----------------------------------------------------------"
  exit 1
fi

echo "=========================================================="
echo "                System Driver Installation                "
echo "=========================================================="

# Function for consistent error handling
handle_error() {
  echo "----------------------------------------------------------"
  echo "ERROR: $1"
  echo "----------------------------------------------------------"
  exit 1
}

echo "Step 1: Detecting System Information..."
# Detect Linux Distribution
if command -v lsb_release >/dev/null 2>&1; then
  DISTRO=$(lsb_release -is)
elif [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
else
  handle_error "Unable to detect Linux distribution"
fi
echo "Detected Distribution: $DISTRO"

echo "Step 2: Checking for required tools..."
# Install pciutils if missing
install_pciutils() {
  case $DISTRO in
  "Ubuntu" | "Debian") apt update -y && apt install -y pciutils ;;
  "Arch" | "Manjaro") pacman -Syu --noconfirm pciutils ;;
  "Fedora") dnf update -y && dnf install -y pciutils ;;
  "OpenSUSE") zypper refresh && zypper install -y pciutils ;;
  *) handle_error "Unsupported distribution for pciutils install" ;;
  esac
}

if ! command -v lspci >/dev/null 2>&1; then
  echo "pciutils package not found. Attempting to install..."
  install_pciutils || handle_error "Failed to install pciutils"
fi

echo "Step 3: Detecting GPU..."
GPU_DETECTED=""
if lspci | grep -qi "nvidia"; then
  GPU_DETECTED="NVIDIA"
elif lspci | grep -qi "amd"; then
  GPU_DETECTED="AMD"
elif lspci | grep -qi "intel.*vga"; then
  GPU_DETECTED="Intel"
else
  GPU_DETECTED="Generic"
  echo "WARNING: Specific GPU not detected, using generic drivers"
fi
echo "Detected GPU: $GPU_DETECTED"

echo "=========================================================="
echo "                Installing Appropriate Drivers            "
echo "=========================================================="

# Common driver packages
install_common() {
  case $DISTRO in
  "Ubuntu" | "Debian")
    apt install -y mesa-utils libgl1-mesa-dri libgles2-mesa mesa-vulkan-drivers vulkan-tools
    ;;
  "Arch" | "Manjaro")
    pacman -S --noconfirm mesa mesa-utils vulkan-tools vulkan-icd-loader
    ;;
  "Fedora")
    dnf install -y mesa-dri-drivers mesa-libGL mesa-vulkan-drivers
    ;;
  "OpenSUSE")
    zypper install -y Mesa-dri Mesa-utils vulkan-tools
    ;;
  esac
}

# GPU-specific installation
case $DISTRO in
"Ubuntu" | "Debian")
  apt update -y || handle_error "Failed to update packages"
  install_common
  case $GPU_DETECTED in
  "NVIDIA")
    echo "Installing NVIDIA drivers..."
    apt install -y nvidia-driver nvidia-utils nvidia-vulkan-common
    ;;
  "AMD")
    echo "Installing AMD drivers..."
    apt install -y firmware-amd-graphics mesa-opencl-icd
    ;;
  "Intel")
    echo "Intel integrated graphics detected (using default Mesa drivers)"
    ;;
  esac
  ;;

"Arch" | "Manjaro")
  pacman -Syu --noconfirm || handle_error "Failed to update packages"
  install_common
  case $GPU_DETECTED in
  "NVIDIA")
    echo "Installing NVIDIA drivers..."
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
    ;;
  "AMD")
    echo "Installing AMD drivers..."
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon
    ;;
  "Intel")
    echo "Installing Intel drivers..."
    pacman -S --noconfirm vulkan-intel
    ;;
  esac
  ;;

"Fedora")
  dnf update -y || handle_error "Failed to update packages"
  install_common
  case $GPU_DETECTED in
  "NVIDIA")
    echo "Checking for RPM Fusion..."
    if ! dnf repolist | grep -q rpmfusion; then
      handle_error "RPM Fusion required for NVIDIA drivers. See: https://rpmfusion.org/Configuration"
    fi
    echo "Installing NVIDIA drivers..."
    dnf install -y akmod-nvidia nvidia-vulkan-common
    ;;
  "AMD")
    echo "Installing AMD drivers..."
    dnf install -y mesa-va-drivers mesa-vdpau-drivers
    ;;
  "Intel")
    echo "Installing Intel drivers..."
    dnf install -y intel-media-driver
    ;;
  esac
  ;;

"OpenSUSE")
  zypper refresh || handle_error "Failed to refresh repositories"
  install_common
  case $GPU_DETECTED in
  "NVIDIA")
    echo "Adding NVIDIA repository..."
    zypper --non-interactive addrepo -f https://download.nvidia.com/opensuse/tumbleweed NVIDIA
    zypper --gpg-auto-import-keys refresh
    echo "Installing NVIDIA drivers..."
    zypper install -y nvidia-video-G05 nvidia-vulkan-common
    ;;
  "AMD")
    echo "Installing AMD drivers..."
    zypper install -y Mesa-dri Mesa-utils vulkan-radeon
    ;;
  "Intel")
    echo "Installing Intel drivers..."
    zypper install -y vulkan-intel
    ;;
  esac
  ;;

*)
  handle_error "Unsupported distribution: $DISTRO"
  ;;
esac

echo "=========================================================="
echo "            Driver Installation Completed                 "
echo "=========================================================="
echo -e "\nPost-installation notes:"
[ "$GPU_DETECTED" = "NVIDIA" ] && echo "* NVIDIA: Check Secure Boot configuration if enabled"
[ "$GPU_DETECTED" = "Intel" ] && echo "* Intel: Hardware video acceleration may require additional configuration"
echo -e "\nPlease reboot your system to apply changes\n"

