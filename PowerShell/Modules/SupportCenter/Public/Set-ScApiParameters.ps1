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