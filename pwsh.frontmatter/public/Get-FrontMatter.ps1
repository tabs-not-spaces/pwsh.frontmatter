function Get-FrontMatter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # detect if the frontmatter is yaml, toml, or json - write a private function to do this
    $frontMatterType = Get-FrontMatterType -FilePath $FilePath
    
    # read the frontmatter
    $frontMatter = ConvertFrom-FrontMatter -FilePath $FilePath -FrontMatterType $frontMatterType
    
    return $frontMatter
}