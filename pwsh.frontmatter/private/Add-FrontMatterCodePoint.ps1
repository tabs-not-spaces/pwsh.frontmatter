function Add-FrontMatterCodePoint {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Text.StringBuilder]$Builder,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [int]$Index,

        [Parameter(Mandatory = $true)]
        [int]$Length,

        [Parameter(Mandatory = $true)]
        [string]$Escape
    )

    $digits = if (($Index + $Length) -le $Value.Length) { $Value.Substring($Index, $Length) } else { '' }
    $parsed = 0
    if ($digits -match '^[0-9A-Fa-f]+$' -and [int]::TryParse($digits, [System.Globalization.NumberStyles]::HexNumber, [cultureinfo]::InvariantCulture, [ref]$parsed)) {
        if ($parsed -gt 0xFFFF) {
            [void]$Builder.Append([char]::ConvertFromUtf32($parsed))
        }
        else {
            # Cast, not ConvertFromUtf32: a hardened astral character is
            # emitted as two \uXXXX surrogate halves and ConvertFromUtf32
            # rejects a lone surrogate.
            [void]$Builder.Append([char]$parsed)
        }
        return $Index + $Length
    }

    [void]$Builder.Append('\' + $Escape)
    return $Index
}
