function Set-FrontMatter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$FilePath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$FrontMatter,
        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml', 'json')]
        [string]$As
    )

    # Read the entire file content as a single string.
    $content = Get-Content -Path $FilePath -Raw
    if (-not $content) {
        throw "File is empty: $FilePath"
    }

    # Get the first non-empty line by splitting into lines.
    $lines = $content -split "\r?\n"
    $firstNonEmpty = $lines | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1

    # Convert the front matter object to the expected string format.
    $newFrontMatter = switch ($As) {
        'yaml' { ConvertTo-YamlFrontMatter -FrontMatter $FrontMatter }
        'toml' { ConvertTo-TomlFrontMatter -FrontMatter $FrontMatter }
        'json' { ConvertTo-JsonFrontMatter -FrontMatter $FrontMatter }
        default { throw "Invalid output type: $As" }
    }

    # Determine the front matter markers based on the first non-empty line.
    Switch ($firstNonEmpty) {
        '---' { $startMarker = '---'; $endMarker = '---' }
        '+++' { $startMarker = '+++'; $endMarker = '+++' }
        '{'   { $startMarker = '{';  $endMarker = '}' }
        default { throw "Unknown front matter format: $firstNonEmpty" }
    }

    # Build a regex pattern to capture the block from the start marker to the end marker.
    # The (?ms) flags enable multi-line and single-line modes.
    $pattern = "(?ms)^" + [regex]::Escape($startMarker) + ".*?" + [regex]::Escape($endMarker) + "\r?\n?"
    
    if ($content -match $pattern) {
        # Replace the first occurrence of the front matter block with the new front matter.
        $newContent = [regex]::Replace($content, $pattern, $newFrontMatter + "`n", 1)
    }
    else {
        Write-Error 'Unable to locate front matter markers in the file.'
        return
    }

    # Write the updated content back to the file.
    $newContent | Set-Content -Path $FilePath -Encoding utf8 -NoNewline
}