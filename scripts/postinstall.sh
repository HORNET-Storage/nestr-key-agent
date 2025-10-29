#!/bin/bash
# Nestr Key Agent post-installation script for DEB/RPM packages

set -e

echo "Configuring Nestr Key Agent..."

# Create systemd service
if command -v systemctl &> /dev/null; then
    echo "Setting up systemd service..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable service
    systemctl enable keyagent.service
    
    # Start service
    systemctl start keyagent.service
    
    # Check status
    sleep 2
    if systemctl is-active --quiet keyagent.service; then
        echo "✓ Key Agent service started successfully"
        echo ""
        echo "Service commands:"
        echo "  Status:  systemctl status keyagent"
        echo "  Stop:    systemctl stop keyagent"
        echo "  Restart: systemctl restart keyagent"
        echo "  Logs:    journalctl -u keyagent -f"
    else
        echo "⚠ Service installed but not running"
        echo "Start it with: systemctl start keyagent"
        echo "Check logs with: journalctl -u keyagent"
    fi
else
    echo "⚠ systemd not found. You'll need to start the key agent manually."
    echo "Run: keyagent &"
fi

echo ""
echo "Nestr Key Agent installation complete!"
echo "Use 'keyagent-cli --help' to interact with the agent"

exit 0
