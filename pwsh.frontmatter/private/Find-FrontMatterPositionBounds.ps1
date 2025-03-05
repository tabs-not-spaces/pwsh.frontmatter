function Find-FrontMatterPositionBounds {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Content,
        [Parameter(Mandatory = $true)]
        [string]$StartMarker,
        [Parameter(Mandatory = $true)]
        [string]$EndMarker
    )
    $startIndex = $null
    $endIndex = $null
    if ($startMarker -eq '{') {
        # For JSON front matter, use a brace counter to find matching closing brace.
        $braceCount = 0
        for ($i = 0; $i -lt $content.Count; $i++) {
            $line = $content[$i].Trim()
            if ($line -eq $startMarker) {
                if ($braceCount -eq 0) { $startIndex = $i }
                $braceCount++
            }
            if ($line -eq $endMarker -and $braceCount -gt 0) {
                $braceCount--
                if ($braceCount -eq 0) {
                    $endIndex = $i
                    break
                }
            }
        }
    }
    else {
        for ($i = 0; $i -lt $content.Count; $i++) {
            if ($content[$i].Trim() -eq $startMarker) {
                if ($null -eq $startIndex) { $startIndex = $i }
                else { $endIndex = $i; break }
            }
        }
    }
    return $startIndex, $endIndex
}