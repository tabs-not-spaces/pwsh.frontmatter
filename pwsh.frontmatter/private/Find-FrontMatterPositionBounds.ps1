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
    $lines = @($Content)
    if ($startMarker -eq '{') {
        # For JSON front matter, brace count over the whole block so a brace
        # that shares a line with its key is still counted, then map the
        # character offsets back to line indexes.
        $joined = $lines -join "`n"
        $openOffset = $joined.IndexOf($StartMarker)
        if ($openOffset -ge 0) {
            $closeOffset = Find-FrontMatterJsonBlockEnd -Content $joined -StartIndex $openOffset
            if ($closeOffset -ge 0 -and $joined[$closeOffset] -eq $EndMarker) {
                $startIndex = ($joined.Substring(0, $openOffset) -split "`n").Count - 1
                $endIndex = ($joined.Substring(0, $closeOffset) -split "`n").Count - 1
            }
        }
    }
    else {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq $startMarker) {
                if ($null -eq $startIndex) { $startIndex = $i }
                else { $endIndex = $i; break }
            }
        }
    }
    return $startIndex, $endIndex
}
