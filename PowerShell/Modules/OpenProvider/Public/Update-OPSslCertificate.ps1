<#
    .SYNOPSIS
    Starts SSL Certificate renewal process through the OpenProvider API

    .LINK
    https://docs.openprovider.com/doc/all#operation/RenewOrder

    .EXAMPLE
    Update-OPSslCertificate -ID 865534

    .EXAMPLE
    Get-OPSslCertificate -Domain 'www.contoso.com' | Select-Object -ExpandProperty ID | Update-OPSslCertificate

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Update-OPSslCertificate {
    [Alias("Update-OPSslCert")]
    [CmdletBinding()]
    param (
        # OpenProvider Order ID of SSL certificate 
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('OrderID')]
        [Int] $ID,

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
        $URL = "$($URL)/$($ID)/renew"

        $Body = @{
            id = $ID
        } | ConvertTo-Json
        
        $Headers = @{
            Authorization = "Bearer $Token"
        }
                
        $Params = @{
            Method      = 'POST'
            Uri         = $URL
            Headers     = $Headers
            Body        = $Body
            ContentType = 'application/json'
        }

        try {
            $Response = (Invoke-RestMethod @Params -StatusCodeVariable 'statusCode')
            if ($null -ne $Response.data.id) {
                Write-Output "SSL Certificate with order ID $($ID) renewed successfully!"
            }
        }
        catch {
            if ($_.ErrorDetails.Message | ConvertFrom-Json | Where-Object { $_.Code -eq '25003' } ) {
                Write-Error $_.ErrorDetails.Message
                Write-Warning 'Renewal seems to be pending already!'
            }
            else {
                Write-Host $_
            }
        }

    } # end process 

}
