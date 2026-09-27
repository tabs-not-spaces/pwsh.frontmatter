function ConvertTo-YamlFrontMatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FrontMatter
    )

    $yamlLines = @()
    $yamlLines += '---'
    foreach ($prop in $FrontMatter.PSObject.Properties) {
        $key = $prop.Name
        Assert-FrontMatterKey -Key $key -Format 'yaml'
        $value = $prop.Value
        if ($value -is [Array] -and $value.Count -eq 0) {
            # Flow style, so an empty array is not confused with an empty
            # string on the way back in.
            $yamlLines += "$key`: []"
        }
        elseif ($value -is [Array]) {
            $yamlLines += "$key`:"
            foreach ($item in $value) {
                # Always quote and escape string items so no value can break
                # out of its own line and forge keys or close the block.
                if ($item -is [string]) {
                    $formattedItem = ConvertTo-FrontMatterScalar -Value $item -Format 'yaml'
                }
                else {
                    $formattedItem = $item
                }
                $yamlLines += "  - $formattedItem"
            }
        }
        else {
            if ($value -is [string]) {
                $formattedValue = ConvertTo-FrontMatterScalar -Value $value -Format 'yaml'
            }
            else {
                $formattedValue = $value
            }
            $yamlLines += "$key`: $formattedValue"
        }
    }
    $yamlLines += '---'
    return $yamlLines -join "`n"
}
