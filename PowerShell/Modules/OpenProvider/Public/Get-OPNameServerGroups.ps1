function Get-OPNameServerGroups {
    [CmdletBinding()]
    [Alias("Get-OPNameServerGroup")]
    param (
        [Parameter()]
        [String] $Name
    )

    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Token for OpenProvider API Authorization - Requires Get-OPBearerToken function.
        [Parameter()]
        [String] $Token = (Get-OPBearerToken).token
    }

    process {

        $URL = 'https://api.openprovider.eu/v1beta/dns/nameservers/groups'
        
        $Body = @{
            ns_name_pattern = '*'
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

    } # end process


}