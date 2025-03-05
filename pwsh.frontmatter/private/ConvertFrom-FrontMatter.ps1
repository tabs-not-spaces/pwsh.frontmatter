function ConvertFrom-FrontMatter {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [ValidateScript({ $_ -match '\.md$'})]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml', 'json')]
        [string]$FrontMatterType
    )

    $frontMatter = switch ($FrontMatterType) {
        'yaml' { ConvertFrom-YamlFrontMatter -InputFile $FilePath }
        'toml' { ConvertFrom-TomlFrontMatter -InputFile $FilePath }
        'json' { ConvertFrom-JsonFrontMatter -InputFile $FilePath }
    }

    return $frontMatter
}