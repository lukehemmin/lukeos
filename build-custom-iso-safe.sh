#!/bin/bash

# Hemmins OS ISO Builder - Safe Version
# 더 안전하고 에러 처리가 강화된 버전

set -e  # 에러 발생 시 스크립트 중단

WORK_DIR="$(pwd)/hemmins-os"
OS_NAME="Hemmins_OS"
VERSION="1.0"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 에러 처리 함수
cleanup_on_error() {
    log_error "스크립트 실행 중 에러가 발생했습니다!"
    
    # 강제 종료
    sudo fuser -km "$WORK_DIR/chroot" 2>/dev/null || true
    sleep 2
    
    # chroot 마운트 해제 (에러 무시)
    sudo umount "$WORK_DIR/chroot/dev/pts" 2>/dev/null || true
    sudo umount "$WORK_DIR/chroot/dev" 2>/dev/null || true
    sudo umount "$WORK_DIR/chroot/proc" 2>/dev/null || true
    sudo umount "$WORK_DIR/chroot/sys" 2>/dev/null || true
    
    exit 1
}

# 에러 발생 시 cleanup 함수 호출
trap cleanup_on_error ERR

echo "=== Hemmins OS ISO Builder (Safe Version) ==="
log_info "작업 디렉토리: $WORK_DIR"

# 1. 작업 환경 준비
log_info "[1/13] 작업 환경 준비 중..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{chroot,image/{live,isolinux,boot/grub}}
cd "$WORK_DIR"

# 2. 필요한 패키지 확인 및 설치
log_info "[2/13] 필요한 도구들 설치 확인..."
REQUIRED_PACKAGES="debootstrap squashfs-tools xorriso isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin mtools"

for package in $REQUIRED_PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        log_warning "필요한 패키지 설치 중: $package"
        sudo apt update && sudo apt install -y $package
    fi
done

# 3. 기본 데비안 시스템 생성
log_info "[3/13] 기본 데비안 시스템 생성 중..."
sudo debootstrap --arch=amd64 bookworm chroot http://deb.debian.org/debian/

# 4. chroot 환경 마운트
log_info "[4/13] chroot 환경 설정 중..."
sudo mount --bind /dev chroot/dev
sudo mount --bind /dev/pts chroot/dev/pts
sudo mount --bind /proc chroot/proc
sudo mount --bind /sys chroot/sys

# 5. chroot 스크립트를 별도 파일로 생성
log_info "[5/13] chroot 설정 스크립트 생성 중..."
cat > chroot_setup.sh << 'EOF'
#!/bin/bash

# chroot 환경에서 실행될 스크립트
set -e

# 환경 변수 설정
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 기본 설정
echo "hemmins-os" > /etc/hostname
echo "127.0.0.1 localhost hemmins-os" > /etc/hosts

# 패키지 소스 설정
cat > /etc/apt/sources.list << 'SOURCES_EOF'
deb http://deb.debian.org/debian bookworm main
deb-src http://deb.debian.org/debian bookworm main
deb http://deb.debian.org/debian-security/ bookworm-security main
deb-src http://deb.debian.org/debian-security/ bookworm-security main
deb http://deb.debian.org/debian bookworm-updates main
deb-src http://deb.debian.org/debian bookworm-updates main
SOURCES_EOF

echo "패키지 업데이트 중..."
apt update

echo "커널 및 필수 패키지 설치 중..."
apt install -y linux-image-amd64 linux-headers-amd64
apt install -y live-boot live-boot-initramfs-tools initramfs-tools
apt install -y systemd-sysv network-manager openssh-server
apt install -y sudo curl wget htop nano vim net-tools
apt install -y locales console-setup keyboard-configuration

# 한글 폰트 및 언어 패키지 추가 (Debian용)
echo "한글 지원 패키지 설치 중..."
apt install -y fonts-nanum fonts-nanum-coding fonts-nanum-extra
apt install -y fonts-unfonts-core fonts-baekmuk
# language-pack-ko 제거 (Debian에 없음)
# apt install -y language-pack-ko language-pack-ko-base
apt install -y fcitx5 fcitx5-hangul fcitx5-config-qt

