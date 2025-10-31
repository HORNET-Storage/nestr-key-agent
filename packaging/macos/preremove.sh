#!/bin/bash
# Nestr Key Agent pre-removal script for macOS

set -e

SERVICE_LABEL="com.hornetstorage.nestr-key-agent"
PLIST_PATH="/Library/LaunchDaemons/com.hornetstorage.nestr-key-agent.plist"

echo "Stopping Nestr Key Agent..."

# Stop the service
launchctl stop "$SERVICE_LABEL" 2>/dev/null || true

# Unload the launch daemon
launchctl unload "$PLIST_PATH" 2>/dev/null || true

echo "Nestr Key Agent stopped"

exit 0
