<#
    .SYNOPSIS
    Copies DNS zone(s) from OpenProvider to Azure. Also creates DNS zone in Azure if it does not exist.

    .LINK
    OpenProvider: https://docs.openprovider.com/doc/all#tag/ZoneService
    Azure: https://docs.microsoft.com/en-us/azure/dns/dns-operations-dnszones

    .EXAMPLE
    Sync-OPDnsToAzure -Domain 'ucsystems.nl'

    .EXAMPLE
    Sync-OPDnsToAzure -Domains 'ucsystems.nl', 'google.com'

    .EXAMPLE
    'ucsystems.nl', 'google.com', 'contoso.com' | Sync-OPDnsToAzure

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Sync-OPDnsToAzure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValuefromPipeline = $true)]
        [Alias('Domain', 'Name', 'DomainName')]
        [String[]] $Domains,

        [ValidateNotNullorEmpty()]
        [String] $ResourceGroupName = 'DNS',

        [Switch] $Search,

        [Switch] $Force
    )

    begin {
        # Set ErrorActionPreference for easier error handling
        $ErrorActionPreference = 'Stop'

        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Check for required modules, and import or install them
        $Modules = @("Az.Accounts", "Az.Resources", "Az.DNS")
        try {
            foreach ($Module in $Modules) {
                if ( ! ( Get-Module $Module ) ) {
                    if ( Get-Module -ListAvailable -Name $Module -Verbose:$false ) {
                        Write-Verbose "Loading module: $Module..."
                        Import-Module $Module -Verbose:$false
                    }
                    else {
                        Write-Warning "Module $Module not installed! Installing module..."
                        Install-Module $Module -Verbose:$false
                    }
                }
            }
        }
        catch {
            Write-Error $_
            throw 'Error importing/installing required modules. Aborting...'
        }

        # Check for Az context
        if ( ! (Get-AzContext)) {
            Write-Output 'Seems there is no connection to Azure. Please login to your Azure account'
            try {
                Connect-AzAccount
            }
            catch {
                Write-Error $_
                throw 'Error connecting to Azure. Aborting...'
            }
        }
        else {
            Write-Verbose 'Connected to Azure. Continuing...'
        }

        # Check for Az Resource Group permissions
        if ( ! (Get-AzResourceGroup -Name $ResourceGroupName)) {
            throw "Cannot access resource group $ResourceGroupName. Please check your permissions, or change to the correct context with Get-AzSubscription and Set-AzContext."
        }
        else {
            Write-Verbose "Account has permissions for Resource Group $ResourceGroupName. Continuing..."
        }
    } # end Begin

    process {
        foreach ($Domain in $Domains) {
            # Get domain info from OpenProvider; prompt user for confirmation
            Write-Information "Getting OpenProvider NameServer group for $($Domain)"
            try {
                if ($Search) {
                    $OPDomainInfo = Get-OPDomain -Domain $Domain -Search
                }
                else {
                    $OPDomainInfo = Get-OPDomain -Domain $Domain
                }
                if ( ! ($Force.IsPresent)) {
                    Write-Output '=== Received the following domain information from OpenProvider. Please verify if this domain is correct.'
                    $OPDomainInfo
                    Pause
                }
            }
            catch {
                Write-Error $_
                throw 'Error getting NameServer group from OpenProvider. Try again or check OpenProvider directly.'
            }

            # Get DNS zone from OpenProvider
            Write-Information "Getting OpenProvider DNS zone for $($Domain)"
            try {
                $OPDnsZone = Get-OPDnsZone -Domain $Domain | Where-Object -Property RecordType -ne 'NS'
            }
            catch {
                Write-Error $_
                throw 'Error getting DNS zone from OpenProvider. Try again or check OpenProvider directly.'
            }

            # Get DNS zone from Azure and create if needed
            Write-Information "Getting Azure DNS zone for $($Domain)"
            Get-AzDnsZone -Name $Domain -ResourceGroupName $ResourceGroupName -ErrorVariable NotFound -ErrorAction 'SilentlyContinue' | Out-Null
            if ($NotFound) {
                Write-Warning "DNS Zone not found in Azure."
                Write-Information 'Creating new DNS zone...' -ForegroundColor 'Green'
                try {
                    New-AzDnsZone -Name $Domain -ResourceGroupName $ResourceGroupName | Out-Null
                }
                catch {
                    throw 'Error creating DNS zone in Azure'
                }
            }

            # A-Records
            Write-Information 'Processing A-Records...'
            $ARecords = $OPDnsZone | Where-Object 'RecordType' -eq 'A'
            if ($null -ne $ARecords) {
                $ARecords | ForEach-Object {
                    try {
                        $AzARecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorVariable 'NotFound' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $($_.Name) does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ($NotFound) {
                        Write-Output "Creating A-Record Set: $($_.Name)"
                        $AParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -IPv4Address $_.Value)
                        }
                        New-AzDnsRecordSet @AParams | Out-Null
                    }
                    elseif ($AzARecordSet.Records.IPv4Address -contains $_.Value) {
                        Write-Verbose "Record set AND value already exist."
                    }
                    else {
                        Write-Information 'A-Record Set already exists. Updating record set with additional value...'
                        Add-AzDnsRecordConfig -RecordSet $AzARecordSet -Ipv4Address $_.Value
                        Set-AzDnsRecordSet -RecordSet $AzARecordSet
                    }
                } # end Foreach-Object 'A' records
            }
            else {
                Write-Verbose 'No A-Records found. '
            }

            # AAAA-Records
            Write-Information 'Processing AAAA-Records...'
            $AaaaRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'AAAA'
            if ($null -ne $AaaaRecords) {
                $AaaaRecords | ForEach-Object {
                    try {
                        $AzAaaaRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorVariable 'NotFound' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $($_.Name) does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ($Notfound) {
                        Write-Output "Creating AAAA-Record Set: $($_.Name)"
                        $AaaaParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -IPv6Address $_.Value)
                        }
                        New-AzDnsRecordSet @AaaaParams | Out-Null
                    }
                    elseif ($AzAaaaRecordSet.Records.IPv6Address -contains $_.Value) {
                        Write-Verbose "Record set AND value already exist."
                    }
                    else {
                        Write-Information 'AAAA-Record Set already exists. Updating record set with additional value...'
                        Add-AzDnsRecordConfig -RecordSet $AzAaaaRecordSet -Exchange $_.Value -Preference $_.Priority
                        Set-AzDnsRecordSet -RecordSet $AzAaaaRecordSet
                    }
                } # end Foreach-Object 'AAAA' records
            }
            else {
                Write-Verbose 'No AAAA-Records found. '
            }

            # CAA-Records
            Write-Information 'Processing CAA-Records...'
            $CaaRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'CAA'
            if ($null -ne $CaaRecords) {
                $CaaRecords | ForEach-Object {
                    $CaaFlags = $($_.Value.split(' ')[0])
                    $CaaTag   = $($_.Value.split(' ')[1])
                    $CaaValue = $($_.Value.split(' ')[2])
                    try {
                        $AzCaaRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $($_.Name) does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzCaaRecordSet)) {
                        Write-Output "Creating SRV-Record Set: $($_.Name)"
                        $CaaParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -CaaFlags $CaaFlags -CaaTag $CaaTag -CaaValue $CaaValue)
                        }
                        New-AzDnsRecordSet @CaaParams | Out-Null
                    }
                    elseif ($AzCaaRecordSet.Records.Target -contains $Target) {
                        Write-Verbose "Record set AND value already exist."
                    }
                    else {
                        Write-Information 'CAA-Record Set already exists. Updating record set with additional value...'
                        Add-AzDnsRecordConfig -RecordSet $AzCaaRecordSet -CaaFlags $CaaFlags -CaaTag $CaaTag -CaaValue $CaaValue
                        Set-AzDnsRecordSet -RecordSet $AzCaaRecordSet
                    }
                } # end Foreach-Object 'CAA' records
            }
            else {
                Write-Verbose 'No CAA-records found. '
            }

            # CNAME-Records
            Write-Information 'Processing CNAME-Records...'
            $CnameRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'CNAME'
            if ($null -ne $CnameRecords) {
                $CnameRecords | ForEach-Object {
                    try {
                        $AzCnameRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $($_.Name) does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzCnameRecordSet)) {
                        Write-Output "Creating CNAME-Record Set: $($_.Name)"
                        $CnameParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Cname $($_.Value))
                        }
                        New-AzDnsRecordSet @CnameParams | Out-Null
                    }
                    elseif ($AzCnameRecordSet.Records.Cname -contains $_.Value) {
                        Write-Verbose "Record set AND value already exist."
                    }
                    else {
                        Write-Information 'Record Set already exists. Updating record set with additional value...'
                        Add-AzDnsRecordConfig -RecordSet $AzCnameRecordSet -Cname $_.Value
                        Set-AzDnsRecordSet -RecordSet $AzCnameRecordSet
                    }
                } # end Foreach-Object 'CNAME' records
            }
            else {
                Write-Verbose 'No CNAME-Records found.'
            }

            # MX-Records
            Write-Information 'Processing MX-Records...'
            $MxRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'MX'
            if ($null -ne $MxRecords) {
                $MxRecords | ForEach-Object {
                    try {
                        $AzMxRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $($_.Name) does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzMxRecordSet)) {
                        Write-Output "Creating MX-Record Set: $($_.Name)"
                        $MxParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Exchange $_.Value -Preference $_.Priority)
                        }
                        New-AzDnsRecordSet @MxParams | Out-Null
                    }
                    elseif ($AzMxRecordSet.Records.Exchange -contains $_.Value) {
                        Write-Verbose "Record set AND value already exist."
                    }
                    else {
                        Write-Information "Record Set already exists. Updating record set with additional value... $($_.Value)"
                        Add-AzDnsRecordConfig -RecordSet $AzMxRecordSet -Exchange $_.Value -Preference $_.Priority | Out-Null
                        Set-AzDnsRecordSet -RecordSet $AzMxRecordSet | Out-Null
                    }
                } # end Foreach-Object 'MX' records
            }
            else {
                Write-Verbose 'No MX-Records found.'
            }

            # SRV Records
            Write-Information 'Processing SRV-Records...'
            $SrvRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'SRV'
            if ($null -ne $SrvRecords) {
                $SrvRecords | ForEach-Object {
                    $Weight = $($_.Value.split(' ')[0])
                    $Port   = $($_.Value.split(' ')[1])
                    $Target = $($_.Value.split(' ')[2])
                    try {
                        $AzSrvRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $($_.Name) does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzSrvRecordSet)) {
                        Write-Output "Creating SRV-Record Set: $($_.Name)"
                        $SrvParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Priority $_.Priority -Weight $Weight -Port $Port -Target $Target)
                        }
                        New-AzDnsRecordSet @SrvParams | Out-Null
                    }
                    elseif ($AzSrvRecordSet.Records.Target -contains $Target) {
                        Write-Verbose "Record set AND value already exist."
                    }
                    else {
                        Write-Information 'Record Set already exists. Updating record set with additional value...'
                        Add-AzDnsRecordConfig -RecordSet $AzSrvRecordSet -Priority $_.Priority -Weight $Weight -Port $Port -Target $Target | Out-Null
                        Set-AzDnsRecordSet -RecordSet $AzSrvRecordSet | Out-Null
                    }
                } # end Foreach-Object 'SRV' records
            }
            else {
                Write-Verbose 'No SRV-Records found.'
            }

            # TXT-Records
            Write-Information 'Processing TXT-Records...'
            $TxtRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'TXT'
            if ($null -ne $TxtRecords) {
                $TxtRecords | ForEach-Object {
                    $Value = $_.Value -replace '"', ""
                    try {
                        $AzTxtRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $($_.Name) does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzTxtRecordSet)) {
                        Write-Output "Creating TXT-Record Set: $($_.Name)"
                        $TxtParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Value $Value)
                        }
                        New-AzDnsRecordSet @TxtParams | Out-Null
                    }
                    elseif ($AzTxtRecordSet.Records.Value -contains $Value) {
                        Write-Verbose "Record set AND value already exist."
                    }
                    else {
                        Write-Information "TXT Record Set $($_.Name) already exists. Updating record set with additional value... $($Value)"
                        Add-AzDnsRecordConfig -RecordSet $AzTxtRecordSet -Value $Value  | Out-Null
                        Set-AzDnsRecordSet -RecordSet $AzTxtRecordSet  | Out-Null
                    }
                } # end Foreach-Object 'TXT' records
            }
            else {
                Write-Verbose 'No TXT-Records found.'
            }

            Write-Output "FINISHED Syncing DNS zone to Azure for domain: $Domain"
        }
    } # end Process

    end {
        # TO DO: Generate better output report for every domain (PSCustomObject)

    }
}