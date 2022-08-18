<#
    .SYNOPSIS
    Gets tickets/requests throught the SupportCenter API.

    .LINK
    https://www.manageengine.com/products/support-center/help/adminguide/api/api-req-operation.html#viewRequestBasedOnFilters

    .EXAMPLE
    Get-ScTickets -Type 'Open' -Count 50

    .EXAMPLE
    Get-ScTickets -Type 'Unassigned' -Count 5

    .EXAMPLE
    Get-ScTickets -Engineer 'Tom' -Status 'On Hold' | ft

    .NOTES
    Author:   Tom de Leeuw
    Website:  https://ucsystems.nl / https://tech-tom.com
#>
function Get-ScTickets {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [Alias('Get-Ticket', 'Get-Request', 'Get-Requests')]
    param (
        # Type of tickets to get. i.e. 'Open', 'Unassigned'
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByEngineer')]
        [ValidateSet("Open", "Unassigned")]
        [string] $Type,

        # Full name of engineer to get tickets from.
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByEngineer')]
        [ValidateSet("Normal", "Low" ,"Gepland", "Unassigned")]
        [string] $Priority,

        # Full name of engineer to get tickets from.
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByEngineer')]
        [ValidateSet("Open", "Closed", "On Hold", "Opheffing", "Oplevering", "Unassigned")]
        [string] $Status,

        # Full name of engineer to get tickets from.
        [Parameter(ParameterSetName = 'ByEngineer')]
        [string] $Engineer,

        # Amount of tickets to return. Default = 100, Maximum = 100.
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ByEngineer')]
        [ValidateNotNullorEmpty()]
        [int] $Count = 100
    )

    begin {
        # Check required API parameters
        Test-ScApiRequirements
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Default') {
            $ViewName = switch ( $Type ) {
                Unassigned { 'Unassigned_System' }
                Open { 'Open_System' }
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByEngineer') {
            <#
                TO DO: These are view names from my own, other API keys will not work!!
            #>
            $ViewName = switch ( $Engineer ) {
                Tom         { "17712_MyView" }   
                Henk        { "17713_MyView" }
                Duncan      { "17714_MyView" }
                Johan       { "17715_MyView" }
                Derek       { "17717_MyView" }
                Frank       { "17718_MyView" }
                Thom        { "17719_MyView" }
                Wouter      { "17720_MyView" }
                Dennis      { "17721_MyView" }
                Mike        { "17724_MyView" }
                Hoessein    { "17723_MyView" }
            }
        }
        
        # Build request body
        $Body = @{
            apikey       = $APIKey
            businessUnit = $BusinessUnit
            viewName     = $ViewName
            count        = $Count
        }
    
        # Send request
        $Response = Invoke-ScApiRequest -Method 'GET' -Operation 'getRequestsByView' -Body $Body

        # Verify response result, then build output
        if ($Response.response.result.statuscode -eq 200) {
            $Result = $Response.response.result.requests.request
            $Output = $Result | ForEach-Object {
                [PSCustomObject]@{
                    ID          = $_.requestID
                    Priority    = $_.Priority
                    Status      = $_.status
                    Engineer    = $_.supportRep
                    Created     = $_.createdTime
                    Subject     = $_.Subject
                    Contact     = $_.Contact
                    Account     = $_.Account
                    isOverDue   = $_.isOverDue
                    Expires     = $_.dueByTime
                    Updated     = $_.updatedTime
                    #AccountID   = $_.AccountID
                    #supportRepCostPerHour
                    #templateId
                    #statusID
                    #userTimeFormat
                }
            } | Sort-Object { $_.Created } -Descending
        }
        else {
            Write-Error $_
            throw "ERROR: Could not get tickets using this query."
        }
    } # end Process block

    end {
        # Output formatting
        if ($Priority) {
            $Output = $Output | Where-Object { $_.Priority -eq $Priority }
        }
        if ($Status) {
            $Output = $Output | Where-Object { $_.Status -eq $Status }
        }
        return $Output
    }
}
