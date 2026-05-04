# VMware vSphere 8.0 STIG Scanning - Quick Reference Cheat Sheet

**Author:** Noah Farshad | **Blog:** essential.coach | **Version:** 1.0 | **Date:** December 2025

---

## Environment Variables Setup

```bash
# Enter PowerShell
pwsh

# Set vCenter connection details
$env:VISERVER='192.168.1.100'
$env:VISERVER_USERNAME='administrator@vsphere.local'
$env:VISERVER_PASSWORD='YourPasswordHere'
```

**Special Character Escaping:** Each single quote `'` → four ticks `''''`

---

## Complete vCenter STIG Audit (All Components)

### 1. Scan vCenter Product Controls (API-based)

**Working Directory:** `/vsphere/inspec/` baseline

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
pwd  # Verify: should show vsphere/inspec path
cinc-auditor exec ./vcenter/ -t vmware:// --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/vCenter_Product.json
```

**Covers:** ~67 vCenter product-level STIG controls

---

## Scan ESXi Hosts

**Working Directory:** `/vsphere/inspec/` baseline (same as vCenter)

```bash
# Ensure environment variables are still set from vCenter scan
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline

# Configure inputs file first
vi inputs-example.yml
# Set: esximode: 'allesxi'
# Set: syslogServer, ntpServers, etc.

# Scan all ESXi hosts
cinc-auditor exec ./esxi/ -t vmware:// --input-file ./inputs-example.yml --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/ESXi_All_Hosts.json
```

**Covers:** ~240 ESXi security controls per host

**Common esximode Options:**
- `allesxi` - Scan all ESXi hosts in vCenter
- `cluster` - Scan all hosts in a specific cluster
- `host` - Scan a single ESXi host

**Note:** For accreditation, use PowerShell runner script to generate individual CKL per host:
- Location: `/usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/powercli/`
- Script: `VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner.ps1`

---

## Scan VCSA Appliance Components (SSH-based)

### 3. Scan VCSA Appliance Components

**Working Directory:** `/vcsa/inspec/` baseline

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
pwd  # Verify: should show vcsa/inspec path
cinc-auditor exec . -t 'ssh://root@192.168.1.100' --password 'RootPassword' --show-progress --enhanced-outcomes --reporter cli json:/tmp/reports/VCSA_Appliance.json
```

**Covers:** All 9 appliance components in one comprehensive scan (200+ checks total)
- PostgreSQL (~30 checks)
- Photon OS 4.0 (~140 checks)  
- EAM, Envoy, Lookup, Perfcharts, STS, VAMI, UI (remaining checks)

**Runtime:** 5-10 minutes for complete VCSA scan

---

## Individual VCSA Component Scans

**Working Directory:** `/vcsa/inspec/` baseline

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline

# PostgreSQL
cinc-auditor exec ./postgresql/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_PostgreSQL.json

# Photon OS
cinc-auditor exec ./photon/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_Photon.json

# EAM
cinc-auditor exec ./eam/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_EAM.json

# Envoy
cinc-auditor exec ./envoy/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_Envoy.json

# Lookup
cinc-auditor exec ./lookup/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_Lookup.json

# Perfcharts
cinc-auditor exec ./perfcharts/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_Perfcharts.json

# STS
cinc-auditor exec ./sts/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_STS.json

# UI
cinc-auditor exec ./ui/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_UI.json

# VAMI
cinc-auditor exec ./vami/ -t 'ssh://root@192.168.1.100' --password 'Password' --show-progress --reporter json:/tmp/reports/VCSA_VAMI.json
```

---

## Scan ESXi Hosts Only

**Working Directory:** `/vsphere/inspec/` baseline

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline

# Configure inputs first (vi inputs-example.yml)
cinc-auditor exec ./esxi/ -t vmware:// --input-file ./inputs-example.yml --show-progress --reporter json:/tmp/reports/ESXi_Scan.json
```

---

## Report Conversion

### Generate CKL Files (Works with STIG Viewer 2.x and 3.x)

```bash
saf convert hdf2ckl -i /tmp/reports/vCenter_Product.json -o /tmp/reports/vCenter_Product.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100

saf convert hdf2ckl -i /tmp/reports/VCSA_Appliance.json -o /tmp/reports/VCSA_Appliance.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100
```

**Important Notes:**
- Node.js warnings are normal - they indicate successful conversion!
- SAF CLI produces **CKL format (XML only)**, not CKLB (JSON)
- CKL files work with both STIG Viewer 2.x and 3.x

---

## Individual Component Scans

### vCenter Only (No ESXi, No VMs)

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
cinc-auditor exec ./vcenter/ -t vmware:// --show-progress \
  --reporter json:/tmp/reports/vCenter_Only.json
```

### PostgreSQL Only

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
cinc-auditor exec ./postgresql/ -t ssh://root@192.168.1.100 --password 'Password' \
  --show-progress --reporter json:/tmp/reports/PostgreSQL_Only.json
```

