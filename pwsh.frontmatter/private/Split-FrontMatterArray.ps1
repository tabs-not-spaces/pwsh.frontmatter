function Split-FrontMatterArray {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    # Split an inline array body on commas that sit outside a quoted string.
    # Double quoted strings honour backslash escapes, single quoted do not.
    $items = [System.Collections.Generic.List[string]]::new()
    $current = [System.Text.StringBuilder]::new()
    $quote = [char]0
    $escaped = $false

    foreach ($char in $Value.ToCharArray()) {
        if ($quote -ne [char]0) {
            [void]$current.Append($char)
            if ($escaped) { $escaped = $false }
            elseif ($quote -eq '"' -and $char -eq '\') { $escaped = $true }
            elseif ($char -eq $quote) { $quote = [char]0 }
        }
        elseif ($char -eq '"' -or $char -eq "'") {
            $quote = $char
            [void]$current.Append($char)
        }
        elseif ($char -eq ',') {
            $items.Add($current.ToString())
            [void]$current.Clear()
        }
        else {
            [void]$current.Append($char)
        }
    }

    # A trailing comma is legal TOML and does not add an item.
    if ($current.ToString().Trim() -ne '' -or $items.Count -eq 0) {
        $items.Add($current.ToString())
    }
    return $items.ToArray()
}
