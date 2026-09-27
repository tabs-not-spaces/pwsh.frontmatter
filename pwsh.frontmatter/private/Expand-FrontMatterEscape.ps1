function Expand-FrontMatterEscape {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    # Reverses ConvertTo-FrontMatterScalar. Unknown escapes are kept verbatim
    # so a stray backslash in hand written front matter survives a read.
    $builder = [System.Text.StringBuilder]::new()
    $i = 0
    while ($i -lt $Value.Length) {
        $char = $Value[$i]
        if ($char -ne '\' -or $i -eq ($Value.Length - 1)) {
            [void]$builder.Append($char)
            $i++
            continue
        }

        $next = $Value[$i + 1]
        $i += 2
        # Case sensitive: \u and \U are different escapes, and a case
        # insensitive switch would run both clauses for one of them.
        switch -CaseSensitive ($next) {
            '\' { [void]$builder.Append('\') }
            '"' { [void]$builder.Append('"') }
            '/' { [void]$builder.Append('/') }
            '0' { [void]$builder.Append([char]0) }
            'b' { [void]$builder.Append([char]8) }
            't' { [void]$builder.Append("`t") }
            'n' { [void]$builder.Append("`n") }
            'f' { [void]$builder.Append([char]12) }
            'r' { [void]$builder.Append("`r") }
            'x' { $i = Add-FrontMatterCodePoint -Builder $builder -Value $Value -Index $i -Length 2 -Escape 'x' }
            'u' { $i = Add-FrontMatterCodePoint -Builder $builder -Value $Value -Index $i -Length 4 -Escape 'u' }
            'U' { $i = Add-FrontMatterCodePoint -Builder $builder -Value $Value -Index $i -Length 8 -Escape 'U' }
            default { [void]$builder.Append('\' + $next) }
        }
    }

    return $builder.ToString()
}
