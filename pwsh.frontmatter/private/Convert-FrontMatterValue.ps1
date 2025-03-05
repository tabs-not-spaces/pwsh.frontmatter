function Convert-FrontMatterValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$value
    )
    # Remove surrounding quotes if present
    $fmQuotedValuesRegex = "^([`"\'])(.*)\1$"
    $value = $value.Trim() -replace $fmQuotedValuesRegex, '$2'
    if ($value -as [int] -and $value -match '^\d+$') {
        return [int]$value
    }
    return $value
}