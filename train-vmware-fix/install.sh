#!/bin/bash
# Train-VMware Password Fix - Installation Script
# Author: Noah Farshad (noah@essential.coach)
# essential.coach
# December 2025
#
# Installs the patched connection.rb file for train-vmware plugin
# to support special characters in vCenter passwords

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PLUGIN_DIR="/root/.inspec/gems/3.1.0/gems/train-vmware-0.2.0"
CONNECTION_FILE="${PLUGIN_DIR}/lib/train-vmware/connection.rb"
BACKUP_FILE="${CONNECTION_FILE}.backup"

echo ""
echo "Train-VMware Password Fix Installer"
echo "===================================="
echo ""

# Root check
if [ "$EUID" -ne 0 ]; then 
   echo -e "${RED}Error: Need to run this as root${NC}"
   exit 1
fi

# Verify plugin exists
if [ ! -d "$PLUGIN_DIR" ]; then
    echo -e "${RED}Can't find train-vmware plugin at:${NC}"
    echo "  $PLUGIN_DIR"
    echo ""
    echo "Install it first with:"
    echo "  inspec plugin install train-vmware"
    exit 1
fi

if [ ! -f "$CONNECTION_FILE" ]; then
    echo -e "${RED}Missing connection.rb at:${NC}"
    echo "  $CONNECTION_FILE"
    exit 1
fi

echo "Found plugin at: $PLUGIN_DIR"
echo ""

# Handle existing backup
if [ -f "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}Backup already exists at:${NC}"
    echo "  $BACKUP_FILE"
    read -p "Create new timestamped backup? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP_FILE="${CONNECTION_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Creating: $BACKUP_FILE"
    fi
else
    echo "Backing up original file..."
fi

# Backup
if [[ ! "$BACKUP_FILE" =~ "backup\." ]]; then
    cp "$CONNECTION_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}Backup created${NC}"
fi

# Check patch file
if [ ! -f "connection.rb" ]; then
    echo -e "${RED}Can't find connection.rb in current directory${NC}"
    echo "Extract the full package first"
    exit 1
fi

# Install
echo ""
echo "Installing patched file..."
cp connection.rb "$CONNECTION_FILE"
chmod 644 "$CONNECTION_FILE"

# Verify
if grep -q "Base64.strict_encode64" "$CONNECTION_FILE"; then
    echo -e "${GREEN}Installation verified${NC}"
else
    echo -e "${RED}Verification failed - something went wrong${NC}"
    exit 1
fi

echo ""
echo "===================================="
echo -e "${GREEN}Installation complete${NC}"
echo "===================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Set your credentials:"
echo "   export VISERVER=\"vcenter.example.com\""
echo "   export VISERVER_USERNAME=\"administrator@vsphere.local\""
echo "   export VISERVER_PASSWORD=\"YourP@ssw0rd!\$%\""
echo ""
echo "2. Test it:"
echo "   inspec exec /usr/share/stigs/vsphere/8.0/v2r1-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline/esxi/ \\"
echo "     -t vmware:// \\"
echo "     --input vmhostName=esxi-host.example.com \\"
echo "     --reporter cli"
echo ""
echo "To rollback:"
echo "   cp $BACKUP_FILE $CONNECTION_FILE"
echo ""
