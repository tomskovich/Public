function Test-ScApiRequirements {
    
    # Checks if each of the -required- variables exists.
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