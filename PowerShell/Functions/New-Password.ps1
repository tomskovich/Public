<#
    .SYNOPSIS
    Generates one or more "random" human-readable passwords. Default language is English.

    .LINK
    https://tech-tom.com/posts/powershell-password-generator/

    .EXAMPLE
    New-Password -Count 10

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://tech-tom.com / https://ucsystems.nl
#>
function New-Password {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param(
        # Language to use
        [Parameter(ParameterSetName = 'Default')]
        [ValidateSet('NL', 'EN')]
        [ValidateNotNullOrEmpty()]
        [string] $Language = 'EN',

        # URL to get wordlist from
        [Parameter(ParameterSetName = 'Default')]
        [ValidateNotNullOrEmpty()]
        [string] $URL = "https://raw.githubusercontent.com/tomskovich/Public/main/src/Wordlists/$($Language).txt",

        # Path to file with words to use
        [Parameter(ParameterSetName = 'Custom')]
        [ValidateScript({ Test-Path -Path $_ })]
        [Alias('Path', 'WordList', 'File', 'SourceFile')]
        [string] $WordListFile,

        # Amount of passwords to generate
        [Alias('PasswordCount', 'PassCount')]
        [int] $Count = 1,
    
        # Amount of words to use when generating password
        [int] $WordCount = 2,
    
        # Amount of numbers to use in password
        [int] $NumberCount = 4,

        # Amount of special characters to use
        [Alias('CharCount')]
        [int] $CharacterCount = 1,

        # Range of numbers to use in password
        [array] $NumberRange = 1..9,

        # Special characters to use in password
        [array] $Characters = '!,@,#,$,%' -split ','
    )

    begin {
        # Parameter validation
        if ($WordListFile) {
            try {
                $WordList = Get-Content -Path $WordListFile
            }
            catch {
                throw "No wordlist found! Verify if $WordList exists."
            }
        }
        if ($Language) {
            try {
                $Request  = Invoke-WebRequest -Uri $URL
                $WordList = $Request.Content.Trim().split("`n")
            }
            catch {
                throw "Error getting wordlist from $URL"
            }
        }
        # Create arraylist for output 
        $Passwords = New-Object System.Collections.ArrayList
    } # end Begin

    process {
        foreach ($i in 1..$Count) {
            # Get random word(s) from list, then title-case each word
            $RandomWords = -join (
                Get-Random -InputObject $WordList -Count $WordCount).ForEach({
                    (Get-Culture).TextInfo.ToTitleCase($_)
                }
            )
            # Generate random special character(s)
            $RandomCharacters = -join (Get-Random -InputObject $Characters -Count $CharacterCount)
            # Generate random number
            $RandomNumbers = -join (Get-Random -InputObject $NumberRange -Count $NumberCount)
            # Join everything to create final password
            $Password = -join (
                $RandomWords,
                $RandomCharacters,
                $RandomNumbers
            )
            # Add password to collection but hide output
            [void] $Passwords.Add($Password)
        } # end Foreach
    } # end Process

    end {
        return $Passwords
    } # end End
}