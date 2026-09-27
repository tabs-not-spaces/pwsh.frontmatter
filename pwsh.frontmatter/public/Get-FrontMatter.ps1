function Get-FrontMatter {
    <#
    .SYNOPSIS
        Reads the front matter block from a markdown file.

    .DESCRIPTION
        Get-FrontMatter detects which front matter format a markdown file uses,
        parses the block, and returns it as a PSCustomObject. Detection reads the
        first line of the file: '---' means yaml, '+++' means toml and '{' means
        json. If none of those markers is present, the function throws.

        Values are typed conservatively. A whole number becomes an [int]; every
        other scalar stays a [string]. Booleans, dates and floating point numbers
        are returned as strings. Quote a value in the source file to keep it a
        string.

        Parsing is line based. Nested mappings in yaml and toml are not supported
        and are not returned. Comments in a yaml block are skipped. Key order is
        preserved, but property lookup on the returned object is case insensitive,
        so two keys that differ only by case collide.

        This module requires PowerShell 7.0 or later.

    .PARAMETER FilePath
        Path to one markdown file to read. The file must already exist.

        The wildcard metacharacters '*' and '?' are rejected, so pass a single
        literal file path. The file is read with -LiteralPath, which means square
        brackets in a file name are treated as ordinary characters rather than as
        a character class.

    .EXAMPLE
        PS> Get-FrontMatter -FilePath ./post.md

        title : My first post
        draft : false
        views : 42
        tags  : {powershell, markdown}

        Reads the yaml block at the top of post.md and returns it as an object.

    .EXAMPLE
        PS> $frontMatter = Get-FrontMatter -FilePath ./post.md
        PS> $frontMatter.views.GetType().Name
        Int32
        PS> $frontMatter.draft.GetType().Name
        String

        Shows the typing rule. The whole number 42 comes back as an [int], while
        the boolean-looking value 'false' comes back as a [string].

    .EXAMPLE
        PS> Get-ChildItem ./posts -Filter *.md |
        >>     ForEach-Object { Get-FrontMatter -FilePath $_.FullName } |
        >>     Where-Object { $_.draft -eq 'true' } |
        >>     Select-Object title

        title
        -----
        Work in progress

        Reads every post in a folder and lists the drafts. Get-FrontMatter takes
        no pipeline input, so bind each path with ForEach-Object.

    .INPUTS
        None. Get-FrontMatter does not accept pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        One object whose properties are the front matter keys. Nothing is written
        to the pipeline if the block cannot be parsed.

    .NOTES
        Module: pwsh.frontmatter
        Requires: PowerShell 7.0 or later

        Get-FrontMatter only reads. Use Set-FrontMatter to write a block back to a
        file, or Convert-FrontMatter to render one as a string.

    .LINK
        Set-FrontMatter

    .LINK
        Convert-FrontMatter
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if ($_ -match '[\*\?]') { throw "Wildcards are not allowed in -FilePath: $_" }
                if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) { throw "Not a file: $_" }
                $true
            })]
        [string]$FilePath
    )

    # Resolve once so every downstream read works on a literal absolute path.
    $resolvedPath = (Resolve-Path -LiteralPath $FilePath).ProviderPath

    # detect if the frontmatter is yaml, toml, or json - write a private function to do this
    $frontMatterType = Get-FrontMatterType -FilePath $resolvedPath

    # read the frontmatter
    $frontMatter = ConvertFrom-FrontMatter -FilePath $resolvedPath -FrontMatterType $frontMatterType

    return $frontMatter
}
