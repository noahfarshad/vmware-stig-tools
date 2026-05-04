<#
.SYNOPSIS
    VMware vSphere 8.0 STIG ESXi InSpec Runner - Enhanced Edition
    Runs InSpec scans against ESXi hosts with individual report generation per host

.DESCRIPTION
    This script connects to vCenter, retrieves ESXi hosts based on parameters,
    and runs InSpec compliance scans against each host individually.
    Generates individual JSON and CKL files per host for STIG accreditation.

.PARAMETER vcenter
    vCenter Server hostname or IP address

.PARAMETER vccred
    PSCredential object for vCenter authentication

.PARAMETER allhosts
    Switch parameter to scan ALL ESXi hosts in vCenter

.PARAMETER cluster
    Cluster name to scan all hosts within that cluster

.PARAMETER hosts
    Array of specific ESXi hostnames to scan

.PARAMETER reportPath
    Path where reports will be saved

.PARAMETER inspecPath
    Path to the InSpec ESXi profile directory

.PARAMETER inputsFile
    Path to the InSpec inputs YAML file

.PARAMETER attestationFile
    Optional path to SAF CLI attestation file

.EXAMPLE
    # Scan all hosts in vCenter
    $cred = Get-Credential
    .\VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 -vcenter 10.50.50.50 -allhosts -vccred $cred -reportPath /tmp/reports/esxi -inspecPath /path/to/esxi -inputsFile /path/to/inputs.yml

.EXAMPLE
    # Scan specific cluster
    .\VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 -vcenter 10.50.50.50 -cluster "Production" -vccred $cred -reportPath /tmp/reports/esxi -inspecPath /path/to/esxi -inputsFile /path/to/inputs.yml

.EXAMPLE
    # Scan specific hosts
    .\VMware_vSphere_8.0_STIG_ESXi_InSpec_Runner_Enhanced.ps1 -vcenter 10.50.50.50 -hosts "esxi-01.local","esxi-02.local" -vccred $cred -reportPath /tmp/reports/esxi -inspecPath /path/to/esxi -inputsFile /path/to/inputs.yml

.NOTES
    Author: Noah Farshad
    Version: 2.0 (Enhanced with -allhosts support)
    Modified: January 2026
    
    Requires:
    - PowerCLI 13+
    - PowerShell 7+
    - CINC Auditor 6.6.0+
    - SAF CLI (optional, for CKL generation)
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$vcenter,

    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential]$vccred,

    [Parameter(Mandatory=$false)]
    [switch]$allhosts,

    [Parameter(Mandatory=$false)]
    [string]$cluster,

    [Parameter(Mandatory=$false)]
    [string[]]$hosts,

    [Parameter(Mandatory=$true)]
    [string]$reportPath,

    [Parameter(Mandatory=$true)]
    [string]$inspecPath,

    [Parameter(Mandatory=$true)]
    [string]$inputsFile,

    [Parameter(Mandatory=$false)]
    [string]$attestationFile
)

# Function to write timestamped console messages
function Write-ToConsole {
    param([string]$message)
    $timestamp = Get-Date -Format "hh:mm:ss tt"
    Write-Host "$timestamp $message"
}

function Write-ToConsoleGreen {
    param([string]$message)
    $timestamp = Get-Date -Format "hh:mm:ss tt"
    Write-Host "$timestamp $message" -ForegroundColor Green
}

function Write-ToConsoleRed {
    param([string]$message)
    $timestamp = Get-Date -Format "hh:mm:ss tt"
    Write-Host "$timestamp $message" -ForegroundColor Red
}

# Validate parameter combinations
if (-not ($allhosts -or $cluster -or $hosts)) {
    Write-ToConsoleRed "...ERROR: Must specify either -allhosts, -cluster, or -hosts parameter"
    exit 1
}

if (($allhosts -and $cluster) -or ($allhosts -and $hosts) -or ($cluster -and $hosts)) {
    Write-ToConsoleRed "...ERROR: Can only specify ONE of: -allhosts, -cluster, or -hosts"
    exit 1
}

