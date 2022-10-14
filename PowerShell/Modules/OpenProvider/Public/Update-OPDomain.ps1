<#
    .SYNOPSIS
    Modifies NameServer group for a specific domain.

    .LINK
    https://docs.openprovider.com/doc/all#operation/UpdateDomain

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Update-OPDomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Name', 'DomainName')]
        [String] $Domain,

        [Parameter(Mandatory = $false, ValuefromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Switch] $DisableDNSSec
    )

    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Token for OpenProvider API Authorization - Requires Get-OPBearerToken function.
        [String] $Token = (Get-OPBearerToken).token
    }

    process {
        # Get current Domain information from OpenProvider
        $DomainData = Get-OPDomain -Domain $Domain

        if ($DisableDNSSec) {
            $DNSSecEnabled = $DomainData | Select-Object -ExpandProperty DNSSecEnabled
            if ($DNSSecEnabled -eq $false) {
                return Write-Host "DNSSec is already disabled for $Domain. No changes required." -ForegroundColor 'Green'
            }
        }

        $DomainID = $DomainData | Select-Object -ExpandProperty ID

        $URL = 'https://api.openprovider.eu/v1beta/domains/' + $DomainID

        $Body = @{
            is_dnssec_enabled = $false
        } | ConvertTo-Json

        $Headers = @{
            Authorization = "Bearer $Token"
        }

        $Params = @{
            Method      = 'PUT'
            Uri         = $URL
            Headers     = $Headers
            Body        = $Body
            ContentType = 'application/json'
        }

        $Response = (Invoke-RestMethod @Params)
        if ($Response.code -eq '0') {
            Write-Host "Disabled DNSSec successfully for domain $($Domain)" -ForegroundColor 'Green'
        }
        elseif ($Response.code -eq '349') {
            Write-Host "Cannot disable DNSSEC for $Domain. Please do it manually through the web interface."
        }
        else {
            Write-Error $Response.Warnings
            throw "OpenProvider returned error code: $($Response.code) with above warnings."
        }
    } # end process
}