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

# 기본 언어 설정
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

# 언어별 텍스트 정의
declare -A TEXTS

# 영어 텍스트
TEXTS[en_title]="Hemmins OS Installer"
TEXTS[en_welcome]="Welcome to Hemmins OS Installation"
TEXTS[en_start_install]="Start Installation"
TEXTS[en_view_disk]="View Disk Information"
TEXTS[en_language]="Language / 언어"
TEXTS[en_exit]="Exit"
TEXTS[en_cancel]="Cancel"
TEXTS[en_continue]="Continue"
TEXTS[en_yes]="Yes"
TEXTS[en_no]="No"
TEXTS[en_back]="Back"
TEXTS[en_next]="Next"
TEXTS[en_arrow_keys]="Arrow keys to select, Enter to confirm"

# 디스크 관련
TEXTS[en_select_disk]="Select disk to install:"
TEXTS[en_install_type]="Select installation type:"
TEXTS[en_full_disk]="Use entire disk (erase existing data)"
TEXTS[en_manual_partition]="Manual partition setup"
TEXTS[en_partition_config]="Partition Configuration"
TEXTS[en_efi_size]="EFI partition size (MB):"
TEXTS[en_swap_size]="Swap partition size (MB, 0=disable):"
TEXTS[en_configured_partitions]="Configured partitions:"
TEXTS[en_remaining_space]="remaining space"
TEXTS[en_continue_question]="Continue? (y/n):"
TEXTS[en_disk_too_small]="Disk is too small! Minimum 8GB required, found %dGB."
TEXTS[en_usb_warning]="Warning: This appears to be a USB drive. Are you sure? (y/n):"
TEXTS[en_partition_too_large]="Total partition size (%dMB) exceeds disk capacity (%dMB)!"

# 네트워크 관련
TEXTS[en_network_check]="Checking network connectivity..."
TEXTS[en_network_ok]="Network connection available"
TEXTS[en_network_warning]="No network connection detected. Continue anyway? (y/n):"

# 비밀번호 관련
TEXTS[en_password_strength]="Password strength: %s"
TEXTS[en_password_weak]="Weak"
TEXTS[en_password_medium]="Medium"
TEXTS[en_password_strong]="Strong"
TEXTS[en_password_too_weak]="Password is too weak! Use at least 6 characters. Continue? (y/n):"

# 사용자 관련
TEXTS[en_user_config]="User Account Configuration"
TEXTS[en_admin_username]="Administrator username:"
TEXTS[en_admin_password]="Administrator password:"
TEXTS[en_confirm_password]="Confirm password:"
TEXTS[en_root_password]="Root password:"
TEXTS[en_password_mismatch]="Passwords do not match. Please try again."
TEXTS[en_default]="default"
TEXTS[en_invalid_username]="Invalid username! Use only lowercase letters and numbers."

# 시스템 관련
TEXTS[en_system_config]="System Configuration"
TEXTS[en_hostname]="Hostname:"
TEXTS[en_invalid_hostname]="Invalid hostname! Use only letters, numbers, and hyphens."

# 설치 관련
TEXTS[en_install_summary]="Installation Summary"
TEXTS[en_disk]="Disk"
TEXTS[en_install_type_label]="Installation type"
TEXTS[en_full_disk_label]="Full disk"
TEXTS[en_manual_label]="Manual setup"
TEXTS[en_efi_partition]="EFI partition"
TEXTS[en_swap_partition]="Swap partition"
TEXTS[en_hostname_label]="Hostname"
TEXTS[en_administrator]="Administrator"
TEXTS[en_warning_text]="WARNING: All data on /dev/%s will be erased!"
TEXTS[en_start_confirm]="Start installation? (yes/no):"
TEXTS[en_installing]="Installing Hemmins OS..."
TEXTS[en_install_complete]="Installation Complete!"
TEXTS[en_install_success]="System has been successfully installed."
TEXTS[en_install_info]="Installed System Information:"
TEXTS[en_next_steps]="Next Steps:"
TEXTS[en_remove_media]="1. Remove USB/CD media"
TEXTS[en_reboot_system]="2. Reboot the system"
TEXTS[en_boot_from_disk]="3. Hemmins OS will boot from hard disk"
TEXTS[en_reboot_options]="Reboot Options:"
TEXTS[en_reboot_now]="Reboot now"
TEXTS[en_reboot_later]="Reboot manually later"
TEXTS[en_rebooting]="Rebooting in 3 seconds..."

