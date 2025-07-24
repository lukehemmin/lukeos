#!/bin/bash

# Hemmins OS Installer Auto-Restart Wrapper
# 설치 프로그램이 예기치 않게 종료될 때 자동으로 재시작하는 래퍼 스크립트

set -e

# 색상 및 스타일 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# 로그 함수들
log_info() { echo -e "${BLUE}[WRAPPER]${NC} $1"; }
log_success() { echo -e "${GREEN}[WRAPPER]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WRAPPER]${NC} $1"; }
log_error() { echo -e "${RED}[WRAPPER]${NC} $1"; }

# 설치 프로그램 경로
INSTALLER_PATH="/usr/local/bin/install-to-disk.sh"
INSTALLER_BACKUP_PATH="/home/installer/install-to-disk.sh"

# 환경 변수
export INSTALLER_AUTO_RESTART=1
export TERM=${TERM:-linux}

# 시그널 핸들링
cleanup_wrapper() {
    log_info "Installer wrapper shutting down..."
    exit 0
}

force_exit() {
    log_warning "Force exit requested"
    exit 0
}

# 시그널 트랩 설정
trap cleanup_wrapper TERM
trap force_exit INT

# 설치 프로그램 존재 여부 확인
check_installer() {
    if [[ -f "$INSTALLER_PATH" ]] && [[ -x "$INSTALLER_PATH" ]]; then
        return 0
    elif [[ -f "$INSTALLER_BACKUP_PATH" ]] && [[ -x "$INSTALLER_BACKUP_PATH" ]]; then
        INSTALLER_PATH="$INSTALLER_BACKUP_PATH"
        return 0
    else
        return 1
    fi
}

