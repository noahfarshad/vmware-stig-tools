#!/bin/bash
# Example invocations for the vmware-stig-tools toolkit
#
# These are illustrative — copy and adapt the lines you need.
# Don't run this script verbatim; it's a reference, not a runner.

# =============================================================================
# Common environment setup
# =============================================================================

# Set vCenter credentials. PowerShell-style env vars are what the InSpec
# vmware:// transport reads.
export VISERVER="vcenter.example.com"
export VISERVER_USERNAME="administrator@vsphere.local"
export VISERVER_PASSWORD='YourActualP@ssw0rd!'

# Output directory for reports
export REPORT_DIR="/tmp/reports"
mkdir -p "$REPORT_DIR"

# STIG content paths on the appliance
export STIG_BASE="/usr/share/stigs/vsphere/8.0/v2r3-stig"
export VSPHERE_BASELINE="$STIG_BASE/vsphere/inspec/vmware-vsphere-8.0-stig-baseline"
export VCSA_BASELINE="$STIG_BASE/vcsa/inspec/vmware-vcsa-8.0-stig-baseline"


# =============================================================================
# 1. vCenter Product Controls (API-based)
# =============================================================================
# Scans the vCenter product itself — roles, permissions, API surface,
# certificate handling, etc. ~67 controls.

cd "$VSPHERE_BASELINE"
cinc-auditor exec ./vcenter/ \
    -t vmware:// \
    --show-progress \
    --enhanced-outcomes \
    --reporter cli json:"$REPORT_DIR/vCenter_Product.json"


# =============================================================================
# 2. ESXi Host Controls (per-host accreditation)
# =============================================================================
# For accreditation, use the enhanced PowerShell runner so you get one CKL
# per host. Direct cinc-auditor invocation produces a single aggregate JSON
# which is fine for compliance dashboards but not for accreditation packages.

# Direct (single aggregate report):
cinc-auditor exec ./esxi/ \
    -t vmware:// \
    --input-file "$VSPHERE_BASELINE/inputs-example.yml" \
    --show-progress \
    --enhanced-outcomes \
    --reporter cli json:"$REPORT_DIR/ESXi_All.json"

# Recommended (per-host JSON + CKL via enhanced runner):
pwsh -c "
\$cred = New-Object System.Management.Automation.PSCredential('$VISERVER_USERNAME', (ConvertTo-SecureString '$VISERVER_PASSWORD' -AsPlainText -Force))
./inspec-runner/VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 \
    -vcenter $VISERVER \
    -allhosts \
    -vccred \$cred \
    -reportPath $REPORT_DIR/esxi \
    -inspecPath $VSPHERE_BASELINE/esxi \
    -inputsFile $VSPHERE_BASELINE/inputs-example.yml
"


# =============================================================================
# 3. VCSA Appliance Components (SSH-based)
# =============================================================================
# Scans the appliance OS, PostgreSQL, and the various vSphere services.
# Different transport (ssh:// instead of vmware://) because these are
# component-level checks that need shell access.

cd "$VCSA_BASELINE"
cinc-auditor exec . \
    -t "ssh://root@$VISERVER" \
    --password "$VCSA_ROOT_PASSWORD" \
    --show-progress \
    --enhanced-outcomes \
    --reporter cli json:"$REPORT_DIR/VCSA_Appliance.json"


# =============================================================================
# 4. CKL → CKLB Conversion for STIG Viewer 3.x
# =============================================================================
# STIG Viewer 3.x reads CKLB natively. Direct conversion preserves metadata
# better than CKL import + re-export from STIG Viewer 3.x.

# First convert JSON to CKL via SAF CLI:
saf convert hdf2ckl \
    -i "$REPORT_DIR/vCenter_Product.json" \
    -o "$REPORT_DIR/vCenter_Product.ckl" \
    --hostname vcsa-01 \
    --fqdn vcsa-01.example.com \
    --ip 192.168.1.100

# Then convert CKL to native CKLB:
python3 ../ckl-converter/ckl_to_cklb_converter.py \
    "$REPORT_DIR/vCenter_Product.ckl" \
    "$REPORT_DIR/vCenter_Product.cklb"


# =============================================================================
# 5. Full pipeline (one-liner)
# =============================================================================
# Useful for cron-driven scheduled scans. Adjust paths for your environment.

mkdir -p "$REPORT_DIR" && \
cd "$VSPHERE_BASELINE" && \
cinc-auditor exec ./vcenter/ -t vmware:// --reporter json:"$REPORT_DIR/vCenter.json" && \
cd "$VCSA_BASELINE" && \
cinc-auditor exec . -t "ssh://root@$VISERVER" --password "$VCSA_ROOT_PASSWORD" \
    --reporter json:"$REPORT_DIR/VCSA.json" && \
saf convert hdf2ckl -i "$REPORT_DIR/vCenter.json" -o "$REPORT_DIR/vCenter.ckl" \
    --hostname vcsa-01 --fqdn vcsa-01.example.com --ip 192.168.1.100 && \
saf convert hdf2ckl -i "$REPORT_DIR/VCSA.json" -o "$REPORT_DIR/VCSA.ckl" \
    --hostname vcsa-01 --fqdn vcsa-01.example.com --ip 192.168.1.100 && \
ls -lh "$REPORT_DIR/"
