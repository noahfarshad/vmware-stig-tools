# Enhanced VMware vSphere 8.0 STIG ESXi InSpec Runner

A PowerShell script that wraps CINC Auditor (or InSpec) for ESXi STIG scanning, with three improvements over the sample script shipped with the VMware STIG Tools Appliance:

1. **`-allhosts` switch** — scan every ESXi host in vCenter in a single invocation
2. **Per-host report generation** — produces individual JSON and CKL files per host (not a single aggregate report)
3. **Multiple targeting modes** — scan all hosts, a specific cluster, or named hosts

The per-host CKL output is the format DoD STIG accreditation requires.

## Why an Enhanced Runner?

The official sample runner expects you to specify a single ESXi host. For accreditation across larger environments, you need:

- One JSON file per host (machine-readable for SAF CLI conversion)
- One CKL file per host (auditor-readable, hand-attestable)
- Consistent file naming so the CKL set can be uploaded as a batch
- `allhosts` and cluster-level targeting because typing host names doesn't scale

This script handles all of that with PowerShell parameter sets that make the targeting mode explicit.

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-vcenter` | string | yes | vCenter Server hostname or IP |
| `-vccred` | PSCredential | yes | Credentials for vCenter authentication |
| `-allhosts` | switch | one of these three | Scan every ESXi host in vCenter |
| `-cluster` | string | one of these three | Scan all hosts in the named cluster |
| `-hosts` | string[] | one of these three | Scan the named hosts only |
| `-reportPath` | string | yes | Directory to write per-host reports |
| `-inspecPath` | string | yes | Path to the InSpec ESXi profile directory |
| `-inputsFile` | string | yes | Path to the InSpec inputs YAML |
| `-attestationFile` | string | optional | SAF CLI attestation file for partial-fail overrides |

## Examples

### Scan all hosts in vCenter

```powershell
$cred = Get-Credential
.\VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 `
    -vcenter 192.168.1.100 `
    -allhosts `
    -vccred $cred `
    -reportPath /tmp/reports/esxi `
    -inspecPath /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline/esxi `
    -inputsFile /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline/inputs-example.yml
```

### Scan a specific cluster

```powershell
.\VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 `
    -vcenter 192.168.1.100 `
    -cluster "Production" `
    -vccred $cred `
    -reportPath /tmp/reports/esxi `
    -inspecPath /path/to/esxi `
    -inputsFile /path/to/inputs.yml
```

### Scan specific hosts

```powershell
.\VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 `
    -vcenter 192.168.1.100 `
    -hosts "esxi-01.local","esxi-02.local","esxi-03.local" `
    -vccred $cred `
    -reportPath /tmp/reports/esxi `
    -inspecPath /path/to/esxi `
    -inputsFile /path/to/inputs.yml
```

## Output Files

For each ESXi host scanned, the script produces two files in `-reportPath`:

```
ESXi_<hostname>_<timestamp>.json    # CINC Auditor JSON report
ESXi_<hostname>_<timestamp>.ckl     # SAF-converted DoD CKL for accreditation
```

The hostname is sanitized (dots become underscores) so the filenames stay safe across filesystems.

## Requirements

- **PowerShell 7+** (the script uses pipeline parallelism in some paths)
- **PowerCLI 13+** (for vCenter connectivity)
- **CINC Auditor 6.6.0+** (or InSpec equivalent) on the runner host
- **SAF CLI** installed and in `PATH` (for CKL output)
- **train-vmware plugin** with the [special-character password fix](../train-vmware-fix/) applied if your vCenter password contains special characters
- **Network reachability** from the runner host to the vCenter API and to all ESXi hosts being scanned

## How It Works

1. Connects to vCenter using the supplied credentials
2. Resolves the target host list based on the targeting parameter (`-allhosts`, `-cluster`, or `-hosts`)
3. For each target host:
   - Sets the appropriate environment variables (`VISERVER`, `VISERVER_USERNAME`, `VISERVER_PASSWORD`, `VMHOSTNAME`)
   - Invokes `cinc-auditor exec` with the InSpec profile and inputs file
   - Writes the JSON report
   - Invokes `saf convert hdf2ckl` to produce the CKL
4. Disconnects from vCenter
5. Prints a summary of files produced

The per-host scan uses the `vmware://` transport, not SSH — InSpec talks to the vCenter API and gets per-host detail through the API, so you don't need SSH access to each ESXi host directly.

## Common Issues

**Authentication fails immediately on every host:** if your vCenter password contains special characters, install the [`train-vmware-fix`](../train-vmware-fix/) patch first.

**Some hosts time out, others succeed:** vCenter API rate limiting. The script doesn't currently throttle. For large environments, run against clusters individually rather than `-allhosts`.

**SAF CLI not found:** install via `npm install -g @mitre/saf` or use the appliance's bundled version (it's in `PATH` by default on the VMware STIG Tools Appliance).

**InSpec profile path wrong:** the appliance ships profiles at `/usr/share/stigs/vsphere/8.0/<version>/vsphere/inspec/vmware-vsphere-8.0-stig-baseline/`. Confirm the version (v2r3 at this writing) and use the appliance-resident path; don't try to run from a copy unless you've copied the entire baseline directory.

## See Also

- [`../docs/VMware_vSphere_STIG_Scanning_Guide.md`](../docs/VMware_vSphere_STIG_Scanning_Guide.md) — full walkthrough including environment setup
- [`../docs/VMware_STIG_Cheat_Sheet.md`](../docs/VMware_STIG_Cheat_Sheet.md) — quick reference for common scan commands
- [`../examples/`](../examples/) — sample inputs file and example invocations
