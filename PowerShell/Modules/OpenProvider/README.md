# OpenProvider API wrapper

`IMPORTANT: This module is still a work in progress!`

At my current job, we use [OpenProvider](https://openprovider.com) as our main domain registrar and DNS provider.

I initially wrote this module for personal convenience, but I've also integrated some of the functions in our [PowerShell Universal](https://ironmansoftware.com/powershell-universal) dashboards.


# Functions\Private

- [Get-OPBearerToken](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Private/Get-OPBearerToken.ps1) 
    - Retrieves/verifies Bearer token for OpenProvider API authentication.
- [Convert-SecureToPlain](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Private/Convert-SecureToPlain.ps1)
    - In PS 7, you can use "ConvertFrom-SecureString and -AsPlainText"
- [Format-DomainName](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Private/Format-DomainName.ps1)
    - Verifies if given domain name is valid, then extracts the domain name.
    - OPTIONAL: Removes domain extension for usage in search queries with multiple results.

# Functions\Public

- [Get-OPDomain](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Get-OPDomain.ps1) 
    - Searches/gets a domain through the OpenProvider API. Returns Domain ID, Owner etc.
- [Get-OPTransferToken](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Get-OPTransferToken.ps1) 
    - Retrieves domain transfer key(s) through the OpenProvider API
- [Get-OPDnsZone](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Get-OPDnsZone.ps1)
    - Retrieves domain DNS zone(s) through the OpenProvider API
- [Get-OPNameServerGroups](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Get-OPNameServerGroups.ps1)
    - Retrieves NameServer groups from your OpenProvider account. Search query optional.
- [Get-OPSslCertificate](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Get-OPSslCertificate.ps1)
    - Retrieves SSL Certificate information through the OpenProvider API.
- [Update-OPSslCertificate](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Update-OPSslCertificate.ps1)
    - Starts SSL Certificate renewal process through the OpenProvider API
- [Set-OPNameServerGroup](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Set-OPNameServerGroup.ps1)
    - Modifies NameServer group for a specific domain.
- [Sync-OPDnsToAzure](https://github.com/tomskovich/Public/blob/main/PowerShell/Modules/OpenProvider/Public/Sync-OPDnsToAzure.ps1)
    - Lately, OpenProvider has had multiple DNS outages. This has forced us to migrate some of our bigger clients' DNS-zones to Azure. I added this function to automate this process.
    - Copies DNS zone(s) from OpenProvider to Azure. Also creates DNS zone in Azure if it does not exist.
    - OPTIONAL - Also changes the NameServer group in OpenProvider When the "-Migrate" parameter is passed to immediately migrate the DNS zone to Azure.
