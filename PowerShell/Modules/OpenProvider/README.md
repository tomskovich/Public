# OpenProvider API wrapper

`IMPORTANT: This module is still a work in progress!`

At my current job, we use [OpenProvider](https://openprovider.com) as our main domain registrar and DNS provider.

I initially wrote this module for personal convenience, but I've also integrated some of the functions in our [PowerShell Universal](https://ironmansoftware.com/powershell-universal) dashboards.

Lately, OpenProvider has had multiple DNS outages. This has forced us to migrate some of our bigger clients' DNS-zones to Azure.

To automate this process, I added the `Sync-OPDnsToAzure` function.