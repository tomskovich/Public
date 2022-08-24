function Format-DomainName {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position=0)]
        [String] $Domain,

        [Switch] $RemoveExtension
    )
    
    # Create TLDs List as save it to "script" for faster next run.
    if ( ! $ExtensionList) {
        $ExtensionListRow = Invoke-RestMethod -Uri https://publicsuffix.org/list/public_suffix_list.dat
        $script:ExtensionList = ($ExtensionListRow -split "`n" | Where-Object {$_ -notlike '//*' -and $_})
        [array]::Reverse($ExtensionList)
    }

    $Ok = $false

    # Skip TLD verification if -RemoveExtension is passed
    if ($RemoveExtension) {
        $Ok = $true
    }
    else {
        foreach ($Extension in $ExtensionList) {
            if ($Domain -Like "*.$Extension") {
                $Ok = $true
                break
            }
        }
    }

    if ($Ok) {
        if ($RemoveExtension) {
            $Domain = ($Domain -replace "\.$Extension" -split '\.')[-1]
            return $Domain
        }
        else {
            $Domain = ($Domain -replace "\.$Extension" -split '\.')[-1] + ".$Extension"
            return $Domain
        }
    }
    else {
        throw 'Not a valid TLD/Domain name'
    }
}