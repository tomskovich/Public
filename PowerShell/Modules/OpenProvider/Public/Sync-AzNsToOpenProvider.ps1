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
            Write-Output "Starting NameServer migration..."
            # Try to find matching NS group in OpenProvider
            $NsToMatch = $AzNsInfo[0]
            $OPNsGroup = Find-OPNsGroupMatch -Name $NsToMatch

            if ($OPNsGroup) {
                Write-Information "Matching NS Group found in OpenProvider: $OPNsGroup"

                # Disable DNSSEC
                Write-Verbose "Disabling DNSSEC in OpenProvider for $Domain..."
                Update-OPDomain -Domain $Domain -DisableDNSSec

                # Edit NameServer group
                Write-Verbose "Editing OpenProvider NameServer group..."
                Set-OPNameServerGroup -Domain $Domain -GroupName $OPNsGroup
            }
        }
        catch {
            Write-Error $_
        }
    }
}