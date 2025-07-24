#!/bin/bash

# Hemmins OS Interactive Installer
# 다국어 지원 대화형 TUI 기반 설치 프로그램 (개선된 버전)

set -e

# 색상 및 스타일 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Installation language: English only (Korean support available after installation)
LANG_CODE="en"

# 전역 변수
SELECTED_DISK=""
ADMIN_USER=""
ADMIN_PASS=""
ROOT_PASS=""
HOSTNAME=""
INSTALL_TYPE="full"
EFI_SIZE="512"
SWAP_SIZE="2048"
DISK_SIZE_GB=0
TOTAL_REQUIRED_SIZE=0

# Static English text definitions (simplified)
INSTALLER_TITLE="Hemmins OS Installer"
WELCOME_MSG="Welcome to Hemmins OS Installation\n\nKorean language support will be available after installation."
START_INSTALL="Start Installation"
VIEW_DISK="View Disk Information"
EXIT_INSTALLER="Exit Installer"

# Disk and installation text
SELECT_DISK="Select disk to install"
INSTALL_TYPE="Select installation type"
FULL_DISK="Use entire disk (erase existing data)"
MANUAL_PARTITION="Manual partition setup"
PARTITION_CONFIG="Partition Configuration"
USER_CONFIG="User Account Configuration"
SYSTEM_CONFIG="System Configuration"
INSTALL_SUMMARY="Installation Summary"









# Additional text definitions
CANCEL="Cancel"
CONTINUE="Continue"
YES="Yes"
NO="No"
BACK="Back"
NEXT="Next"

# Error messages
ERROR_ROOT="This installer must be run with root privileges."
ERROR_DISK_NOT_FOUND="Disk /dev/%s not found."
ERROR_INSTALL="Error occurred during installation!"
USE_SUDO="Please use: sudo %s"
PRESS_KEY="Press any key to continue..."

# Installation step messages
STEP_DISK_PREP="Preparing disk"
STEP_PARTITION="Creating partitions"
STEP_FILESYSTEM="Creating filesystems"
STEP_MOUNT="Mounting partitions"
STEP_COPY="Copying system files"
STEP_CONFIG="Configuring system"
STEP_USERS="Setting up user accounts"
STEP_BOOTLOADER="Installing bootloader"
STEP_FINALIZE="Finalizing configuration"
STEP_CLEANUP="Cleaning up"

# Installation messages
INSTALLING="Installing Hemmins OS..."
INSTALL_COMPLETE="Installation Complete!"
INSTALL_SUCCESS="System has been successfully installed."
INSTALL_INFO="Installed system information:"
NEXT_STEPS="Next steps:"
REMOVE_MEDIA="1. Remove USB/CD media"
REBOOT_SYSTEM="2. Reboot the system"
BOOT_FROM_DISK="3. Hemmins OS will boot from hard disk"
REBOOT_OPTIONS="Reboot options:"
REBOOT_NOW="Reboot now"
REBOOT_LATER="Reboot manually later"
REBOOTING="Rebooting in 3 seconds..."

# Warning messages
WARNING_TEXT="WARNING: All data on /dev/%s will be erased!"
UEFI_FAILED="UEFI installation failed, trying Legacy BIOS..."
LEGACY_FALLBACK="Switching to Legacy BIOS installation"

# Simple text formatting function
get_formatted_text() {
    local text="$1"
    shift
    printf "$text" "$@"
}

# Get text function for compatibility
get_text() {
    local key="$1"
    case "$key" in
        "step_disk_prep") echo "$STEP_DISK_PREP" ;;
        "step_partition") echo "$STEP_PARTITION" ;;
        "step_filesystem") echo "$STEP_FILESYSTEM" ;;
        "step_mount") echo "$STEP_MOUNT" ;;
        "step_copy") echo "$STEP_COPY" ;;
        "step_config") echo "$STEP_CONFIG" ;;
        "step_users") echo "$STEP_USERS" ;;
        "step_bootloader") echo "$STEP_BOOTLOADER" ;;
        "step_finalize") echo "$STEP_FINALIZE" ;;
        "step_cleanup") echo "$STEP_CLEANUP" ;;
        "installing") echo "$INSTALLING" ;;
        "install_complete") echo "$INSTALL_COMPLETE" ;;
        "install_success") echo "$INSTALL_SUCCESS" ;;
        "install_info") echo "$INSTALL_INFO" ;;
        "next_steps") echo "$NEXT_STEPS" ;;
        "remove_media") echo "$REMOVE_MEDIA" ;;
        "reboot_system") echo "$REBOOT_SYSTEM" ;;
        "boot_from_disk") echo "$BOOT_FROM_DISK" ;;
        "rebooting") echo "$REBOOTING" ;;
        "uefi_failed") echo "$UEFI_FAILED" ;;
        "legacy_fallback") echo "$LEGACY_FALLBACK" ;;
        "error_install") echo "$ERROR_INSTALL" ;;
        "disk") echo "Disk" ;;
        "hostname_label") echo "Hostname" ;;
        "administrator") echo "Administrator" ;;
        "password_strong") echo "Strong" ;;
        "password_medium") echo "Medium" ;;
        "password_weak") echo "Weak" ;;
        *) echo "$key" ;;
    esac
}

# Signal handling setup function
setup_signal_handling() {
    trap 'echo; log_info "Use menu options to exit safely"; sleep 2' INT TERM
}

