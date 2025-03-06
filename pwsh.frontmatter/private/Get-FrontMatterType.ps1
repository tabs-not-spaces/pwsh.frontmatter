function Get-FrontMatterType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    $content = Get-Content -Path $FilePath -Raw
    $type = switch -Regex ($content) {
        '^---'    { 'yaml'; break }
        '^\+\+\+' { 'toml'; break }
        '^{'      { 'json'; break }
        default  { throw 'Front matter type not detected.' }
    }
    Write-Verbose "Front matter type detected: $type"
    return $type
}