# 설치 완료 여부 확인
is_installation_complete() {
    # 설치가 완료되었는지 확인하는 다양한 방법
    
    # 1. 가장 확실한 방법: 설치 완료 후 래퍼 스크립트가 삭제되었는지 확인  
    if [[ ! -f "/usr/local/bin/install-to-disk.sh" ]] && [[ ! -f "/usr/local/bin/installer-wrapper.sh" ]]; then
        return 0
    fi
    
    # 2. 설치 중이 아닌 일반 시스템에서 실행 중인지 확인
    if ! grep -q "boot=live" /proc/cmdline 2>/dev/null; then
        return 0
    fi
    
    # 3. installer 사용자가 없는 경우 (이미 제거됨)
    if ! id installer >/dev/null 2>&1; then
        return 0
    fi
    
    # 4. 설치된 시스템의 흔적 확인 (백업 체크)
    if [[ -f "/etc/hemmins-release" ]] && ! grep -q "installer" /etc/passwd 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# 사용자가 의도적으로 종료했는지 확인
is_intentional_exit() {
    local exit_code=$1
    
    # Exit code 0 = 정상 종료 (설치 완료 또는 사용자가 Exit 선택)
    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi
    
    # Exit code 130 = Ctrl+C (SIGINT)
    if [[ $exit_code -eq 130 ]]; then
        return 0
    fi
    
    # Exit code 143 = SIGTERM
    if [[ $exit_code -eq 143 ]]; then
        return 0
    fi
    
    return 1
}

# 터미널 환경 설정
setup_terminal() {
    # UTF-8 환경 설정
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
    
    # 터미널 크기 설정
    if command -v resize >/dev/null 2>&1; then
        eval $(resize)
    fi
    
    # 콘솔 폰트 설정 (한글 지원)
    if [[ "$TERM" == "linux" ]] && command -v setfont >/dev/null 2>&1; then
        setfont /usr/share/consolefonts/Uni2-VGA16.psf.gz 2>/dev/null || \
        setfont /usr/share/consolefonts/unifont.psf.gz 2>/dev/null || \
        true
    fi
}

# 메인 래퍼 루프
main() {
    log_info "Hemmins OS Installer Auto-Restart Wrapper starting..."
    
    # 터미널 환경 설정
    setup_terminal
    
    # 설치 프로그램 확인
    if ! check_installer; then
        log_error "Installer script not found!"
        log_error "Looked for: $INSTALLER_PATH"
        log_error "Also looked for: $INSTALLER_BACKUP_PATH"
        echo -e "${RED}Installation cannot proceed without the installer script.${NC}"
        echo -e "${YELLOW}Please ensure the installer script is available.${NC}"
        sleep 10
        exit 1
    fi
    
    log_success "Found installer at: $INSTALLER_PATH"
    
    # 설치가 이미 완료되었는지 확인
    if is_installation_complete; then
        log_info "Installation appears to be complete. Not starting installer."
        echo -e "${GREEN}Hemmins OS installation is complete!${NC}"
        echo -e "${CYAN}You can now use your system normally.${NC}"
        exec /bin/bash --login
        exit 0
    fi
    
    local restart_count=0
    local max_restarts=10
    local restart_delay=3
    
    while [[ $restart_count -lt $max_restarts ]]; do
        clear
        
        if [[ $restart_count -gt 0 ]]; then
            echo -e "${CYAN}${BOLD}=== Hemmins OS Installer Auto-Restart ===${NC}"
            echo -e "${YELLOW}Installer restarted $restart_count time(s)${NC}"
            echo -e "${BLUE}Starting installer...${NC}"
            echo
            sleep 2
        fi
        
        # 설치 프로그램 실행
        log_info "Starting installer (attempt $((restart_count + 1))/$max_restarts)"
        
        # 설치 프로그램을 sudo로 실행
        sudo "$INSTALLER_PATH"
        local exit_code=$?
        
        log_info "Installer exited with code: $exit_code"
        
        # 설치 완료 여부 재확인
        if is_installation_complete; then
            log_success "Installation completed successfully!"
            
            # 성공적으로 설치 완료된 경우, wrapper 자기 제거
            if [[ -f "/usr/local/bin/installer-wrapper.sh" ]]; then
                log_info "Cleaning up installer wrapper..."
                sudo rm -f "/usr/local/bin/installer-wrapper.sh" 2>/dev/null || true
                rm -f "/home/installer/installer-wrapper.sh" 2>/dev/null || true
            fi
            break
        fi
        
        # 사용자가 의도적으로 종료했는지 확인
        if is_intentional_exit $exit_code; then
            log_info "User requested exit or installation completed"
            break
        fi
        
        # 예기치 않은 종료인 경우 재시작
        ((restart_count++))
        
        if [[ $restart_count -ge $max_restarts ]]; then
            log_error "Installer failed too many times ($max_restarts attempts)"
            echo -e "${RED}The installer has failed multiple times.${NC}"
            echo -e "${YELLOW}You can try running it manually with:${NC}"
            echo -e "${CYAN}sudo $INSTALLER_PATH${NC}"
            echo
            echo -e "${YELLOW}Or access the shell to troubleshoot the issue.${NC}"
            echo -e "${BLUE}Press any key to continue to shell...${NC}"
            read -n1 -s
            exec /bin/bash --login
            break
        fi
        
        # 재시작 안내 및 대기
        echo
        log_warning "Installer exited unexpectedly (exit code: $exit_code)"
        echo -e "${YELLOW}The installer will automatically restart in $restart_delay seconds...${NC}"
        echo -e "${CYAN}Press Ctrl+C to cancel auto-restart and access shell${NC}"
        
        # 사용자가 Ctrl+C를 누를 수 있도록 interruptible sleep
        local count=0
        while [[ $count -lt $restart_delay ]]; do
            sleep 1
            ((count++))
            printf "\r${BLUE}Restarting in %d seconds... ${NC}" $((restart_delay - count))
        done
        echo
    done
    
    # 최종 정리
    log_info "Installer wrapper finished"
    
    # 설치가 완료되지 않은 경우 쉘 제공
    if ! is_installation_complete; then
        echo -e "${YELLOW}Starting interactive shell...${NC}"
        echo -e "${CYAN}You can run the installer manually with: sudo $INSTALLER_PATH${NC}"
        exec /bin/bash --login
    fi
}

# 스크립트가 직접 실행된 경우에만 main 함수 호출
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi