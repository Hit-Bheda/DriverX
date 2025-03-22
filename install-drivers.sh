#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

echo "==== Detecting System Information ===="

# Detect Linux Distribution
if command -v lsb_release >/dev/null 2>&1; then
  DISTRO=$(lsb_release -is)
elif [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
else
  echo "Unknown Linux distribution. Exiting..."
  exit 1
fi
echo "Detected Distribution: $DISTRO"

# Detect GPU
if lspci | grep -i nvidia >/dev/null 2>&1; then
  GPU="NVIDIA"
elif lspci | grep -i amd >/dev/null 2>&1; then
  GPU="AMD"
elif lspci | grep -i "Intel Corporation" | grep -i "VGA" >/dev/null 2>&1; then
  GPU="Intel"
else
  echo "GPU not detected. Installing generic drivers."
  GPU="VESA"
fi
echo "Detected GPU: $GPU"

# Install Drivers Based on GPU and Distribution
echo "==== Installing Drivers ===="

case $DISTRO in
"Ubuntu" | "Debian")
  apt update -y
  apt install -y \
    mesa-utils libgl1-mesa-dri libgl1-mesa-glx libglx-mesa0 libgles2-mesa \
    opencl-icd vesa xserver-xorg-video-vesa \
    vulkan-tools mesa-vulkan-drivers

  if [ "$GPU" == "NVIDIA" ]; then
    apt install -y nvidia-driver nvidia-utils nvidia-opencl-icd vulkan-utils
  elif [ "$GPU" == "AMD" ]; then
    apt install -y firmware-amd-graphics mesa-opencl-icd xserver-xorg-video-amdgpu vulkan-utils
  elif [ "$GPU" == "Intel" ]; then
    apt install -y xserver-xorg-video-intel intel-opencl-icd mesa-vulkan-drivers
  fi
  ;;
"Arch" | "Manjaro")
  pacman -Syu --noconfirm
  pacman -S --noconfirm \
    mesa mesa-utils lib32-mesa lib32-mesa-utils opencl-mesa xf86-video-vesa \
    vulkan-tools vulkan-mesa-layers lib32-vulkan-mesa-layers

  if [ "$GPU" == "NVIDIA" ]; then
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings opencl-nvidia vulkan-icd-loader
  elif [ "$GPU" == "AMD" ]; then
    pacman -S --noconfirm mesa xf86-video-amdgpu opencl-mesa vulkan-radeon lib32-vulkan-radeon
  elif [ "$GPU" == "Intel" ]; then
    pacman -S --noconfirm mesa xf86-video-intel opencl-mesa vulkan-intel lib32-vulkan-intel
  fi
  ;;
"Fedora")
  dnf update -y
  dnf install -y \
    mesa-dri-drivers mesa-libGL mesa-libEGL mesa-libGLU xorg-x11-drv-vesa \
    vulkan vulkan-tools mesa-vulkan-drivers

  if [ "$GPU" == "NVIDIA" ]; then
    dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia opencl-nvidia vulkan
  elif [ "$GPU" == "AMD" ]; then
    dnf install -y mesa-dri-drivers xorg-x11-drv-amdgpu opencl-mesa vulkan-radeon
  elif [ "$GPU" == "Intel" ]; then
    dnf install -y xorg-x11-drv-intel opencl-mesa vulkan-intel
  fi
  ;;
"OpenSUSE")
  zypper refresh
  zypper install -y \
    Mesa-dri Mesa-utils xorg-x11-driver-vesa \
    vulkan-tools Mesa-vulkan-drivers

  if [ "$GPU" == "NVIDIA" ]; then
    zypper install -y nvidia-gfxG05-kmp-default vulkan-nvidia
  elif [ "$GPU" == "AMD" ]; then
    zypper install -y Mesa-dri Mesa-utils xorg-x11-driver-video-amdgpu vulkan-radeon
  elif [ "$GPU" == "Intel" ]; then
    zypper install -y xf86-video-intel Mesa-libGL1 vulkan-intel
  fi
  ;;
*)
  echo "Unsupported distribution. Install drivers manually."
  exit 1
  ;;
esac

echo "==== Driver Installation Completed ===="
echo "Reboot your system for changes to take effect."
