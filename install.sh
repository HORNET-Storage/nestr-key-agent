#!/bin/bash
# Nestr Key Agent Installation Script for Linux/macOS

set -e

INSTALL_DIR="/usr/local/bin"
PRODUCT_NAME="keyagent"
REPO_OWNER="HORNET-Storage"
REPO_NAME="nestr-key-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case "$OS" in
        linux*)
            OS="linux"
            ;;
        darwin*)
            OS="darwin"
            ;;
        *)
            echo -e "${RED}Unsupported operating system: $OS${NC}"
            exit 1
            ;;
    esac
    
    case "$ARCH" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}Detected platform: ${OS}_${ARCH}${NC}"
}

# Get the latest release version
get_latest_version() {
    echo -e "${YELLOW}Fetching latest version...${NC}"
    VERSION=$(curl -s "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$VERSION" ]; then
        echo -e "${RED}Failed to fetch latest version${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Latest version: ${VERSION}${NC}"
}

# Download and install binaries
install_binaries() {
    DOWNLOAD_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${VERSION}/${REPO_NAME}_${VERSION#v}_${OS}_${ARCH}.tar.gz"
    
    echo -e "${YELLOW}Downloading from: ${DOWNLOAD_URL}${NC}"
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    if ! curl -L -o "keyagent.tar.gz" "$DOWNLOAD_URL"; then
        echo -e "${RED}Failed to download ${PRODUCT_NAME}${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    echo -e "${YELLOW}Extracting archive...${NC}"
    tar -xzf "keyagent.tar.gz"
    
    echo -e "${YELLOW}Installing binaries to ${INSTALL_DIR}...${NC}"
    
    if [ ! -w "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Requesting sudo access to install to ${INSTALL_DIR}${NC}"
        sudo install -m 755 "keyagent" "$INSTALL_DIR/"
        sudo install -m 755 "keyagent-cli" "$INSTALL_DIR/"
    else
        install -m 755 "keyagent" "$INSTALL_DIR/"
        install -m 755 "keyagent-cli" "$INSTALL_DIR/"
    fi
    
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✓ Binaries installed successfully!${NC}"
}

# Setup service for Linux (systemd)
setup_linux_service() {
    echo -e "${YELLOW}Setting up systemd service...${NC}"
    
    SERVICE_FILE="/etc/systemd/system/keyagent.service"
    
    cat << 'EOF' | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Nestr Key Agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/keyagent
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✓ Service file created${NC}"
    
    echo -e "${YELLOW}Enabling and starting service...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable keyagent.service
    sudo systemctl start keyagent.service
    
    sleep 2
    
    if sudo systemctl is-active --quiet keyagent.service; then
        echo -e "${GREEN}✓ Service is running${NC}"
    else
        echo -e "${RED}✗ Failed to start service${NC}"
        echo -e "${YELLOW}Check logs with: sudo journalctl -u keyagent.service${NC}"
    fi
}

# Setup service for macOS (launchd)
setup_macos_service() {
    echo -e "${YELLOW}Setting up LaunchAgent...${NC}"
    
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/io.hornet-storage.keyagent.plist"
    
    mkdir -p "$PLIST_DIR"
    
    cat << EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.hornet-storage.keyagent</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_DIR}/keyagent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/keyagent.log</string>
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/keyagent.log</string>
</dict>
</plist>
EOF

    echo -e "${GREEN}✓ LaunchAgent created${NC}"
    
    echo -e "${YELLOW}Loading and starting service...${NC}"
    
    # Create log directory
    sudo mkdir -p /usr/local/var/log
    sudo chown $(whoami) /usr/local/var/log
    
    launchctl load "$PLIST_FILE"
    launchctl start io.hornet-storage.keyagent
    
    sleep 2
    
    if launchctl list | grep -q "io.hornet-storage.keyagent"; then
        echo -e "${GREEN}✓ Service is running${NC}"
    else
        echo -e "${RED}✗ Failed to start service${NC}"
        echo -e "${YELLOW}Check logs at: /usr/local/var/log/keyagent.log${NC}"
    fi
}

# Setup service based on OS
setup_service() {
    echo ""
    echo -e "${YELLOW}Do you want to install the Key Agent as a background service?${NC}"
    echo -e "${YELLOW}This will make it start automatically on boot. (recommended)${NC}"
    read -p "Setup as service? [Y/n]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        if [ "$OS" = "linux" ]; then
            setup_linux_service
        elif [ "$OS" = "darwin" ]; then
            setup_macos_service
        fi
    else
        echo -e "${YELLOW}Skipping service setup.${NC}"
        echo -e "${YELLOW}You can start the agent manually with: keyagent${NC}"
    fi
}

# Verify installation
verify_installation() {
    echo ""
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    if command -v "$PRODUCT_NAME" &> /dev/null; then
        VERSION_OUTPUT=$("$PRODUCT_NAME" --version 2>&1 || echo "version unknown")
        echo -e "${GREEN}✓ ${PRODUCT_NAME} is installed: ${VERSION_OUTPUT}${NC}"
    else
        echo -e "${RED}✗ ${PRODUCT_NAME} was not found in PATH${NC}"
        echo -e "${YELLOW}You may need to add ${INSTALL_DIR} to your PATH${NC}"
    fi
    
    if command -v "keyagent-cli" &> /dev/null; then
        echo -e "${GREEN}✓ keyagent-cli is installed${NC}"
    else
        echo -e "${RED}✗ keyagent-cli was not found in PATH${NC}"
    fi
}

# Show usage information
show_usage() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo -e "${YELLOW}Key Agent is now running in the background.${NC}"
    echo ""
    echo -e "${YELLOW}Manage the service:${NC}"
    if [ "$OS" = "linux" ]; then
        echo "  Start:   sudo systemctl start keyagent"
        echo "  Stop:    sudo systemctl stop keyagent"
        echo "  Restart: sudo systemctl restart keyagent"
        echo "  Status:  sudo systemctl status keyagent"
        echo "  Logs:    sudo journalctl -u keyagent -f"
    elif [ "$OS" = "darwin" ]; then
        echo "  Start:   launchctl start io.hornet-storage.keyagent"
        echo "  Stop:    launchctl stop io.hornet-storage.keyagent"
        echo "  Status:  launchctl list | grep keyagent"
        echo "  Logs:    tail -f /usr/local/var/log/keyagent.log"
    fi
    echo ""
    echo -e "${YELLOW}Use the CLI tool:${NC}"
    echo "  keyagent-cli --help"
    echo ""
    echo -e "${YELLOW}For more information, visit: https://github.com/HORNET-Storage/nestr-key-agent${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
}

# Main installation flow
main() {
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   Nestr Key Agent Installation${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    
    detect_platform
    get_latest_version
    install_binaries
    setup_service
    verify_installation
    show_usage
}

main