### Photon OS Only

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
cinc-auditor exec ./photon/ -t ssh://root@192.168.1.100 --password 'Password' \
  --show-progress --reporter json:/tmp/reports/Photon_Only.json
```

### VAMI Only

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline
cinc-auditor exec ./vami/ -t ssh://root@192.168.1.100 --password 'Password' \
  --show-progress --reporter json:/tmp/reports/VAMI_Only.json
```

---

## Verification Commands

```bash
# List generated reports
ls -lh /tmp/reports/

# Verify CKL format (XML)
head -n 20 /tmp/reports/vCenter_Product.ckl

# Verify CKLB format (JSON)
jq '.title' /tmp/reports/vCenter_Product.cklb

# Count number of checks in JSON report
jq '.profiles[0].controls | length' /tmp/reports/vCenter_Product.json
```

---

## Troubleshooting

### Check Tool Versions

```bash
cinc-auditor version
saf version
cinc-auditor plugin list | grep train-vmware
```

### Test Connectivity

```bash
# Test vCenter API (in PowerShell)
Connect-VIServer -Server $env:VISERVER -User $env:VISERVER_USERNAME -Password $env:VISERVER_PASSWORD

# Test SSH to VCSA
ssh root@192.168.1.100
```

### Install train-vmware Plugin (if missing)

```bash
cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline
cinc-auditor plugin install train-vmware-0.2.0.gem
```

---

## Repository Structure

```
/usr/share/stigs/vsphere/8.0/v2r3-stig/
├── vsphere/inspec/vmware-vsphere-8.0-stig-baseline/  ← vCenter PRODUCT controls
│   ├── vcenter/     ← vCenter product controls (API-based)
│   ├── esxi/        ← ESXi host controls (API-based) *** USE THIS FOR ESXI ***
│   └── vm/          ← Virtual Machine controls
└── vcsa/inspec/vmware-vcsa-8.0-stig-baseline/       ← VCSA APPLIANCE components
    ├── postgresql/  ← PostgreSQL database (SSH-based)
    ├── photon/      ← Photon OS 4.0
    ├── eam/         ← ESX Agent Manager
    ├── envoy/       ← Envoy proxy
    ├── lookup/      ← Lookup service
    ├── perfcharts/  ← Performance charts
    ├── sts/         ← Security Token Service
    ├── vami/        ← Virtual Appliance Management
    └── ui/          ← vSphere UI service
```

**⚠️ CRITICAL:** Always verify your working directory with `pwd` before running scans!

**For ESXi Host Scanning:** Use `/vsphere/inspec/` baseline, NOT `/vcsa/inspec/`

---

## Key Concepts

**Two Connection Types:**
1. **API-based** (`vmware://`) - For vCenter product controls, ESXi, and VMs
2. **SSH-based** (`ssh://`) - For VCSA appliance components
   - **Important in PowerShell:** Quote the SSH target: `-t 'ssh://root@IP'`

**Report Formats:**
- **JSON** - Native InSpec output
- **CKL** - XML format for STIG Viewer (works with 2.x and 3.x)
- **Note:** SAF CLI does NOT produce true CKLB format

**Complete Coverage Requires:**
- ✅ vCenter product scan (API)
- ✅ VCSA appliance scan (SSH)

---

## One-Liner: Complete Audit Script

**Note:** This is formatted as a single long command. For readability, the step-by-step approach above is recommended.

```bash
mkdir -p /tmp/reports && pwsh -c '$env:VISERVER="192.168.1.100"; $env:VISERVER_USERNAME="administrator@vsphere.local"; $env:VISERVER_PASSWORD="YourPassword"; cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline; cinc-auditor exec ./vcenter/ -t vmware:// --show-progress --reporter json:/tmp/reports/vCenter.json' && cd /usr/share/stigs/vsphere/8.0/v2r3-stig/vcsa/inspec/vmware-vcsa-8.0-stig-baseline && cinc-auditor exec . -t 'ssh://root@192.168.1.100' --password 'RootPassword' --show-progress --reporter json:/tmp/reports/VCSA.json && saf convert hdf2ckl -i /tmp/reports/vCenter.json -o /tmp/reports/vCenter.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100 && saf convert hdf2ckl -i /tmp/reports/VCSA.json -o /tmp/reports/VCSA.ckl --hostname vcsa-01 --fqdn vcsa-01.essential.coach --ip 192.168.1.100 && ls -lh /tmp/reports/
```

This single command:
1. Creates report directory
2. Scans vCenter product controls (67 checks)
3. Scans all 9 VCSA appliance components (200+ checks)
4. Converts both to CKL format
5. Lists all generated reports

**Note:** The SSH target is quoted (`'ssh://root@...'`) for PowerShell compatibility

---

**Resources:**
- Full Guide: See "VMware_vSphere_STIG_Scanning_Guide.md"
- Blog: https://essential.coach
- DoD Repo: https://github.com/vmware/dod-compliance-and-automation
- DISA STIGs: https://public.cyber.mil/stigs/

**Version:** 1.0 | **Date:** December 16, 2025 | **STIG:** vSphere 8.0 v2r3 | **Author:** Noah Farshad
