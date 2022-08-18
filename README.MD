# PUBLIC REPOSITORY

This is my repo for useful PowerShell/Python stuff. 
Most of this code is created for daily SysAdmin tasks, but some private projects will be present as well.

More information will be posted on my [blog](https://tech-tom.com).

## INDEX

- [PowerShell](https://github.com/tomskovich/Public#powershell)
    - [Scripts](https://github.com/tomskovich/Public#powershellscripts)
    - [Functions](https://github.com/tomskovich/Public#powershellfunctions)
        - [New-Password]
    - [Modules](https://github.com/tomskovich/Public#powershellmodules)

- [Python](https://github.com/tomskovich/Public#python)
    - [Scripts](https://github.com/tomskovich/Public#pythonscripts)

## LINKS

- [Blog](https://tech-tom.com)
- [Report bug, issue, improvement request](https://github.com/tomskovich/Public/tree/main/PowerShell/issues/new/choose)

# POWERSHELL

## Functions

- #####[New-Password](https://github.com/tomskovich/Public/tree/main/PowerShell/blob/main/Functions/New-Password.ps1) 
    - Generates one or more "random" human-readable passwords, with some options for complexity and language. See [blog post](https://tech-tom.com/posts/powershell-password-generator/) for more information.

## Modules

All of these modules are a work in progress.

- [OpenProvider](https://github.com/tomskovich/Public/tree/main/PowerShell/Modules/OpenProvider)
    - PowerShell wrapper around the OpenProvider API (OpenProvider = Domain registrar)
    - Also includes a function to duplicate DNS zones from OpenProvider to Azure. (Sync-OPDnsToAzure)
        - I wrote this because we were having recurring issues with OpenProvider that forced us to move several DNS zones to Azure.
- [SupportCenter](https://github.com/tomskovich/Public/tree/main/PowerShell/Modules/SupportCenter)
    - PowerShell wrapper around ManageEngine SupportCenter API. (fml)
    - Mainly used for personal convenience, and for usage in dashboards.

## Scripts

- [Placeholder]


# PYTHON

## Scripts

- [Placeholder]


