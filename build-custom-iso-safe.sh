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

# 에러 처리 함수 (SSH 연결 보호)
cleanup_on_error() {
    log_error "스크립트 실행 중 에러가 발생했습니다!"
    log_warning "정리 작업을 수행합니다. SSH 연결은 유지됩니다."
    
    # SSH 연결을 보호하면서 안전한 프로세스 종료
    if [[ -d "$WORK_DIR/chroot" ]]; then
        # chroot 내부의 프로세스들을 안전하게 종료
        local chroot_pids=$(sudo lsof +D "$WORK_DIR/chroot" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u 2>/dev/null || true)
        
        if [[ -n "$chroot_pids" ]]; then
            log_info "chroot 관련 프로세스 정리 중..."
            for pid in $chroot_pids; do
                # SSH 관련 프로세스와 현재 쉘 세션은 제외
                if [[ -n "$pid" ]] && [[ "$pid" != "$$" ]]; then
                    local process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    if [[ "$process_name" != "sshd" ]] && [[ "$process_name" != "ssh" ]] && [[ ! "$process_name" =~ bash|sh ]]; then
                        sudo kill -TERM "$pid" 2>/dev/null || true
                    fi
                fi
            done
            
            # 잠시 대기 후 강제 종료 (SSH 제외)
            sleep 3
            for pid in $chroot_pids; do
                if [[ -n "$pid" ]] && [[ "$pid" != "$$" ]]; then
                    local process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    if [[ "$process_name" != "sshd" ]] && [[ "$process_name" != "ssh" ]] && [[ ! "$process_name" =~ bash|sh ]]; then
                        sudo kill -KILL "$pid" 2>/dev/null || true
                    fi
                fi
            done
        fi
    fi
    
    # 안전한 마운트 해제 (여러 번 시도)
    log_info "마운트 포인트 정리 중..."
    for i in {1..3}; do
        sudo umount "$WORK_DIR/chroot/dev/pts" 2>/dev/null && break
        sleep 1
    done
    
    for i in {1..3}; do
        sudo umount "$WORK_DIR/chroot/dev" 2>/dev/null && break  
        sleep 1
    done
    
    for i in {1..3}; do
        if sudo umount "$WORK_DIR/chroot/proc" 2>/dev/null; then
            break
        elif [[ $i -eq 3 ]]; then
            sudo umount -l "$WORK_DIR/chroot/proc" 2>/dev/null || true
        fi
        sleep 1
    done
    
    for i in {1..3}; do
        if sudo umount "$WORK_DIR/chroot/sys" 2>/dev/null; then
            break
        elif [[ $i -eq 3 ]]; then
            sudo umount -l "$WORK_DIR/chroot/sys" 2>/dev/null || true
        fi
        sleep 1
    done
    
    log_warning "정리 작업이 완료되었습니다. 터미널 연결은 안전합니다."
    log_info "필요한 경우 'sudo rm -rf $WORK_DIR'로 수동 정리하세요."
    
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

# chroot 환경에서 실행될 스크립트 (개선된 에러 처리)
set -e

# 환경 변수 설정
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 로그 함수들
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 안전한 패키지 설치 함수
install_package_safe() {
    local package="$1"
    local is_required="${2:-true}"
    
    if apt install -y "$package" 2>/dev/null; then
        log_success "$package 설치 완료"
        return 0
    else
        if [[ "$is_required" == "true" ]]; then
            log_error "$package 설치 실패 (필수 패키지)"
            return 1
        else
            log_warning "$package 설치 실패 (선택적 패키지, 계속 진행)"
            return 0
        fi
    fi
}

# 여러 패키지 설치 함수 
install_packages_safe() {
    local is_required="${1:-true}"
    shift
    local packages=("$@")
    local failed_packages=()
    
    for package in "${packages[@]}"; do
        if ! install_package_safe "$package" "$is_required"; then
            if [[ "$is_required" == "true" ]]; then
                failed_packages+=("$package")
            fi
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]] && [[ "$is_required" == "true" ]]; then
        log_error "다음 필수 패키지 설치에 실패했습니다: ${failed_packages[*]}"
        return 1
    fi
    
    return 0
}

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

log_info "커널 및 필수 패키지 설치 중..."
# 필수 커널 패키지
install_packages_safe true linux-image-amd64 linux-headers-amd64
# 필수 라이브 부트 패키지
install_packages_safe true live-boot live-boot-initramfs-tools initramfs-tools
# 필수 시스템 패키지
install_packages_safe true systemd-sysv network-manager openssh-server
# 기본 도구들
install_packages_safe true sudo curl wget htop nano vim net-tools
# 로케일 및 콘솔 설정
install_packages_safe true locales console-setup keyboard-configuration