echo "설치에 필요한 패키지들 설치 중..."
# 설치에 필요한 패키지들
apt install -y parted rsync grub-efi-amd64 grub2-common

echo "로케일 설정 중..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 콘솔 폰트 설정 추가
echo "강화된 콘솔 한글 지원 설정 중..."
apt install -y console-data
echo 'CHARMAP="UTF-8"' >> /etc/default/console-setup
echo 'CODESET="Uni2"' >> /etc/default/console-setup
echo 'FONTFACE="Terminus"' >> /etc/default/console-setup
echo 'FONTSIZE="16"' >> /etc/default/console-setup

# 환경 변수 설정
echo 'export LANG=en_US.UTF-8' >> /etc/environment
echo 'export LC_ALL=en_US.UTF-8' >> /etc/environment

echo "기본 사용자 계정 설정 중..."
# root 사용자 비밀번호 설정
echo "root:root123" | chpasswd

# 임시 사용자 생성 (설치 후 제거됨)
useradd -m -s /bin/bash installer
echo "installer:installer" | chpasswd
usermod -aG sudo installer

# installer 사용자에게 passwordless sudo 권한 부여
echo "installer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/installer
chmod 440 /etc/sudoers.d/installer

echo "서비스 설정 중..."
systemctl enable ssh
systemctl enable NetworkManager

echo "자동 설치 프로그램 실행 설정 중..."
# 설치 프로그램이 자동으로 실행되도록 설정
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << 'GETTY_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin installer --noclear %I $TERM
GETTY_EOF

# installer 사용자의 .bashrc에 설치 프로그램 자동 실행 추가
cat >> /home/installer/.bashrc << 'BASHRC_EOF'

# Hemmins OS 설치 프로그램 자동 시작
if [[ -f /usr/local/bin/install-to-disk.sh ]] && [[ -z "$INSTALLER_STARTED" ]]; then
    export INSTALLER_STARTED=1
    sudo /usr/local/bin/install-to-disk.sh
fi
BASHRC_EOF

echo "initramfs 업데이트 중..."
update-initramfs -u

echo "시스템 정리 중..."
apt autoremove -y
apt clean

echo "chroot 환경 설정 완료!"
EOF

# 6. chroot 스크립트 실행
log_info "[6/13] chroot 환경에서 시스템 구성 중..."
chmod +x chroot_setup.sh
sudo cp chroot_setup.sh chroot/
sudo chroot chroot /chroot_setup.sh

# chroot 스크립트 정리
sudo rm -f chroot/chroot_setup.sh
rm -f chroot_setup.sh

# 6.5. 설치 스크립트 추가
log_info "[6.5/13] 설치 스크립트 추가 중..."

# 설치 스크립트 존재 여부 및 내용 확인
if [[ ! -f "../install-to-disk.sh" ]]; then
    log_error "install-to-disk.sh 파일을 찾을 수 없습니다!"
    log_error "상위 디렉토리에 install-to-disk.sh 파일이 있어야 합니다."
    exit 1
fi

# 스크립트 유효성 검사
if ! bash -n ../install-to-disk.sh; then
    log_error "install-to-disk.sh에 문법 오류가 있습니다!"
    exit 1
fi

# 필수 함수들이 있는지 확인
if ! grep -q "perform_installation" ../install-to-disk.sh; then
    log_error "install-to-disk.sh가 올바른 설치 스크립트가 아닙니다!"
    exit 1
fi

log_success "설치 스크립트 검증 완료"

# 설치 스크립트를 시스템에 복사
sudo cp ../install-to-disk.sh chroot/usr/local/bin/
sudo chmod +x chroot/usr/local/bin/install-to-disk.sh

