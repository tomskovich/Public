<#
    .SYNOPSIS
    Modifies NameServer group for a specific domain.

    .LINK
    https://docs.openprovider.com/doc/all#operation/UpdateGroup

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Set-OPNameServerGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Name', 'DomainName')]
        [String] $Domain,

        [Parameter()]
        [String] $GroupName
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

        $DomainID = $DomainData | Select-Object -ExpandProperty ID

        $URL = 'https://api.openprovider.eu/v1beta/domains/' + $DomainID

        $Body = @{
            ns_group = $GroupName
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
            Write-Host 'Changed NameServer group successfully!' -ForegroundColor 'Green'
        }
        else {
            Write-Error $Response.Warnings
            throw "OpenProvider returned error code: $($Response.code) with above warnings."
        }

    } # end process
}