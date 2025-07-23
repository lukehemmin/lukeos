# 🚀 LukeOS

**A Modern, User-Friendly Linux Distribution Based on Debian**

LukeOS is a custom Linux distribution built from the ground up with focus on simplicity, reliability, and user experience. Built on Debian's stable foundation, it provides a streamlined installation process and modern system management tools.

## ✨ Features

### 🎯 **Installation Experience**
- **Multilingual Support**: Full English and Korean language support
- **Interactive TUI**: Beautiful text-based user interface with arrow key navigation
- **Smart Disk Detection**: Automatic detection of disk types (SATA, NVMe, USB) with warnings
- **Flexible Partitioning**: Full disk or manual partition configuration
- **Dual Boot Support**: UEFI + Legacy BIOS compatibility with automatic fallback

### 🔧 **System Features**
- **Debian Bookworm Base**: Built on stable Debian foundation
- **Live Environment**: Test before installation
- **Automatic Updates**: Built-in update system support
- **Network Ready**: NetworkManager with automatic DHCP configuration
- **Security First**: SSH enabled with key generation, sudo-enabled admin user

### 🛡️ **Advanced Validation**
- **Password Strength**: Real-time password strength assessment
- **Input Validation**: Comprehensive validation for usernames, hostnames, and partitions
- **Network Connectivity**: Automatic network detection with offline installation support
- **Error Recovery**: Robust error handling with safe cleanup procedures

## 📋 System Requirements

- **Minimum Disk Space**: 8GB
- **RAM**: 1GB minimum, 2GB recommended
- **Architecture**: x86_64 (64-bit)
- **Boot**: UEFI or Legacy BIOS

## 🛠️ Quick Start

### Prerequisites

Ensure you have the following packages installed on your Debian/Ubuntu system:

```bash
sudo apt update
sudo apt install -y debootstrap squashfs-tools xorriso isolinux \
                    syslinux-efi grub-pc-bin grub-efi-amd64-bin mtools
```

### Building the ISO

1. **Clone the repository**:
```bash
git clone https://github.com/lukehemmin/lukeos.git
cd lukeos
```

2. **Make scripts executable**:
```bash
chmod +x build-custom-iso-safe.sh
chmod +x install-to-disk.sh
```

3. **Build the ISO**:
```bash
./build-custom-iso-safe.sh
```

4. **Find your ISO**:
```bash
# The ISO will be created in:
./hemmins-os/Hemmins_OS-v1.0.iso
```

## 💿 Installation

### Creating Bootable Media

**For USB drives**:
```bash
# Replace /dev/sdX with your USB device
sudo dd if=./hemmins-os/Hemmins_OS-v1.0.iso of=/dev/sdX bs=4M status=progress
sync
```

**For VirtualBox/VMware**:
Simply mount the ISO file directly in your virtual machine settings.

### Installing LukeOS

1. **Boot from your media**
2. **Language Selection**: Choose between English and Korean
3. **Network Check**: Automatic connectivity verification
4. **Disk Selection**: Choose your target drive with smart detection
5. **Installation Type**: Full disk or manual partitioning
6. **User Setup**: Create your admin account with password strength validation
7. **System Configuration**: Set hostname and system preferences
8. **Installation**: Automated installation with real-time progress
9. **Completion**: Automatic reboot to your new LukeOS system

## 🏗️ Architecture

### Build System (`build-custom-iso-safe.sh`)

- **Debian Bootstrap**: Creates clean Debian Bookworm base system
- **Package Management**: Installs essential packages and tools
- **Localization**: Configures multilingual support
- **Auto-installer Integration**: Embeds installation system
- **Boot Configuration**: Sets up ISOLINUX and GRUB EFI
- **ISO Generation**: Creates hybrid ISO with dual boot support

### Installation System (`install-to-disk.sh`)

- **TUI Framework**: Modern text-based interface
- **Multilingual Engine**: Dynamic language switching
- **Validation System**: Comprehensive input checking
- **Partition Manager**: Intelligent disk partitioning
- **System Deployment**: Efficient file copying with progress
- **Boot Setup**: Automatic bootloader configuration
- **User Management**: Secure account creation

## 🔧 Customization

### Adding Software

Modify the `chroot_setup.sh` section in `build-custom-iso-safe.sh`:

```bash
# Add your packages here
apt install -y your-package-name
```

### Customizing Appearance

Edit the boot menu in `build-custom-iso-safe.sh`:

```bash
# ISOLINUX configuration
cat > image/isolinux/isolinux.cfg << 'EOF'
# Your custom boot menu here
EOF
```

### Language Support

Add new languages by extending the `TEXTS` array in `install-to-disk.sh`:

```bash
# Add new language
TEXTS[fr_welcome]="Bienvenue à LukeOS"
```

## 🐛 Troubleshooting

### Common Issues

**Build fails with "Package not found"**:
```bash
sudo apt update && sudo apt upgrade
```

**ISO won't boot**:
- Verify UEFI/Legacy BIOS settings
- Try recreating bootable media
- Check ISO integrity with `md5sum`

**Installation fails**:
- Ensure target disk has sufficient space (8GB+)
- Check network connectivity for package downloads
- Verify disk isn't mounted elsewhere

### Debug Mode

Enable verbose installation:
```bash
# During boot, select "Verbose" option for detailed logging
```

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Test thoroughly** on different hardware/VMs
5. **Submit a pull request**

### Development Guidelines

- Follow existing code style and comments
- Test on both UEFI and Legacy BIOS systems
- Ensure multilingual compatibility
- Add appropriate error handling
- Update documentation for new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Debian Project**: For providing the stable base system
- **Live-boot Project**: For live system functionality
- **ISOLINUX/GRUB**: For boot loader technologies
- **Open Source Community**: For inspiration and tools

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/lukehemmin/lukeos/issues)
- **Discussions**: [GitHub Discussions](https://github.com/lukehemmin/lukeos/discussions)
- **Email**: [ps040211@gmail.com]

## 🗺️ Roadmap

- [ ] Web-based management interface
- [ ] Package manager GUI
- [ ] Automated backup system
- [ ] Container support
- [ ] Additional language support
- [ ] ARM64 architecture support

---

<div align="center">

**Built with ❤️ by [Luke Hemmin](https://github.com/lukehemmin)**

*Creating accessible, powerful Linux distributions for everyone*

![Made with Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)
![Debian Based](https://img.shields.io/badge/Based%20on-Debian-red.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

</div>