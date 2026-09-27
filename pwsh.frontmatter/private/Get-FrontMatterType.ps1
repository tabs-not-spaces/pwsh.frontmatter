function Get-FrontMatterType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    $content = Get-Content -LiteralPath $FilePath -Raw
    # An empty file returns $null, and switch enumerates $null as zero items,
    # so the default arm would never run without this check.
    if ([string]::IsNullOrEmpty($content)) {
        throw 'Front matter type not detected.'
    }
    $type = switch -Regex ($content) {
        '^---'    { 'yaml'; break }
        '^\+\+\+' { 'toml'; break }
        '^{'      { 'json'; break }
        default  { throw 'Front matter type not detected.' }
    }
    Write-Verbose "Front matter type detected: $type"
    return $type
}