# 설치 단계
TEXTS[en_step_disk_prep]="Preparing disk"
TEXTS[en_step_partition]="Creating partitions"
TEXTS[en_step_filesystem]="Creating filesystems"
TEXTS[en_step_mount]="Mounting partitions"
TEXTS[en_step_copy]="Copying system files"
TEXTS[en_step_config]="Configuring system"
TEXTS[en_step_users]="Setting up user accounts"
TEXTS[en_step_bootloader]="Installing bootloader"
TEXTS[en_step_finalize]="Finalizing configuration"
TEXTS[en_step_cleanup]="Cleaning up"

# Legacy BIOS 관련
TEXTS[en_uefi_failed]="UEFI installation failed, trying Legacy BIOS..."
TEXTS[en_legacy_fallback]="Falling back to Legacy BIOS installation"

# 에러 메시지
TEXTS[en_error_root]="This installer must be run as root."
TEXTS[en_error_disk_not_found]="Disk /dev/%s not found."
TEXTS[en_error_install]="An error occurred during installation!"
TEXTS[en_error_partition_failed]="Failed to create partitions!"
TEXTS[en_error_filesystem_failed]="Failed to create filesystems!"
TEXTS[en_error_mount_failed]="Failed to mount partitions!"
TEXTS[en_error_copy_failed]="Failed to copy system files!"
TEXTS[en_error_bootloader_failed]="Failed to install bootloader!"
TEXTS[en_use_sudo]="Use: sudo %s"
TEXTS[en_press_key]="Press any key to continue..."

# 한국어 텍스트
TEXTS[ko_title]="Hemmins OS 설치 프로그램"
TEXTS[ko_welcome]="Hemmins OS 설치에 오신 것을 환영합니다"
TEXTS[ko_start_install]="설치 시작"
TEXTS[ko_view_disk]="디스크 정보 보기"
TEXTS[ko_language]="언어 선택 / Language"
TEXTS[ko_exit]="종료"
TEXTS[ko_cancel]="취소"
TEXTS[ko_continue]="계속"
TEXTS[ko_yes]="예"
TEXTS[ko_no]="아니오"
TEXTS[ko_back]="뒤로"
TEXTS[ko_next]="다음"
TEXTS[ko_arrow_keys]="화살표 키로 선택, Enter로 확인"

# 디스크 관련
TEXTS[ko_select_disk]="설치할 디스크를 선택하세요:"
TEXTS[ko_install_type]="설치 유형을 선택하세요:"
TEXTS[ko_full_disk]="전체 디스크 사용 (기존 데이터 삭제)"
TEXTS[ko_manual_partition]="수동 파티션 설정"
TEXTS[ko_partition_config]="파티션 설정"
TEXTS[ko_efi_size]="EFI 파티션 크기 (MB):"
TEXTS[ko_swap_size]="스왑 파티션 크기 (MB, 0=사용안함):"
TEXTS[ko_configured_partitions]="설정된 파티션:"
TEXTS[ko_remaining_space]="나머지 전체"
TEXTS[ko_continue_question]="계속하시겠습니까? (y/n):"
TEXTS[ko_disk_too_small]="디스크가 너무 작습니다! 최소 8GB 필요, %dGB 발견."
TEXTS[ko_usb_warning]="경고: USB 드라이브로 보입니다. 계속하시겠습니까? (y/n):"
TEXTS[ko_partition_too_large]="전체 파티션 크기(%dMB)가 디스크 용량(%dMB)을 초과합니다!"

# 네트워크 관련
TEXTS[ko_network_check]="네트워크 연결 확인 중..."
TEXTS[ko_network_ok]="네트워크 연결 사용 가능"
TEXTS[ko_network_warning]="네트워크 연결이 감지되지 않습니다. 계속하시겠습니까? (y/n):"

# 비밀번호 관련
TEXTS[ko_password_strength]="비밀번호 강도: %s"
TEXTS[ko_password_weak]="약함"
TEXTS[ko_password_medium]="보통"
TEXTS[ko_password_strong]="강함"
TEXTS[ko_password_too_weak]="비밀번호가 너무 약합니다! 최소 6자 이상 사용하세요. 계속하시겠습니까? (y/n):"

