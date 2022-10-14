<#
    .SYNOPSIS
    Retrieves domain DNS zone(s) through the OpenProvider API

    .LINK
    https://docs.openprovider.com/doc/all#tag/ZoneService

    .EXAMPLE
    Get-OPDnsZone -Domain 'ucsystems.nl'

    .EXAMPLE
    Get-OPDnsZone -Domains 'ucsystems.nl', 'google.com'

    .EXAMPLE
    'ucsystems.nl', 'google.com', 'contoso.com' | Get-OPDnsZone

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Get-OPDnsZone {
    [CmdletBinding()]
    param (
        # Domain name(s) to get transfer token for
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Domain', 'Name', 'DomainName')]
        [String[]] $Domains
    )

    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Token for OpenProvider API Authorization - Requires Get-OPBearerToken function.
        [String] $Token = (Get-OPBearerToken).token
    }

    process {
        $Data = foreach ($Domain in $Domains) {
            $URL = 'https://api.openprovider.eu/v1beta/dns/zones/' + $Domain
            
            $Body = @{
                with_records = 'true'
                with_dnskey  = 'true'
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
                $Request  = Invoke-RestMethod @Params -Verbose:$false
                $Response = ($Request).data
            }
            catch {
                Write-Error $_
                throw "Error getting DNS zone. Please try again."
            }
            
            if ($Response) {
                ($Response).records | ForEach-Object {
                    [PSCustomObject]@{
                        Domain     = $Domain
                        Name       = if ($Domain -eq $_.name) { '@' } 
                                    elseif ($_.name -like "*.$Domain") { $_.name -replace "\.$Domain", "" } 
                                    else { $_.name }
                        RecordType = $_.type
                        Priority   = $_.prio
                        Value      = $_.value
                        Ttl        = $_.ttl
                    }
                }
                # DNSSec
                $Response | ForEach-Object {
                    [PSCustomObject]@{
                        DNSKey     = $_.dnskey
                    }
                }
            }
            else {
                throw "ERROR: Could not find domain: $Domain. Please try again. (This happens sometimes)"
            }
        } # end foreach

        return $Data
    } # end process
}