# Import PowerCLI modules
Write-ToConsole "...Importing PowerCLI modules"
try {
    Import-Module VMware.VimAutomation.Core -ErrorAction Stop | Out-Null
    $powerCLIVersion = (Get-Module VMware.VimAutomation.Core).Version
    Write-ToConsole "...PowerCLI version $powerCLIVersion loaded successfully"
} catch {
    Write-ToConsoleRed "...ERROR: Failed to import PowerCLI modules. Is PowerCLI installed?"
    Write-ToConsoleRed $_.Exception.Message
    exit 1
}

# Connect to vCenter
Write-ToConsole "...Connecting to vCenter Server $vcenter"
try {
    Connect-VIServer -Server $vcenter -Credential $vccred -Protocol https -ErrorAction Stop | Out-Null
    Write-ToConsoleGreen "...Successfully connected to vCenter $vcenter"
} catch {
    Write-ToConsoleRed "...ERROR: Failed to connect to vCenter $vcenter"
    Write-ToConsoleRed $_.Exception.Message
    exit 1
}

# Get ESXi hosts based on parameters
Write-ToConsole "...Retrieving ESXi hosts based on parameters"
$vmhosts = @()

try {
    if ($allhosts) {
        Write-ToConsole "...Getting ALL ESXi hosts in vCenter: $vcenter"
        $vmhosts = Get-VMHost -Server $vcenter | Sort-Object Name
        Write-ToConsole "...Found $($vmhosts.Count) total ESXi hosts"
    }
    elseif ($cluster) {
        Write-ToConsole "...Getting ESXi hosts in cluster: $cluster"
        $vmhosts = Get-Cluster -Name $cluster -ErrorAction Stop | Get-VMHost | Sort-Object Name
        Write-ToConsole "...Found $($vmhosts.Count) hosts in cluster $cluster"
    }
    elseif ($hosts) {
        Write-ToConsole "...Getting specified ESXi hosts: $($hosts -join ', ')"
        foreach ($hostname in $hosts) {
            $vmhost = Get-VMHost -Name $hostname -ErrorAction Stop
            $vmhosts += $vmhost
        }
        Write-ToConsole "...Retrieved $($vmhosts.Count) specified hosts"
    }
} catch {
    Write-ToConsoleRed "...ERROR: Failed to retrieve ESXi hosts"
    Write-ToConsoleRed $_.Exception.Message
    Disconnect-VIServer -Server $vcenter -Confirm:$false
    exit 1
}

if ($vmhosts.Count -eq 0) {
    Write-ToConsoleRed "...ERROR: No ESXi hosts found matching criteria"
    Disconnect-VIServer -Server $vcenter -Confirm:$false
    exit 1
}

# Validate report path
if (-not (Test-Path -Path $reportPath)) {
    Write-ToConsole "...Creating report directory: $reportPath"
    try {
        New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
        Write-ToConsoleGreen "...Created report directory successfully"
    } catch {
        Write-ToConsoleRed "...ERROR: Failed to create report directory"
        Write-ToConsoleRed $_.Exception.Message
        Disconnect-VIServer -Server $vcenter -Confirm:$false
        exit 1
    }
} else {
    Write-ToConsole "...Validated report path at $reportPath"
}

# Check for SAF CLI
$safCLIInstalled = $false
try {
    $safVersion = saf --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $safCLIInstalled = $true
        Write-ToConsoleGreen "...Detected SAF CLI version: $safVersion"
    }
} catch {
    Write-ToConsole "...SAF CLI not detected - CKL files will not be generated"
}

# Process each ESXi host
Write-ToConsole "...Beginning InSpec scans for $($vmhosts.Count) hosts"

# Set PowerCLI environment variables for InSpec transport
Write-ToConsole "...Setting up environment variables for InSpec vmware:// transport"
$env:VISERVER = $vcenter
$env:VISERVER_USERNAME = $vccred.UserName
$env:VISERVER_PASSWORD = $vccred.GetNetworkCredential().Password
Write-ToConsoleGreen "...Environment variables configured for vmware:// transport"

$successCount = 0
$failureCount = 0

