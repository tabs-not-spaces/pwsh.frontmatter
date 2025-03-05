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
        $value = $prop.Value
        if ($value -is [Array]) {
            $yamlLines += "$key`:"
            foreach ($item in $value) {
                # Wrap string items in quotes and escape any embedded quotes
                if ($item -is [string]) {
                    $formattedItem = '"' + $item.Replace('"', '\"') + '"'
                }
                else {
                    $formattedItem = $item
                }
                $yamlLines += "  - $formattedItem"
            }
        }
        else {
            if ($value -is [string]) {
                # If the string contains special characters or spaces, wrap in quotes
                if ($value -match '[:\s]') {
                    $formattedValue = '"' + $value.Replace('"', '\"') + '"'
                }
                else {
                    $formattedValue = $value
                }
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