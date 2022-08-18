<#
    .SYNOPSIS
    Retrieves SSL Certificate information through the OpenProvider API

    .LINK
    https://docs.openprovider.com/doc/all#tag/Order

    .EXAMPLE
    Get-OPSslCertificate -Domain 'ucsystems.nl'

    .EXAMPLE
    Get-OPSslCertificate -Domains 'ucsystems.nl', 'google.com'

    .EXAMPLE
    'ucsystems.nl', 'google.com', 'contoso.com' | Get-OPSslCertificate

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Get-OPSslCertificate {
    [Alias("Get-OPSslCert")]
    [CmdletBinding()]
    param(
        # Domain name(s) to get SSL Certificate information for
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Domain', 'Name', 'DomainName')]
        [String[]] $Domains,

        # API URL
        [Parameter()]
        [Alias('URI')]
        [String] $URL = 'https://api.openprovider.eu/v1beta/ssl/orders',

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
            $Data = foreach ($Domain in $Domains) {
                $Body = @{
                    common_name_pattern = $Domain
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
                            id               = $_.id
                            email_reissue    = $_.email_reissue
                            CommonName       = $_.common_name
                            ProductName      = $_.product_name
                            OrderDate        = $_.order_date
                            ExpirationDate   = $_.expiration_date
                            HostNames        = $_.host_names -join ','
                            Email            = $_.email_reissue
                            CSR              = $_.csr
                            Certificate      = $_.certificate
                            RootCertificate  = $_.root_certificate
                            CABundle         = ($_.intermediate_certificate + "`r`n" + $_.root_certificate)
                            IntermediateCert = $_.intermediate_certificate
                        }
                    }
                }
                else {
                    throw "ERROR: Could not find domain: $Domain."
                }
            } # end foreach
            return $Data
        }
        catch {
            Write-Error $_
        }
    } # end process

}

