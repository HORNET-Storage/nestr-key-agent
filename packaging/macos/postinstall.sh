#!/bin/bash
# Nestr Key Agent post-installation script for macOS

set -e

PLIST_PATH="/Library/LaunchDaemons/com.hornetstorage.nestr-key-agent.plist"
SERVICE_LABEL="com.hornetstorage.nestr-key-agent"

echo "Configuring Nestr Key Agent for macOS..."

# Create working directory
mkdir -p /usr/local/var/nestr-key-agent
chmod 755 /usr/local/var/nestr-key-agent

# Create log directory
mkdir -p /var/log
touch /var/log/nestr-key-agent.log
touch /var/log/nestr-key-agent.err
chmod 644 /var/log/nestr-key-agent.log
chmod 644 /var/log/nestr-key-agent.err

# Set proper permissions on the plist
chmod 644 "$PLIST_PATH"
chown root:wheel "$PLIST_PATH"

# Load the launch daemon
echo "Loading launch daemon..."
launchctl load "$PLIST_PATH" 2>/dev/null || true

# Start the service
echo "Starting Nestr Key Agent..."
launchctl start "$SERVICE_LABEL" 2>/dev/null || true

# Give it a moment to start
sleep 2

# Check if it's running
if launchctl list | grep -q "$SERVICE_LABEL"; then
    echo "✓ Nestr Key Agent started successfully"
    echo ""
    echo "Service commands:"
    echo "  Status:  launchctl list | grep nestr-key-agent"
    echo "  Stop:    sudo launchctl stop $SERVICE_LABEL"
    echo "  Start:   sudo launchctl start $SERVICE_LABEL"
    echo "  Restart: sudo launchctl kickstart -k system/$SERVICE_LABEL"
    echo "  Logs:    tail -f /var/log/nestr-key-agent.log"
else
    echo "⚠ Service installed but may not be running"
    echo "Check logs: tail -f /var/log/nestr-key-agent.log"
fi

echo ""
echo "Nestr Key Agent installation complete!"
echo "Use 'keyagent-cli --help' to interact with the agent"

exit 0