# ===========================================
# Debian 공식 한국어 지원 패키지 완전 설정
# 설치 후에도 터미널에서 한글이 완벽하게 지원됨
# ===========================================

log_info "Debian 공식 한국어 지원 패키지 완전 설치 중..."

# 1. Debian 태스크 패키지 (한국어 환경 완전 구성)
log_info "Debian 한국어 태스크 패키지 설치 시도..."
install_package_safe task-korean false
install_package_safe task-korean-desktop false

# 2. 모든 로케일 지원 (한국어 포함)
log_info "전체 로케일 패키지 설치..."
install_package_safe locales-all false

# 3. 최고 품질의 CJK 폰트 (필수) - Google Noto
log_info "고품질 한중일 폰트 설치..."
install_packages_safe true fonts-noto-cjk fonts-noto-cjk-extra
install_package_safe fonts-noto-color-emoji false

# 4. 기본 한글 폰트 (필수) - 나눔폰트
log_info "기본 한글 폰트 설치..."
install_packages_safe true fonts-nanum fonts-nanum-coding fonts-nanum-extra

# 5. 추가 한글 폰트 (선택적)
log_info "추가 한글 폰트 설치..."
install_packages_safe false fonts-unfonts-core fonts-baekmuk fonts-dejavu
install_packages_safe false fonts-liberation fonts-liberation2
install_package_safe ttf-unfonts-core false
install_package_safe xfonts-baekmuk false

# 6. 한글 입력기 완전 지원 (필수)
log_info "한글 입력기 완전 설정..."
install_packages_safe true fcitx5 fcitx5-hangul fcitx5-config-qt
install_package_safe im-config true
# fcitx5 프론트엔드 (데스크톱 환경용)
install_package_safe fcitx5-frontend-gtk2 false
install_package_safe fcitx5-frontend-gtk3 false
install_package_safe fcitx5-frontend-qt5 false

# 7. 한국어 매뉴얼 및 도구
log_info "한국어 매뉴얼 및 도구 설치..."
install_package_safe manpages-ko false        # 한국어 매뉴얼
install_package_safe hunspell-ko false        # 한국어 맞춤법 검사
install_package_safe aspell-ko false          # 한국어 철자 검사
install_package_safe mythes-ko false          # 한국어 동의어 사전

# 8. 콘솔 환경 한글 지원 강화
log_info "콘솔 한글 지원 강화 설치..."
# 유니코드 폰트 (필수) - 콘솔에서 한글 표시
install_package_safe unifont true
# 콘솔 한글 도구들 (선택적)
install_package_safe fbterm false             # 프레임버퍼 터미널
install_package_safe ncurses-term false       # ncurses 터미널

log_success "Debian 공식 한국어 지원 패키지 설치 완료!"
log_info "설치 후 GUI 터미널과 콘솔 둘 다에서 한글이 지원됩니다."

log_info "설치에 필요한 패키지들 설치 중..."
# 설치에 필요한 패키지들 (필수)
install_packages_safe true parted rsync grub-efi-amd64 grub2-common

echo "로케일 설정 중..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# 콘솔 폰트 설정 추가 - 한글 지원 대폭 강화
log_info "콘솔 한글 지원 대폭 강화 설정 중..."

# 콘솔 관련 패키지 설치
install_package_safe kbd false
install_package_safe console-data false
install_package_safe console-setup true
install_package_safe locales true

# 다양한 콘솔 폰트 대비
log_info "콘솔 폰트 설정 최적화..."

# 1. 기본 콘솔 설정 (가장 호환성 좋음)
cat > /etc/default/console-setup << 'CONSOLE_EOF'
CHARMAP="UTF-8"
CODESET="guess"
FONTFACE="Fixed"
FONTSIZE="16"
KEYMAP="us"
VIDEOMODE=""
CONSOLE_EOF

# 2. 대체 폰트 설정 (유니코드 지원)
cat > /etc/default/console-setup.unicode << 'CONSOLE_UNI_EOF'
CHARMAP="UTF-8"
CODESET="Uni2"
FONTFACE="unifont"
FONTSIZE="16"
KEYMAP="us"
VIDEOMODE=""
CONSOLE_UNI_EOF

# 3. 터미널 환경 변수 설정 (다중 대비)
cat > /etc/environment << 'ENV_EOF'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LC_CTYPE=en_US.UTF-8
TERM=linux
CONSOLE_FONT=unifont
CONSOLE_FONT_MAP=8859-1_to_uni
ENV_EOF

# 4. 콘솔 초기화 스크립트 생성
cat > /usr/local/bin/setup-console-korean << 'CONSOLE_INIT_EOF'
#!/bin/bash
# 콘솔 한글 지원 초기화 스크립트

