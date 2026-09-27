function Convert-FrontMatter {
    <#
    .SYNOPSIS
        Renders a front matter object as a yaml, toml or json block.

    .DESCRIPTION
        Convert-FrontMatter takes a PSCustomObject, usually one returned by
        Get-FrontMatter, and returns the matching front matter block as a string.
        The returned string includes the delimiters for the format you ask for:
        '---' for yaml, '+++' for toml and the surrounding braces for json.

        Nothing is written to disk. Use Set-FrontMatter to rewrite a file in
        place.

        Conversion is lossy in both directions. Comments, multi-line strings and
        nested structures in yaml and toml are not carried across, because the
        parsers do not read them in the first place. Values that contain a line
        break are emitted as numeric character escapes so they cannot forge a key
        or close the block early.

        This module requires PowerShell 7.0 or later.

    .PARAMETER FrontMatter
        The front matter object to render. Accepts pipeline input. Every object
        you pipe in is converted and produces its own string.

    .PARAMETER OutputType
        The format to render. Valid values are 'yaml', 'toml' and 'json'.

        yaml and toml are emitted as flat key/value lines, so nested objects are
        not supported. Arrays are supported in all three formats. toml always
        quotes string values; yaml quotes only when the value would otherwise be
        ambiguous.

    .EXAMPLE
        PS> $frontMatter = Get-FrontMatter -FilePath ./post.md
        PS> Convert-FrontMatter -FrontMatter $frontMatter -OutputType toml

        +++
        title = "My first post"
        draft = "false"
        views = 42
        tags = [ "powershell", "markdown" ]
        +++

        Reads a yaml block and renders the same data as toml.

    .EXAMPLE
        PS> $frontMatter | Convert-FrontMatter -OutputType json

        {
          "title": "My first post",
          "draft": "false",
          "views": 42,
          "tags": [
            "powershell",
            "markdown"
          ]
        }

        Pipes the object in instead of binding it by name. json is the only
        format that round trips nested objects.

    .EXAMPLE
        PS> [PSCustomObject]@{ title = 'Draft'; tags = @() } |
        >>     Convert-FrontMatter -OutputType yaml

        ---
        title: Draft
        tags: []
        ---

        Builds an object by hand. An empty array is written in flow style so the
        parser does not read it back as an empty string.

    .INPUTS
        System.Management.Automation.PSCustomObject

        Objects piped to Convert-FrontMatter bind to the FrontMatter parameter.

    .OUTPUTS
        System.String

        One block of front matter text per input object, delimiters included.

    .NOTES
        Module: pwsh.frontmatter
        Requires: PowerShell 7.0 or later

    .LINK
        Get-FrontMatter

    .LINK
        Set-FrontMatter
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$FrontMatter,

        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml', 'json')]
        [String]$OutputType
    )

    process {
        $output = switch ($OutputType) {
            'yaml' { ConvertTo-YamlFrontMatter -FrontMatter $FrontMatter }
            'toml' { ConvertTo-TomlFrontMatter -FrontMatter $FrontMatter }
            'json' { ConvertTo-JsonFrontMatter -FrontMatter $FrontMatter }
            default { throw "Invalid output type: $OutputType" }
        }
        return $output
    }
}
