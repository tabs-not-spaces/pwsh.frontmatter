function ConvertFrom-JsonFrontMatter {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$InputFile
    )

    $content = Get-Content -Path $InputFile
    # Use regex to extract a JSON block at the beginning of the input.
    $jsonPattern = '^\s*(\{.*?\})'
    $match = [regex]::Match($Content, $jsonPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        Write-Error 'Unable to locate JSON frontmatter in the file.'
        return
    }

    $jsonBlock = $match.Groups[1].Value

    try {
        $data = $jsonBlock | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to convert JSON frontmatter to PSCustomObject: $_"
        return
    }

    return $data
}