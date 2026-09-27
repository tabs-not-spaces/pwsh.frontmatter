function ConvertFrom-JsonFrontMatter {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$InputFile
    )

    # -Raw keeps the real line structure; without it the content arrives as a
    # string array that gets space joined before anything can parse it.
    $content = Get-Content -LiteralPath $InputFile.FullName -Raw
    $openIndex = if ($content) { $content.IndexOf('{') } else { -1 }
    $closeIndex = if ($openIndex -ge 0) { Find-FrontMatterJsonBlockEnd -Content $content -StartIndex $openIndex } else { -1 }
    if ($openIndex -lt 0 -or $closeIndex -lt 0) {
        Write-Error 'Unable to locate JSON frontmatter in the file.'
        return
    }

    $jsonBlock = $content.Substring($openIndex, ($closeIndex - $openIndex + 1))

    try {
        $data = $jsonBlock | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to convert JSON frontmatter to PSCustomObject: $_"
        return
    }

    return $data
}
