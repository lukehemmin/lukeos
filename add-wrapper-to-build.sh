#!/bin/bash

# Patch script to add installer wrapper to the build script

BUILD_SCRIPT="build-custom-iso-safe.sh"

if [[ ! -f "$BUILD_SCRIPT" ]]; then
    echo "Error: $BUILD_SCRIPT not found!"
    exit 1
fi

echo "Adding installer wrapper installation to build script..."

# Find the line number after the installer script installation
LINE_NUM=$(grep -n "sudo chmod +x chroot/home/installer/install-to-disk.sh" "$BUILD_SCRIPT" | cut -d: -f1)

if [[ -z "$LINE_NUM" ]]; then
    echo "Error: Could not find installer script installation line!"
    exit 1
fi

echo "Found installer installation at line $LINE_NUM"

# Create temporary file with the wrapper installation code
cat > wrapper_install.tmp << 'EOF'

# 설치 래퍼 스크립트 추가
if [[ -f "../installer-wrapper.sh" ]]; then
    log_info "Installing auto-restart wrapper script..."
    
    # 래퍼 스크립트 검증
    if ! bash -n ../installer-wrapper.sh; then
        log_error "installer-wrapper.sh에 문법 오류가 있습니다!"
        exit 1
    fi
    
    # 래퍼 스크립트를 시스템에 복사
    sudo cp ../installer-wrapper.sh chroot/usr/local/bin/
    sudo chmod +x chroot/usr/local/bin/installer-wrapper.sh
    
    # installer 사용자 홈에도 복사 (백업용)
    sudo cp ../installer-wrapper.sh chroot/home/installer/
    sudo chown 1001:1001 chroot/home/installer/installer-wrapper.sh
    sudo chmod +x chroot/home/installer/installer-wrapper.sh
    
    log_success "Auto-restart wrapper script installed"
else
    log_error "installer-wrapper.sh not found! Auto-restart functionality will not be available."
    exit 1
fi

EOF

# Insert the wrapper installation code after the installer script installation
head -n "$LINE_NUM" "$BUILD_SCRIPT" > build_temp.sh
cat wrapper_install.tmp >> build_temp.sh
tail -n +"$((LINE_NUM + 1))" "$BUILD_SCRIPT" >> build_temp.sh

# Replace the original file
mv build_temp.sh "$BUILD_SCRIPT"
chmod +x "$BUILD_SCRIPT"

# Clean up
rm wrapper_install.tmp

echo "Successfully added wrapper installation to build script!"
echo "The build script now includes auto-restart functionality."