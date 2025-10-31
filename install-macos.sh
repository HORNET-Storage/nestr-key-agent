#!/bin/bash
# macOS Installation Script for Nestr Key Agent
# This script automates the installation and launchd setup

set -e

BINARY_NAME="keyagent"
SERVICE_NAME="com.hornetstorage.nestr-key-agent"
INSTALL_DIR="/usr/local/bin"
PLIST_DIR="/Library/LaunchDaemons"
PLIST_FILE="${PLIST_DIR}/${SERVICE_NAME}.plist"
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/nestr-key-agent.log"
ERR_FILE="${LOG_DIR}/nestr-key-agent.err"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}Nestr Key Agent - macOS Installer${NC}"
echo -e "${GREEN}===================================${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run with sudo${NC}"
  echo "Usage: sudo bash install-macos.sh"
  exit 1
fi

# Check if binary exists in current directory
if [ ! -f "./${BINARY_NAME}" ]; then
  echo -e "${RED}Error: ${BINARY_NAME} binary not found in current directory${NC}"
  echo "Please extract the release archive first:"
  echo "  tar -xzf nestr-key-agent_VERSION_darwin_amd64.tar.gz"
  echo "  cd nestr-key-agent_VERSION_darwin_amd64"
  echo "  sudo bash install-macos.sh"
  exit 1
fi

# Stop existing service if running
if launchctl list | grep -q "${SERVICE_NAME}"; then
  echo -e "${YELLOW}Stopping existing service...${NC}"
  launchctl bootout system/"${SERVICE_NAME}" 2>/dev/null || true
  launchctl unload "${PLIST_FILE}" 2>/dev/null || true
  sleep 2
fi

# Copy binary
echo -e "${GREEN}Installing binary to ${INSTALL_DIR}...${NC}"
cp "${BINARY_NAME}" "${INSTALL_DIR}/"
chmod 755 "${INSTALL_DIR}/${BINARY_NAME}"

# Create launchd plist
echo -e "${GREEN}Creating launchd service configuration...${NC}"
cat > "${PLIST_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SERVICE_NAME}</string>

  <key>ProgramArguments</key>
  <array>
    <string>${INSTALL_DIR}/${BINARY_NAME}</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>

  <key>StandardErrorPath</key>
  <string>${ERR_FILE}</string>

  <key>WorkingDirectory</key>
  <string>/tmp</string>
</dict>
</plist>
EOF

chmod 644 "${PLIST_FILE}"

# Load and start service
echo -e "${GREEN}Starting service...${NC}"
launchctl bootstrap system "${PLIST_FILE}"
launchctl enable system/"${SERVICE_NAME}"

# Wait a moment for service to start
sleep 2

# Check if service is running
if launchctl list | grep -q "${SERVICE_NAME}"; then
  echo
  echo -e "${GREEN}✓ Installation successful!${NC}"
  echo
  echo "Service Status:"
  launchctl list | grep "${SERVICE_NAME}" || echo "Service check failed"
  echo
  echo "Useful Commands:"
  echo "  Check status:  sudo launchctl list | grep ${SERVICE_NAME}"
  echo "  View logs:     tail -f ${LOG_FILE}"
  echo "  View errors:   tail -f ${ERR_FILE}"
  echo "  Stop service:  sudo launchctl bootout system/${SERVICE_NAME}"
  echo "  Start service: sudo launchctl bootstrap system ${PLIST_FILE}"
  echo
else
  echo
  echo -e "${YELLOW}⚠ Service installed but may not be running${NC}"
  echo "Check logs for errors:"
  echo "  tail ${ERR_FILE}"
  echo
fi

echo -e "${GREEN}Installation complete!${NC}"
