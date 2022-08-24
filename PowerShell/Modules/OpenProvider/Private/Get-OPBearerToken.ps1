<#
    .SYNOPSIS
    Retrieves/verifies Bearer token for OpenProvider API authentication

    .LINK
    https://support.openprovider.eu/hc/en-us/articles/360025683173-Getting-started-with-Openprovider-API

    .EXAMPLE
    Get-OPBearerToken

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://tech-tom.com / https://ucsystems.nl
#>
function Get-OPBearerToken {
    param (
        # API URL 
        [Alias('URI')]
        [ValidateNotNullOrEmpty()]
        [String] $URL = 'https://api.openprovider.eu/v1beta/auth/login'
    )

    begin {
        # Use TLS 1.2 for older PowerShell versions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Check if the token already exists and is not expired
        $Token = Get-Variable -Name 'OPToken' -Scope Global -ErrorAction SilentlyContinue
    }

    process {
        if ( ($null -eq $Token) -or ($Token.CreationTime -gt $(Get-Date).AddHours(-24)) ) {
            Write-Host 'API Token is expired or does not exist. Requesting new token.' -ForegroundColor 'Yellow'

            $Credential = Get-Credential -Message 'Enter username/password for OpenProvider API authentication:'
            
            # -AsPlainText parameter does not exist in PS5; Added custom function in catch block to fix this.
            try {
                $Body = @{
                    username = $Credential.Username
                    password = $Credential.Password | ConvertFrom-SecureString -AsPlainText
                } | ConvertTo-Json
            }
            catch {
                $Body = @{
                    username = $Credential.Username
                    password = Convert-SecureToPlain -SecureString $Credential.Password
                } | ConvertTo-Json
            }

            $Params = @{
                Method      = 'POST'
                Uri         = $URL
                Body        = $Body
                ContentType = 'application/json'
            }
        
            $Response = (Invoke-RestMethod @Params).data
            
            $Data = [PSCustomObject]@{
                Token        = $Response.Token
                CreationTime = (Get-Date)
            }
            
            try {
                Set-Variable -Name 'OPToken' -Value $Data -Option Private -Scope 'Global'
            }
            catch {
                Write-Error $_
            }
        } # end If
        else {
            Write-Verbose 'Token exists and is still valid. Continuing..'
        }
    }

    end {
        $Token = Get-Variable -Name 'OPToken' -Scope Global -ErrorAction SilentlyContinue
        return $Token.Value
    }

}
