function Move-OPDnsToAzure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Domain', 'Name', 'DomainName')]
        [String[]] $Domains,

        [ValidateNotNullorEmpty()]
        [String] $ResourceGroupName = 'DNS',

        [Switch] $Export
    )
    
    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    
    process {
        foreach ($Domain in $Domains) {
            # First compare DNS zones and show diff?
            Write-Host "Starting full DNS migration process for $Domain." -ForegroundColor 'Yellow'
            
            # Sync DNS zones
            try {
                Write-Host "Synchronizing DNS zone from OpenProvider to Azure..." -ForegroundColor 'Yellow'
                Sync-OPDnsToAzure -Domain $Domain -Force
            }
            catch {
                Write-Error $_
            }
            
            # Sync/edit NameServer group in OpenProvider
            try {
                Write-Host "Synchronizing NameServer group from Azure to OpenProvider..." -ForegroundColor 'Yellow'
                Sync-AzNsToOpenProvider -Domain $Domain
            }
            catch {
                Write-Error $_
            }

            Write-Host "Generating report for $Domain..." -ForegroundColor 'Yellow'
            $OPDnsZone = Get-OPDnsZone -Domain $Domain | Where-Object -Property RecordType -ne 'NS' |
                Select-Object Name, TTL, RecordType, Value | Sort-Object -Property RecordType
            $AzDnsZone = Get-AzDnsRecordSet -ZoneName $Domain -ResourceGroupName $ResourceGroupName | 
                Select-Object Name, TTL, RecordType, Records | Sort-Object -Property RecordType
            $OPDomain  = Get-OPDomain -Domain $Domain | Select-Object Domain, Owner, DNSSecEnabled, NSGroup, NameServers

            if ( ! ($Export.IsPresent)) {
                # Report section
                Write-Host "=== OPENPROVIDER DNS Data for $($Domain):" -ForegroundColor Cyan
                $OPDnsZone | Format-Table
            
                Write-Host "=== AZURE DNS Data for $($Domain):" -ForegroundColor Cyan
                $AzDnsZone | Format-Table

                Write-Host "=== Current OpenProvider Domain data for $($Domain):" -ForegroundColor Cyan
                $OPDomain | Format-Table
            }

            if ($Export.IsPresent) {
                $OPDnsZone | Export-Csv -Path "$env:TEMP\$($Domain)_OpDnsZone.csv" -NoTypeInformation -Encoding ASCII -Force
                Write-Host "Saved file: $env:TEMP\$($Domain)_OpDnsZone.csv" -ForegroundColor 'Cyan'

                $AzDnsZone | ForEach-Object {
                    [PSCustomObject]@{ 
                        Name       = $_.Name
                        TTL        = $_.TTL
                        RecordType = $_.RecordType
                        Records    = $_.Records -join ','
                    }
                } | Export-Csv -Path "$env:TEMP\$($Domain)_AzDnsZone.csv" -NoTypeInformation -Encoding ASCII -Force
                Write-Host "Saved file: $env:TEMP\$($Domain)_AzDnsZone.csv" -ForegroundColor 'Cyan'

                $OPDomain | ForEach-Object {
                    [PSCustomObject]@{ 
                        Owner         = $_.Owner
                        DNSSecEnabled = $_.DNSSecEnabled
                        NSGroup       = $_.NSGroup
                        NameServers   = $_.NameServers -join ','
                    }
                } | Export-Csv -Path "$env:TEMP\$($Domain)_OpDomainInfo.csv" -NoTypeInformation -Encoding ASCII -Force
                Write-Host "Saved file: $env:TEMP\$($Domain)_OpDomainInfo.csv" -ForegroundColor 'Cyan'
            }
        }
    }
}