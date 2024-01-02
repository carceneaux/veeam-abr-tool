<#
.SYNOPSIS
Generates Veeam Backup & Replication (VBR) AsBuiltReport

.DESCRIPTION
This script automates the installation and initial configuration of the AsBuiltReport
tool and generates an AsBuiltReport for Veeam Backup & Replication (VBR)

NOTE: Script is designed to be run directly on the Veeam Backup & Replication server

.PARAMETER Credential
VBR Server Local Administrator account PS Credential Object

.PARAMETER SkipSetup
Flag to skip install/config of the AsBuiltReport tool

.OUTPUTS
veeam-abr-tool is interactive and leaves an HTML file on the current user's desktop

.EXAMPLE
veeam-abr-tool.ps1

Description
-----------
Perform initial configuration of AsBuiltReport and generate a report

.EXAMPLE
veeam-abr-tool.ps1 -Credential (Get-Credential)

Description
-----------
PowerShell credentials object is supported

.EXAMPLE
veeam-abr-tool.ps1 -SkipSetup

Description
-----------
Generates a report skipping AsBuiltReport configuration

.NOTES
NAME:  veeam-abr-tool.ps1
VERSION: 1.0
AUTHOR: Chris Arceneaux
TWITTER: @chris_arceneaux
GITHUB: https://github.com/carceneaux

#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory = $false)]
    [switch]$SkipSetup
)

$DirectorySeparatorChar = [System.IO.Path]::DirectorySeparatorChar

Function Get-Software {
    # Sourced from https://mcpmag.com/articles/2017/07/27/gathering-installed-software-using-powershell.aspx
    [OutputType('System.Software.Inventory')]
    [Cmdletbinding()] 
    Param( 
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)] 
        [String[]]$Computername = $env:COMPUTERNAME
    )         
    Begin {
    }
    Process {     
        ForEach ($Computer in  $Computername) { 
            If (Test-Connection -ComputerName  $Computer -Count  1 -Quiet) {
                $Paths = @("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall", "SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")         
                ForEach ($Path in $Paths) { 
                    Write-Verbose  "Checking Path: $Path"
                    #  Create an instance of the Registry Object and open the HKLM base key 
                    Try { 
                        $reg = [microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine', $Computer, 'Registry64') 
                    }
                    Catch { 
                        Write-Error $_ 
                        Continue 
                    } 
                    #  Drill down into the Uninstall key using the OpenSubKey Method 
                    Try {
                        $regkey = $reg.OpenSubKey($Path)  
                        # Retrieve an array of string that contain all the subkey names 
                        $subkeys = $regkey.GetSubKeyNames()      
                        # Open each Subkey and use GetValue Method to return the required  values for each 
                        ForEach ($key in $subkeys) {   
                            Write-Verbose "Key: $Key"
                            $thisKey = $Path + "\\" + $key 
                            Try {  
                                $thisSubKey = $reg.OpenSubKey($thisKey)   
                                # Prevent Objects with empty DisplayName 
                                $DisplayName = $thisSubKey.getValue("DisplayName")
                                If ($DisplayName -AND $DisplayName -notmatch '^Update  for|rollup|^Security Update|^Service Pack|^HotFix') {
                                    $Date = $thisSubKey.GetValue('InstallDate')
                                    If ($Date) {
                                        Try {
                                            $Date = [datetime]::ParseExact($Date, 'yyyyMMdd', $Null)
                                        }
                                        Catch {
                                            Write-Warning "$($Computer): $_ <$($Date)>"
                                            $Date = $Null
                                        }
                                    } 
                                    # Create New Object with empty Properties 
                                    $Publisher = Try {
                                        $thisSubKey.GetValue('Publisher').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('Publisher')
                                    }
                                    $Version = Try {
                                        #Some weirdness with trailing [char]0 on some strings
                                        $thisSubKey.GetValue('DisplayVersion').TrimEnd(([char[]](32, 0)))
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('DisplayVersion')
                                    }
                                    $UninstallString = Try {
                                        $thisSubKey.GetValue('UninstallString').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('UninstallString')
                                    }
                                    $InstallLocation = Try {
                                        $thisSubKey.GetValue('InstallLocation').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('InstallLocation')
                                    }
                                    $InstallSource = Try {
                                        $thisSubKey.GetValue('InstallSource').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('InstallSource')
                                    }
                                    $HelpLink = Try {
                                        $thisSubKey.GetValue('HelpLink').Trim()
                                    } 
                                    Catch {
                                        $thisSubKey.GetValue('HelpLink')
                                    }
                                    $Object = [pscustomobject]@{
                                        Computername    = $Computer
                                        DisplayName     = $DisplayName
                                        Version         = $Version
                                        InstallDate     = $Date
                                        Publisher       = $Publisher
                                        UninstallString = $UninstallString
                                        InstallLocation = $InstallLocation
                                        InstallSource   = $InstallSource
                                        HelpLink        = $HelpLink
                                        EstimatedSizeMB = [decimal]([math]::Round(($thisSubKey.GetValue('EstimatedSize') * 1024) / 1MB, 2))
                                    }
                                    $Object.pstypenames.insert(0, 'System.Software.Inventory')
                                    Write-Output $Object
                                }
                            }
                            Catch {
                                Write-Warning "$Key : $_"
                            }   
                        }
                    }
                    Catch { }   
                    $reg.Close() 
                }                  
            }
            Else {
                Write-Error  "$($Computer): unable to reach remote system!"
            }
        } 
    } 
}

