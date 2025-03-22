#!/bin/bash

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

echo "Step 1: Detecting System Information..."
# Detect Linux Distribution
if command -v lsb_release >/dev/null 2>&1; then
  DISTRO=$(lsb_release -is)
elif [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
else
  echo "----------------------------------------------------------"
  echo "ERROR: Unable to detect Linux distribution. Exiting..."
  echo "----------------------------------------------------------"
  exit 1
fi
echo "Detected Distribution: $DISTRO"

# Ensure lspci is available
echo "Step 2: Checking for required tools..."
if ! command -v lspci >/dev/null 2>&1; then
  echo "pciutils package not found. Attempting to install..."
  case $DISTRO in
  "Ubuntu" | "Debian")
    apt update -y && apt install -y pciutils
    ;;
  "Arch" | "Manjaro")
    pacman -Syu --noconfirm pciutils
    ;;
  "Fedora")
    dnf update -y && dnf install -y pciutils
    ;;
  "OpenSUSE")
    zypper refresh && zypper install -y pciutils
    ;;
  *)
    echo "----------------------------------------------------------"
    echo "ERROR: Unsupported distribution. Please install pciutils manually."
    echo "----------------------------------------------------------"
    exit 1
    ;;
  esac
fi

echo "Step 3: Detecting GPU..."
# Detect GPU
if lspci | grep -i nvidia >/dev/null 2>&1; then
  GPU="NVIDIA"
elif lspci | grep -i amd >/dev/null 2>&1; then
  GPU="AMD"
elif lspci | grep -i "Intel Corporation" | grep -i "VGA" >/dev/null 2>&1; then
  GPU="Intel"
else
  GPU="VESA"
  echo "WARNING: GPU not detected. Defaulting to generic drivers."
fi
echo "Detected GPU: $GPU"

echo "=========================================================="
echo "                Installing Appropriate Drivers            "
echo "=========================================================="
case $DISTRO in
"Ubuntu" | "Debian")
  echo "Updating package lists..."
  apt update -y
  echo "Installing essential driver packages..."
  apt install -y mesa-utils libgl1-mesa-dri libgles2-mesa vulkan-tools
  if [ "$GPU" == "NVIDIA" ]; then
    echo "Installing NVIDIA drivers..."
    apt install -y nvidia-driver nvidia-utils
  elif [ "$GPU" == "AMD" ]; then
    echo "Installing AMD drivers..."
    apt install -y firmware-amd-graphics mesa-opencl-icd
  elif [ "$GPU" == "Intel" ]; then
    echo "Installing Intel drivers..."
    apt install -y xserver-xorg-video-intel
  fi
  ;;
"Arch" | "Manjaro")
  echo "Updating system packages..."
  pacman -Syu --noconfirm
  echo "Installing essential driver packages..."
  pacman -S --noconfirm mesa mesa-utils vulkan-tools
  if [ "$GPU" == "NVIDIA" ]; then
    echo "Installing NVIDIA drivers..."
    pacman -S --noconfirm nvidia nvidia-utils
  elif [ "$GPU" == "AMD" ]; then
    echo "Installing AMD drivers..."
    pacman -S --noconfirm xf86-video-amdgpu
  elif [ "$GPU" == "Intel" ]; then
    echo "Installing Intel drivers..."
    pacman -S --noconfirm xf86-video-intel
  fi
  ;;
"Fedora")
  echo "Updating system packages..."
  dnf update -y
  echo "Installing essential driver packages..."
  dnf install -y mesa-dri-drivers mesa-libGL
  if [ "$GPU" == "NVIDIA" ]; then
    echo "Installing NVIDIA drivers..."
    dnf install -y akmod-nvidia
  elif [ "$GPU" == "AMD" ]; then
    echo "Installing AMD drivers..."
    dnf install -y mesa-dri-drivers
  elif [ "$GPU" == "Intel" ]; then
    echo "Installing Intel drivers..."
    dnf install -y xorg-x11-drv-intel
  fi
  ;;
"OpenSUSE")
  echo "Refreshing repositories..."
  zypper refresh
  echo "Installing essential driver packages..."
  zypper install -y Mesa-dri Mesa-utils
  if [ "$GPU" == "NVIDIA" ]; then
    echo "Installing NVIDIA drivers..."
    zypper install -y x11-video-nvidiaG05
  elif [ "$GPU" == "AMD" ]; then
    echo "Installing AMD drivers..."
    zypper install -y Mesa-dri Mesa-utils
  elif [ "$GPU" == "Intel" ]; then
    echo "Installing Intel drivers..."
    zypper install -y xf86-video-intel
  fi
  ;;
*)
  echo "----------------------------------------------------------"
  echo "ERROR: Unsupported distribution. Install drivers manually."
  echo "----------------------------------------------------------"
  exit 1
  ;;
esac

echo "=========================================================="
echo "            Driver Installation Completed                 "
echo "=========================================================="
echo "Please reboot your system to apply the changes."