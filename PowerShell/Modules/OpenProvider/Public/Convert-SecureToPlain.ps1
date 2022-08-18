<#
    .SYNOPSIS
    Converts SecureString to plain. This is to support older PowerShell versions.
    In PS 7, you can use "ConvertFrom-SecureString and -AsPlainText"

    .LINK
    https://stackoverflow.com/questions/28352141/convert-a-secure-string-to-plain-text

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Convert-SecureToPlain {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Security.SecureString] $SecureString
    )

    $BasicString     = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    $PlainTextString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BasicString)

    return $PlainTextString

}
