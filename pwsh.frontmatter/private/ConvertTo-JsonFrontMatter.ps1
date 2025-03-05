function ConvertTo-JsonFrontMatter {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FrontMatter
    )

    $json = $FrontMatter | ConvertTo-Json -Depth 100 -EscapeHandling Default
    return $json
}