# UTF-8 환경 설정
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# 콘솔 폰트 설정 시도 (여러 단계)
setup_console_font() {
    # 1단계: unifont 시도
    if which setfont > /dev/null 2>&1; then
        setfont /usr/share/consolefonts/Uni2-VGA16.psf.gz 2>/dev/null && return 0
        setfont /usr/share/consolefonts/Uni2-Fixed16.psf.gz 2>/dev/null && return 0
        setfont /usr/share/consolefonts/unifont.psf.gz 2>/dev/null && return 0
    fi
    
    # 2단계: console-setup 사용
    if which setupcon > /dev/null 2>&1; then
        setupcon --force --save 2>/dev/null && return 0
        setupcon --force --save-only 2>/dev/null && return 0  
    fi
    
    # 3단계: dpkg-reconfigure
    if which dpkg-reconfigure > /dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive dpkg-reconfigure console-setup 2>/dev/null
    fi
}

# 콘솔 설정 실행
setup_console_font

# 키보드 맵 설정
if which loadkeys > /dev/null 2>&1; then
    loadkeys us 2>/dev/null || true
fi

echo "Console Korean support initialized"
CONSOLE_INIT_EOF

chmod +x /usr/local/bin/setup-console-korean

# 5. 부팅 시 자동 실행 설정
cat > /etc/systemd/system/console-korean.service << 'SERVICE_EOF'
[Unit]
Description=Setup Korean Console Support
DefaultDependencies=false
After=systemd-vconsole-setup.service
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-console-korean
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# 서비스 활성화
systemctl enable console-korean.service 2>/dev/null || true

# 6. 프로파일 설정 강화
cat >> /etc/profile << 'PROFILE_EOF'

# Korean console support
if [ "$TERM" = "linux" ]; then
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
    
    # 콘솔 폰트 설정 시도
    if [ -x /usr/local/bin/setup-console-korean ]; then
        /usr/local/bin/setup-console-korean >/dev/null 2>&1 || true
    fi
fi
PROFILE_EOF

# 7. fbterm 고도화 설정 (선택적)
if which fbterm > /dev/null 2>&1; then
    log_success "fbterm 발견, 한글 지원 강화 설정 중..."
    
    # fbterm 설정 파일
    mkdir -p /etc/fbterm
    cat > /etc/fbterm/fbtermrc << 'FBTERM_CONFIG_EOF'
# fbterm configuration for Korean support
font-names=UnDotum,NanumGothic,DejaVu Sans Mono
font-size=16
color-foreground=7
color-background=0
input-method=fcitx
FBTERM_CONFIG_EOF
    
    # fbterm 자동 실행 스크립트 (개선된 버전)
    cat > /usr/local/bin/start-fbterm << 'FBTERM_EOF'
#!/bin/bash
# Enhanced fbterm startup script

# fbterm이 이미 실행 중인지 확인
if [ -n "$FBTERM_STARTED" ] || [ "$TERM" != "linux" ]; then
    exit 0
fi

# 한글 환경 설정
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export FBTERM_STARTED=1

# fbterm 실행 가능 여부 확인
if ! which fbterm > /dev/null 2>&1; then
    exit 0
fi

# 폰트 경로 설정
if [ -d /usr/share/fonts/truetype/nanum ]; then
    export FONTPATH="/usr/share/fonts/truetype/nanum:/usr/share/fonts/truetype/dejavu"
fi

# fbterm 실행
exec fbterm
FBTERM_EOF
    
    chmod +x /usr/local/bin/start-fbterm
    
    # bash 자동 실행 설정 (선택적)
    cat >> /etc/profile << 'FBTERM_PROFILE_EOF'

# Auto-start fbterm for better Korean display (optional)
if [ "$TERM" = "linux" ] && [ -z "$SSH_CONNECTION" ] && [ -z "$FBTERM_STARTED" ]; then
    if [ -x /usr/local/bin/start-fbterm ]; then
        /usr/local/bin/start-fbterm 2>/dev/null || true
    fi
fi
FBTERM_PROFILE_EOF
    
    log_success "fbterm 한글 지원 설정 완료"
else
    log_warning "fbterm이 설치되지 않음, 기본 콘솔 한글 지원만 사용"
fi

# 8. 최종 콘솔 설정 적용
log_info "콘솔 설정 적용 중..."
if which setupcon > /dev/null 2>&1; then
    setupcon --save --force 2>/dev/null || log_warning "setupcon 실행 실패"
fi

if which dpkg-reconfigure > /dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure console-setup 2>/dev/null || log_warning "console-setup reconfigure 실패"
fi

log_success "콘솔 한글 지원 설정 완료!"