# installer 사용자 홈에도 복사 (백업용)
sudo cp ../install-to-disk.sh chroot/home/installer/
sudo chown 1001:1001 chroot/home/installer/install-to-disk.sh
sudo chmod +x chroot/home/installer/install-to-disk.sh

# 디스크 공간 확인
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
if [[ $AVAILABLE_SPACE -lt 2000000 ]]; then  # 2GB
    log_warning "디스크 공간이 부족할 수 있습니다 (여유공간: $((AVAILABLE_SPACE/1024))MB)"
    read -p "계속하시겠습니까? (y/n): " confirm
    [[ "$confirm" != "y" ]] && exit 1
fi

# 7. chroot 환경 마운트 해제 - 안전한 버전
log_info "[7/13] chroot 환경 정리 중..."

# 더 안전한 프로세스 정리 (SSH 연결 보호)
sudo lsof +D chroot 2>/dev/null | awk 'NR>1 {print $2}' | sort -u | while read pid; do
    if [[ -n "$pid" ]] && [[ "$pid" != "$$" ]]; then
        sudo kill -TERM "$pid" 2>/dev/null || true
    fi
done
sleep 2

# 안전한 마운트 해제
sudo umount chroot/dev/pts 2>/dev/null || true
sudo umount chroot/dev 2>/dev/null || true

# proc과 sys는 여러 번 시도 (fuser -k 대신 lazy umount 사용)
for i in {1..3}; do
    if sudo umount chroot/proc 2>/dev/null; then
        break
    fi
    echo "proc 마운트 해제 재시도 중... ($i/3)"
    sleep 1
    # 마지막 시도에서는 lazy umount 사용
    if [[ $i -eq 3 ]]; then
        sudo umount -l chroot/proc 2>/dev/null || true
    fi
done

for i in {1..3}; do
    if sudo umount chroot/sys 2>/dev/null; then
        break
    fi
    echo "sys 마운트 해제 재시도 중... ($i/3)"
    sleep 1
    if [[ $i -eq 3 ]]; then
        sudo umount -l chroot/sys 2>/dev/null || true
    fi
done

# 8. 커널과 initrd 복사
log_info "[8/13] 부트 파일 복사 중..."
if ! ls chroot/boot/vmlinuz-* 1> /dev/null 2>&1; then
    log_error "커널 파일을 찾을 수 없습니다!"
    exit 1
fi

sudo cp chroot/boot/vmlinuz-* image/live/vmlinuz
sudo cp chroot/boot/initrd.img-* image/live/initrd

log_success "커널 파일 복사 완료"
ls -la image/live/

# 9. SquashFS 생성
log_info "[9/13] SquashFS 생성 중..."
sudo mksquashfs chroot image/live/filesystem.squashfs -e boot -comp xz

# 10. 부트로더 설정
log_info "[10/13] 부트로더 설정 중..."

