function Find-OPNsGroupMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $Name
    )

    begin {
        $OPAzNameServers = @{
            'Azure-NS01' = 'ns1-01.azure-dns.com.'
            'Azure-NS02' = 'ns1-02.azure-dns.com.'
            'Azure-NS03' = 'ns1-03.azure-dns.com.'
            'Azure-NS04' = 'ns1-04.azure-dns.com.'
            'Azure-NS05' = 'ns1-05.azure-dns.com.'
            'Azure-NS06' = 'ns1-06.azure-dns.com.'
            'Azure-NS07' = 'ns1-07.azure-dns.com.'
            'Azure-NS08' = 'ns1-08.azure-dns.com.'
            'Azure-NS09' = 'ns1-09.azure-dns.com.'
        }
    }
    
    process {
        # Find matching NS Group name from hashtable
        $MatchingGroup = $OPAzNameServers.GetEnumerator() | Where-Object { $_.Value -Match $Name }

        if ($MatchingGroup) {
            return $MatchingGroup.Name
        }
        else {
            throw 'No matching group found in OpenProvider NS Groups.'
        }
    }
}