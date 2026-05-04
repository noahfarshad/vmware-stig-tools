# CKL → CKLB Converter

Convert legacy DISA STIG Viewer CKL (XML) files to the native STIG Viewer 3.x CKLB (JSON) format.

## Why This Exists

DISA STIG Viewer 3.x reads two formats:

- **CKL** — the legacy XML format produced by STIG Viewer 2.x and most existing tooling
- **CKLB** — the native JSON format introduced in STIG Viewer 3.x

STIG Viewer 3.x can import CKL files, but the import lossily flattens the data: target metadata gets simplified, mode flags are lost, GUIDs are regenerated, and the `cklb_version` field gets set to a compatibility value rather than the native one.

For accreditation packages submitted to STIG Viewer 3.x environments — and for any tooling downstream that expects native CKLB — a direct CKL → CKLB converter that produces the *expanded* native format avoids the round-trip data loss.

This converter walks the CKL XML, builds the corresponding CKLB JSON structure with proper UUIDs, target_data fields, and stigs/rules nesting, and writes the result.

## Usage

```bash
python3 ckl_to_cklb_converter.py input.ckl output.cklb
```

That's it. No flags, no configuration. The converter reads the CKL, transforms it, and writes the CKLB.

## What Gets Converted

| CKL XML Field | CKLB JSON Path |
|---|---|
| `ASSET/HOST_NAME` | `target_data.host_name` |
| `ASSET/HOST_IP` | `target_data.ip_address` |
| `ASSET/HOST_MAC` | `target_data.mac_address` |
| `ASSET/HOST_FQDN` | `target_data.fqdn` |
| `ASSET/ROLE` | `target_data.role` |
| `ASSET/TECH_AREA` | `target_data.technology_area` |
| `STIG_INFO` fields | `stigs[*].display_name`, `stig_id`, `version`, `release_info` |
| `VULN/STIG_DATA` rule details | `stigs[*].rules[*].rule_id`, `vuln_num`, `severity`, `group_title`, etc. |
| `VULN/STATUS` | `stigs[*].rules[*].status` (Open / NotAFinding / Not_Applicable / Not_Reviewed) |
| `VULN/FINDING_DETAILS` | `stigs[*].rules[*].finding_details` |
| `VULN/COMMENTS` | `stigs[*].rules[*].comments` |

The converter generates a fresh top-level `id` (UUID v4) per output file and per stig, matching the STIG Viewer 3.x expectation that each CKLB has a stable identifier.

## Why Native Format Matters

If you import a CKL file into STIG Viewer 3.x, then export it as CKLB, you get a slightly different document than if you use this converter:

- **Native conversion** (this tool): produces `cklb_version: "1.0"`, sets `mode: 2` (the standard standalone-document mode), preserves the full target metadata, keeps target_type / role / technology_area as separate fields.
- **STIG Viewer 3.x import + export**: collapses some fields, regenerates UUIDs on every export (so document identity drifts), flags the document as imported.

For accreditation packages where document identity should be stable and the metadata should match what the original tool captured, the native conversion is preferable.

## Compatibility

- **Python 3.7+** (uses standard library only — no external dependencies)
- **Input:** any CKL produced by STIG Viewer 2.x, SAF CLI `hdf2ckl`, or other DISA-conformant tooling
- **Output:** CKLB readable by STIG Viewer 3.0.0 and later

## Limitations

- The converter does not validate CKL input against a schema. If the input is malformed XML, you'll get a `xml.etree.ElementTree.ParseError`.
- The converter does not reverse-direction (CKLB → CKL). For that you need DISA STIG Viewer or SAF CLI's reverse conversions.
- Comments and finding_details are passed through unchanged, including any HTML entities. STIG Viewer 3.x renders these correctly; downstream tooling may need to decode entities.

## Example: Full Pipeline

```bash
# 1. Run InSpec scan, output JSON
cinc-auditor exec ./esxi/ -t vmware:// \
    --input vmhostName=esxi-01.example.com \
    --reporter json:/tmp/reports/esxi-01.json

# 2. Convert JSON to CKL via SAF CLI
saf convert hdf2ckl \
    -i /tmp/reports/esxi-01.json \
    -o /tmp/reports/esxi-01.ckl \
    --hostname esxi-01 \
    --fqdn esxi-01.example.com \
    --ip 192.168.1.10

# 3. Convert CKL to native CKLB for STIG Viewer 3.x
python3 ckl_to_cklb_converter.py /tmp/reports/esxi-01.ckl /tmp/reports/esxi-01.cklb
```

The result is a CKLB that opens cleanly in STIG Viewer 3.x with full metadata fidelity.

## Author

Noah Farshad — [essential.coach](https://essential.coach)

## License

GPL-3.0 (matching the parent repository).