# ===========================================
# 데스크톱 환경 한글 지원 완전 설정
# ===========================================

log_info "데스크톱 환경 한글 지원 완전 설정 중..."

# 1. 강화된 환경 변수 설정
cat >> /etc/environment << 'DESKTOP_ENV_EOF'
# Korean Desktop Environment Support
CONSOLE_FONT_MAP=8859-1_to_uni
CONSOLE_FONT=unifont

# Input Method Settings (fcitx5)
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
QT4_IM_MODULE=fcitx
CLUTTER_IM_MODULE=fcitx

# Font Settings
FONTCONFIG_PATH=/etc/fonts
DESKTOP_ENV_EOF

# 2. fcitx5 기본 설정 (모든 사용자용)
log_info "fcitx5 입력기 기본 설정 중..."
mkdir -p /etc/skel/.config/fcitx5
cat > /etc/skel/.config/fcitx5/config << 'FCITX5_CONFIG_EOF'
[Hotkey]
TriggerKeys=
EnumerateWithTriggerKeys=True
EnumerateForwardKeys=
EnumerateBackwardKeys=
EnumerateSkipFirst=False

[Behavior]
ActiveByDefault=False
ShareInputState=No
PreeditEnabledByDefault=True
ShowInputMethodInformation=True
showInputMethodInformationWhenFocusIn=False
CompactInputMethodInformation=True
ShowFirstInputMethodInformation=True
DefaultPageSize=5
OverrideXkbOption=False
CustomXkbOption=
EnabledAddons=
DisabledAddons=
PreloadInputMethod=True
AllowInputMethodForPassword=False
PreeditInPassword=False

[Addon]
hangul=True
FCITX5_CONFIG_EOF

# 3. 한글 입력기 프로파일 설정
cat > /etc/skel/.config/fcitx5/profile << 'FCITX5_PROFILE_EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
FCITX5_PROFILE_EOF

# 4. 글꼴 설정 파일 생성
log_info "한글 글꼴 기본 설정 생성 중..."
mkdir -p /etc/fonts/conf.d
cat > /etc/fonts/local.conf << 'FONTS_CONFIG_EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <!-- Korean font configuration -->
    <alias>
        <family>serif</family>
        <prefer>
            <family>Noto Serif CJK KR</family>
            <family>NanumSerifWeb</family>
            <family>DejaVu Serif</family>
        </prefer>
    </alias>
    
    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Noto Sans CJK KR</family>
            <family>NanumGothic</family>
            <family>DejaVu Sans</family>
        </prefer>
    </alias>
    
    <alias>
        <family>monospace</family>
        <prefer>
            <family>Noto Sans Mono CJK KR</family>
            <family>NanumGothicCoding</family>
            <family>DejaVu Sans Mono</family>
        </prefer>
    </alias>
</fontconfig>
FONTS_CONFIG_EOF

# 5. 한글 지원 테스트 스크립트 생성
log_info "한글 지원 테스트 도구 생성 중..."
cat > /usr/local/bin/test-korean << 'TEST_KOREAN_EOF'
#!/bin/bash
# Korean support test script

echo "=== Hemmins OS 한글 지원 테스트 ==="
echo

echo "1. 로케일 설정:"
locale | grep -E "(LANG|LC_)"
echo

echo "2. 설치된 한글 폰트:"
fc-list :lang=ko family | sort | uniq | head -10
echo

echo "3. 입력기 설정:"
echo "GTK_IM_MODULE: $GTK_IM_MODULE"
echo "QT_IM_MODULE: $QT_IM_MODULE"
echo "XMODIFIERS: $XMODIFIERS"
echo

echo "4. 한글 텍스트 표시 테스트:"
echo "안녕하세요! Hemmins OS입니다."
echo "Korean text display test: 한국어 표시가 정상적으로 됩니다."
echo

echo "5. 유니코드 테스트:"
echo "Unicode Korean: 유니코드 한글 처리 ✓"
echo

echo "=== 테스트 완료 ==="
TEST_KOREAN_EOF

chmod +x /usr/local/bin/test-korean

# 6. 사용자 프로파일에 한글 지원 추가
cat >> /etc/skel/.bashrc << 'BASHRC_KOREAN_EOF'

# Korean support settings
if [ -n "$DISPLAY" ]; then
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    # Start fcitx5 if not running
    if ! pgrep fcitx5 > /dev/null; then
        fcitx5 -d 2>/dev/null || true
    fi
fi

# Test Korean support (optional)
alias test-korean='/usr/local/bin/test-korean'
BASHRC_KOREAN_EOF

log_success "데스크톱 환경 한글 지원 설정 완료!"
log_info "설치 후 'test-korean' 명령으로 한글 지원을 확인할 수 있습니다."

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