# Checking if Veeam Backup & Replication is installed
$vbr = Get-Software | Where-Object { $_.DisplayName -eq "Veeam Backup & Replication Server" } | Select-Object DisplayName, Version
if ($vbr) {
    Write-Host "Veeam Backup & Replication Server found: $($vbr.Version)" -ForegroundColor Green
}
else {
    Throw "Veeam Backup & Replication not found on this server. Script will not work unless run on a server where Veeam Backup & Replication is installed."
}

# Skipping AsBuiltReport configuration if specified
if ($false -eq $SkipSetup) {
    Write-Host "Installing required PowerShell module (AsBuiltReport.Veeam.VBR) and its dependencies..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Find-PackageProvider -Name Nuget -ForceBootstrap -IncludeDependencies -Force | Out-Null
    # Determine if AsBuiltReport.Veeam.VBR module is already present
    $module = Get-Module -ListAvailable -Name AsBuiltReport.Veeam.VBR
    $latest = Find-Module -Name AsBuiltReport.Veeam.VBR
    switch ($true) {
    ($null -eq $module) { 
            Write-Host "Installing AsBuiltReport.Veeam.VBR module..."
            Install-Module -Name AsBuiltReport.Veeam.VBR -SkipPublisherCheck -Force -ErrorAction Stop
            Write-Host "AsBuiltReport.Veeam.VBR module installed successfully" -ForegroundColor Green
            break
        }
    ($module.Version.ToString() -ne $latest.Version) {
            Write-Host "AsBuiltReport.Veeam.VBR module is already installed: $($module.Version.ToString())"
            Write-Host "Upgrading AsBuiltReport.Veeam.VBR module to the latest version: $($($latest.Version))"
            Uninstall-Module -Name AsBuiltReport.Veeam.VBR -Force -ErrorAction Stop
            Install-Module -Name AsBuiltReport.Veeam.VBR -SkipPublisherCheck -Force -ErrorAction Stop
            Write-Host "AsBuiltReport.Veeam.VBR module upgraded successfully" -ForegroundColor Green
        }
        Default {
            Write-Host "AsBuiltReport.Veeam.VBR module is already installed: $($module.Version.ToString())"
        }
    }

    # Deleting current configuration files if located in the default folder (we're about to create new ones)
    if (Test-Path -Path "$($Home + $DirectorySeparatorChar)AsBuiltReport") {
        Remove-Item "$($Home + $DirectorySeparatorChar)AsBuiltReport$($DirectorySeparatorChar)*.json" -Recurse -Force
    }

    # Generating AsBuilt configuration file
    New-AsBuiltConfig
   
    # Generating AsBuilt report configuration file
    Write-Host ""
    $ReportConfigFolder = Read-Host -Prompt "Enter the full path of the folder to use for storing the configuration files [$($Home + $DirectorySeparatorChar)AsBuiltReport]"
    if (($ReportConfigFolder -like $null) -or ($ReportConfigFolder -eq "")) {
        $ReportConfigFolder = $Home + $DirectorySeparatorChar + "AsBuiltReport"
    }
    New-AsBuiltReportConfig -Report Veeam.VBR -FolderPath $ReportConfigFolder

    # Updating report configuration
    $ReportConfigFile = $ReportConfigFolder + $DirectorySeparatorChar + "AsBuiltReport.Veeam.VBR.json"
  (Get-Content $ReportConfigFile).Replace(": 1", ": 3") | Set-Content $ReportConfigFile
  (Get-Content $ReportConfigFile).Replace("`"EnableHardwareInventory`": false", "`"EnableHardwareInventory`": true") | Set-Content $ReportConfigFile
}

# Retrieving AsBuiltReport config files
if ($null -eq $ReportConfigFolder) {
    Write-Host ""
    $ReportConfigFolder = Read-Host -Prompt "Enter the full path of the folder used to store the configuration files [$($Home + $DirectorySeparatorChar)AsBuiltReport]"
    if (($ReportConfigFolder -like $null) -or ($ReportConfigFolder -eq "")) {
        $ReportConfigFolder = $Home + $DirectorySeparatorChar + "AsBuiltReport"
    }
}
$ConfigFile = $ReportConfigFolder + $DirectorySeparatorChar + "AsBuiltReport.json"
$ReportConfigFile = $ReportConfigFolder + $DirectorySeparatorChar + "AsBuiltReport.Veeam.VBR.json"

# Validating config files
if (Test-Path -Path $ConfigFile -PathType Leaf) {
    Write-Host "AsBuiltReport config file present: $ConfigFile" -ForegroundColor Green
}
else {
    Throw "Unable to find the AsBuiltReport config file at the specified location ($ConfigFile)"
}
if (Test-Path -Path $ReportConfigFile -PathType Leaf) {
    Write-Host "AsBuiltReport report config file present: $ReportConfigFile" -ForegroundColor Green
}
else {
    Throw "Unable to find the AsBuiltReport report config file at the specified location ($ReportConfigFile)"
}

# Setting desktop location
$Desktop = [Environment]::GetFolderPath("Desktop")

# Retrieving credentials
if ($null -eq $Credential) {
    $Credential = Get-Credential -Message "Local administrator account required"
}

# Validating credentials
if ($null -eq $Credential) {
    throw "User terminated script by not entering credentials"
}

# Retrieving server fqdn
$HostName = ([System.Net.Dns]::GetHostByName($env:COMPUTERNAME)).HostName

# Running AsBuiltReport
New-AsBuiltReport -Report Veeam.VBR -Target $HostName -Credential $Credential -Format HTML -OutputFolderPath $Desktop -EnableHealthCheck -ReportConfigFilePath $ReportConfigFile -AsBuiltConfigFilePath $ConfigFile