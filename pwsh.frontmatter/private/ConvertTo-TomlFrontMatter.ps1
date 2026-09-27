function ConvertTo-TomlFrontMatter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FrontMatter
    )

    $tomlLines = @()
    $tomlLines += '+++'
    foreach ($prop in $FrontMatter.PSObject.Properties) {
        $key = $prop.Name
        Assert-FrontMatterKey -Key $key -Format 'toml'
        $value = $prop.Value
        if ($value -is [Array]) {
            $formattedItems = $value | ForEach-Object {
                # Always quote and escape string items, see ConvertTo-FrontMatterScalar.
                if ($_ -is [string]) {
                    ConvertTo-FrontMatterScalar -Value $_ -Format 'toml'
                }
                else {
                    $_
                }
            }
            $formattedArray = '[ ' + ($formattedItems -join ', ') + ' ]'
            $tomlLines += "$key = $formattedArray"
        }
        else {
            if ($value -is [string]) {
                $formattedValue = ConvertTo-FrontMatterScalar -Value $value -Format 'toml'
            }
            else {
                $formattedValue = $value
            }
            $tomlLines += "$key = $formattedValue"
        }
    }
    $tomlLines += '+++'
    return $tomlLines -join "`n"
}
