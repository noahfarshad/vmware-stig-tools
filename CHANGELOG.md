# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-04

### Initial Release

Production-tested tooling for VMware vSphere 8.0 STIG compliance scanning and reporting,
emerged from a federal-customer compliance engagement.

### Added

- **`train-vmware-fix/` v1.0.0** — Patched `connection.rb` for the train-vmware InSpec plugin.
  Fixes special-character handling in vCenter passwords by Base64-encoding before passing
  to PowerShell, preventing shell metacharacter interpretation (`$`, `%`, `&`, `|`, backticks,
  quotes, backslashes). Includes idempotent `install.sh` with backup of original file.

- **`inspec-runner/` v2.0** — Enhanced PowerShell script for running the VMware vSphere 8.0
  STIG ESXi InSpec profile across one or all ESXi hosts in a cluster. Produces individual
  JSON and CKL reports per host suitable for STIG accreditation. Supports `allhosts` mode
  for full-cluster scans, automatic SAF CLI conversion, and consolidated summary reporting.

- **`ckl-converter/` v1.0** — Python converter from legacy CKL (XML) format to native
  STIG Viewer 3.x CKLB (JSON) format. Preserves mode flags, GUIDs, target metadata,
  and finding details that get lost in the round-trip through STIG Viewer 3.x's import path.
  Handles the v2r3 STIG content baseline.

- **`docs/`** — Three documentation guides:
  - `STIG_Appliance_Network_Configuration.md` — Static IP configuration on Photon OS 5.0
    using `systemd-networkd` (federal environments where DHCP is not available).
  - `VMware_STIG_Cheat_Sheet.md` — Quick-reference for common STIG scanning tasks.
  - `VMware_vSphere_STIG_Scanning_Guide.md` — End-to-end walkthrough of vSphere 8.0
    STIG scanning workflow including train-vmware setup, InSpec invocation, CINC Auditor
    alternatives, SAF CLI conversion, and STIG Viewer 3.x reporting.

- **`examples/`** — Sample InSpec inputs file and example invocation script demonstrating
  the full scanning pipeline.

### Tested Against

- VMware vSphere 8.0 U3
- VMware STIG Tools Appliance (Photon OS 5.0)
- train-vmware InSpec plugin v0.2.0
- vmware-vsphere-8.0-stig-baseline v2r3
- STIG Viewer 3.x
- CINC Auditor (open-source InSpec replacement)
- SAF CLI

### Origin

This tooling was developed during a federal agency customer's STIG compliance program
and is published with all customer-identifying information removed. The patterns and
fixes apply broadly to any organization performing vSphere STIG scanning at scale.

See the customer success story on [essential.coach](https://essential.coach/) for the full
engagement narrative once published.

[1.0.0]: https://github.com/noahfarshad/vmware-stig-tools/releases/tag/v1.0.0
