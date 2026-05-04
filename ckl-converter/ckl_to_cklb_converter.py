#!/usr/bin/env python3
"""
CKL to STIG Viewer 3.x Native CKLB Converter by Noah Farshad
Converts DISA STIG Viewer checklist files from CKL (XML) format 
to the native STIG Viewer 3.x CKLB (JSON) format.

This produces the expanded CKLB format used by STIG Viewer 3.x,
not the compact Heimdall CKLB format.
"""

import xml.etree.ElementTree as ET
import json
import sys
import os
import uuid
from pathlib import Path
from typing import Dict, List, Any


def parse_ckl_to_stigviewer3_cklb(ckl_path: str) -> Dict[str, Any]:
    """
    Parse a CKL XML file and convert to STIG Viewer 3.x native CKLB format.
    
    Args:
        ckl_path: Path to the CKL file
        
    Returns:
        Dictionary containing the checklist data in STIG Viewer 3.x CKLB format
    """
    tree = ET.parse(ckl_path)
    root = tree.getroot()
    
    # Initialize the STIG Viewer 3.x CKLB structure
    cklb_data = {
        "title": "",
        "id": str(uuid.uuid4()),
        "active": False,
        "mode": 2,
        "has_path": True,
        "target_data": {},
        "stigs": [],
        "cklb_version": "1.0"
    }
    
    # Parse ASSET section
    asset = root.find('.//ASSET')
    if asset is not None:
        # Map CKL asset fields to STIG Viewer 3.x target_data format
        target_data = {
            "target_type": asset.findtext('ASSET_TYPE', ''),
            "host_name": asset.findtext('HOST_NAME', ''),
            "ip_address": asset.findtext('HOST_IP', ''),
            "mac_address": asset.findtext('HOST_MAC', ''),
            "fqdn": asset.findtext('HOST_FQDN', ''),
            "comments": asset.findtext('TARGET_COMMENT', ''),
            "role": asset.findtext('ROLE', ''),
            "is_web_database": asset.findtext('WEB_OR_DATABASE', 'false').lower() == 'true',
            "technology_area": asset.findtext('TECH_AREA', ''),
            "web_db_site": asset.findtext('WEB_DB_SITE', ''),
            "web_db_instance": asset.findtext('WEB_DB_INSTANCE', ''),
            "classification": None
        }
        cklb_data["target_data"] = target_data
        cklb_data["title"] = target_data["host_name"] or "Untitled"
    
    # Parse STIGS section
    stigs_element = root.find('.//STIGS')
    if stigs_element is not None:
        for stig_element in stigs_element.findall('iSTIG'):
            # Parse STIG_INFO to get STIG metadata
            stig_info_elem = stig_element.find('STIG_INFO')
            stig_metadata = {}
            if stig_info_elem is not None:
                for si_data in stig_info_elem.findall('SI_DATA'):
                    sid_name = si_data.findtext('SID_NAME', '')
                    sid_data = si_data.findtext('SID_DATA', '')
                    stig_metadata[sid_name] = sid_data
            
            # Create STIG structure
            stig_data = {
                "stig_name": stig_metadata.get('title', ''),
                "display_name": stig_metadata.get('title', ''),
                "stig_id": stig_metadata.get('stigid', ''),
                "version": stig_metadata.get('version', ''),
                "release_info": stig_metadata.get('releaseinfo', ''),
                "uuid": stig_metadata.get('uuid', str(uuid.uuid4())),
                "reference_identifier": "",
                "size": 0,  # Will be set to rule count
                "rules": []
            }
            
            # Parse VULNs (rules)
            rules = []
            for vuln in stig_element.findall('.//VULN'):
                # Extract all STIG_DATA into a lookup dict
                vuln_data = {}
                for stig_data_elem in vuln.findall('STIG_DATA'):
                    attr = stig_data_elem.findtext('VULN_ATTRIBUTE', '')
                    value = stig_data_elem.findtext('ATTRIBUTE_DATA', '')
                    vuln_data[attr] = value
                
                # Map to STIG Viewer 3.x rule structure
                rule = {
                    "group_id_src": vuln_data.get('Vuln_Num', ''),
                    "group_tree": [{
                        "id": vuln_data.get('Vuln_Num', ''),
                        "title": vuln_data.get('Group_Title', ''),
                        "description": "<GroupDescription></GroupDescription>"
                    }],
                    "group_id": vuln_data.get('Vuln_Num', ''),
                    "severity": vuln_data.get('Severity', 'medium'),
                    "group_title": vuln_data.get('Rule_Title', ''),
                    "rule_id_src": vuln_data.get('Rule_ID', ''),
                    "rule_id": vuln_data.get('Rule_ID', '').replace('_rule', '') if '_rule' in vuln_data.get('Rule_ID', '') else vuln_data.get('Rule_ID', ''),
                    "rule_version": vuln_data.get('Rule_Ver', ''),
                    "rule_title": vuln_data.get('Rule_Title', ''),
                    "fix_text": vuln_data.get('Fix_Text', ''),
                    "weight": vuln_data.get('Weight', '10.0'),
                    "check_content": vuln_data.get('Check_Content', ''),
                    "check_content_ref": {
                        "href": vuln_data.get('STIGRef', ''),
                        "name": vuln_data.get('Check_Content_Ref', 'M')
                    },
                    "classification": vuln_data.get('Class', 'Unclass'),
                    "discussion": vuln_data.get('Vuln_Discuss', ''),
                    "false_positives": vuln_data.get('False_Positives', ''),
                    "false_negatives": vuln_data.get('False_Negatives', ''),
                    "documentable": vuln_data.get('Documentable', 'false').lower(),
                    "security_override_guidance": vuln_data.get('Security_Override_Guidance', ''),
                    "potential_impacts": vuln_data.get('Potential_Impact', ''),
                    "third_party_tools": vuln_data.get('Third_Party_Tools', ''),
                    "ia_controls": vuln_data.get('IA_Controls', ''),
                    "responsibility": vuln_data.get('Responsibility', ''),
                    "mitigations": vuln_data.get('Mitigations', ''),
                    "mitigation_control": vuln_data.get('Mitigation_Control', ''),
                    "legacy_ids": [],  # Would need to parse if present
                    "ccis": [vuln_data.get('CCI_REF', '')] if vuln_data.get('CCI_REF') else [],
                    "reference_identifier": "",
                    "uuid": vuln_data.get('STIG_UUID', str(uuid.uuid4())),
                    "stig_uuid": stig_data["uuid"],
                }
                
                # Add status, comments, finding_details from VULN level elements
                status = vuln.findtext('STATUS', 'Not_Reviewed')
                # Map status to STIG Viewer 3.x format (lowercase with underscores)
                status_map = {
                    'NotAFinding': 'not_a_finding',
                    'Not_A_Finding': 'not_a_finding',
                    'Not_Applicable': 'not_applicable',
                    'Open': 'open',
                    'Not_Reviewed': 'not_reviewed',
                    'NotReviewed': 'not_reviewed'
                }
                rule["status"] = status_map.get(status, status.lower().replace(' ', '_'))
                
                rule["overrides"] = {}
                rule["comments"] = vuln.findtext('COMMENTS', '')
                rule["finding_details"] = vuln.findtext('FINDING_DETAILS', '')
                
                rules.append(rule)
            
            stig_data["rules"] = rules
            stig_data["size"] = len(rules)
            cklb_data["stigs"].append(stig_data)
    
    return cklb_data


