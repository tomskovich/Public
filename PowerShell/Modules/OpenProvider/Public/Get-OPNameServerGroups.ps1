<#
    .SYNOPSIS
    Retrieves NameServer groups from your OpenProvider account. Search query optional.

    .LINK
    https://docs.openprovider.com/doc/all#tag/NsGroupService

    .EXAMPLE
    Get-OPNameServerGroups

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://tech-tom.com / https://ucsystems.nl
#>
function Get-OPNameServerGroups {
    [CmdletBinding()]
    [Alias("Get-OPNameServerGroup")]
    param (
        # Search query (optional for if you have a lot of NS groups)
        [Alias('Filter')]
        [String] $Name,

        [ValidateNotNullOrEmpty()]
        [String] $URL = 'https://api.openprovider.eu/v1beta/dns/nameservers/groups'
    )

    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Token for OpenProvider API Authorization - Requires Get-OPBearerToken function.
        [String] $Token = (Get-OPBearerToken).token
    }

    process {
        if ($Name) {
            $Body = @{
                ns_name_pattern = "*$Name*"
            }
        }
        else {
            $Body = @{
                ns_name_pattern = '*'
            }
        }
        
        $Headers = @{
            Authorization = "Bearer $Token"
        }
        
        $Params = @{
            Method      = 'GET'
            Uri         = $URL
            Headers     = $Headers
            Body        = $Body
            ContentType = 'application/json'
        }
        
        try {
            $Response = (Invoke-RestMethod @Params).data.results
            $Result = $Response | ForEach-Object {
                [PSCustomObject]@{
                    Name        = $_.ns_group
                    NameServers = $_.name_servers
                    ID          = $_.id
                }
            }
        }
        catch {
            Write-Error $_
            throw "Error getting NameServer groups. Please try again."
        }
        
        return $Result
    } # end Process
}