foreach ($vmhost in $vmhosts) {
    $name = $vmhost.Name
    $Date = Get-Date
    
    Write-ToConsole ""
    Write-ToConsole "========================================="
    Write-ToConsole "...Processing ESXi host: $name"
    Write-ToConsole "========================================="
    
    # Generate report filenames
    $reportFile = Join-Path $reportPath ("VMware_vSphere_8.0_STIG_ESXi_Inspec_Report_" + $name + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".json")
    
    Write-ToConsole "...Report file will be: $reportFile"
    
    # Run InSpec scan
    Write-ToConsole "...Running InSpec scan against $name"
    $inspecCommand = "cinc-auditor exec `"$inspecPath`" -t vmware:// --input vmhostName=$name --input-file `"$inputsFile`" --show-progress --reporter=json:`"$reportFile`""
    
    Write-ToConsole "...Executing: $inspecCommand"
    
    try {
        Invoke-Expression $inspecCommand
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 100 -or $LASTEXITCODE -eq 101) {
            # InSpec exit codes: 0 = success, 100 = failures found, 101 = skipped
            Write-ToConsoleGreen "...InSpec scan completed for $name"
            
            # Verify JSON file was created
            if (Test-Path -Path $reportFile) {
                Write-ToConsoleGreen "...Report file created successfully: $reportFile"
                $successCount++
                
                # Process attestation file if provided
                if ($attestationFile -and (Test-Path -Path $attestationFile)) {
                    Write-ToConsole "...Applying attestation file to results for $name"
                    $reportFileWithAttestations = $reportFile -replace ".json$", "_with_Attestations.json"
                    
                    $attestCommand = "saf attest apply -i `"$reportFile`" `"$attestationFile`" -o `"$reportFileWithAttestations`""
                    Invoke-Expression $attestCommand
                    
                    if (Test-Path -Path $reportFileWithAttestations) {
                        Write-ToConsoleGreen "...Attestation applied successfully"
                        $reportFile = $reportFileWithAttestations
                    }
                }
                
                # Generate CKL if SAF CLI is available
                if ($safCLIInstalled) {
                    Write-ToConsole "...Generating STIG Viewer Checklist for $name"
                    
                    # Get host details for CKL
                    $mgmtip = ($vmhost | Get-VMHostNetworkAdapter | Where-Object {$_.ManagementTrafficEnabled -eq $true} | Select-Object -First 1).IP
                    $mgmtmac = ($vmhost | Get-VMHostNetworkAdapter | Where-Object {$_.ManagementTrafficEnabled -eq $true} | Select-Object -First 1).Mac
                    
                    $cklFile = $reportFile -replace ".json$", ".ckl"
                    $cklCommand = "saf convert hdf2ckl -i `"$reportFile`" -o `"$cklFile`" --hostname $name --fqdn $name --ip $mgmtip --mac $mgmtmac"
                    
                    Invoke-Expression $cklCommand
                    
                    if (Test-Path -Path $cklFile) {
                        Write-ToConsoleGreen "...CKL file created: $cklFile"
                    } else {
                        Write-ToConsoleRed "...WARNING: CKL file was not created"
                    }
                } else {
                    Write-ToConsole "...Skipping CKL generation (SAF CLI not installed)"
                }
            } else {
                Write-ToConsoleRed "...ERROR: Report file was not created for $name"
                $failureCount++
            }
        } else {
            Write-ToConsoleRed "...ERROR: InSpec scan failed for $name with exit code $LASTEXITCODE"
            $failureCount++
        }
    } catch {
        Write-ToConsoleRed "...ERROR: Exception during InSpec scan for $name"
        Write-ToConsoleRed $_.Exception.Message
        $failureCount++
    }
}

# Disconnect from vCenter
Write-ToConsole ""
Write-ToConsole "...Disconnecting from vCenter"
Disconnect-VIServer -Server $vcenter -Confirm:$false

# Clear sensitive environment variables
Write-ToConsole "...Clearing environment variables"
$env:VISERVER = $null
$env:VISERVER_USERNAME = $null
$env:VISERVER_PASSWORD = $null

# Summary
Write-ToConsole ""
Write-ToConsole "========================================="
Write-ToConsole "SCAN SUMMARY"
Write-ToConsole "========================================="
Write-ToConsole "...Total hosts processed: $($vmhosts.Count)"
Write-ToConsoleGreen "...Successful scans: $successCount"
if ($failureCount -gt 0) {
    Write-ToConsoleRed "...Failed scans: $failureCount"
}
Write-ToConsole "...Reports saved to: $reportPath"
Write-ToConsole "========================================="
Write-ToConsoleGreen "...Script execution completed"