def write_cklb_file(data: Dict[str, Any], output_path: str) -> None:
    """
    Write the checklist data to a CKLB JSON file.
    
    Args:
        data: Dictionary containing the checklist data
        output_path: Path where the CKLB file should be written
    """
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)


def convert_ckl_to_cklb(input_path: str, output_path: str = None) -> str:
    """
    Convert a CKL file to STIG Viewer 3.x native CKLB format.
    
    Args:
        input_path: Path to the input CKL file
        output_path: Optional path for the output CKLB file.
                    If not provided, will use the same name with .cklb extension.
    
    Returns:
        Path to the created CKLB file
    """
    # Generate output path if not provided
    if output_path is None:
        input_file = Path(input_path)
        output_path = str(input_file.with_suffix('.cklb'))
    
    # Parse the CKL file
    print(f"Reading CKL file: {input_path}")
    cklb_data = parse_ckl_to_stigviewer3_cklb(input_path)
    
    # Write the CKLB file
    print(f"Writing STIG Viewer 3.x CKLB file: {output_path}")
    write_cklb_file(cklb_data, output_path)
    
    print(f"✓ Conversion complete!")
    print(f"  - Converted {len(cklb_data['stigs'])} STIG(s)")
    for stig in cklb_data['stigs']:
        print(f"  - {stig['stig_name']}: {stig['size']} rules")
    
    return output_path


def batch_convert(input_dir: str, output_dir: str = None) -> List[str]:
    """
    Convert all CKL files in a directory to CKLB format.
    
    Args:
        input_dir: Directory containing CKL files
        output_dir: Optional output directory. If not provided, files will be
                   created in the same directory as the input files.
    
    Returns:
        List of paths to created CKLB files
    """
    input_path = Path(input_dir)
    
    if not input_path.is_dir():
        raise ValueError(f"Input path is not a directory: {input_dir}")
    
    # Find all CKL files
    ckl_files = list(input_path.glob("*.ckl"))
    
    if not ckl_files:
        print(f"No CKL files found in {input_dir}")
        return []
    
    print(f"Found {len(ckl_files)} CKL file(s) to convert")
    
    output_files = []
    for ckl_file in ckl_files:
        if output_dir:
            output_path = Path(output_dir) / ckl_file.with_suffix('.cklb').name
        else:
            output_path = ckl_file.with_suffix('.cklb')
        
        try:
            convert_ckl_to_cklb(str(ckl_file), str(output_path))
            output_files.append(str(output_path))
        except Exception as e:
            print(f"Error converting {ckl_file}: {e}")
    
    return output_files


def main():
    """Main entry point for the script."""
    if len(sys.argv) < 2:
        print("CKL to STIG Viewer 3.x Native CKLB Converter")
        print("=" * 60)
        print()
        print("Usage:")
        print("  Single file:  python script.py <input.ckl> [output.cklb]")
        print("  Batch mode:   python script.py --batch <input_dir> [output_dir]")
        print()
        print("Examples:")
        print("  python script.py checklist.ckl")
        print("  python script.py checklist.ckl converted.cklb")
        print("  python script.py --batch ./ckl_files/")
        print("  python script.py --batch ./ckl_files/ ./cklb_files/")
        sys.exit(1)
    
    if sys.argv[1] == "--batch":
        # Batch conversion mode
        if len(sys.argv) < 3:
            print("Error: --batch requires an input directory")
            sys.exit(1)
        
        input_dir = sys.argv[2]
        output_dir = sys.argv[3] if len(sys.argv) > 3 else None
        
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
        
        batch_convert(input_dir, output_dir)
    else:
        # Single file conversion mode
        input_file = sys.argv[1]
        output_file = sys.argv[2] if len(sys.argv) > 2 else None
        
        if not os.path.exists(input_file):
            print(f"Error: Input file not found: {input_file}")
            sys.exit(1)
        
        convert_ckl_to_cklb(input_file, output_file)


if __name__ == "__main__":
    main()