# ISOLINUX 파일 복사
cp /usr/lib/ISOLINUX/isolinux.bin image/isolinux/
cp /usr/lib/syslinux/modules/bios/*.c32 image/isolinux/

# ISOLINUX 설정 파일 생성
cat > image/isolinux/isolinux.cfg << 'ISOLINUX_EOF'
UI menu.c32

prompt 0
menu title Hemmins OS v1.0

timeout 300

label live
    menu label ^Start Hemmins OS
    menu default
    kernel /live/vmlinuz
    append initrd=/live/initrd boot=live quiet splash

label live-verbose
    menu label Start Hemmins OS (^Verbose)
    kernel /live/vmlinuz
    append initrd=/live/initrd boot=live debug systemd.log_level=debug

label live-failsafe
    menu label Start Hemmins OS (^Safe Mode)
    kernel /live/vmlinuz
    append initrd=/live/initrd boot=live config memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal
ISOLINUX_EOF

# GRUB EFI 설정
cat > image/boot/grub/grub.cfg << 'GRUB_EOF'
set default="0"
set timeout=10

menuentry "Hemmins OS v1.0" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}

menuentry "Hemmins OS (Verbose)" {
    linux /live/vmlinuz boot=live debug systemd.log_level=debug
    initrd /live/initrd
}

menuentry "Hemmins OS (Safe Mode)" {
    linux /live/vmlinuz boot=live config memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal
    initrd /live/initrd
}
GRUB_EOF

# 11. EFI 이미지 생성
log_info "[11/13] EFI 부트 이미지 생성 중..."
dd if=/dev/zero of=image/boot/grub/efi.img bs=1M count=10 2>/dev/null
sudo mkfs.fat image/boot/grub/efi.img >/dev/null 2>&1

sudo mkdir -p /tmp/efi-mount
sudo mount -o loop image/boot/grub/efi.img /tmp/efi-mount
sudo mkdir -p /tmp/efi-mount/EFI/BOOT

# GRUB EFI 생성 (에러 처리 추가)
if ! sudo grub-mkstandalone \
    --format=x86_64-efi \
    --output=/tmp/efi-mount/EFI/BOOT/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=image/boot/grub/grub.cfg" >/dev/null 2>&1; then
    
    log_warning "GRUB EFI 생성 실패, Legacy BIOS만 지원됩니다"
    sudo umount /tmp/efi-mount
    sudo rmdir /tmp/efi-mount
    rm -f image/boot/grub/efi.img
    EFI_SUPPORT=false
else
    sudo umount /tmp/efi-mount
    sudo rmdir /tmp/efi-mount
    EFI_SUPPORT=true
    log_success "EFI 지원 활성화됨"
fi

# 12. ISO 이미지 생성
log_info "[12/13] ISO 이미지 생성 중..."
OUTPUT_ISO="$OS_NAME-v$VERSION.iso"

# EFI 지원 여부에 따라 다른 xorriso 명령 사용
if [[ "$EFI_SUPPORT" == "true" ]]; then
    log_info "하이브리드 ISO 생성 중 (Legacy + UEFI)"
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "${OS_NAME}_${VERSION}" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -append_partition 2 0xef image/boot/grub/efi.img \
        -output "$OUTPUT_ISO" \
        image/ >/dev/null 2>&1
else
    log_info "Legacy BIOS 전용 ISO 생성 중"
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "${OS_NAME}_${VERSION}" \
        -eltorito-boot isolinux/isolinux.bin \
        -eltorito-catalog isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -output "$OUTPUT_ISO" \
        image/ >/dev/null 2>&1
fi

echo ""
log_success "=== 빌드 완료! ==="
echo "ISO 파일 위치: $WORK_DIR/$OUTPUT_ISO"
echo "파일 크기: $(du -h "$OUTPUT_ISO" | cut -f1)"
echo ""
echo "기본 정보:"
echo "  OS 이름: Hemmins OS v$VERSION"
echo "  부트 지원: $([ "$EFI_SUPPORT" == "true" ] && echo "Legacy BIOS + UEFI" || echo "Legacy BIOS만")"
echo "  자동 설치 프로그램: 부팅 시 자동 실행"
echo "  임시 계정: installer/installer"
echo ""
echo "테스트 방법:"
echo "1. VirtualBox나 VMware에서 ISO 파일로 부팅"
echo "2. $([ "$EFI_SUPPORT" == "true" ] && echo "Legacy BIOS와 UEFI 모두 지원" || echo "Legacy BIOS 지원")"
echo "3. 부팅 후 자동으로 설치 프로그램이 실행됩니다"
echo "4. 언어 선택 후 설치를 진행하세요"
echo ""
if [[ "$EFI_SUPPORT" != "true" ]]; then
    log_warning "주의: UEFI 지원이 비활성화되었습니다"
    echo "  대부분의 시스템에서는 문제없이 작동하지만,"
    echo "  최신 UEFI 전용 시스템에서는 부팅이 안될 수 있습니다."
fi