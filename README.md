# vmware-stig-tools

Production-tested tooling for VMware vSphere 8.0 STIG compliance scanning and reporting.

This repository collects the tools that emerged from a federal-customer STIG compliance engagement: workarounds for issues with the VMware STIG Tools Appliance, a CKL → CKLB format converter for STIG Viewer 3.x compatibility, and an enhanced InSpec runner script that produces per-host accreditation reports.

**The step after these tools is [STIG Triage](https://github.com/noahfarshad/stig-triage):** it reads the per-host checklists this runner produces, turns the open findings into reviewed fix plans and POA&M entries, and scans vCenter Server, ESXi, the vCenter appliance, Linux and Windows into checklists itself, as one program for Windows or Linux. Its story is [The Fix Plan That Would Have Undone the Hardening](https://essential.coach/stig-triage-open-findings-to-approved-fix-plans/).

## What's Included

| Component | Purpose | Language |
|---|---|---|
| [`train-vmware-fix/`](./train-vmware-fix/) | Patched `connection.rb` for the train-vmware InSpec plugin — fixes special-character handling in vCenter passwords | Ruby |
| [`inspec-runner/`](./inspec-runner/) | Enhanced PowerShell runner that produces individual JSON + CKL reports per ESXi host for STIG accreditation | PowerShell |
| [`ckl-converter/`](./ckl-converter/) | Python converter from legacy CKL (XML) format to native STIG Viewer 3.x CKLB (JSON) format | Python |
| [`docs/`](./docs/) | VMware STIG scanning guide, quick-reference cheat sheet, and STIG appliance network configuration guide | Markdown |
| [`examples/`](./examples/) | Sample InSpec inputs file and example invocations | YAML / Bash |

## Background

The VMware STIG Tools Appliance ships ready-to-use, but in real federal customer engagements you encounter edge cases the documentation doesn't cover:

- **Passwords with special characters break authentication** because `train-vmware`'s `connection.rb` passes them directly to PowerShell where `$`, `%`, `&`, etc. get interpreted as shell metacharacters before the auth call ever happens.
- **Per-host CKL reports for accreditation** require running InSpec separately against each ESXi host with the right inputs file, then converting JSON → CKL via SAF CLI. The provided sample script handles single hosts; auditors need it run against full clusters or `allhosts`.
- **STIG Viewer 3.x prefers native CKLB (JSON)** over legacy CKL (XML). Importing CKL files into STIG Viewer 3.x works but loses fidelity (mode flags, GUIDs, target metadata). A direct converter that produces the expanded native format avoids the round-trip.
- **The appliance defaults to DHCP** but federal environments need static IPs configured against `systemd-networkd` (Photon OS 5.0). Standard `network-scripts` files don't apply.

This repository captures the fixes and tooling for all four of these.

## Quick Start

### train-vmware password fix

If your vCenter administrator password contains special characters (`$`, `%`, `&`, `|`, backticks, quotes, backslashes), apply the fix before running scans:

```bash
cd train-vmware-fix
chmod +x install.sh
sudo ./install.sh
```

The installer backs up the original `connection.rb` and replaces it with a Base64-encoded version that survives PowerShell variable interpolation. See [`train-vmware-fix/README.md`](./train-vmware-fix/README.md) for the full story.

### Enhanced InSpec runner for ESXi accreditation

Generate per-host JSON and CKL reports for STIG accreditation:

```powershell
$cred = Get-Credential
.\inspec-runner\VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 `
    -vcenter 192.168.1.100 `
    -allhosts `
    -vccred $cred `
    -reportPath /tmp/reports/esxi `
    -inspecPath /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline/esxi `
    -inputsFile /usr/share/stigs/vsphere/8.0/v2r3-stig/vsphere/inspec/vmware-vsphere-8.0-stig-baseline/inputs-example.yml
```

Supports `-allhosts`, `-cluster`, or specific `-hosts`. See [`inspec-runner/README.md`](./inspec-runner/README.md) for full parameters and examples.

### CKL → CKLB conversion

```bash
python3 ckl-converter/ckl_to_cklb_converter.py input.ckl output.cklb
```

Produces the expanded STIG Viewer 3.x native format with proper UUIDs, target metadata, and mode flags. Detailed usage in [`ckl-converter/README.md`](./ckl-converter/README.md).

### Documentation

- [`docs/VMware_vSphere_STIG_Scanning_Guide.md`](./docs/VMware_vSphere_STIG_Scanning_Guide.md) — full walkthrough from appliance setup through report generation
- [`docs/VMware_STIG_Cheat_Sheet.md`](./docs/VMware_STIG_Cheat_Sheet.md) — quick reference for the common scan commands
- [`docs/STIG_Appliance_Network_Configuration.md`](./docs/STIG_Appliance_Network_Configuration.md) — static IP configuration for the Photon OS 5.0 appliance via `systemd-networkd`

## Customer Story

For the engagement narrative — the challenges, the discoveries, the lessons learned — see the customer success story:

**[STIG Compliance at Federal Scale: Building VMware Compliance Tooling for vSphere 8.0](https://essential.coach/vmware-stig-compliance-tooling/)**

The sequel, on what to do about the open findings and the scanner that grew out of it: **[The Fix Plan That Would Have Undone the Hardening: STIG Triage, From Open Findings to Approved Fix Plans](https://essential.coach/stig-triage-open-findings-to-approved-fix-plans/)**

## Compatibility

- **VMware vSphere 8.0** (U2 / U3) with v2r3 STIG content
- **VMware STIG Tools Appliance** running Photon OS 5.0
- **CINC Auditor** 6.6.0+ (or InSpec equivalent)
- **train-vmware plugin** 0.2.0
- **PowerShell 7+** with PowerCLI 13+
- **Python 3.7+** for the CKL converter
- **SAF CLI** (MITRE Security Automation Framework) for CKL output

## License

GPL-3.0. See [`LICENSE`](./LICENSE).

## Contributing

Issues and PRs welcome. The patterns in this repository emerged from real customer engagements — if you've hit similar issues and have improvements, please contribute back.

## Author

Noah Farshad — [essential.coach](https://essential.coach) — [noah@essential.coach](mailto:noah@essential.coach)
