function ConvertFrom-YamlFrontMatter {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$InputFile
    )
    $content = Get-Content $InputFile
    $startIndex = $null
    $endIndex = $null

    # YAML frontmatter is delimited by '---'
    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i].Trim() -eq '---') {
            if ($null -eq $startIndex) { $startIndex = $i }
            else { $endIndex = $i; break }  
        }
    }

    if ($null -eq $startIndex -or $null -eq $endIndex) {
        Write-Error 'Unable to locate frontmatter markers in the file.'
        return
    }

    # Extract the frontmatter lines (excluding the marker lines)
    $frontmatterLines = $content[($startIndex + 1)..($endIndex - 1)]
    $properties = @{}
    $currentKey = $null
    $inArray = $false
    $arrayValues = @()

    foreach ($line in $frontmatterLines) {
        $trimLine = $line.TrimEnd()
        if ($trimLine -match '^(?<key>[^:]+):\s*(?<value>.*)$') {
            # If we were collecting array items for the previous key, save them.
            if ($inArray -and $null -ne $currentKey) {
                $properties[$currentKey] = $arrayValues
                $arrayValues = @()
                $inArray = $false
            }
            $currentKey = $Matches['key'].Trim()
            $value = $Matches['value'].Trim()
            if ($value -eq "") {
                # No inline value; expect multi-line array items
                $inArray = $true
            }
            else {
                $properties[$currentKey] = Convert-FrontMatterValue $value
            }
        }
        elseif ($inArray -and $trimLine -match '^\s*-\s*(?<item>.+)$') {
            $item = $Matches['item'].Trim()
            $arrayValues += Convert-FrontMatterValue $item
        }
    }

    # If the last key was an array, add it to properties
    if ($inArray -and $null -ne $currentKey) {
        $properties[$currentKey] = $arrayValues
    }

    return [PSCustomObject]$properties
}