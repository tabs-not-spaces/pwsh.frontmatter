function ConvertFrom-YamlFrontMatter {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$InputFile
    )
    $content = Get-Content -LiteralPath $InputFile.FullName
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
    # Ordered so key order survives a read, unlike a plain hashtable.
    $properties = [System.Collections.Specialized.OrderedDictionary]::new()
    $currentKey = $null
    $inArray = $false
    $arrayValues = @()

    foreach ($line in $frontmatterLines) {
        $trimLine = $line.TrimEnd()
        # Comments are not data, and a nested key is not a top level key:
        # promoting an indented key would let 'author: {role: admin}' become a
        # top level 'role'.
        if ($trimLine -match '^\s*#') { continue }
        if ($trimLine -match '^\s+\S' -and $trimLine -notmatch '^\s*-\s') { continue }
        if ($trimLine -match '^(?<key>[^:]+):\s*(?<value>.*)$') {
            # If we were collecting array items for the previous key, save them.
            if ($inArray -and $null -ne $currentKey -and $arrayValues.Count -gt 0) {
                $properties[$currentKey] = $arrayValues
            }
            $arrayValues = @()
            $inArray = $false
            $currentKey = $Matches['key'].Trim()
            $value = $Matches['value'].Trim()
            if ($value -eq "") {
                # A bare key is an empty value until block array items show up.
                $inArray = $true
                $properties[$currentKey] = ''
            }
            elseif ($value -match '^\[(.*)\]$') {
                $inner = $Matches[1].Trim()
                if ([string]::IsNullOrWhiteSpace($inner)) {
                    $properties[$currentKey] = @()
                }
                else {
                    $properties[$currentKey] = @($inner -split ',' | ForEach-Object {
                            Convert-FrontMatterValue -Value $_.Trim()
                        })
                }
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
    if ($inArray -and $null -ne $currentKey -and $arrayValues.Count -gt 0) {
        $properties[$currentKey] = $arrayValues
    }

    return [PSCustomObject]$properties
}
