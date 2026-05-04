# VMware STIG Tools Appliance - Network Configuration Guide

## Overview
This guide documents the network configuration process for the VMware STIG Tools Appliance running on Photon OS 5.0.

## Background
Photon OS 5.0 uses **systemd-networkd** for network management instead of the traditional network-scripts (`/etc/sysconfig/network-scripts/`) found in RHEL/CentOS systems.

## Configuration Steps

### 1. Identify Network Interface
```bash
ip link show
```
The interface is typically named `eth0` (may also show alternate names like `ens160`, `eno1`).

### 2. Create Network Configuration File
Network configurations are stored in `/etc/systemd/network/` as `.network` files.

```bash
cd /etc/systemd/network/
vi 10-eth0.network
```

### 3. Configure Static IP
Add the following configuration (adjust values for your environment):

```ini
[Match]
Name=eth0

[Network]
Address=192.168.10.50/25
Gateway=192.168.10.1
DNS=192.168.10.10
Domains=.example.lan
DHCP=no
IPv6AcceptRA=no
LinkLocalAddressing=no

[Link]
RequiredForOnline=yes
```

**Important Notes:**
- Use CIDR notation for the subnet mask (e.g., `/25` NOT `/255.255.255.128`)
- Ensure `DHCP=no` is set for static IP configurations
- Remove any conflicting DHCP configuration files (e.g., `99-dhcp-en.network`)

### 4. Set Proper Permissions
```bash
chmod 644 /etc/systemd/network/10-eth0.network
```

### 5. Apply Configuration
```bash
systemctl restart systemd-networkd
```

### 6. Verify Connectivity
```bash
# Check IP assignment
ip addr show eth0

# Verify routing
ip route

# Test gateway connectivity
ping <gateway_ip>

# Test DNS resolution
ping <dns_server_ip>
```

## Accessing the Appliance

### SSH Access
```bash
ssh root@<appliance_ip>
```
Use the password configured during deployment.

### Web-Based Documentation
Access the built-in documentation site:
```
http://<appliance_ip>
```
**Note:** The appliance serves HTTP only (port 80), not HTTPS.

## Troubleshooting

### Common Issues

**Issue:** Interface shows IPv6 only or no IP address
- **Cause:** Conflicting DHCP configuration file
- **Solution:** Remove any `99-dhcp-en.network` files from `/etc/systemd/network/`

**Issue:** Cannot ping gateway
- **Cause:** Incorrect subnet mask notation
- **Solution:** Verify CIDR notation is used (e.g., `/25` not `/255.255.255.128`)

**Issue:** Network adapter shows as connected in vCenter but no connectivity
- **Cause:** Verify correct port group/VLAN assignment in vCenter
- **Solution:** Confirm VM is attached to the correct distributed port group

### Verification Commands
```bash
# View current network configuration
cat /etc/systemd/network/10-eth0.network

# Check systemd-networkd status
systemctl status systemd-networkd

# View neighbor (ARP) table
ip neigh show

# Monitor network traffic
tcpdump -i eth0 -n
```

## Production Environment Details
- **IP Address:** 192.168.10.50/25
- **Gateway:** 192.168.10.1
- **DNS Server:** 192.168.10.10
- **Domain:** .example.lan
- **Port Group:** VLAN-MGMT-PG

---

**For Support:**
Contact: noah@essential.coach
