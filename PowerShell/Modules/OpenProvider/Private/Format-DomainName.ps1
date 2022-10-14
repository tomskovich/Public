<#
    .SYNOPSIS
    Verifies if given domain name is valid, then extracts the domain name.
    OPTIONAL: Removes domain extension for usage in search queries with multiple results.

    .EXAMPLE
    Format-DomainName -Domain 'contoso.com'

    .EXAMPLE
    Format-DomainName -Domain 'server01.contoso.com'

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://tech-tom.com / https://ucsystems.nl
#>
function Format-DomainName {
    [CmdletBinding()]
    param (
        # Domain name to parse/format
        [Parameter(Mandatory, Position=0)]
        [String] $Domain,

        # [OPTIONAL] Removes domain extension from domain
        [Switch] $RemoveExtension
    )
    

    if ( ! $Extensions ) {
        # Get list of valid TLD's
        $ExtensionsRaw = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat"
        # Remove comments and unnecessary lines, and save to script variable for faster future runs
        $Extensions = $ExtensionsRaw -split "`n" | Where-Object { $_ -notlike '//*' -and $_ }
        $script:ExtensionsList  = New-Object System.Collections.ArrayList
        [void] $script:ExtensionsList.Add($Extensions)
    }

    $Valid = $false
    
    # Remove 'www' from domain
    $Prefix = 'www'
    $Domain = $Domain -replace "$Prefix."

    # Skip TLD verification if -RemoveExtension is passed
    if ($RemoveExtension) {
        $Valid = $true
    }
    else {
        foreach ($Extension in $Extensions) {
            if ($Domain -Like "*.$Extension") {
                $Valid = $true
                break
            }
        }
    }

    if ($Valid) {
        if ($RemoveExtension) {
            $Domain = $Domain -replace "$Extension"
            return $Domain
        }
        else {
            #$Domain = ($Domain -replace "\.$Extension" -split '\.')[-1] + ".$Extension"
            return $Domain
        }
    }
    else {
        throw 'Not a valid TLD/Domain name.'
    }
}
