$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'public'
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'private'

foreach ($folder in @($publicPath, $privatePath)) {
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        throw "pwsh.frontmatter: required folder not found: $folder"
    }
}

$Public = @(Get-ChildItem -LiteralPath $publicPath -Filter '*.ps1')
$Private = @(Get-ChildItem -LiteralPath $privatePath -Filter '*.ps1')

if ($Public.Count -eq 0) {
    throw "pwsh.frontmatter: no public functions found under $publicPath"
}

foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        throw "Failed to import function $($import.FullName): $_"
    }
}

# Explicit allowlist. build.ps1 also pins FunctionsToExport in the manifest at
# build time; source and artifact must agree, so keep the two lists in sync.
Export-ModuleMember -Function @('Convert-FrontMatter', 'Get-FrontMatter', 'Set-FrontMatter')
