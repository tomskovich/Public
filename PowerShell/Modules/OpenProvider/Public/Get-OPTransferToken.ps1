<#
    .SYNOPSIS
    Retrieves domain transfer key(s) through the OpenProvider API

    .LINK
    https://docs.openprovider.com/doc/all#tag/descDomainQuickstart

    .EXAMPLE
    Get-OPTransferToken -Domain 'ucsystems.nl'

    .EXAMPLE
    Get-OPTransferToken -Domain 'ucsystems'

    .EXAMPLE
    Get-OPTransferToken -Domains 'ucsystems.nl', 'google.com'

    .EXAMPLE
    'ucsystems.nl', 'google.com', 'contoso.com' | Get-OPTransferToken

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Get-OPTransferToken {
    [CmdletBinding()]
    param (
        # Domain name(s) to get transfer token for
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Domain', 'Name', 'DomainName')]
        [String[]] $Domains,

        # API URL
        [Parameter()]
        [Alias('URI')]
        [String] $URL = 'https://api.openprovider.eu/v1beta/domains',

        # Token for OpenProvider API Authorization - Requires Get-OPBearerToken function.
        [Parameter()]
        [String] $Token = (Get-OPBearerToken).token
    )

    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    process {
        try {
            # Remove domain extensions (required)
            $Domains = ($Domains) -replace '\..*$', ''

            $Data = foreach ($Domain in $Domains) {
                $Body = @{
                    domain_name_pattern = "*$Domain*"
                    status              = 'ACT'
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

                if ($null -ne $Response) {
                    $Response | ForEach-Object {
                        [PSCustomObject]@{
                            Domain    = $Domain
                            Extension = $_.domain.extension
                            Owner     = $_.owner_company_name
                            AuthCode  = $_.auth_code
                        }
                    }
                }
                else {
                    throw "ERROR: Could not find domain: $Domain."
                }
            } # end foreach
            return $Data
        } # end try
        catch {
            Write-Error $_
        }
    } # end process

}