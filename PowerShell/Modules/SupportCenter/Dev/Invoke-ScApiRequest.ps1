function Set-ScApiParameters {
    [CmdLetBinding()]
    param(
        # Personal API key found in SupportCenter account preferences
        [Parameter()]
        [string] $APIKey,

        # API Base URL
        [Parameter()]
        [ValidateNotNullorEmpty()]
        [string] $BaseURL = 'https://service.ucsystems.net/api/json/',

        [Parameter()]
        [ValidateNotNullorEmpty()]
        [string] $BusinessUnit = 'UC Systems'
    )

    try {
        # Set BaseURL
        New-Variable -Name BaseURL -Value $BaseURL -Scope Script -Option ReadOnly -Force

        # Set BusinessUnit
        New-Variable -Name BusinessUnit -Value $BusinessUnit -Scope Script -Option ReadOnly -Force 
        
        # Set API Key
        if ($PSBoundParameters.ContainsKey('APIKey')) {
            New-Variable -Name APIKey -Value $APIKey -Scope Script -Force
            Write-Host "API Key saved successfully." -ForegroundColor Green
        }
        else {
            $Key = Read-Host 'Please enter your personal API key'
            New-Variable -Name APIKey -Value $Key -Scope Script -Force
            Write-Host "API Key saved successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Error $_
    }

}

function Test-ScApiRequirements {

    if ($null -eq $APIKey) {
        throw "API Key missing. Please run Set-ScApiParameters first."
    }
    elseif ($null -eq $BaseURL) {
        throw "Base URL missing. Please run Set-ScApiParameters first."
    }
    elseif ($null -eq $BusinessUnit) {
        throw "BusinessUnit missing. Please run Set-ScApiParameters first."
    }

}

<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function Invoke-ScApiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('GET', 'PUT', 'POST', 'DELETE')]
        [string] $Method,

        [Parameter(Mandatory=$true)]
        [string] $Operation,

        [Parameter(Mandatory=$false)]
        [hashtable] $Body
    )
    
    begin {
        # Check required API parameters
        Test-ScApiRequirements

        # Build request URI
        $URI = $BaseURL + $Operation

        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    
    process {
        # Parameters for Invoke-Restmethod
        $Params = [ordered]@{
            Uri             = $URI
            Method          = $Method
            ContentType     = "application/json"
            UseBasicParsing = $true
        }

        # Add Body to parameters if present
        if ($Body) {
            $Params.Body = $Body
        }
        
        # Make request
        try {
            $Response = Invoke-RestMethod @Params
            return $Response
        }
        catch {
            Write-Error $_
        }
    }

}

Set-ScApiParameters -APIkey 'E1607002-F969-4DC8-915A-39AEB839563D'

$Count = 10
$ViewName = '17712_MyView'
# Build request body
$Body = @{
    apikey       = $APIKey
    businessUnit = $BusinessUnit
    viewName     = $ViewName
    count        = $Count
}

Invoke-ScApiRequest -Method 'GET' -Operation 'getRequestsByView' -Body $Body

