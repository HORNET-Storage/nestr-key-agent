#!/bin/bash
# Nestr Key Agent pre-removal script for DEB/RPM packages

echo "Stopping Nestr Key Agent service..."

if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet keyagent.service; then
        systemctl stop keyagent.service
        echo "✓ Service stopped"
    fi
    
    if systemctl is-enabled --quiet keyagent.service; then
        systemctl disable keyagent.service
        echo "✓ Service disabled"
    fi
fi

exit 0
