function ConvertFrom-TomlFrontMatter {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$InputFile
    )

    $content = Get-Content -LiteralPath $InputFile.FullName
    $startIndex = $null
    $endIndex = $null

    # Find the first two lines that are exactly '+++'
    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i].Trim() -eq '+++') {
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
    $properties = [System.Collections.Specialized.OrderedDictionary]::new()

    foreach ($line in $frontmatterLines) {
        $line = $line.Trim()
        if ($line -match '^\s*#') { continue }
        $fmLineRegex = '^(?<key>[^=\s]+)\s*=\s*(?<value>.+)$'
        if (-not [string]::IsNullOrWhiteSpace($line) -and $line -match $fmLineRegex) {
            $key = $Matches['key']
            $rawValue = $Matches['value'].Trim()

            # Handle array values (e.g. [ "PowerBI", "Graph", "Intune" ])
            # before unquoting, so an empty array stays an empty array.
            $fmArrayRegex = '^\[(.*)\]$'
            if ($rawValue -match $fmArrayRegex) {
                $inner = $Matches[1].Trim()
                if ([string]::IsNullOrWhiteSpace($inner)) {
                    $value = @()
                }
                else {
                    $value = @($inner -split ',' | ForEach-Object {
                            Convert-FrontMatterValue -Value $_.Trim()
                        })
                }
            }
            else {
                $value = Convert-FrontMatterValue -Value $rawValue
            }
            $properties[$key] = $value
        }
    }
    return [PSCustomObject]$properties
}
