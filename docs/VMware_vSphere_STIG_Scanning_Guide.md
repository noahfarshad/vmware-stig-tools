# VMware vSphere 8.0 STIG Compliance Scanning Guide

## Overview

This guide provides a complete walkthrough for auditing VMware vSphere 8.0 environments for STIG (Security Technical Implementation Guide) compliance using the VMware STIG Tools Appliance. Based on real-world deployment experience with vSphere 8.0 U3 and the official DoD v2r3-stig content.

**Author:** Noah Farshad, Sr. Automation Consultant at VMware by Broadcom  
**Blog:** essential.coach  
**Date:** December 2025

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Understanding STIG Coverage](#understanding-stig-coverage)
3. [Environment Setup](#environment-setup)
4. [Scanning vCenter Product Controls](#scanning-vcenter-product-controls)
5. [Scanning VCSA Appliance Components](#scanning-vcsa-appliance-components)
6. [Complete vCenter Audit (All Components)](#complete-vcenter-audit-all-components)
7. [Report Generation and Conversion](#report-generation-and-conversion)
8. [Common Issues and Solutions](#common-issues-and-solutions)
9. [Quick Reference Commands](#quick-reference-commands)

---

## Prerequisites

### Required Components
- **VMware STIG Tools Appliance** (Photon OS 5.0-based)
- **vCenter Server 8.0** (U2 or U3)
- **Network connectivity** from STIG appliance to vCenter
- **Credentials:**
  - vCenter SSO administrator account (e.g., `administrator@vsphere.local`)
  - VCSA root SSH password
- **DoD Compliance Repository:** Pre-installed at `/usr/share/stigs/`

### Tools Installed on STIG Appliance
- **CINC Auditor** (InSpec alternative) - Compliance scanning engine
- **SAF CLI** (MITRE Security Automation Framework) - Report conversion
- **train-vmware plugin** - Custom VMware PowerCLI integration for InSpec
- **PowerShell Core (pwsh)** - For environment variable management

---

## Understanding STIG Coverage

VMware vSphere 8.0 STIG compliance is split into **two major categories**:

### 1. vSphere Product Controls (API-Based)
**Location:** `/usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/`

**Components:**
- **vCenter** - vCenter Server product-level controls (~67 checks)
- **ESXi** - ESXi host security controls
- **VM** - Virtual Machine security controls

**Connection Method:** VMware API via `vmware://` transport (uses vCenter credentials)

### 2. VCSA Appliance Controls (SSH-Based)
**Location:** `/usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/`

**Components:**
- **PostgreSQL** - vCenter database security
- **Photon OS 4.0** - Operating system hardening
- **EAM** - ESX Agent Manager service
- **Envoy** - Envoy proxy service
- **Lookup** - Lookup service
- **Perfcharts** - Performance charts service
- **STS** - Security Token Service
- **UI** - vSphere UI service
- **VAMI** - Virtual Appliance Management Interface

**Connection Method:** SSH via `ssh://` transport (uses root credentials)

---

## Environment Setup

### Step 1: Verify STIG Tools Installation

```bash
# Check CINC Auditor version
cinc-auditor version

# Check SAF CLI installation
saf version

# Verify train-vmware plugin
cinc-auditor plugin list | grep train-vmware

# Expected output:
# │ train-vmware │ 0.2.0 │ gem (user) │ train-1 │ Train Plugin for VMware PowerCLI │
```

### Step 2: Verify Repository Structure

```bash
# Check vsphere STIG content
ls -la /usr/share/stigs/vsphere/8.0/v2r3-stig/

# Expected output:
# drwxr-xr-x 4 root root 4096 Apr 25  2025 vcsa      ← Appliance components
# drwxr-xr-x 4 root root 4096 Apr 25  2025 vsphere   ← Product controls
```

### Step 3: Create Reports Directory

```bash
# Create directory for scan reports
mkdir -p /tmp/reports
```

---

## Scanning vCenter Product Controls

This scan targets **vCenter product-level STIG controls only** (no ESXi hosts, no VMs, no appliance components).

### Step 1: Set Environment Variables

```bash
# Enter PowerShell
pwsh

# Set vCenter connection details
$env:VISERVER='192.168.1.100'
$env:VISERVER_USERNAME='administrator@vsphere.local'
$env:VISERVER_PASSWORD='YourPasswordHere'
```

**Important:** If your password contains special characters (especially single quotes `'`), use proper escaping:
- Each single quote `'` must be replaced with **four ticks** `''''`
- Example: Password `P@ss'word` becomes `P@ss''''word`

### Step 2: Navigate to InSpec Profile

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
```

### Step 3: Run vCenter-Only Scan

```bash
cinc-auditor exec ./vcenter/ -t vmware:// --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/vCenter_Product_Report.json
```

**Command Breakdown:**
- `exec ./vcenter/` - Execute the vCenter profile only
- `-t vmware://` - Use VMware API transport (credentials from env vars)
- `--show-progress` - Display real-time progress
- `--enhanced-outcomes` - Include enhanced result details
- `--reporter cli json:...` - Output to both console and JSON file

**Note:** All commands in this guide are written as single lines to avoid shell parsing issues with line continuation characters (`\`).

### Step 4: Review Results

```bash
# Check JSON report was created
ls -lh /tmp/reports/vCenter_Product_Report.json

# Quick summary of results
jq '.profiles[0].controls | length' /tmp/reports/vCenter_Product_Report.json
```

---

## Scanning ESXi Hosts

This scan targets **ESXi host security controls** for all hosts managed by vCenter.

### Step 1: Ensure Environment Variables Are Set

```bash
# These should already be set from the vCenter scan
pwsh
$env:VISERVER='192.168.1.100'
$env:VISERVER_USERNAME='administrator@vsphere.local'
$env:VISERVER_PASSWORD='YourPasswordHere'
```

### Step 2: Navigate to vSphere Baseline Directory

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline

# Verify you're in the correct location
pwd
# Should output: /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
```

### Step 3: Configure ESXi Inputs File

The ESXi scan requires an inputs file to specify which hosts to scan and environment-specific settings.

```bash
# Edit the inputs file
vi inputs-example.yml
```

Update the following settings in the inputs file:

```yaml
# Choose whether to scan a single host, all hosts in a cluster, or all hosts in vCenter
# Options: 'host', 'cluster', 'allesxi'
esximode: 'allesxi'

# If scanning a single host (esximode: 'host'), specify the hostname or IP
vmhostName: '192.168.1.10'

# If scanning a cluster (esximode: 'cluster'), specify the cluster name
cluster: 'Production-Cluster'

# Environment-specific settings (adjust to your environment)
syslogServer: 'tcp://syslog.essential.coach:514'
ntpServers:
  - 'time.essential.coach'
  - 'time2.essential.coach'
```

### Step 4: Run ESXi Host Scan

**Scan All ESXi Hosts in vCenter:**
```bash
cinc-auditor exec ./esxi/ -t vmware:// --input-file ./inputs-example.yml --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/ESXi_All_Hosts.json
```

**Scan Single ESXi Host:**
```bash
# First, update inputs-example.yml with esximode: 'host' and vmhostName
cinc-auditor exec ./esxi/ -t vmware:// --input-file ./inputs-example.yml --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/ESXi_Single_Host.json
```

**Scan All Hosts in a Cluster:**
```bash
# First, update inputs-example.yml with esximode: 'cluster' and cluster name
cinc-auditor exec ./esxi/ -t vmware:// --input-file ./inputs-example.yml --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/ESXi_Cluster.json
```

### Step 5: Convert ESXi Report to CKL

```bash
saf convert hdf2ckl -i /tmp/reports/ESXi_All_Hosts.json -o /tmp/reports/ESXi_All_Hosts.ckl --hostname esxi-hosts --fqdn esxi.essential.coach --ip 192.168.1.10
```

**Note:** For production accreditation, you typically need **individual CKL files per ESXi host**. The VMware repository includes PowerShell runner scripts that automate this:
- Located at: `/usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/powercli/`
- Script: `VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner.ps1`
- This script loops through hosts and creates individual JSON/CKL files for each

---

## Scanning VCSA Appliance Components

This scan targets **all VCSA appliance-level components** including PostgreSQL, Photon OS, and all services. You have two approaches: scan all components at once, or scan them individually.

### Approach 1: Scan All VCSA Components at Once (Recommended for Complete Audits)

**Step 1: Navigate to VCSA Baseline Directory**

```bash
# CRITICAL: Make sure you're in the VCSA directory, NOT vsphere directory
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline

# Verify you're in the correct location
pwd
# Should output: /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
```

**Step 2: Run Complete VCSA Scan (All 9 Components)**

```bash
cinc-auditor exec . -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/VCSA_All_Components.json
```

**What This Scans:**
This single command executes checks across all 9 VCSA components:
- ✅ **PostgreSQL** - Database security (~30 checks)
- ✅ **Photon OS 4.0** - Operating system hardening (~140 checks)
- ✅ **EAM** - ESX Agent Manager service
- ✅ **Envoy** - Envoy proxy service
- ✅ **Lookup** - Lookup service
- ✅ **Perfcharts** - Performance charts service
- ✅ **STS** - Security Token Service
- ✅ **UI** - vSphere UI service
- ✅ **VAMI** - Virtual Appliance Management Interface

**Total:** 200+ security checks executed in one scan

**Expected Runtime:** 5-10 minutes depending on network latency and VCSA performance

---

### Approach 2: Scan Individual VCSA Components (Recommended for Targeted Audits)

For more control and clearer results, you can scan each component separately. Each produces its own dedicated report.

**Step 1: Navigate to VCSA Baseline Directory**

```bash
# Start from the VCSA baseline directory
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
```

**Step 2: Scan Individual Components**

```bash
# PostgreSQL Database (~30 checks)
cinc-auditor exec ./postgresql/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_PostgreSQL.json

# Photon OS 4.0 (~140 checks)
cinc-auditor exec ./photon/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_Photon.json

# EAM Service
cinc-auditor exec ./eam/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_EAM.json

# Envoy Service
cinc-auditor exec ./envoy/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_Envoy.json

# Lookup Service
cinc-auditor exec ./lookup/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_Lookup.json

# Perfcharts Service
cinc-auditor exec ./perfcharts/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_Perfcharts.json

# STS Service
cinc-auditor exec ./sts/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_STS.json

# UI Service
cinc-auditor exec ./ui/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_UI.json

# VAMI Service
cinc-auditor exec ./vami/ -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --reporter cli json:/tmp/reports/VCSA_VAMI.json
```

**Benefits of Individual Scans:**
- ✅ Each component gets its own dedicated CKL file for STIG Viewer
- ✅ Easier troubleshooting if one component has issues
- ✅ Can scan only specific components as needed
- ✅ Clearer attribution of results per service

**Step 3: Convert Each Report to CKL**

```bash
# Convert each component report individually
saf convert hdf2ckl -i /tmp/reports/VCSA_PostgreSQL.json -o /tmp/reports/VCSA_PostgreSQL.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_Photon.json -o /tmp/reports/VCSA_Photon.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_EAM.json -o /tmp/reports/VCSA_EAM.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_Envoy.json -o /tmp/reports/VCSA_Envoy.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_Lookup.json -o /tmp/reports/VCSA_Lookup.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_Perfcharts.json -o /tmp/reports/VCSA_Perfcharts.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_STS.json -o /tmp/reports/VCSA_STS.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_UI.json -o /tmp/reports/VCSA_UI.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_VAMI.json -o /tmp/reports/VCSA_VAMI.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100
```

---

### ⚠️ Common Mistake to Avoid

**DO NOT** run VCSA scans from the vsphere directory:
```bash
# WRONG - This scans ESXi/vCenter product/VMs, NOT VCSA components
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
cinc-auditor exec . -t 'ssh://root@192.168.1.100' --password 'Password'
```

**Always verify your working directory** before running VCSA scans:
```bash
pwd
# Must show: /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
```

---

## Complete vCenter Audit (All Components)

For a **comprehensive vCenter STIG audit**, you need to run three scans to cover all components. Pay close attention to which directory you're working from.

### Three-Scan Approach (vCenter Product + ESXi Hosts + VCSA Appliance)

```bash
# ============================================
# SCAN 1: vCenter Product Controls (API-based)
# ============================================

# Set environment variables in PowerShell
pwsh
$env:VISERVER='192.168.1.100'
$env:VISERVER_USERNAME='administrator@vsphere.local'
$env:VISERVER_PASSWORD='YourPasswordHere'

# Navigate to vSphere baseline (for vCenter product controls)
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline

# Verify you're in the correct directory
pwd
# Should show: /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline

# Run vCenter product scan
cinc-auditor exec ./vcenter/ -t vmware:// --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/vCenter_Product_Complete.json


# ============================================
# SCAN 2: ESXi Hosts (API-based)
# ============================================

# Still in the same directory (/vsphere/inspec/ baseline)
# Configure inputs file first (vi inputs-example.yml)
# Set esximode: 'allesxi' to scan all hosts

# Run ESXi scan
cinc-auditor exec ./esxi/ -t vmware:// --input-file ./inputs-example.yml --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/ESXi_All_Hosts.json


# ============================================
# SCAN 3: VCSA Appliance Components (SSH-based)
# ============================================

# Navigate to VCSA baseline (for appliance components)
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline

# Verify you're in the correct directory
pwd
# Should show: /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline

# Run VCSA appliance scan
cinc-auditor exec . -t 'ssh://root@192.168.1.100' --password 'YourRootPassword' --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/VCSA_Appliance_Complete.json
```

### Coverage Summary

After all three scans complete, you will have:

**Scan 1 - vCenter Product Report:**
- Source: `/vsphere/inspec/` baseline
- Contains: ~67 vCenter-specific STIG controls
- Transport: VMware API (`vmware://`)

**Scan 2 - ESXi Hosts Report:**
- Source: `/vsphere/inspec/` baseline
- Contains: ~240 ESXi host security controls (per host)
- Transport: VMware API (`vmware://`)
- Note: May need individual reports per host for accreditation

**Scan 3 - VCSA Appliance Report:**
- Source: `/vcsa/inspec/` baseline  
- Contains: 9 service components with 200+ checks total
  - PostgreSQL (~30 checks)
  - Photon OS 4.0 (~140 checks)
  - EAM, Envoy, Lookup, Perfcharts, STS, VAMI, UI (remaining checks)
- Transport: SSH (`ssh://`)

**Total Coverage:** Complete vCenter STIG compliance audit across all components

### ⚠️ Critical Directory Distinction

```
/usr/share/stigs/vsphere/8.0/v2r3-stig/
├── vsphere/inspec/vmware-vsphere-8.0-stig-baseline/   ← vCenter PRODUCT controls
│   ├── vcenter/     (Use this for vCenter product scan)
│   ├── esxi/
│   └── vm/
└── vcsa/inspec/vmware-vcsa-8.0-stig-baseline/        ← VCSA APPLIANCE components
    ├── postgresql/  (Use this directory for VCSA scans)
    ├── photon/
    ├── eam/
    └── ... (other services)
```

**Always verify your working directory with `pwd` before running scans!**

---

## Report Generation and Conversion

InSpec outputs JSON reports by default. For accreditation purposes, you'll need **CKL (Checklist) files** for STIG Viewer.

### Convert JSON to CKL Format

```bash
# Convert vCenter product report to CKL
saf convert hdf2ckl -i /tmp/reports/vCenter_Product_Complete.json -o /tmp/reports/vCenter_Product_Complete.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

# Convert VCSA appliance report to CKL
saf convert hdf2ckl -i /tmp/reports/VCSA_Appliance_Complete.json -o /tmp/reports/VCSA_Appliance_Complete.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100
```

**Important Notes:**
- The `saf convert` command will show a Node.js CommonJS/ES Module warning - this is normal and harmless. The conversion succeeds silently without a confirmation message.
- SAF CLI produces **CKL format (XML)** regardless of the file extension you specify
- These CKL files work with both STIG Viewer 2.x and STIG Viewer 3.x

### About CKLB Format

**Note:** SAF CLI does **not** produce true CKLB format (STIG Viewer 3.x native JSON format). The `hdf2ckl` command always generates CKL (XML) format, even if you specify a `.cklb` extension. 

If you need true CKLB format for STIG Viewer 3.x, you'll need to use alternative conversion tools or scripts. The CKL files produced by SAF CLI are compatible with STIG Viewer 3.x and work for accreditation purposes.

### Verify Generated Files

```bash
# List all generated reports
ls -lh /tmp/reports/

# Expected output:
# -rw-r----- 1 root root 587K Dec 11 16:02 vCenter_Product_Complete.json
# -rw-r----- 1 root root 633K Dec 11 16:04 vCenter_Product_Complete.ckl
# -rw-r----- 1 root root 1.2M Dec 11 16:10 VCSA_Appliance_Complete.json
# -rw-r----- 1 root root 1.4M Dec 11 16:11 VCSA_Appliance_Complete.ckl

# Verify CKL format (should be XML)
head -n 20 /tmp/reports/vCenter_Product_Complete.ckl

# Should show XML structure like:
# <?xml version="1.0" encoding="UTF-8"?>
# <!--Heimdall Version :: 2.11.5-->
# <CHECKLIST>
#   <ASSET>
#     <HOST_NAME>vcsa-01</HOST_NAME>
```

---

## Common Issues and Solutions

### Issue 1: Password Contains Special Characters

**Problem:** InSpec scan fails with authentication errors when password contains single quotes or other special characters.

**Solution:** For passwords with single quotes in PowerShell environment variables:
```bash
# Each single quote ' must become ''''
# Example: P@ss'word becomes P@ss''''word
$env:VISERVER_PASSWORD='P@ss''''word'
```

**Alternative Solution:** Use Base64 encoding (as implemented in our fixed train-vmware plugin):
```bash
# The train-vmware 0.2.0 plugin automatically Base64-encodes passwords
# No special escaping needed if plugin is properly installed
```

### Issue 2: SAF CLI Shows Warning But No Output

**Problem:** Running `saf convert hdf2ckl` shows Node.js warnings but no confirmation message.

**Diagnosis:** This is **completely normal** - SAF CLI succeeds silently. The warning about CommonJS/ES Module is harmless and can be safely ignored.

**Example of normal output:**
```bash
(node:59895) ExperimentalWarning: CommonJS module /opt/saf/lib/commands/validate/threshold.js is loading ES Module /opt/saf/node_modules/chai/chai.js using require().
Support for loading ES Module in require() is an experimental feature and might change at any time
```

This just means the conversion completed successfully!

**Verification:**
```bash
# Check if file was created
ls -lh /tmp/reports/*.ckl

# Verify it's valid XML (CKL format)
head -n 20 /tmp/reports/vCenter_Product_Complete.ckl

# You should see:
# <?xml version="1.0" encoding="UTF-8"?>
# <!--Heimdall Version :: 2.11.5-->
# <CHECKLIST>
#   <ASSET>
#     <HOST_NAME>vcsa-01</HOST_NAME>
#     ...
```

### Issue 3: Cannot Find train-vmware Plugin

**Problem:** InSpec cannot connect to vCenter - missing train-vmware plugin.

**Solution:**
```bash
# Install the train-vmware plugin (included in baseline)
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
cinc-auditor plugin install train-vmware-0.2.0.gem

# Verify installation
cinc-auditor plugin list | grep train-vmware
```

### Issue 4: SSH Connection Fails to VCSA

**Problem:** Cannot connect via SSH to run appliance component scans.

**Diagnosis Steps:**
```bash
# Test SSH connectivity
ssh root@192.168.1.100

# Check if SSH is enabled on VCSA
# From VCSA shell:
systemctl status sshd

# Enable SSH if needed (from VCSA VAMI interface)
# https://vcsa-01.essential.coach:5480
# Navigate to: Access > Edit > Enable SSH
```

### Issue 5: VISERVER Environment Variables Not Recognized

**Problem:** InSpec reports "Unable to connect to vCenter" despite setting environment variables.

**Solution:**
```bash
# Ensure you're in PowerShell context
pwsh

# Verify variables are set
echo $env:VISERVER
echo $env:VISERVER_USERNAME

# Re-export if needed
$env:VISERVER='192.168.1.100'
$env:VISERVER_USERNAME='administrator@vsphere.local'
$env:VISERVER_PASSWORD='YourPassword'

# Stay in pwsh shell when running cinc-auditor
```

### Issue 6: CKLB File Won't Open in STIG Viewer 3.x

**Problem:** STIG Viewer 3.x shows "SyntaxError: Unexpected token '<'" when trying to open a `.cklb` file.

**Diagnosis:** SAF CLI's `hdf2ckl` command produces CKL (XML) format regardless of the file extension you specify. It does **not** create true CKLB (STIG Viewer 3.x native JSON) format.

**Solution:**
```bash
# Simply use the .ckl file instead
# The CKL (XML) format works with both STIG Viewer 2.x and 3.x

# If you accidentally created a .cklb file, just rename it
mv /tmp/reports/VCSA_Complete.cklb /tmp/reports/VCSA_Complete.ckl

# Or use the .ckl file that was already created
ls -lh /tmp/reports/*.ckl
```

**Verification:**
```bash
# CKL files should be XML
file /tmp/reports/VCSA_Complete.ckl
# Output: XML 1.0 document

# If you need true CKLB format (STIG Viewer 3.x native JSON), you'll need 
# to use alternative conversion tools beyond SAF CLI
```

---

## Quick Reference Commands

### Complete vCenter STIG Audit (Copy-Paste Ready)

```bash
# ============================================
# COMPLETE VCENTER STIG AUDIT - QUICK START
# ============================================

# Step 1: Create reports directory
mkdir -p /tmp/reports

# Step 2: Set vCenter credentials (in PowerShell)
pwsh
$env:VISERVER='192.168.1.100'
$env:VISERVER_USERNAME='administrator@vsphere.local'
$env:VISERVER_PASSWORD='YourPasswordHere'

# Step 3: Scan vCenter product controls
# Working Directory: /vsphere/inspec/ baseline
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
pwd  # Verify location before scanning
cinc-auditor exec ./vcenter/ -t vmware:// --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/vCenter_Product.json

# Step 4: Scan VCSA appliance components (all 9 components in one scan)
# Working Directory: /vcsa/inspec/ baseline
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
pwd  # Verify location before scanning
cinc-auditor exec . -t 'ssh://root@192.168.1.100' --password 'RootPassword' --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/VCSA_Appliance.json

# Step 5: Convert to CKL format
saf convert hdf2ckl -i /tmp/reports/vCenter_Product.json -o /tmp/reports/vCenter_Product.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_Appliance.json -o /tmp/reports/VCSA_Appliance.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

# Step 6: Verify reports were generated
ls -lh /tmp/reports/
```

**Note:** All commands are single-line to prevent shell parsing issues. The Node.js warnings from SAF CLI are normal and can be ignored. SAF CLI produces CKL format (XML) which works with both STIG Viewer 2.x and 3.x.

### Individual Component Scans

```bash
# ============================================
# vCenter Product Controls
# ============================================
# Working Directory: /vsphere/inspec/ baseline
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
cinc-auditor exec ./vcenter/ -t vmware:// --show-progress --reporter json:/tmp/reports/vCenter_Only.json


# ============================================
# ESXi Hosts
# ============================================
# Working Directory: /vsphere/inspec/ baseline (same as above)
# First configure inputs-example.yml with your settings

# Scan all ESXi hosts
cinc-auditor exec ./esxi/ -t vmware:// --input-file ./inputs-example.yml --show-progress --reporter json:/tmp/reports/ESXi_All.json


# ============================================
# VCSA Appliance Components
# ============================================
# Working Directory: /vcsa/inspec/ baseline
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline

# PostgreSQL
cinc-auditor exec ./postgresql/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/PostgreSQL_Only.json

# Photon OS
cinc-auditor exec ./photon/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/Photon_Only.json

# EAM
cinc-auditor exec ./eam/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/EAM_Only.json

# Envoy
cinc-auditor exec ./envoy/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/Envoy_Only.json

# Lookup
cinc-auditor exec ./lookup/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/Lookup_Only.json

# Perfcharts
cinc-auditor exec ./perfcharts/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/Perfcharts_Only.json

# STS
cinc-auditor exec ./sts/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/STS_Only.json

# UI
cinc-auditor exec ./ui/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/UI_Only.json

# VAMI
cinc-auditor exec ./vami/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VAMI_Only.json

# Scan ALL VCSA components at once (from same directory)
cinc-auditor exec . -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_Complete.json
```

### Report Conversion Cheat Sheet

```bash
# JSON to CKL (Works with STIG Viewer 2.x and 3.x)
saf convert hdf2ckl -i input.json -o output.ckl --hostname HOSTNAME --fqdn FQDN --ip IP_ADDRESS

# Note: SAF CLI will show a Node.js warning - this is normal and means success!
# Note: SAF CLI only produces CKL (XML) format, not true CKLB (JSON) format

# Verify CKL structure (should be XML)
head -n 20 output.ckl

# Should see XML like:
# <?xml version="1.0" encoding="UTF-8"?>
# <!--Heimdall Version :: 2.11.5-->
# <CHECKLIST>
```

### Troubleshooting Commands

```bash
# Verify CINC Auditor installation
cinc-auditor version

# List installed InSpec plugins
cinc-auditor plugin list

# Test vCenter connectivity
pwsh
$env:VISERVER='192.168.1.100'
$env:VISERVER_USERNAME='administrator@vsphere.local'
$env:VISERVER_PASSWORD='Password'
Connect-VIServer -Server $env:VISERVER -User $env:VISERVER_USERNAME -Password $env:VISERVER_PASSWORD

# Test SSH connectivity to VCSA
ssh root@192.168.1.100

# Check if PostgreSQL is running on VCSA
ssh root@192.168.1.100 'systemctl status vmware-vpostgres'

# View InSpec profile structure
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
cat inspec.yml

cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
cat inspec.yml
```

---

## Key Takeaways

### What We Accomplished

1. ✅ **Deployed VMware STIG Tools Appliance** with pre-configured compliance scanning tools
2. ✅ **Scanned vCenter product-level STIG controls** using InSpec via VMware API
3. ✅ **Scanned all VCSA appliance components** (9 services) using InSpec via SSH
4. ✅ **Generated compliance reports** in multiple formats (JSON, CKL, CKLB)
5. ✅ **Resolved authentication issues** with special character handling in passwords
6. ✅ **Documented complete workflow** for reproducible STIG compliance auditing

### Best Practices Learned

1. **Separate API and SSH scans** - vCenter product controls use API, appliance components use SSH
2. **Use wrapper profiles** - Run the baseline root directory (`.`) to scan all components at once
3. **Generate multiple formats** - Create both CKL (legacy) and CKLB (modern) formats for flexibility
4. **Password handling** - Use Base64 encoding or proper escaping for special characters
5. **Verify before moving on** - Always check report files were created and contain valid data

### Production Deployment Considerations

- **Schedule regular scans** - Automate weekly/monthly compliance audits
- **Baseline first** - Run initial scan before making any changes to establish baseline
- **Test remediations** - Use separate test environment before applying STIG fixes to production
- **Document exceptions** - Use attestation files for accepted risks and approved deviations
- **Integrate with SIEM** - Forward compliance reports to central security monitoring

---

## Additional Resources

### Official Documentation
- **VMware STIG Documentation:** https://techdocs.broadcom.com/us/en/vmware-cis/vcf/stig/9-0/
- **DoD Compliance Repository:** https://github.com/vmware/dod-compliance-and-automation
- **DISA STIG Library:** https://public.cyber.mil/stigs/

### Tools & Frameworks
- **InSpec Documentation:** https://docs.chef.io/inspec/
- **MITRE SAF CLI:** https://saf-cli.mitre.org/
- **STIG Viewer:** https://public.cyber.mil/stigs/srg-stig-tools/

### Related Blog Posts
- **essential.coach** - VMware Security & Automation Blog
- Previous work: CKL/CKLB format conversion and STIG Viewer compatibility

---

## About the Author

**Noah Farshad** is a Senior Automation Consultant at VMware by Broadcom, specializing in enterprise security compliance automation and STIG tools deployment. His work focuses on helping customers implement automated compliance scanning for VMware vSphere/ESXi environments using specialized appliances and InSpec-based tools.

Connect: [essential.coach](https://essential.coach)

---

**Document Version:** 1.0  
**Last Updated:** December 16, 2025  
**STIG Version:** vSphere 8.0 v2r3-stig (Version 2 Release 3)  
**Tested Environment:** vSphere 8.0 U3, STIG Tools Appliance (Photon OS 5.0)