# 사용자 관련
TEXTS[ko_user_config]="사용자 계정 설정"
TEXTS[ko_admin_username]="관리자 사용자명:"
TEXTS[ko_admin_password]="관리자 비밀번호:"
TEXTS[ko_confirm_password]="비밀번호 확인:"
TEXTS[ko_root_password]="root 비밀번호:"
TEXTS[ko_password_mismatch]="비밀번호가 일치하지 않습니다. 다시 입력하세요."
TEXTS[ko_default]="기본값"
TEXTS[ko_invalid_username]="잘못된 사용자명입니다! 소문자와 숫자만 사용하세요."

# 시스템 관련
TEXTS[ko_system_config]="시스템 설정"
TEXTS[ko_hostname]="호스트명:"
TEXTS[ko_invalid_hostname]="잘못된 호스트명입니다! 문자, 숫자, 하이픈만 사용하세요."

# 설치 관련
TEXTS[ko_install_summary]="설치 요약"
TEXTS[ko_disk]="디스크"
TEXTS[ko_install_type_label]="설치 유형"
TEXTS[ko_full_disk_label]="전체 디스크"
TEXTS[ko_manual_label]="수동 설정"
TEXTS[ko_efi_partition]="EFI 파티션"
TEXTS[ko_swap_partition]="스왑 파티션"
TEXTS[ko_hostname_label]="호스트명"
TEXTS[ko_administrator]="관리자"
TEXTS[ko_warning_text]="경고: /dev/%s의 모든 데이터가 삭제됩니다!"
TEXTS[ko_start_confirm]="설치를 시작하시겠습니까? (yes/no):"
TEXTS[ko_installing]="Hemmins OS 설치 중..."
TEXTS[ko_install_complete]="설치 완료!"
TEXTS[ko_install_success]="시스템이 성공적으로 설치되었습니다."
TEXTS[ko_install_info]="설치된 시스템 정보:"
TEXTS[ko_next_steps]="다음 단계:"
TEXTS[ko_remove_media]="1. USB/CD를 제거하세요"
TEXTS[ko_reboot_system]="2. 시스템을 재부팅하세요"
TEXTS[ko_boot_from_disk]="3. 하드디스크에서 Hemmins OS가 부팅됩니다"
TEXTS[ko_reboot_options]="재부팅 옵션:"
TEXTS[ko_reboot_now]="지금 재부팅"
TEXTS[ko_reboot_later]="나중에 수동으로 재부팅"
TEXTS[ko_rebooting]="3초 후 재부팅합니다..."

# 설치 단계
TEXTS[ko_step_disk_prep]="디스크 준비"
TEXTS[ko_step_partition]="파티션 생성"
TEXTS[ko_step_filesystem]="파일시스템 생성"
TEXTS[ko_step_mount]="파티션 마운트"
TEXTS[ko_step_copy]="시스템 파일 복사"
TEXTS[ko_step_config]="시스템 설정"
TEXTS[ko_step_users]="사용자 계정 설정"
TEXTS[ko_step_bootloader]="부트로더 설치"
TEXTS[ko_step_finalize]="설정 마무리"
TEXTS[ko_step_cleanup]="정리"

# Legacy BIOS 관련
TEXTS[ko_uefi_failed]="UEFI 설치 실패, Legacy BIOS 시도 중..."
TEXTS[ko_legacy_fallback]="Legacy BIOS 설치로 전환"

# 에러 메시지
TEXTS[ko_error_root]="이 설치 프로그램은 root 권한으로 실행해야 합니다."
TEXTS[ko_error_disk_not_found]="디스크 /dev/%s를 찾을 수 없습니다."
TEXTS[ko_error_install]="설치 중 에러가 발생했습니다!"
TEXTS[ko_error_partition_failed]="파티션 생성에 실패했습니다!"
TEXTS[ko_error_filesystem_failed]="파일시스템 생성에 실패했습니다!"
TEXTS[ko_error_mount_failed]="파티션 마운트에 실패했습니다!"
TEXTS[ko_error_copy_failed]="시스템 파일 복사에 실패했습니다!"
TEXTS[ko_error_bootloader_failed]="부트로더 설치에 실패했습니다!"
TEXTS[ko_use_sudo]="다음 명령을 사용하세요: sudo %s"
TEXTS[ko_press_key]="아무 키나 누르면 계속됩니다..."

# 텍스트 가져오기 함수
get_text() {
    local key="${LANG_CODE}_$1"
    local text="${TEXTS[$key]}"
    if [[ -z "$text" ]]; then
        # 폴백: 영어 텍스트 사용
        text="${TEXTS[en_$1]}"
    fi
    echo "$text"
}