# 네트워크 연결 확인 함수
check_network() {
    echo -e "${BLUE}Checking network connection...${NC}"
    
    # 다양한 방법으로 네트워크 확인
    local network_ok=false
    
    # 1. ping으로 확인
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        network_ok=true
    # 2. DNS 확인
    elif nslookup google.com >/dev/null 2>&1; then
        network_ok=true
    # 3. 네트워크 인터페이스 확인
    elif ip route | grep -q default; then
        network_ok=true
    fi
    
    if [[ "$network_ok" == "true" ]]; then
        log_success "Network connection available"
        return 0
    else
        log_warning "No network connection detected"
        if show_whiptail_yesno "Network Warning" "No network connection detected.\n\nDo you want to continue without network?"; then
            return 0
        else
            return 1
        fi
    fi
}

# 비밀번호 강도 확인 함수
check_password_strength() {
    local password="$1"
    local strength=0
    local strength_text=""
    
    # 길이 체크
    if [[ ${#password} -ge 8 ]]; then
        ((strength += 2))
    elif [[ ${#password} -ge 6 ]]; then
        ((strength += 1))
    fi
    
    # 대소문자 체크
    if [[ "$password" =~ [a-z] ]] && [[ "$password" =~ [A-Z] ]]; then
        ((strength += 2))
    elif [[ "$password" =~ [a-zA-Z] ]]; then
        ((strength += 1))
    fi
    
    # 숫자 체크
    if [[ "$password" =~ [0-9] ]]; then
        ((strength += 1))
    fi
    
    # 특수문자 체크
    if [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        ((strength += 1))
    fi
    
    # 강도 판정
    if [[ $strength -ge 5 ]]; then
        strength_text="$(get_text password_strong)"
    elif [[ $strength -ge 3 ]]; then
        strength_text="$(get_text password_medium)"
    else
        strength_text="$(get_text password_weak)"
    fi
    
    echo "$strength_text"
    return $strength
}

# 디스크 크기 확인 함수
get_disk_size_gb() {
    local disk="$1"
    local size_bytes=$(lsblk -b -d -o SIZE -n "/dev/$disk" 2>/dev/null | head -1)
    if [[ -n "$size_bytes" ]]; then
        echo $((size_bytes / 1024 / 1024 / 1024))
    else
        echo 0
    fi
}

# USB 디스크 감지 함수
is_usb_disk() {
    local disk="$1"
    # USB 디스크 감지 (다양한 방법)
    if [[ -e "/sys/block/$disk/removable" ]] && [[ "$(cat /sys/block/$disk/removable)" == "1" ]]; then
        return 0
    elif lsusb | grep -qi "$(lsblk -d -o MODEL -n "/dev/$disk" 2>/dev/null)"; then
        return 0
    elif [[ "$disk" =~ ^sd[a-z]$ ]] && dmesg | grep -i usb | grep -qi "$disk"; then
        return 0
    fi
    return 1
}

# 강화된 키 입력 함수
read_key_safe() {
    local key=""
    local timeout=${1:-0}  # 타임아웃 설정 (기본값: 무제한)
    
    # 타임아웃이 설정된 경우
    if [[ $timeout -gt 0 ]]; then
        if ! read -t $timeout -rsn1 key 2>/dev/null; then
            return 1  # 타임아웃
        fi
    else
        if ! read -rsn1 key 2>/dev/null; then
            return 1  # 읽기 실패
        fi
    fi
    
    # ESC 시퀀스 처리
    if [[ "$key" == $'\x1b' ]]; then
        local seq=""
        # 짧은 타임아웃으로 나머지 시퀀스 읽기
        if read -t 0.1 -rsn1 seq 2>/dev/null; then
            if [[ "$seq" == "[" ]]; then
                if read -t 0.1 -rsn1 seq 2>/dev/null; then
                    key="$key[$seq"
                else
                    key="$key["
                fi
            else
                key="$key$seq"
            fi
        fi
    fi
    
    echo "$key"
    return 0
}

# Language selection removed - English only
# Korean support will be available after OS installation

# 로그 및 UI 함수들
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Whiptail menu function
show_whiptail_menu() {
    local title="$1"
    local message="$2"
    shift 2
    local options=("$@")
    
    # Build whiptail menu options
    local menu_items=()
    for i in "${!options[@]}"; do
        menu_items+=("$i" "${options[i]}")
    done
    
    local choice
    if choice=$(whiptail --title "$title" --menu "$message" 20 70 10 "${menu_items[@]}" 3>&1 1>&2 2>&3); then
        return $choice
    else
        return 255  # User cancelled
    fi
}

# Whiptail input functions
get_whiptail_input() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    
    whiptail --title "$title" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3
}

get_whiptail_password() {
    local title="$1"
    local prompt="$2"
    
    whiptail --title "$title" --passwordbox "$prompt" 10 60 3>&1 1>&2 2>&3
}

show_whiptail_yesno() {
    local title="$1"
    local message="$2"
    
    whiptail --title "$title" --yesno "$message" 10 60
}

show_whiptail_msgbox() {
    local title="$1"
    local message="$2"
    
    whiptail --title "$title" --msgbox "$message" 15 70
}

# Legacy function for compatibility
get_input() {
    local prompt="$1"
    local default="$2"
    local is_password="$3"
    
    if [[ "$is_password" == "true" ]]; then
        get_whiptail_password "Input Required" "$prompt"
    else
        get_whiptail_input "Input Required" "$prompt" "$default"
    fi
}

# 디스크 선택 함수 (개선됨)
select_disk() {
    local disks=()
    local disk_info=()
    
    # 사용 가능한 디스크 찾기
    while IFS= read -r line; do
        local disk=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local model=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')
        
        if [[ "$disk" != "NAME" ]] && [[ "$disk" != sr* ]] && [[ "$disk" != loop* ]] && [[ -n "$disk" ]]; then
            # 디스크 크기 확인
            local size_gb=$(get_disk_size_gb "$disk")
            
            # USB 디스크 표시
            local usb_marker=""
            if is_usb_disk "$disk"; then
                usb_marker=" [USB]"
            fi
            
            disks+=("$disk")
            disk_info+=("$disk ($size) - $model$usb_marker")
        fi
    done < <(lsblk -d -o NAME,SIZE,MODEL 2>/dev/null)
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        log_error "No suitable disks found!"
        return 1
    fi
    
    disk_info+=("$CANCEL")
    
    show_whiptail_menu "Select Disk" "Choose disk to install Hemmins OS:" "${disk_info[@]}"
    local choice=$?
    
    if [[ $choice -eq 255 ]]; then
        return 1  # User cancelled
    fi
    
    if [[ $choice -eq ${#disk_info[@]}-1 ]]; then
        return 1  # Cancel option selected
    fi
    
    SELECTED_DISK="${disks[$choice]}"
    
    # Disk existence check
    if [[ ! -b "/dev/$SELECTED_DISK" ]]; then
        show_whiptail_msgbox "Disk Not Found" "Disk /dev/$SELECTED_DISK not found."
        return 1
    fi
    
    # Disk size check
    DISK_SIZE_GB=$(get_disk_size_gb "$SELECTED_DISK")
    if [[ $DISK_SIZE_GB -lt 8 ]]; then
        show_whiptail_msgbox "Disk Too Small" "Disk is too small! Minimum 8GB required, found ${DISK_SIZE_GB}GB."
        return 1
    fi
    
    # USB disk warning
    if is_usb_disk "$SELECTED_DISK"; then
        if ! show_whiptail_yesno "USB Warning" "WARNING: This appears to be a USB drive.\n\nDo you want to continue?"; then
            return 1
        fi
    fi
    
    return 0
}

# 설치 타입 선택
select_install_type() {
    local types=(
        "$FULL_DISK"
        "$MANUAL_PARTITION"
        "$CANCEL"
    )
    
    show_whiptail_menu "Installation Type" "Select installation type:" "${types[@]}"
    local choice=$?
    
    case $choice in
        0) INSTALL_TYPE="full" ;;
        1) INSTALL_TYPE="manual" ;;
        2|255) return 1 ;;
    esac
    return 0
}

# Partition configuration with whiptail
configure_partitions() {
    if [[ "$INSTALL_TYPE" == "manual" ]]; then
        while true; do
            EFI_SIZE=$(get_whiptail_input "Partition Configuration" "EFI partition size (MB):" "512")
            if [[ $? -ne 0 ]]; then
                return 1  # User cancelled
            fi
            
            SWAP_SIZE=$(get_whiptail_input "Partition Configuration" "Swap partition size (MB, 0=no swap):" "2048")
            if [[ $? -ne 0 ]]; then
                return 1  # User cancelled
            fi
            
            # Number validation
            if ! [[ "$EFI_SIZE" =~ ^[0-9]+$ ]] || ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
                show_whiptail_msgbox "Invalid Input" "Please enter valid numbers for partition sizes."
                continue
            fi
            
            # Partition size validation
            TOTAL_REQUIRED_SIZE=$((EFI_SIZE + SWAP_SIZE + 4096))  # Minimum 4GB root
            local disk_mb=$((DISK_SIZE_GB * 1024))
            
            if [[ $TOTAL_REQUIRED_SIZE -gt $disk_mb ]]; then
                show_whiptail_msgbox "Insufficient Space" "Total partition size (${TOTAL_REQUIRED_SIZE}MB) exceeds disk capacity (${disk_mb}MB)!"
                continue
            fi
            
            break
        done
        
        local root_size=$((disk_mb - EFI_SIZE - SWAP_SIZE))
        local summary="Configured partitions:\n\n"
        summary+="EFI: ${EFI_SIZE}MB\n"
        summary+="Swap: ${SWAP_SIZE}MB\n"
        summary+="Root: ${root_size}MB\n\n"
        summary+="Continue with this configuration?"
        
        if ! show_whiptail_yesno "Partition Configuration" "$summary"; then
            return 1
        fi
    fi
    return 0
}

# User configuration with whiptail
configure_users() {
    # Username input and validation
    while true; do
        ADMIN_USER=$(get_whiptail_input "User Configuration" "Enter administrator username:" "admin")
        
        if [[ $? -ne 0 ]]; then
            return 1  # User cancelled
        fi
        
        # Username validation
        if [[ "$ADMIN_USER" =~ ^[a-z][a-z0-9_-]*$ ]] && [[ ${#ADMIN_USER} -ge 3 ]] && [[ ${#ADMIN_USER} -le 32 ]]; then
            break
        else
            show_whiptail_msgbox "Invalid Username" "Invalid username! Use lowercase letters, numbers, underscore and dash only.\nLength must be 3-32 characters."
        fi
    done
    
    # Password input and validation
    while true; do
        ADMIN_PASS=$(get_whiptail_password "User Configuration" "Enter administrator password:")
        
        if [[ $? -ne 0 ]]; then
            return 1  # User cancelled
        fi
        
        local confirm_pass=$(get_whiptail_password "User Configuration" "Confirm administrator password:")
        
        if [[ $? -ne 0 ]]; then
            return 1  # User cancelled
        fi
        
        if [[ "$ADMIN_PASS" == "$confirm_pass" ]] && [[ -n "$ADMIN_PASS" ]]; then
            break
        else
            show_whiptail_msgbox "Password Mismatch" "Passwords do not match. Please try again."
        fi
    done
    
    # Root password
    while true; do
        ROOT_PASS=$(get_whiptail_password "User Configuration" "Enter root password:")
        
        if [[ $? -ne 0 ]]; then
            return 1  # User cancelled
        fi
        
        if [[ -n "$ROOT_PASS" ]]; then
            break
        else
            show_whiptail_msgbox "Empty Password" "Root password cannot be empty!"
        fi
    done
    
    return 0
}

# System configuration with whiptail
configure_system() {
    while true; do
        HOSTNAME=$(get_whiptail_input "System Configuration" "Enter hostname:" "hemmins-os")
        
        if [[ $? -ne 0 ]]; then
            return 1  # User cancelled
        fi
        
        # Hostname validation
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] && [[ ${#HOSTNAME} -le 63 ]]; then
            break
        else
            show_whiptail_msgbox "Invalid Hostname" "Invalid hostname! Use letters, numbers, and hyphens only.\nMaximum length is 63 characters."
        fi
    done
    
    return 0
}

# Installation summary with whiptail
show_summary() {
    local summary="Installation Summary\n\n"
    summary+="Disk: /dev/$SELECTED_DISK (${DISK_SIZE_GB}GB)\n"
    
    if [[ "$INSTALL_TYPE" == "full" ]]; then
        summary+="Installation Type: Use entire disk\n"
    else
        summary+="Installation Type: Manual partitioning\n"
        summary+="EFI Partition: ${EFI_SIZE}MB\n"
        summary+="Swap Partition: ${SWAP_SIZE}MB\n"
    fi
    
    summary+="Hostname: $HOSTNAME\n"
    summary+="Administrator: $ADMIN_USER\n\n"
    summary+="WARNING: All data on /dev/$SELECTED_DISK will be erased!\n\n"
    summary+="Do you want to start the installation?"
    
    show_whiptail_yesno "$INSTALL_SUMMARY" "$summary"
}

# 향상된 진행률 표시 함수
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    
    printf "\r${BLUE}[%s%s] %d%% - %s${NC}" \
        "$(printf "%*s" $filled | tr ' ' '█')" \
        "$(printf "%*s" $empty | tr ' ' '░')" \
        "$percent" "$message"
}

# rsync 진행률 표시 함수
show_rsync_progress() {
    local source="$1"
    local dest="$2"
    
    rsync -avx --progress \
        --exclude=/dev/* \
        --exclude=/proc/* \
        --exclude=/sys/* \
        --exclude=/tmp/* \
        --exclude=/run/* \
        --exclude=/mnt/* \
        --exclude=/media/* \
        --exclude=/lost+found \
        --exclude=/live \
        --exclude=/cdrom \
        "$source" "$dest" 2>/dev/null | \
    while IFS= read -r line; do
        if [[ "$line" =~ ([0-9]+)% ]]; then
            local percent="${BASH_REMATCH[1]}"
            printf "\r${BLUE}[%s%s] %s%% - %s${NC}" \
                "$(printf "%*s" $((percent/5)) | tr ' ' '█')" \
                "$(printf "%*s" $((20-percent/5)) | tr ' ' '░')" \
                "$percent" "$(get_text step_copy)"
        fi
    done
    echo
}

# 파티션 경로 계산 함수
get_partition_paths() {
    if [[ "$SELECTED_DISK" == nvme* ]] || [[ "$SELECTED_DISK" == mmcblk* ]]; then
        EFI_PARTITION="/dev/${SELECTED_DISK}p1"
        if [[ "$SWAP_SIZE" != "0" ]]; then
            SWAP_PARTITION="/dev/${SELECTED_DISK}p2"
            ROOT_PARTITION="/dev/${SELECTED_DISK}p3"
        else
            ROOT_PARTITION="/dev/${SELECTED_DISK}p2"
        fi
    else
        EFI_PARTITION="/dev/${SELECTED_DISK}1"
        if [[ "$SWAP_SIZE" != "0" ]]; then
            SWAP_PARTITION="/dev/${SELECTED_DISK}2"
            ROOT_PARTITION="/dev/${SELECTED_DISK}3"
        else
            ROOT_PARTITION="/dev/${SELECTED_DISK}2"
        fi
    fi
}

# Legacy BIOS 설치 함수
install_legacy_grub() {
    log_info "$(get_text legacy_fallback)"
    
    # Legacy GRUB 설치
    if chroot /tmp/target apt install -y grub-pc-bin >/dev/null 2>&1; then
        if chroot /tmp/target grub-install --target=i386-pc "/dev/$SELECTED_DISK" >/dev/null 2>&1; then
            chroot /tmp/target update-grub >/dev/null 2>&1
            return 0
        fi
    fi
    return 1
}

# 설치 중 시그널 방지 함수
block_signals() {
    trap '' INT TERM QUIT HUP
}

# 시그널 블록 해제 함수
unblock_signals() {
    trap cleanup_on_error ERR
    trap 'log_warning "Installation cannot be interrupted during critical operations"; sleep 2' INT TERM
}

# 실제 설치 수행 (대폭 개선됨)
perform_installation() {
    clear
    echo -e "${CYAN}${BOLD}$(get_text installing)${NC}"
    echo
    
    # 설치 중에는 시그널 차단
    log_warning "WARNING: Do not interrupt the installation process!"
    log_warning "Interrupting during installation can damage your system."
    echo
    sleep 3
    
    block_signals
    
    local steps=(
        "$(get_text step_disk_prep)"
        "$(get_text step_partition)"
        "$(get_text step_filesystem)"
        "$(get_text step_mount)"
        "$(get_text step_copy)"
        "$(get_text step_config)"
        "$(get_text step_users)"
        "$(get_text step_bootloader)"
        "$(get_text step_finalize)"
        "$(get_text step_cleanup)"
    )
    
    local total_steps=${#steps[@]}
    local failed_step=""
    
    for i in "${!steps[@]}"; do
        # 각 단계마다 시그널 차단 유지
        block_signals
        show_progress $((i+1)) $total_steps "${steps[i]}"
        
        case $i in
            0) # 디스크 준비
                if ! wipefs -af "/dev/$SELECTED_DISK" >/dev/null 2>&1; then
                    failed_step="disk preparation"
                    break
                fi
                sleep 1
                ;;
            1) # 파티션 생성
                if ! parted -s "/dev/$SELECTED_DISK" mklabel gpt >/dev/null 2>&1; then
                    failed_step="partition table creation"
                    break
                fi
                
                if ! parted -s "/dev/$SELECTED_DISK" mkpart primary fat32 1MiB "${EFI_SIZE}MiB" >/dev/null 2>&1; then
                    failed_step="EFI partition creation"
                    break
                fi
                
                if ! parted -s "/dev/$SELECTED_DISK" set 1 esp on >/dev/null 2>&1; then
                    failed_step="EFI flag setting"
                    break
                fi
                
                if [[ "$SWAP_SIZE" != "0" ]]; then
                    local swap_end=$((EFI_SIZE + SWAP_SIZE))
                    if ! parted -s "/dev/$SELECTED_DISK" mkpart primary linux-swap "${EFI_SIZE}MiB" "${swap_end}MiB" >/dev/null 2>&1; then
                        failed_step="swap partition creation"
                        break
                    fi
                    if ! parted -s "/dev/$SELECTED_DISK" mkpart primary ext4 "${swap_end}MiB" 100% >/dev/null 2>&1; then
                        failed_step="root partition creation"
                        break
                    fi
                else
                    if ! parted -s "/dev/$SELECTED_DISK" mkpart primary ext4 "${EFI_SIZE}MiB" 100% >/dev/null 2>&1; then
                        failed_step="root partition creation"
                        break
                    fi
                fi
                
                partprobe "/dev/$SELECTED_DISK" >/dev/null 2>&1
                sleep 3
                
                # 파티션 경로 설정
                get_partition_paths
                
                # 파티션이 실제로 생성되었는지 확인
                local wait_count=0
                while [[ ! -b "$ROOT_PARTITION" ]] && [[ $wait_count -lt 10 ]]; do
                    sleep 1
                    ((wait_count++))
                done
                
                if [[ ! -b "$ROOT_PARTITION" ]]; then
                    failed_step="partition availability check"
                    break
                fi
                ;;
            2) # 파일시스템 생성
                if ! mkfs.fat -F32 "$EFI_PARTITION" >/dev/null 2>&1; then
                    failed_step="EFI filesystem creation"
                    break
                fi
                
                if ! mkfs.ext4 -F "$ROOT_PARTITION" >/dev/null 2>&1; then
                    failed_step="root filesystem creation"
                    break
                fi
                
                if [[ "$SWAP_SIZE" != "0" ]]; then
                    if ! mkswap "$SWAP_PARTITION" >/dev/null 2>&1; then
                        failed_step="swap creation"
                        break
                    fi
                fi
                ;;
            3) # 파티션 마운트
                mkdir -p /tmp/target
                if ! mount "$ROOT_PARTITION" /tmp/target; then
                    failed_step="root mount"
                    break
                fi
                
                mkdir -p /tmp/target/boot/efi
                if ! mount "$EFI_PARTITION" /tmp/target/boot/efi; then
                    failed_step="EFI mount"
                    break
                fi
                
                if [[ "$SWAP_SIZE" != "0" ]]; then
                    swapon "$SWAP_PARTITION" >/dev/null 2>&1 || true
                fi
                ;;
            4) # 시스템 파일 복사
                echo
                show_rsync_progress / /tmp/target/
                
                if [[ $? -ne 0 ]]; then
                    failed_step="system file copy"
                    break
                fi
                
                mkdir -p /tmp/target/{dev,proc,sys,tmp,run,mnt,media}
                chmod 1777 /tmp/target/tmp
                ;;
            5) # 시스템 설정
                # fstab 생성
                ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PARTITION")
                EFI_UUID=$(blkid -s UUID -o value "$EFI_PARTITION")
                
                cat > /tmp/target/etc/fstab << EOF
UUID=$ROOT_UUID / ext4 defaults 0 1
UUID=$EFI_UUID /boot/efi vfat defaults 0 2
EOF
                
                if [[ "$SWAP_SIZE" != "0" ]]; then
                    SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PARTITION")
                    echo "UUID=$SWAP_UUID none swap sw 0 0" >> /tmp/target/etc/fstab
                fi
                
                echo "tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0" >> /tmp/target/etc/fstab
                
                # 호스트명 설정
                echo "$HOSTNAME" > /tmp/target/etc/hostname
                sed -i "s/hemmins-os/$HOSTNAME/g" /tmp/target/etc/hosts
                ;;
            6) # 사용자 계정 설정
                mount --bind /dev /tmp/target/dev
                mount --bind /proc /tmp/target/proc
                mount --bind /sys /tmp/target/sys
                
                cat > /tmp/target/tmp/setup_users.sh << EOF
#!/bin/bash
set -e

# installer 사용자 제거
userdel -r installer 2>/dev/null || true

# 새 관리자 사용자 생성
useradd -m -s /bin/bash "$ADMIN_USER"
echo "$ADMIN_USER:$ADMIN_PASS" | chpasswd
usermod -aG sudo "$ADMIN_USER"
echo "root:$ROOT_PASS" | chpasswd

# SSH 키 생성
sudo -u "$ADMIN_USER" mkdir -p /home/$ADMIN_USER/.ssh
sudo -u "$ADMIN_USER" ssh-keygen -t rsa -b 4096 -f /home/$ADMIN_USER/.ssh/id_rsa -N "" >/dev/null 2>&1 || true
chmod 700 /home/$ADMIN_USER/.ssh 2>/dev/null || true
chmod 600 /home/$ADMIN_USER/.ssh/* 2>/dev/null || true

# 자동 로그인 설정을 새 사용자로 변경
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << 'GETTY_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $ADMIN_USER --noclear %I \$TERM
GETTY_EOF

# Live 시스템 패키지 제거
apt remove --purge -y live-boot live-boot-initramfs-tools >/dev/null 2>&1 || true
apt autoremove -y >/dev/null 2>&1 || true

# 설치 스크립트 제거
rm -f /usr/local/bin/install-to-disk.sh
rm -f /usr/local/bin/installer-wrapper.sh

echo "User setup completed"
EOF
                
                chmod +x /tmp/target/tmp/setup_users.sh
                if ! chroot /tmp/target /tmp/setup_users.sh >/dev/null 2>&1; then
                    failed_step="user setup"
                    break
                fi
                rm -f /tmp/target/tmp/setup_users.sh
                ;;
            7) # 부트로더 설치
                local bootloader_success=false
                
                # UEFI 설치 시도
                if chroot /tmp/target apt update >/dev/null 2>&1 && \
                   chroot /tmp/target apt install -y grub-efi-amd64 grub2-common >/dev/null 2>&1; then
                    
                    if chroot /tmp/target grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=HemminsOS >/dev/null 2>&1; then
                        # GRUB 설정 커스터마이징
                        sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Hemmins OS"/' /tmp/target/etc/default/grub
                        if chroot /tmp/target update-grub >/dev/null 2>&1; then
                            bootloader_success=true
                        fi
                    fi
                fi
                
                # UEFI 실패 시 Legacy BIOS 시도
                if [[ "$bootloader_success" == "false" ]]; then
                    echo
                    log_warning "$(get_text uefi_failed)"
                    
                    if install_legacy_grub; then
                        bootloader_success=true
                    fi
                fi
                
                if [[ "$bootloader_success" == "false" ]]; then
                    failed_step="bootloader installation"
                    break
                fi
                ;;
            8) # 설정 마무리
                # 네트워크 설정
                cat > /tmp/target/etc/systemd/network/20-wired.network << EOF
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF
                
                # 서비스 활성화
                systemctl enable systemd-networkd --root=/tmp/target >/dev/null 2>&1
                systemctl enable systemd-resolved --root=/tmp/target >/dev/null 2>&1
                systemctl enable ssh --root=/tmp/target >/dev/null 2>&1
                
                # 시스템 정보 파일 생성
                cat > /tmp/target/etc/hemmins-release << EOF
PRETTY_NAME="Hemmins OS 1.0"
NAME="Hemmins OS"
VERSION_ID="1.0"
VERSION="1.0"
ID=hemmins
HOME_URL="https://github.com/lukehemmin"
SUPPORT_URL="https://github.com/lukehemmin"
BUILD_DATE="$(date +%Y-%m-%d)"
INSTALLER_VERSION="1.0"
EOF
                ;;
            9) # 정리
                # 스왑 해제
                if [[ "$SWAP_SIZE" != "0" ]]; then
                    swapoff "$SWAP_PARTITION" >/dev/null 2>&1 || true
                fi
                
                # 마운트 해제
                umount /tmp/target/dev >/dev/null 2>&1 || true
                umount /tmp/target/proc >/dev/null 2>&1 || true
                umount /tmp/target/sys >/dev/null 2>&1 || true
                umount /tmp/target/boot/efi >/dev/null 2>&1 || true
                umount /tmp/target >/dev/null 2>&1 || true
                ;;
        esac
        
        sleep 0.5
    done
    
    # 설치 실패 처리
    if [[ -n "$failed_step" ]]; then
        unblock_signals
        echo
        log_error "Installation failed at: $failed_step"
        log_error "$(get_text error_install)"
        return 1
    fi
    
    # 설치 완료 - 시그널 블록 해제
    unblock_signals
    echo
    echo
}

# 설치 완료 화면 (시그널 보호)
show_completion() {
    # 완료 화면에서는 시그널 허용
    trap 'log_info "Installation completed successfully"; exit 0' INT TERM
    
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    local complete_text="$(get_text install_complete)"
    local padding=$(( (62 - ${#complete_text}) / 2 ))
    printf "║%*s%s%*s║\n" $padding "" "$complete_text" $((62 - ${#complete_text} - padding)) ""
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo -e "${WHITE}$(get_text install_success)${NC}"
    echo
    echo "$(get_text install_info)"
    echo "  • $(get_text disk): /dev/$SELECTED_DISK (${DISK_SIZE_GB}GB)"
    echo "  • $(get_text hostname_label): $HOSTNAME"
    echo "  • $(get_text administrator): $ADMIN_USER"
    echo "  • Bootloader: GRUB (UEFI/Legacy)"
    echo "  • OS: Hemmins OS 1.0"
    echo "  • Build: $(date +%Y-%m-%d)"
    echo
    echo -e "${YELLOW}$(get_text next_steps)${NC}"
    echo "$(get_text remove_media)"
    echo "$(get_text reboot_system)"
    echo "$(get_text boot_from_disk)"
    echo
    
    # Safe menu selection for reboot options
    local options=("$REBOOT_NOW" "$REBOOT_LATER")
    show_whiptail_menu "$REBOOT_OPTIONS" "Choose reboot option:" "${options[@]}"
    local choice=$?
    
    if [[ $choice -eq 0 ]]; then
        echo
        log_info "$(get_text rebooting)"
        sleep 3
        reboot
    fi
    
    # 완료 후 시그널 허용
    trap - INT TERM
}

# 에러 처리 (개선됨)
cleanup_on_error() {
    echo
    log_error "$(get_text error_install)"
    
    # 모든 마운트 해제
    if mountpoint -q /tmp/target/dev 2>/dev/null; then
        umount /tmp/target/dev || true
    fi
    if mountpoint -q /tmp/target/proc 2>/dev/null; then
        umount /tmp/target/proc || true
    fi
    if mountpoint -q /tmp/target/sys 2>/dev/null; then
        umount /tmp/target/sys || true
    fi
    if mountpoint -q /tmp/target/boot/efi 2>/dev/null; then
        umount /tmp/target/boot/efi || true
    fi
    if mountpoint -q /tmp/target 2>/dev/null; then
        umount /tmp/target || true
    fi
    
    # 스왑 해제
    if [[ -n "$SWAP_PARTITION" ]]; then
        swapoff "$SWAP_PARTITION" >/dev/null 2>&1 || true
    fi
    
    # 에러 발생 시 안전한 키 대기 (시그널 차단)
    echo -e "${YELLOW}에러가 발생했습니다. 아무 키나 누르면 종료됩니다.${NC}"
    
    # 안전한 키 대기 (최대 30초)
    local key_attempts=0
    while [[ $key_attempts -lt 30 ]]; do
        if bash -c 'trap "" INT TERM; read -n1 -s -t 1' 2>/dev/null; then
            break
        fi
        ((key_attempts++))
    done
    
    exit 1
}

trap cleanup_on_error ERR

# 디스크 정보 표시 함수 (개선됨 + 에러 처리)
show_disk_info() {
    local disk_info="Available Storage Devices:\n"
    
    # Safe command execution with error handling
    if command -v lsblk >/dev/null 2>&1; then
        disk_info+="$(lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,FSTYPE 2>/dev/null || echo 'Error getting disk info')\n\n"
    else
        disk_info+="lsblk command not available\n\n"
    fi
    
    disk_info+="Memory Information:\n"
    if command -v free >/dev/null 2>&1; then
        disk_info+="$(free -h 2>/dev/null || echo 'Error getting memory info')\n\n"
    else
        disk_info+="free command not available\n\n"
    fi
    
    disk_info+="Network Interfaces:\n"
    if command -v ip >/dev/null 2>&1; then
        disk_info+="$(ip addr show 2>/dev/null | grep -E '^[0-9]+:|inet ' | sed 's/^/  /' || echo '  Error getting network info')"
    else
        disk_info+="ip command not available"
    fi
    
    # Error handling for whiptail
    if ! show_whiptail_msgbox "$VIEW_DISK" "$disk_info"; then
        log_warning "Failed to display disk information dialog"
        echo -e "\n${YELLOW}Disk Information:${NC}"
        echo -e "$disk_info"
        echo -e "\n${YELLOW}Press any key to continue...${NC}"
        read -n1 -s
    fi
}

# 안전한 메인 루프 함수
safe_main_loop() {
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        log_info "Starting installer (attempt $((retry_count + 1))/$max_retries)"
        
        if main_installer; then
            log_success "Installer completed successfully"
            return 0
        else
            ((retry_count++))
            log_warning "Installer failed, attempt $retry_count/$max_retries"
            
            if [[ $retry_count -lt $max_retries ]]; then
                log_info "Restarting installer in 3 seconds..."
                sleep 3
            fi
        fi
    done
    
    log_error "Installer failed after $max_retries attempts"
    return 1
}

# 메인 설치 프로세스
main_installer() {
    # Root privilege check
    if [[ $EUID -ne 0 ]]; then
        clear
        log_error "$ERROR_ROOT"
        echo "$(get_formatted_text "$USE_SUDO" "$0")"
        exit 1
    fi
    
    # Set up signal handling for interactive mode
    setup_signal_handling
    
    # Language is fixed to English only
    LANG_CODE="en"
    
    # Network connection check
    check_network || log_warning "Continuing without network connection"
    
    # Main menu loop with enhanced error handling
    local menu_retry_count=0
    local max_menu_retries=5
    
    while true; do
        # Reset retry count on successful menu display
        if [[ $menu_retry_count -gt 0 ]]; then
            log_info "Menu retry count reset"
            menu_retry_count=0
        fi
        
        # Main menu
        local main_options=(
            "$START_INSTALL"
            "$VIEW_DISK"
            "Language (English only)"
            "$EXIT_INSTALLER"
        )
        
        # Safe menu display with error handling
        local choice
        if show_whiptail_menu "$INSTALLER_TITLE" "$WELCOME_MSG" "${main_options[@]}"; then
            choice=$?
        else
            ((menu_retry_count++))
            log_warning "Menu display failed (attempt $menu_retry_count/$max_menu_retries)"
            
            if [[ $menu_retry_count -ge $max_menu_retries ]]; then
                log_error "Menu failed too many times, falling back to text mode"
                echo -e "\n${CYAN}${BOLD}$INSTALLER_TITLE${NC}"
                echo -e "$WELCOME_MSG\n"
                echo "0) $START_INSTALL"
                echo "1) $VIEW_DISK"
                echo "2) Language (English only)"
                echo "3) $EXIT_INSTALLER"
                echo -e "\nEnter choice (0-3): "
                read -r choice
                
                # Validate input
                if ! [[ "$choice" =~ ^[0-3]$ ]]; then
                    log_warning "Invalid choice: $choice"
                    choice=255  # Treat as cancelled
                fi
            else
                sleep 2
                continue
            fi
        fi
        
        case $choice in
            0) # Start installation
                # Block signals during installation
                trap '' INT TERM QUIT HUP
                log_info "Starting installation process..."
                log_warning "Installation cannot be interrupted!"
                
                if select_disk; then
                    if select_install_type; then
                        if configure_partitions; then
                            if configure_users; then
                                if configure_system; then
                                    if show_summary; then
                                        if perform_installation; then
                                            show_completion
                                            break
                                        else
                                            # Installation failed, return to main menu
                                            trap 'echo; log_info "Use menu options to exit safely"; sleep 2' INT TERM
                                            show_whiptail_msgbox "Installation Failed" "Installation failed.\n\nReturning to main menu."
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
                # Return to main menu on any failure
                setup_signal_handling
                ;;
            1) # 디스크 정보 보기
                {
                    log_info "Showing disk information..."
                    show_disk_info || {
                        log_error "Failed to show disk information"
                        show_whiptail_msgbox "Error" "Failed to display disk information.\n\nReturning to main menu."
                    }
                } 2>/dev/null || {
                    log_error "Disk information display failed with error"
                    echo -e "${RED}Error occurred while showing disk information.${NC}"
                    echo -e "${YELLOW}Press any key to continue...${NC}"
                    read -n1 -s 2>/dev/null || sleep 2
                }
                ;;
            2) # Language (fixed to English)
                {
                    log_info "Showing language information..."
                    if ! whiptail --title "Language" --msgbox "Language is fixed to English during installation.\n\nKorean language support will be available after OS installation." 10 60; then
                        log_warning "Failed to display language dialog"
                        echo -e "\n${YELLOW}Language Information:${NC}"
                        echo "Language is fixed to English during installation."
                        echo "Korean language support will be available after OS installation."
                        echo -e "\n${YELLOW}Press any key to continue...${NC}"
                        read -n1 -s
                    fi
                } 2>/dev/null || {
                    log_error "Language dialog failed with error"
                    echo -e "${RED}Error occurred while showing language information.${NC}"
                    echo -e "${YELLOW}Press any key to continue...${NC}"
                    read -n1 -s 2>/dev/null || sleep 2
                }
                ;;
            3|255) # Exit or cancelled
                clear
                echo -e "${YELLOW}$EXIT_INSTALLER...${NC}"
                echo "Installation cancelled."
                echo "Exiting safely."
                sleep 1
                exit 0
                ;;
        esac
    done
}

# Global signal handling setup in main function

# 프로그램 시작 - 래퍼에서 호출되는지 확인
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 스크립트가 직접 실행된 경우
    if [[ -n "$INSTALLER_AUTO_RESTART" ]]; then
        # wrapper에서 호출된 경우 - 단순 실행
        main_installer "$@"
    else
        # 직접 실행된 경우 - 안전한 재시작 메커니즘 사용
        safe_main_loop "$@"
    fi
else
    # 스크립트가 소스로 로드된 경우
    main_installer "$@"
fi