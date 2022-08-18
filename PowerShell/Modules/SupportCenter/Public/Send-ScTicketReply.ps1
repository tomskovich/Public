<#
    .SYNOPSIS
    Reply/send an e-mail from a specific ticket.

    .LINK
    https://www.manageengine.com/products/support-center/help/adminguide/api/api-req-operation.html#sendreply

    .EXAMPLE
    Send-ScTicketReply -TicketID 147584 -ToAddress 'tom@ucsystems.nl' -Description 'Test'

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Send-ScTicketReply {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int] $TicketID,

        [Alias('Recipient')]
        [Parameter(Mandatory = $true)]
        [string] $ToAddress,

        [Alias('Message')]
        [Parameter(Mandatory = $true)]
        [string] $Description,

        [Parameter()]
        [string] $Subject,

        # Whether or not to include the original e-mail conversation
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch] $IncludeOriginalContent = $false
    )

    begin {
        # Check required API parameters
        Test-ScApiRequirements

        # Build request URI
        $Operation = 'sendReply'
        $URI       = $BaseURL + $Operation

        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    
    process {
        # Build request body
        Write-Host $APIKey
        $Body = @{
            apikey          = $APIKey
            toAddress       = $ToAddress
            woID            = $TicketID
            description     = $Description
        }

        # Add optional parameters to body if present
        if ($Subject) {
            $Body.Subject = $Subject
        }
        if ($IncludeOriginalContent) {
            $Body.IncludeOriginalContent = $IncludeOriginalContent
        }

        # Parameters for Invoke-Restmethod
        $Params = @{
            Uri             = $URI
            Method          = 'POST'
            UseBasicParsing = $true
            Body            = $Body
        }

        # Send request
        $Response = Invoke-WebRequest @Params

        # Verify request result
        if ($Response) {
            $JsonResult = $Response.Content | ConvertFrom-Json
            $Result = $JsonResult.Response.Result
            if ($Result.Status -eq 'Success') {
                Write-Host $Result.statusmessage -ForegroundColor Green
            }
            else {
                throw "ERROR: $($Result.Statusmessage)"
            }
        }
        else {
            Write-Error $_
        }
    } # end Process block

}


