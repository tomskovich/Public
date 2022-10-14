function Sync-AzNsToOpenProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Domain', 'Name', 'DomainName')]
        [String[]] $Domains,

        [String] $ResourceGroupName = 'DNS'
    )

    process {
        # Get Azure NameServers for domain
        $AzNsInfo = Get-AzDnsZone -Name $Domain -ResourceGroupName $ResourceGroupName | Select-Object -ExpandProperty NameServers -First 1
        try {
            Write-Host "Starting NameServer migration..." -ForegroundColor 'Yellow'
            # Try to find matching NS group in OpenProvider
            $NsToMatch = $AzNsInfo[0]
            $OPNsGroup = Find-OPNsGroupMatch -Name $NsToMatch

            if ($OPNsGroup) {
                Write-Host "Matching NS Group found in OpenProvider: $OPNsGroup" -ForegroundColor 'Green'

                # Disable DNSSEC
                Write-Host "Disabling DNSSEC in OpenProvider for $Domain..." -ForegroundColor 'Yellow'
                Update-OPDomain -Domain $Domain -DisableDNSSec

                # Edit NameServer group
                Write-Host "Editing OpenProvider NameServer group..." -ForegroundColor 'Yellow'
                Set-OPNameServerGroup -Domain $Domain -GroupName $OPNsGroup
            }
        }
        catch {
            Write-Error $_
        }
    }
}