# 포맷된 텍스트 가져오기 함수
get_formatted_text() {
    local key="$1"
    shift
    local text=$(get_text "$key")
    printf "$text" "$@"
}

# 네트워크 연결 확인 함수
check_network() {
    echo -e "${BLUE}$(get_text network_check)${NC}"
    
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
        log_success "$(get_text network_ok)"
        return 0
    else
        log_warning "$(get_text network_warning)"
        read -p "" confirm
        [[ "$confirm" == "y" ]]
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

# 언어 선택 함수
select_language() {
    local languages=("English" "한국어 (Korean)")
    local selected=0
    local key=""
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                Language Selection / 언어 선택                  ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo
        echo -e "${WHITE}${BOLD}Select Language / 언어를 선택하세요${NC}"
        echo
        
        for i in "${!languages[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "${GREEN}${BOLD}▶ ${languages[i]}${NC}"
            else
                echo -e "  ${languages[i]}"
            fi
        done
        
        echo
        echo -e "${YELLOW}Arrow keys to select, Enter to confirm${NC}"
        echo -e "${YELLOW}화살표 키로 선택, Enter로 확인${NC}"
        
        read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A') ((selected > 0)) && ((selected--)) ;;
                    '[B') ((selected < ${#languages[@]} - 1)) && ((selected++)) ;;
                esac
                ;;
            '') 
                case $selected in
                    0) LANG_CODE="en" ;;
                    1) LANG_CODE="ko" ;;
                esac
                return 0
                ;;
        esac
    done
}

