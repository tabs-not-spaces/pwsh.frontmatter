function Convert-FrontMatterValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$value
    )
    $value = $value.Trim()

    # Quoting is how an author opts a value out of numeric promotion, so a
    # quoted value always comes back as a string.
    $fmQuotedValuesRegex = "^([`"\'])(.*)\1$"
    if ($value -match $fmQuotedValuesRegex) {
        if ($Matches[1] -eq '"') {
            return (Expand-FrontMatterEscape -Value $Matches[2])
        }
        return $Matches[2]
    }

    # Leading zeros are data, so 007 stays a string. 0 and negatives are real
    # integers, which the old -as [int] truthiness test got wrong.
    $parsed = 0
    if ($value -match '^(0|-?[1-9]\d*)$' -and [int]::TryParse($value, [ref]$parsed)) {
        return $parsed
    }
    return $value
}
