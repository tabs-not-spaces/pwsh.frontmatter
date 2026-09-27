function Set-FrontMatter {
    <#
    .SYNOPSIS
        Rewrites the front matter block of a markdown file in place.

    .DESCRIPTION
        Set-FrontMatter replaces the existing front matter block in a markdown
        file with the object you supply, rendered in the format you ask for. The
        body of the document is left untouched. Because the input format and the
        output format are independent, this is also how you convert a file from
        one front matter format to another.

        The existing block must start on the first non-empty line of the file.
        Set-FrontMatter infers the current markers from that line, finds the
        matching end marker, and splices the new block over the old byte range. A
        thematic break or a brace further down the body is never mistaken for
        front matter.

        The write is careful about the rest of the file. The original byte order
        mark is detected and reapplied, the dominant line ending is preserved, and
        the new content is written to a temporary file and then moved over the
        original, so an interrupted write cannot leave a half rewritten document.

        Set-FrontMatter supports ShouldProcess, so -WhatIf shows what it would
        rewrite without touching the file and -Confirm prompts before each write.
        ConfirmImpact is Medium.

        On success the function writes nothing to the pipeline. If the markers
        cannot be located it calls Write-Error and returns, so use
        -ErrorAction Stop if you need a missing block to be fatal.

        This module requires PowerShell 7.0 or later.

    .PARAMETER FilePath
        Path to one markdown file to rewrite. The file must already exist and
        must have a .md extension. Other markdown extensions such as .markdown
        and .mdx are rejected.

        The wildcard metacharacters '*' and '?' are rejected, so pass a single
        literal file path. This is deliberate. An earlier version expanded a
        wildcard and overwrote every matching file with the same block. Only one
        literal path is accepted now. Square brackets in a file name are fine,
        because the file is opened with -LiteralPath.

    .PARAMETER FrontMatter
        The front matter object to write. Accepts pipeline input. Every object
        you pipe in is processed, and each one rewrites the file in turn, so the
        last object piped in is the one left on disk.

    .PARAMETER As
        The format to write. Valid values are 'yaml', 'toml' and 'json'.

        This does not have to match the format already in the file. Set a
        different value to convert the file.

    .EXAMPLE
        PS> $frontMatter = Get-FrontMatter -FilePath ./post.md
        PS> $frontMatter.title = 'Renamed post'
        PS> Set-FrontMatter -FilePath ./post.md -FrontMatter $frontMatter -As yaml
        PS> Get-Content ./post.md -Raw

        ---
        title: Renamed post
        draft: false
        ---

        # Heading

        Reads a block, edits one key, and writes it back in the same format.

    .EXAMPLE
        PS> $frontMatter = Get-FrontMatter -FilePath ./post.md
        PS> $frontMatter | Set-FrontMatter -FilePath ./post.md -As toml
        PS> Get-Content ./post.md -Raw

        +++
        title = "Renamed post"
        draft = "false"
        +++

        # Heading

        Converts the same file from yaml to toml. The body is unchanged.

    .EXAMPLE
        PS> Set-FrontMatter -FilePath ./post.md -FrontMatter $frontMatter -As json -WhatIf

        What if: Performing the operation "Rewrite front matter" on target
        "/Users/you/posts/post.md".

        Shows the file that would be rewritten and leaves it alone. Drop -WhatIf
        to apply the change, or use -Confirm to be prompted first.

    .INPUTS
        System.Management.Automation.PSCustomObject

        Objects piped to Set-FrontMatter bind to the FrontMatter parameter.

    .OUTPUTS
        None. Set-FrontMatter writes to the file and returns nothing.

    .NOTES
        Module: pwsh.frontmatter
        Requires: PowerShell 7.0 or later

        Set-FrontMatter rewrites the file in place and keeps no backup. Commit
        your work or run with -WhatIf first when you are unsure.

    .LINK
        Get-FrontMatter

    .LINK
        Convert-FrontMatter
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if ($_ -match '[\*\?]') { throw "Wildcards are not allowed in -FilePath: $_" }
                if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) { throw "Not a file: $_" }
                if ($_ -notmatch '\.md$') { throw "Not a markdown file: $_" }
                $true
            })]
        [string]$FilePath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$FrontMatter,
        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml', 'json')]
        [string]$As
    )

    begin {
        $resolvedPath = (Resolve-Path -LiteralPath $FilePath).ProviderPath
    }

    process {
        # Read the entire file content as a single string.
        $content = Get-Content -LiteralPath $resolvedPath -Raw
        if (-not $content) {
            throw "File is empty: $resolvedPath"
        }

        # Keep each line's terminator so the body can be spliced back untouched.
        $rawLines = @($content -split "(?<=\n)")
        $lines = @($rawLines | ForEach-Object { $_ -replace "\r?\n$", '' })

        $firstNonEmptyIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -ne '') { $firstNonEmptyIndex = $i; break }
        }
        if ($firstNonEmptyIndex -lt 0) {
            throw "File is empty: $resolvedPath"
        }
        $firstNonEmpty = $lines[$firstNonEmptyIndex].Trim()

        # Convert the front matter object to the expected string format.
        $newFrontMatter = switch ($As) {
            'yaml' { ConvertTo-YamlFrontMatter -FrontMatter $FrontMatter }
            'toml' { ConvertTo-TomlFrontMatter -FrontMatter $FrontMatter }
            'json' { ConvertTo-JsonFrontMatter -FrontMatter $FrontMatter }
            default { throw "Invalid output type: $As" }
        }

        # Determine the front matter markers based on the first non-empty line.
        # Prefix matching, same as Get-FrontMatterType, so single line JSON and
        # a marker line with trailing whitespace both round trip.
        Switch -Regex ($firstNonEmpty) {
            '^---$' { $startMarker = '---'; $endMarker = '---'; break }
            '^\+\+\+$' { $startMarker = '+++'; $endMarker = '+++'; break }
            '^\{' { $startMarker = '{'; $endMarker = '}'; break }
            default { throw "Unknown front matter format: $firstNonEmpty" }
        }

        $startLine, $endLine = Find-FrontMatterPositionBounds -Content $lines -StartMarker $startMarker -EndMarker $endMarker
        # Only ever touch a block that starts on the first non-empty line, so a
        # thematic break further down the body is never mistaken for front matter.
        if ($null -eq $startLine -or $null -eq $endLine -or $startLine -ne $firstNonEmptyIndex) {
            Write-Error 'Unable to locate front matter markers in the file.'
            return
        }

        $blockStart = 0
        for ($i = 0; $i -lt $startLine; $i++) { $blockStart += $rawLines[$i].Length }
        $blockLength = 0
        for ($i = $startLine; $i -le $endLine; $i++) { $blockLength += $rawLines[$i].Length }

        # Preserve the file's dominant line ending and its trailing break.
        $newLine = if ($content -match "`r`n") { "`r`n" } else { "`n" }
        $blockTail = if ($rawLines[$endLine] -match "\r?\n$") { $newLine } else { '' }
        $normalized = ($newFrontMatter -replace "`r`n", "`n") -replace "`n", $newLine

        # Splice literally: a regex replacement string would expand $&, $1 and
        # friends out of an untrusted front matter value.
        $newContent = $content.Remove($blockStart, $blockLength).Insert($blockStart, $normalized + $blockTail)

        if ($PSCmdlet.ShouldProcess($resolvedPath, 'Rewrite front matter')) {
            # Preserve the original BOM state and write via a temp file so an
            # interrupted write cannot leave a half rewritten document.
            $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $encoding = [System.Text.UTF8Encoding]::new($hasBom)
            $tempPath = "$resolvedPath.tmp"
            [System.IO.File]::WriteAllText($tempPath, $newContent, $encoding)
            # Move with overwrite is a rename, so the swap is atomic.
            [System.IO.File]::Move($tempPath, $resolvedPath, $true)
        }
    }
}
