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
        $value = $prop.Value
        if ($value -is [Array]) {
            $formattedItems = $value | ForEach-Object {
                if ($_ -is [string]) {
                    '"' + ($_ -replace '"', '\"') + '"'
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
                $formattedValue = '"' + ($value -replace '"', '\"') + '"'
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