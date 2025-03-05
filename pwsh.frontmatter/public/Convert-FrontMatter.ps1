function Convert-FrontMatter {
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$FrontMatter,

        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml', 'json')]
        [String]$OutputType
    )

    $output = switch ($OutputType) {
        'yaml' { ConvertTo-YamlFrontMatter -FrontMatter $FrontMatter }
        'toml' { ConvertTo-TomlFrontMatter -FrontMatter $FrontMatter }
        'json' { ConvertTo-JsonFrontMatter -FrontMatter $FrontMatter }
        default { throw "Invalid output type: $OutputType" }
    }
    return $output
}