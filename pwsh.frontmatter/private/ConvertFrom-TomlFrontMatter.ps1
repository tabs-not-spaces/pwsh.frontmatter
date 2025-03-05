function ConvertFrom-TomlFrontMatter {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$InputFile
    )
    
    $content = Get-Content $InputFile
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
    $properties = @{}

    foreach ($line in $frontmatterLines) {
        $line = $line.Trim()
        $fmLineRegex = '^(?<key>[^=\s]+)\s*=\s*(?<value>.+)$'
        if (-not [string]::IsNullOrWhiteSpace($line) -and $line -match $fmLineRegex) {
            $key = $Matches['key']
            $value = $Matches['value'].Trim()

            # Remove quotes if present
            $value = Convert-FrontMatterValue -Value $value
            
            # Handle array values (e.g. [ "PowerBI", "Graph", "Intune" ])
            $fmArrayRegex = '^\[(.*)\]$'
            if ($value -match $fmArrayRegex) {
                $inner = $Matches[1]
                $value = $inner -split ',' | ForEach-Object {
                    Convert-FrontMatterValue -Value $_.trim()
                }
            }
            # Try converting to an integer if applicable
            elseif ($value -as [int] -and $value -match '^\d+$') {
                $value = [int]$value
            }
            $properties[$key] = $value
        }
    }
    return [PSCustomObject]$properties
}