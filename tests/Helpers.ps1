# Shared helpers for the pwsh.frontmatter Pester suite.
# Not a *.Tests.ps1 file on purpose: Pester discovery ignores it, each test
# file dot-sources it explicitly from BeforeAll.
# ASCII only. Unicode test content is built with `u{XXXX} escapes, not
# literal characters, so this file stays PSScriptAnalyzer clean.

function Get-FrontMatterModuleManifestPath {
    (Resolve-Path (Join-Path $PSScriptRoot '../pwsh.frontmatter/pwsh.frontmatter.psd1')).Path
}

function Import-FrontMatterModuleFresh {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
    Import-Module -Name (Get-FrontMatterModuleManifestPath) -Force -ErrorAction Stop
}

function New-FrontMatterTestFile {
    <#
        Writes a markdown file with a given marker pair already present, so
        Set-FrontMatter can detect the existing format from the first
        non-empty line, plus a body. Returns the file path.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml', 'json')]
        [string]$Format,
        [Parameter(Mandatory = $true)]
        [string]$Body,
        [string]$InitialFrontMatterBody = ''
    )
    $markers = switch ($Format) {
        'yaml' { @('---', '---') }
        'toml' { @('+++', '+++') }
        'json' { @('{', '}') }
    }
    $lines = @($markers[0])
    if ($InitialFrontMatterBody) { $lines += $InitialFrontMatterBody }
    $lines += $markers[1]
    $content = ($lines -join "`n") + "`n" + $Body
    Set-Content -Path $Path -Value $content -NoNewline -Encoding utf8
    return $Path
}

# A unicode sample string built entirely from escapes: accented latin,
# CJK, and an emoji (surrogate pair), so no raw non-ASCII bytes live in
# this .ps1 file.
function Get-UnicodeSample {
    "h`u{00e9}llo w`u{00f6}rld `u{65e5}`u{672c}`u{8a9e} `u{1F389}"
}
