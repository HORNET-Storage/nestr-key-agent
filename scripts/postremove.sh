#!/bin/bash
# Nestr Key Agent post-removal script for DEB/RPM packages

echo "Cleaning up Nestr Key Agent..."

# Remove systemd service file
if [ -f /lib/systemd/system/keyagent.service ]; then
    rm -f /lib/systemd/system/keyagent.service
    systemctl daemon-reload 2>/dev/null || true
fi

# Ask about removing data
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Key data is stored in user directories and has NOT      ║"
echo "║  been removed. To remove all keys and configuration:     ║"
echo "║                                                           ║"
echo "║    rm -rf ~/.nestr-key-agent                             ║"
echo "║    rm -rf /var/lib/nestr-key-agent                       ║"
echo "║                                                           ║"
echo "║  WARNING: This will permanently delete all stored keys!  ║"
echo "╚═══════════════════════════════════════════════════════════╝"

exit 0
