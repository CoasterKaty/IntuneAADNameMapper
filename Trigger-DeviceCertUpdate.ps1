# Certificate Sync Script
#
# Triggered by 4887 event log (CA issued a certificate)
# Finds the device in AD and adds the cert thumbprint to altSecurityIdentities
#
# Katy Nicholson
# 2024-08-30

[CmdletBinding(DefaultParameterSetName="Main")]
param(
    [string][Parameter(Mandatory=$true,ParameterSetName="Main", HelpMessage="Request ID from event log")][ValidatePattern("^\d+$")]$RequestID,
    [string][Parameter(Mandatory=$true,ParameterSetName="Main", HelpMessage="Requester from event log")]$Requester,
    [string][Parameter(Mandatory=$true,ParameterSetName="Main", HelpMessage="Subject from event log")]$Subject,
    [string][Parameter(Mandatory=$true,ParameterSetName="Main", HelpMessage="Username that the Intune Certificate Connector runs as, this will show as ""Requested by"" in certificate requests")]$IntuneCertUsername,
    [string][Parameter(Mandatory=$true,ParameterSetName="Main", HelpMessage="CA Name, e.g. lab-LAB-SRV-01-CA")]$CertAuthorityName,
    [string][Parameter(Mandatory=$true,ParameterSetName="Main", HelpMessage="Path to folder for writing log files")]$LogPath
)


function New-LogEntry() {
    # Write log entry in format used by CMTrace
    param (
        $Detail,
        $Component,
        [switch]$Error,
        [switch]$Warning,
        $Path
    )
    $Type = "1"
    if ($Warning) { $Type = "2" }
    if ($Error) { $Type = "3" }
    Add-Content -Path "$Path\NameMapperLog-$(Get-Date -Format "yyyy-MM-dd").log" -Value "<![LOG[$Detail]LOG]!><time=""$((Get-Date).ToUniversalTime().ToString("HH:mm:ss.fff+00"))"" date=""$(Get-Date -Format "MM-dd-yyyy")"" component=""$Component"" context="""" type=""$Type"" thread="""" file=""$(Split-Path $MyInvocation.ScriptName -Leaf)"">"
    
}


New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "+++Script Called - RequestID: $RequestID, Requester: $Requester, Subject: $Subject"


$module = Import-Module PSPKI -PassThru -ErrorAction Ignore
if (-not $module) {
    New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "Installing module PSPKI"
    Install-Module PSPKI -Force
}

Import-Module PSPKI -Scope Global
if ($Requester -eq $IntuneCertUsername) {
    try{
        $CAHost = Get-CertificationAuthority -Name $CertAuthorityName -ErrorAction Stop
        $IssuedCert = Get-IssuedRequest -CertificationAuthority $CAHost -RequestID $RequestID -Property RequestID,CommonName,CertificateHash -ErrorAction Stop
        if ($IssuedCert) {
            $CommonName = $IssuedCert.CommonName
            if ([guid]::TryParse($CommonName, $([ref][guid]::Empty))) {
                if ($Subject -eq "CN=$CommonName") {
                    $hash = ($IssuedCert.CertificateHash) -Replace '\s',''
                    $attrib = @{"altSecurityIdentities"="X509:<SHA1-PUKEY>$hash"}
                    New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "Computer $CommonName - adding certificate $hash"
                    Get-ADComputer -Filter "(servicePrincipalName -like 'host/$($CommonName)')" -ErrorAction Stop | Set-ADComputer -Add $attrib -ErrorAction Stop
                } else {
                    New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "CommonName does not match Subject" -Warning
                }
            } else {
                New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "Certificate not issued to an AAD device" -Warning
            }
        } else {
            New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "Certificate not found" -Error
        }
    }
    catch {  
        New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "$($_.Exception.Message)" -Error
    }
} else {
        New-LogEntry -Path $LogPath -Component "Name Mapper" -Detail "Certificate was not requested through Intune Certificate Connector" -Warning
}

 
