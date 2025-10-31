#!/bin/bash
# Quick macOS Installation Script for Nestr Key Agent
# Downloads latest release and installs automatically
# Usage: curl -sSL https://raw.githubusercontent.com/HORNET-Storage/nestr-key-agent/main/scripts/install-macos-quick.sh | sudo bash

set -e

REPO="HORNET-Storage/nestr-key-agent"
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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}===================================${NC}"
echo -e "${GREEN}Nestr Key Agent - Quick Installer${NC}"
echo -e "${GREEN}===================================${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run with sudo${NC}"
  echo "Please run:"
  echo "  curl -sSL https://raw.githubusercontent.com/HORNET-Storage/nestr-key-agent/main/scripts/install-macos-quick.sh | sudo bash"
  exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  GOARCH="amd64"
elif [ "$ARCH" = "arm64" ]; then
  GOARCH="arm64"
else
  echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
  exit 1
fi

echo -e "${BLUE}Detected architecture: $ARCH ($GOARCH)${NC}"

# Get latest release version
echo -e "${BLUE}Fetching latest release...${NC}"
LATEST_VERSION=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
  echo -e "${RED}Error: Could not fetch latest release version${NC}"
  exit 1
fi

echo -e "${GREEN}Latest version: ${LATEST_VERSION}${NC}"

# Construct download URL
ARCHIVE_NAME="nestr-key-agent_${LATEST_VERSION#v}_darwin_${GOARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_VERSION}/${ARCHIVE_NAME}"

echo -e "${BLUE}Downloading ${ARCHIVE_NAME}...${NC}"

# Download to temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

if ! curl -L -o "${ARCHIVE_NAME}" "${DOWNLOAD_URL}"; then
  echo -e "${RED}Error: Failed to download release${NC}"
  echo "URL: ${DOWNLOAD_URL}"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Extract archive
echo -e "${BLUE}Extracting archive...${NC}"
tar -xzf "${ARCHIVE_NAME}"

# Find the binary (it might be in a subdirectory)
BINARY_PATH=$(find . -name "${BINARY_NAME}" -type f | head -n 1)

if [ -z "$BINARY_PATH" ]; then
  echo -e "${RED}Error: Could not find ${BINARY_NAME} in archive${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Stop existing service if running
if launchctl list 2>/dev/null | grep -q "${SERVICE_NAME}"; then
  echo -e "${YELLOW}Stopping existing service...${NC}"
  launchctl bootout system/"${SERVICE_NAME}" 2>/dev/null || true
  launchctl unload "${PLIST_FILE}" 2>/dev/null || true
  sleep 2
fi

# Copy binary
echo -e "${GREEN}Installing binary to ${INSTALL_DIR}...${NC}"
cp "${BINARY_PATH}" "${INSTALL_DIR}/"
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
launchctl bootstrap system "${PLIST_FILE}" 2>/dev/null || launchctl load "${PLIST_FILE}" 2>/dev/null
launchctl enable system/"${SERVICE_NAME}" 2>/dev/null || true

# Wait a moment for service to start
sleep 2

# Cleanup
cd /
rm -rf "$TEMP_DIR"

# Check if service is running
if launchctl list 2>/dev/null | grep -q "${SERVICE_NAME}"; then
  echo
  echo -e "${GREEN}✓ Installation successful!${NC}"
  echo
  echo "Nestr Key Agent ${LATEST_VERSION} is now running"
  echo
  echo "Useful Commands:"
  echo "  Check status:  sudo launchctl list | grep ${SERVICE_NAME}"
  echo "  View logs:     tail -f ${LOG_FILE}"
  echo "  View errors:   tail -f ${ERR_FILE}"
  echo "  Stop service:  sudo launchctl bootout system/${SERVICE_NAME}"
  echo
else
  echo
  echo -e "${YELLOW}⚠ Service installed but may not be running${NC}"
  echo "Check logs for errors:"
  echo "  tail ${ERR_FILE}"
  echo
fi

echo -e "${GREEN}Installation complete!${NC}"