# 로그 및 UI 함수들
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 메뉴 선택 함수
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local key=""
    
    while true; do
        clear
        
        # 헤더
        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        local header_text="$(get_text title)"
        local padding=$(( (62 - ${#header_text}) / 2 ))
        printf "║%*s%s%*s║\n" $padding "" "$header_text" $((62 - ${#header_text} - padding)) ""
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo
        echo -e "${WHITE}${BOLD}$title${NC}"
        echo
        
        # 메뉴 옵션들
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "${GREEN}${BOLD}▶ ${options[i]}${NC}"
            else
                echo -e "  ${options[i]}"
            fi
        done
        
        echo
        echo -e "${YELLOW}$(get_text arrow_keys)${NC}"
        
        read -rsn1 key
        case "$key" in
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A') ((selected > 0)) && ((selected--)) ;;
                    '[B') ((selected < ${#options[@]} - 1)) && ((selected++)) ;;
                esac
                ;;
            '') return $selected ;;
        esac
    done
}

# 텍스트 입력 함수 (개선됨)
get_input() {
    local prompt="$1"
    local default="$2"
    local is_password="$3"
    local input=""
    
    echo -e "${WHITE}${BOLD}$prompt${NC}"
    if [[ -n "$default" ]]; then
        echo -e "${YELLOW}($(get_text default): $default)${NC}"
    fi
    echo -n "> "
    
    if [[ "$is_password" == "true" ]]; then
        read -s input
        echo
        
        # 비밀번호 강도 확인
        if [[ -n "$input" ]]; then
            local strength=$(check_password_strength "$input")
            check_password_strength "$input" >/dev/null
            local strength_level=$?
            
            echo -e "${CYAN}$(get_formatted_text password_strength "$strength")${NC}"
            
            # 너무 약한 비밀번호 경고
            if [[ $strength_level -lt 2 ]] && [[ ${#input} -lt 6 ]]; then
                echo -e "${RED}$(get_text password_too_weak)${NC}"
                read -p "" confirm
                [[ "$confirm" != "y" ]] && return 1
            fi
        fi
    else
        read input
    fi
    
    echo "${input:-$default}"
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
    
    disk_info+=("$(get_text cancel)")
    
    show_menu "$(get_text select_disk)" "${disk_info[@]}"
    local choice=$?
    
    if [[ $choice -eq ${#disk_info[@]}-1 ]]; then
        return 1  # 취소
    fi
    
    SELECTED_DISK="${disks[$choice]}"
    
    # 디스크 존재 확인
    if [[ ! -b "/dev/$SELECTED_DISK" ]]; then
        log_error "$(get_formatted_text error_disk_not_found "$SELECTED_DISK")"
        return 1
    fi
    
    # 디스크 크기 확인
    DISK_SIZE_GB=$(get_disk_size_gb "$SELECTED_DISK")
    if [[ $DISK_SIZE_GB -lt 8 ]]; then
        log_error "$(get_formatted_text disk_too_small "$DISK_SIZE_GB")"
        return 1
    fi
    
    # USB 디스크 경고
    if is_usb_disk "$SELECTED_DISK"; then
        echo -e "${YELLOW}$(get_text usb_warning)${NC}"
        read -p "" confirm
        [[ "$confirm" != "y" ]] && return 1
    fi
    
    return 0
}

# 설치 타입 선택
select_install_type() {
    local types=(
        "$(get_text full_disk)"
        "$(get_text manual_partition)"
        "$(get_text cancel)"
    )
    
    show_menu "$(get_text install_type)" "${types[@]}"
    local choice=$?
    
    case $choice in
        0) INSTALL_TYPE="full" ;;
        1) INSTALL_TYPE="manual" ;;
        2) return 1 ;;
    esac
    return 0
}

# 파티션 크기 설정 (개선됨)
configure_partitions() {
    if [[ "$INSTALL_TYPE" == "manual" ]]; then
        clear
        echo -e "${CYAN}${BOLD}$(get_text partition_config)${NC}"
        echo
        echo "Available disk space: ${DISK_SIZE_GB}GB ($((DISK_SIZE_GB * 1024))MB)"
        echo
        
        while true; do
            EFI_SIZE=$(get_input "$(get_text efi_size)" "512")
            SWAP_SIZE=$(get_input "$(get_text swap_size)" "2048")
            
            # 숫자 검증
            if ! [[ "$EFI_SIZE" =~ ^[0-9]+$ ]] || ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
                log_error "Invalid partition size!"
                continue
            fi
            
            # 파티션 크기 검증
            TOTAL_REQUIRED_SIZE=$((EFI_SIZE + SWAP_SIZE + 4096))  # 최소 4GB 루트
            local disk_mb=$((DISK_SIZE_GB * 1024))
            
            if [[ $TOTAL_REQUIRED_SIZE -gt $disk_mb ]]; then
                log_error "$(get_formatted_text partition_too_large "$TOTAL_REQUIRED_SIZE" "$disk_mb")"
                continue
            fi
            
            break
        done
        
        echo
        echo "$(get_text configured_partitions)"
        echo "  EFI: ${EFI_SIZE}MB"
        echo "  Swap: ${SWAP_SIZE}MB"
        echo "  Root: $((disk_mb - EFI_SIZE - SWAP_SIZE))MB"
        echo
        
        read -p "$(get_text continue_question) " confirm
        [[ "$confirm" != "y" ]] && return 1
    fi
    return 0
}

# 사용자 설정 (개선됨)
configure_users() {
    clear
    echo -e "${CYAN}${BOLD}$(get_text user_config)${NC}"
    echo
    
    # 사용자명 입력 및 검증
    while true; do
        ADMIN_USER=$(get_input "$(get_text admin_username)" "admin")
        
        # 사용자명 검증 (더 엄격함)
        if [[ "$ADMIN_USER" =~ ^[a-z][a-z0-9_-]*$ ]] && [[ ${#ADMIN_USER} -ge 3 ]] && [[ ${#ADMIN_USER} -le 32 ]]; then
            break
        else
            echo -e "${RED}$(get_text invalid_username)${NC}"
            echo
        fi
    done
    
    # 비밀번호 입력 및 검증
    while true; do
        ADMIN_PASS=$(get_input "$(get_text admin_password)" "" "true")
        if [[ $? -ne 0 ]]; then
            continue  # 비밀번호가 너무 약해서 거부됨
        fi
        
        local confirm_pass=$(get_input "$(get_text confirm_password)" "" "true")
        
        if [[ "$ADMIN_PASS" == "$confirm_pass" ]] && [[ -n "$ADMIN_PASS" ]]; then
            break
        else
            echo -e "${RED}$(get_text password_mismatch)${NC}"
            echo
        fi
    done
    
    # Root 비밀번호
    while true; do
        ROOT_PASS=$(get_input "$(get_text root_password)" "" "true")
        if [[ -n "$ROOT_PASS" ]]; then
            break
        else
            log_error "Root password cannot be empty!"
        fi
    done
    
    return 0
}

# 시스템 설정 (개선됨)
configure_system() {
    clear
    echo -e "${CYAN}${BOLD}$(get_text system_config)${NC}"
    echo
    
    while true; do
        HOSTNAME=$(get_input "$(get_text hostname)" "hemmins-os")
        
        # 호스트명 검증 (더 엄격함)
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] && [[ ${#HOSTNAME} -le 63 ]]; then
            break
        else
            echo -e "${RED}$(get_text invalid_hostname)${NC}"
            echo
        fi
    done
    
    return 0
}

# 설치 요약 표시
show_summary() {
    clear
    echo -e "${CYAN}${BOLD}$(get_text install_summary)${NC}"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}$(get_text disk):${NC} /dev/$SELECTED_DISK (${DISK_SIZE_GB}GB)"
    
    if [[ "$INSTALL_TYPE" == "full" ]]; then
        echo -e "${WHITE}$(get_text install_type_label):${NC} $(get_text full_disk_label)"
    else
        echo -e "${WHITE}$(get_text install_type_label):${NC} $(get_text manual_label)"
        echo -e "${WHITE}$(get_text efi_partition):${NC} ${EFI_SIZE}MB"
        echo -e "${WHITE}$(get_text swap_partition):${NC} ${SWAP_SIZE}MB"
    fi
    
    echo -e "${WHITE}$(get_text hostname_label):${NC} $HOSTNAME"
    echo -e "${WHITE}$(get_text administrator):${NC} $ADMIN_USER"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    echo -e "${RED}${BOLD}$(get_formatted_text warning_text "$SELECTED_DISK")${NC}"
    echo
    
    read -p "$(get_text start_confirm) " confirm
    [[ "$confirm" == "yes" ]]
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

# 실제 설치 수행 (대폭 개선됨)
perform_installation() {
    clear
    echo -e "${CYAN}${BOLD}$(get_text installing)${NC}"
    echo
    
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
        echo
        log_error "Installation failed at: $failed_step"
        log_error "$(get_text error_install)"
        return 1
    fi
    
    echo
    echo
}

# 설치 완료 화면
show_completion() {
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
    
    local options=("$(get_text reboot_now)" "$(get_text reboot_later)")
    show_menu "$(get_text reboot_options)" "${options[@]}"
    local choice=$?
    
    if [[ $choice -eq 0 ]]; then
        echo
        log_info "$(get_text rebooting)"
        sleep 3
        reboot
    fi
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
    
    read -p "$(get_text press_key)"
    exit 1
}

trap cleanup_on_error ERR

# 디스크 정보 표시 함수 (개선됨)
show_disk_info() {
    clear
    echo -e "${CYAN}${BOLD}$(get_text view_disk)${NC}"
    echo
    echo "Available Storage Devices:"
    echo "=========================="
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,FSTYPE
    echo
    echo "Memory Information:"
    echo "=================="
    free -h
    echo
    echo "Network Interfaces:"
    echo "=================="
    ip addr show | grep -E '^[0-9]+:|inet ' | sed 's/^/  /'
    echo
    read -p "$(get_text press_key)"
}

# 메인 설치 프로세스
main() {
    # 루트 권한 확인
    if [[ $EUID -ne 0 ]]; then
        clear
        log_error "$(get_text error_root)"
        echo "$(get_formatted_text use_sudo "$0")"
        exit 1
    fi
    
    # 언어 선택
    select_language
    
    # 네트워크 연결 확인
    check_network || log_warning "Continuing without network connection"
    
    # 메인 루프
    while true; do
        # 메인 메뉴
        local main_options=(
            "$(get_text start_install)"
            "$(get_text view_disk)"
            "$(get_text language)"
            "$(get_text exit)"
        )
        
        show_menu "$(get_text welcome)" "${main_options[@]}"
        local choice=$?
        
        case $choice in
            0) # 설치 시작
                # 설치 단계들을 순차적으로 실행
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
                                            # 설치 실패 시 메뉴로 돌아감
                                            read -p "$(get_text press_key)"
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
                # 어느 단계에서든 실패하면 메인 메뉴로 돌아감
                ;;
            1) # 디스크 정보 보기
                show_disk_info
                ;;
            2) # 언어 변경
                select_language
                ;;
            3) # 종료
                clear
                if [[ "$LANG_CODE" == "ko" ]]; then
                    echo "설치를 취소했습니다."
                else
                    echo "Installation cancelled."
                fi
                exit 0
                ;;
        esac
    done
}

# 시그널 처리
trap 'echo; log_info "Installation interrupted by user"; exit 1' INT TERM

# 프로그램 시작
main "$@"