<#
    TO DO: Get domain by exact match instead of pattern
    LINK: https://docs.openprovider.com/doc/all#operation/ListDomains
#>
function Get-OPDomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Name', 'DomainName')]
        [String] $Domain,

        [ValidateNotNullOrEmpty()]
        [String] $URL = 'https://api.openprovider.eu/v1beta/domains',

        [Switch] $Search
    )

    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Token for OpenProvider API Authorization - Requires Get-OPBearerToken function.
        [String] $Token = (Get-OPBearerToken).token
    }

    process {
        if ($Search) {
            # Format domain name so "www" AND extension is removed
            $Domain = Format-DomainName -Domain $Domain -RemoveExtension

            $Body = @{
                domain_name_pattern = $Domain
                limit               = 5
                status              = 'ACT'
            }
        }
        else {
            # Format domain name so "www" is removed, also verifies if TLD/extension is valid
            $Domain = Format-DomainName -Domain $Domain

            $Body = @{
                full_name           = $Domain
                limit               = 1
                status              = 'ACT'
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

        $Response = (Invoke-RestMethod @Params).data.results

        if ($Response) {
            $Result = foreach ($item in $Response) {
                [PSCustomObject]@{
                    Domain      = $item.domain.name + '.' + $item.domain.extension
                    ID          = $item.id
                    NameServers = $item.name_servers.name
                    NSGroup     = $item.ns_group
                    Owner       = $item.owner_company_name
                }
            }
            return $Result
        }
        else {
            throw "ERROR: Could not find domain: $Domain."
        }
    } # end process
}