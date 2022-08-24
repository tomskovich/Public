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

        [Switch] $Migrate
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
                    if ( Get-Module -ListAvailable -Name $Module ) {
                        Write-Host "Loading module: $Module..." -ForegroundColor 'Yellow'
                        Import-Module $Module
                    }
                    else {
                        Write-Host "Module $Module not installed! Installing module..." -ForegroundColor 'Yellow'
                        Install-Module $Module
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
            Write-Host 'Seems there is no connection to Azure. Please login to your Azure account' -ForegroundColor 'Red'
            try {
                Connect-AzAccount
            }
            catch {
                Write-Error $_
                throw 'Error connecting to Azure. Aborting...'
            }
        }
        else {
            Write-Host 'Connected to Azure. Continuing...' -ForegroundColor 'Green'
        }
        
        # Check for Az Resource Group permissions
        if ( ! (Get-AzResourceGroup -Name $ResourceGroupName)) {
            throw "Cannot access resource group $ResourceGroupName. Please check your permissions, or change to the correct context with Get-AzSubscription and Set-AzContext."
        }
        else {
            Write-Host "Account has permissions for Resource Group $ResourceGroupName. Continuing..." -ForegroundColor 'Green'
        }
    } # end Begin

    process {
        foreach ($Domain in $Domains) {
            # Get domain info from OpenProvider; prompt user for confirmation
            Write-host "Getting OpenProvider NameServer group for domain: $($Domain)" -ForegroundColor 'Yellow'
            try {
                if ($Search) {
                    $OPDomainInfo = Get-OPDomain -Domain $Domain -Search
                }
                else {
                    $OPDomainInfo = Get-OPDomain -Domain $Domain
                }
                Write-Host '=== Received the following domain information from OpenProvider. Please verify if this domain is correct.' -ForegroundColor 'Cyan'
                $OPDomainInfo
                Pause
            }
            catch {
                Write-Error $_
                throw 'Error getting NameServer group from OpenProvider. Try again or check OpenProvider directly.'
            }

            # Get DNS zone from OpenProvider
            Write-host "Getting OpenProvider DNS zone for domain: $($Domain)" -ForegroundColor 'Yellow'
            try {
                $OPDnsZone = Get-OPDnsZone -Domain $Domain | Where-Object -Property RecordType -ne 'NS'
            }
            catch {
                Write-Error $_
                throw 'Error getting DNS zone from OpenProvider. Try again or check OpenProvider directly.'
            }

            # Get DNS zone from Azure and create if needed
            Write-host "Getting Azure DNS zone for domain: $($Domain)" -ForegroundColor 'Yellow'
            Get-AzDnsZone -Name $Domain -ResourceGroupName $ResourceGroupName -ErrorVariable NotFound -ErrorAction 'SilentlyContinue' | Out-Null
            if ($NotFound) { 
                Write-Warning "DNS Zone not found in Azure."
                Write-Host 'Creating new DNS zone...' -ForegroundColor 'Yellow'
                try {
                    New-AzDnsZone -Name $Domain -ResourceGroupName $ResourceGroupName
                }
                catch {
                    throw 'Error creating DNS zone in Azure'
                }
            }

            # A-Records
            Write-Host 'Processing A-Records...' -ForegroundColor 'Yellow'
            $ARecords = $OPDnsZone | Where-Object 'RecordType' -eq 'A'
            if ($null -ne $ARecords) {
                $ARecords | ForEach-Object {
                    # Get first part of A-record
                    if ($_.Name -ne '@') { 
                        $Name = $_.Name -replace "\.$Domain", ""
                    }
                    else {
                        $Name = $_.Name
                    }
                    try {
                        $AzARecordSet = Get-AzDnsRecordSet -Name $Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorVariable 'NotFound' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $Name does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ($NotFound) {
                        Write-Host "Creating A-Record Set: $Name" -ForegroundColor 'Yellow'
                        $AParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -IPv4Address $_.Value)
                        }
                        New-AzDnsRecordSet @AParams
                    }
                    elseif ($AzARecordSet.Records.IPv4Address -contains $_.Value) {
                        Write-Host "Record set AND value already exist." -ForegroundColor 'DarkGray'
                    }
                    else {
                        Write-Host 'Record Set already exists. Updating record set with additional value...' -ForegroundColor 'Yellow'
                        Add-AzDnsRecordConfig -RecordSet $AzARecordSet -Ipv4Address $_.Value
                        Set-AzDnsRecordSet -RecordSet $AzARecordSet
                    }
                } # end Foreach-Object 'A' records
            }
            else {
                Write-Host 'No A-Records found. ' -ForegroundColor 'DarkGray'
            }

            # AAAA-Records
            Write-Host 'Processing AAAA-Records...' -ForegroundColor 'Yellow'
            $AaaaRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'AAAA'
            if ($null -ne $AaaaRecords) {
                $AaaaRecords | ForEach-Object {
                    try {
                        $AzAaaaRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $Name does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzAaaaRecordSet)) {
                        Write-Host "Creating AAAA-Record Set: $Name" -ForegroundColor 'Green'
                        $AaaaParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -IPv6Address $_.Value)
                        }
                        New-AzDnsRecordSet @AaaaParams
                    }
                    elseif ($AzAaaaRecordSet.Records.IPv6Address -contains $_.Value) {
                        Write-Host "Record set AND value already exist." -ForegroundColor 'DarkGray' -ForegroundColor 'Yellow'
                    }
                    else {
                        Write-Host 'Record Set already exists. Updating record set with additional value...' -ForegroundColor 'Yellow'
                        Add-AzDnsRecordConfig -RecordSet $AzAaaaRecordSet -Exchange $_.Value -Preference $_.Priority
                        Set-AzDnsRecordSet -RecordSet $AzAaaaRecordSet
                    }
                } # end Foreach-Object 'AAAA' records
            }
            else {
                Write-Host 'No AAAA-Records found. ' -ForegroundColor 'DarkGray'
            }

            # CAA-Records
            Write-Host 'Processing CAA-Records...' -ForegroundColor 'Yellow'
            $CaaRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'CAA'
            if ($null -ne $CaaRecords) {
                $CaaRecords | ForEach-Object {
                    $CaaFlags = $($_.Value.split(' ')[0])
                    $CaaTag   = $($_.Value.split(' ')[1])
                    $CaaValue = $($_.Value.split(' ')[2])
                    try {
                        $AzCaaRecordSet = Get-AzDnsRecordSet -Name $Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $Name does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzCaaRecordSet)) {
                        Write-Host "Creating SRV-Record Set: $Name" -ForegroundColor 'Green'
                        $CaaParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -CaaFlags $CaaFlags -CaaTag $CaaTag -CaaValue $CaaValue)
                        }
                        New-AzDnsRecordSet @CaaParams
                    }
                    elseif ($AzCaaRecordSet.Records.Target -contains $Target) {
                        Write-Host "Record set AND value already exist." -ForegroundColor 'DarkGray'
                    }
                    else {
                        Write-Host 'Record Set already exists. Updating record set with additional value...' -ForegroundColor 'Yellow'
                        Add-AzDnsRecordConfig -RecordSet $AzCaaRecordSet -CaaFlags $CaaFlags -CaaTag $CaaTag -CaaValue $CaaValue
                        Set-AzDnsRecordSet -RecordSet $AzCaaRecordSet
                    }
                } # end Foreach-Object 'CAA' records
            }
            else {
                Write-Host 'No CAA-records found. ' -ForegroundColor 'DarkGray'
            }

            # CNAME-Records
            Write-Host 'Processing CNAME-Records...' -ForegroundColor 'Yellow'
            $CnameRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'CNAME'
            if ($null -ne $CnameRecords) {
                $CnameRecords | ForEach-Object {
                    if ($_.Name -ne '@') { 
                        $Name = $_.Name.Replace(".$($_.Domain)", '')
                    }
                    try {
                        $AzCnameRecordSet = Get-AzDnsRecordSet -Name $Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $Name does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzCnameRecordSet)) {
                        Write-Host "Creating CNAME-Record Set: $Name" -ForegroundColor 'Green'
                        $CnameParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Cname $($_.Value))
                        }
                        New-AzDnsRecordSet @CnameParams
                    }
                    elseif ($AzCnameRecordSet.Records.Cname -contains $_.Value) {
                        Write-Host "Record set AND value already exist." -ForegroundColor 'DarkGray'
                    }
                    else {
                        Write-Host 'Record Set already exists. Updating record set with additional value...' -ForegroundColor 'Yellow'
                        Add-AzDnsRecordConfig -RecordSet $AzCnameRecordSet -Cname $_.Value
                        Set-AzDnsRecordSet -RecordSet $AzCnameRecordSet
                    }
                } # end Foreach-Object 'CNAME' records
            }
            else {
                Write-Host 'No CNAME-Records found. ' -ForegroundColor 'DarkGray'
            }

            # MX-Records
            Write-Host 'Processing MX-Records...' -ForegroundColor 'Yellow'
            $MxRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'MX'
            if ($null -ne $MxRecords) {
                $MxRecords | ForEach-Object {
                    try {
                        $AzMxRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $Name does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzMxRecordSet)) {
                        Write-Host "Creating MX-Record Set: $Name" -ForegroundColor 'Green'
                        $MxParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Exchange $_.Value -Preference $_.Priority)
                        }
                        New-AzDnsRecordSet @MxParams
                    }
                    elseif ($AzMxRecordSet.Records.Exchange -contains $_.Value) {
                        Write-Host "Record set AND value already exist." -ForegroundColor 'DarkGray'
                    }
                    else {
                        Write-Host 'Record Set already exists. Updating record set with additional value...' -ForegroundColor 'Yellow'
                        Add-AzDnsRecordConfig -RecordSet $AzMxRecordSet -Exchange $_.Value -Preference $_.Priority
                        Set-AzDnsRecordSet -RecordSet $AzMxRecordSet
                    }
                } # end Foreach-Object 'MX' records
            }
            else {
                Write-Host 'No MX-Records found. ' -ForegroundColor 'DarkGray'
            }

            # SRV Records
            Write-Host 'Processing SRV-Records...' -ForegroundColor 'Yellow'
            $SrvRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'SRV'
            if ($null -ne $SrvRecords) {
                $SrvRecords | ForEach-Object {
                    $Weight = $($_.Value.split(' ')[0])
                    $Port   = $($_.Value.split(' ')[1])
                    $Target = $($_.Value.split(' ')[2])
                    $Name   = $_.Name.Replace(".$($_.Domain)", '')
                    try {
                        $AzSrvRecordSet = Get-AzDnsRecordSet -Name $Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $Name does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzSrvRecordSet)) {
                        Write-Host "Creating SRV-Record Set: $Name" -ForegroundColor 'Green'
                        $SrvParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Priority $_.Priority -Weight $Weight -Port $Port -Target $Target)
                        }
                        New-AzDnsRecordSet @SrvParams
                    }
                    elseif ($AzSrvRecordSet.Records.Target -contains $Target) {
                        Write-Host "Record set AND value already exist." -ForegroundColor 'DarkGray'
                    }
                    else {
                        Write-Host 'Record Set already exists. Updating record set with additional value...' -ForegroundColor 'Yellow'
                        Add-AzDnsRecordConfig -RecordSet $AzSrvRecordSet -Priority $_.Priority -Weight $Weight -Port $Port -Target $Target
                        Set-AzDnsRecordSet -RecordSet $AzSrvRecordSet
                    }
                } # end Foreach-Object 'SRV' records
            }
            else {
                Write-Host 'No SRV-Records found. ' -ForegroundColor 'DarkGray'
            }

            # TXT-Records
            Write-Host 'Processing TXT-Records...' -ForegroundColor 'Yellow'
            $TxtRecords = $OPDnsZone | Where-Object 'RecordType' -eq 'TXT'
            if ($null -ne $TxtRecords) {
                $TxtRecords | ForEach-Object {
                    $Value = $_.Value -replace '"', ""
                    try {
                        $AzTxtRecordSet = Get-AzDnsRecordSet -Name $_.Name -RecordType $_.RecordType -ZoneName $_.Domain -ResourceGroupName 'DNS' -ErrorAction 'Stop'
                    }
                    catch [Microsoft.Rest.Azure.CloudException] {
                        Write-Warning "Record Set $Name does not exist." -ErrorAction 'SilentlyContinue'
                    }
                    if ( ! ($AzTxtRecordSet)) {
                        Write-Host "Creating TXT-Record Set: $Name" -ForegroundColor 'Green'
                        $TxtParams = @{
                            ResourceGroupName = 'DNS'
                            ZoneName          = $_.Domain
                            Name              = $_.Name
                            RecordType        = $_.RecordType
                            Ttl               = $_.Ttl
                            DnsRecords        = (New-AzDnsRecordConfig -Value $Value)
                        }
                        New-AzDnsRecordSet @TxtParams
                    }
                    elseif ($AzTxtRecordSet.Records.Value -contains $Value) {
                        Write-Host "Record set AND value already exist." -ForegroundColor 'DarkGray'
                    }
                    else {
                        Write-Host 'Record Set already exists. Updating record set with additional value...' -ForegroundColor 'Yellow'
                        Add-AzDnsRecordConfig -RecordSet $AzTxtRecordSet -Value $Value
                        Set-AzDnsRecordSet -RecordSet $AzTxtRecordSet
                    }
                } # end Foreach-Object 'TXT' records
            }
            else {
                Write-Host 'No TXT- Records found. ' -ForegroundColor 'DarkGray'
            }

            # NS Migration (optional param)
            if ($Migrate.IsPresent) {
                Write-Host "Migrate Parameter detected. Starting NS Group migration process..." -ForegroundColor 'DarkGray'

                Write-Host "=== AZURE NameServer data for domain $($Domain):" -ForegroundColor Cyan
                $AzNsInfo = Get-AzDnsZone -Name $Domain -ResourceGroupName $ResourceGroupName | Select-Object NameServers
                $CurrentNsInfo = foreach ($item in $AzNsInfo) {
                    [pscustomobject] @{
                        Registrar = 'Azure'
                        NameServers = $item.NameServers
                    }
                }

                # Show current NameServer data
                $CurrentNsInfo | Format-Table
                Write-Host 'Please make note of the Azure NameServers. You will need these for the next step.' -ForegroundColor 'Cyan'
                Pause

                # Get NS Groups from OpenProvider and build/display menu
                $OPNameserverGroups = Get-OPNameServerGroups
                foreach ($MenuItem in $OPNameserverGroups) {
                    Write-Host "$($OPNameserverGroups.IndexOf($MenuItem) + 1) - $($MenuItem.Name)"
                }

                # Prompt for choice
                $Choice = $null
                while ([string]::IsNullOrEmpty($Choice)) {
                    $Choice = Read-Host 'Please choose a NameServer group by number'
                    if ($Choice -notin 1..$OPNameserverGroups.Count) {
                        Write-Warning "Your choice: $Choice is not valid. Please try again ..."
                        Pause
                        $Choice = ''
                    }
                }
        
                # Verify choice
                $Title      = "LAST VERIFICATION:"
                $Question   = "You chose: $($OPNameserverGroups[$Choice - 1].Name) for domain: $Domain. Is this correct?"
                $Choices    = '&Yes', '&No'
                $NsVerification = $Host.UI.PromptForChoice($Title, $Question, $Choices, 1)
                switch ($NsVerification) {
                    0 { 
                        # Edit NameServer group
                        Write-Host "Editing OpenProvider NameServer group..." -ForegroundColor 'Yellow'
                        $SelectedOpGroup = $OPNameserverGroups | Where-Object 'Name' -eq ($OPNameserverGroups[$Choice - 1].Name)
                        Set-OPNameServerGroup -Domain $Domain -GroupName $SelectedOpGroup.Name
                    }
                    1 { 
                        "Ok, BYE!!"
                        exit 
                    }
                }
            }
            
            # Report section
            Write-Host "=== OPENPROVIDER DNS Data for domain $($Domain):" -ForegroundColor Cyan
            $OPDnsZone | Select-Object Name, TTL, RecordType, Value | Sort-Object -Property RecordType | Format-Table

            Write-Host "=== AZURE DNS Data for domain $($Domain):" -ForegroundColor Cyan
            Get-AzDnsRecordSet -ZoneName $Domain -ResourceGroupName $ResourceGroupName | 
                Select-Object Name, TTL, RecordType, Records | Sort-Object -Property RecordType | Format-Table

            if ($Migrate.IsPresent) {
                Write-Host "=== NEW NameServer data for domain $($Domain):" -ForegroundColor Cyan
                foreach ($item in (Get-OPDomain -Domain $Domain | Select-Object NameServers)) {
                    [pscustomobject] @{
                        Registrar = 'OpenProvider'
                        NameServers = $item.NameServers
                    }
                }
            }
        }
    } # end Process

    end {
        # TO DO: Generate better output report for every domain (PSCustomObject)
    }
}