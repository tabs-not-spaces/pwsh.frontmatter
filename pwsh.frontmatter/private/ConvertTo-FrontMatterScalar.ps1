function ConvertTo-FrontMatterScalar {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml')]
        [string]$Format
    )

    # YAML plain scalars stay unquoted when they cannot be misread: no
    # indicator character at the start, no ': ' or '#', no line break, no
    # trailing space, and nothing that would come back as an integer.
    if ($Format -eq 'yaml' -and
        $Value -match '^[A-Za-z0-9][^:#\r\n\t]*$' -and
        $Value -notmatch '\s$' -and
        $Value -notmatch '^(0|-?[1-9]\d*)$') {
        return $Value
    }

    # Values that carry a line break can forge new keys or close the block
    # early once they are written out, so those get hardened: every character
    # that is not alphanumeric is emitted as a numeric escape. Ordinary values
    # only need the structural escapes.
    $harden = $Value -match "[`r`n]"
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append('"')

    foreach ($char in $Value.ToCharArray()) {
        $code = [int]$char
        if ($char -eq '\') {
            [void]$builder.Append('\\')
        }
        elseif ($char -eq '"') {
            [void]$builder.Append('\"')
        }
        elseif (-not $harden -and $char -eq "`r") {
            [void]$builder.Append('\r')
        }
        elseif (-not $harden -and $char -eq "`n") {
            [void]$builder.Append('\n')
        }
        elseif (-not $harden -and $char -eq "`t") {
            [void]$builder.Append('\t')
        }
        elseif ($code -lt 0x20 -or ($harden -and $char -notmatch '^[A-Za-z0-9]$')) {
            if ($code -lt 0x100 -and $Format -eq 'yaml') {
                [void]$builder.Append('\x' + $code.ToString('x2'))
            }
            else {
                [void]$builder.Append('\u' + $code.ToString('x4'))
            }
        }
        else {
            [void]$builder.Append($char)
        }
    }

    [void]$builder.Append('"')
    return $builder.ToString()
}
