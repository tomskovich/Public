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
        [ValidateSet('getRequestsByView', 'sendReply')]
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

        # Add Body to above parameters if parameter is present
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