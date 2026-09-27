#Requires -Module Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Set-FrontMatter' {

    It 'adds front matter to a file that has none, <Format>' -ForEach @(
        @{ Format = 'yaml' }
        @{ Format = 'toml' }
        @{ Format = 'json' }
    ) {
        # Set-FrontMatter detects existing markers from the first non-empty
        # line, so a file with genuinely NO front matter must already start
        # with the target marker line for it to find something to replace.
        # This documents the actual contract: it replaces, it does not
        # append/insert markers into a marker-free file. See KnownBugs for
        # the "no existing markers" failure case.
        $path = Join-Path $TestDrive "add-fm-$Format.md"
        New-FrontMatterTestFile -Path $path -Format $Format -Body "# Heading`nBody content.`n"
        $fm = [PSCustomObject]@{ title = 'Added' }
        Set-FrontMatter -FilePath $path -FrontMatter $fm -As $Format
        (Get-FrontMatter -FilePath $path).title | Should -Be 'Added'
    }

    It 'throws when the file truly has no marker line to replace' {
        $path = Join-Path $TestDrive 'truly-no-markers.md'
        Set-Content -Path $path -Value "# Heading`nJust prose, no marker line." -NoNewline -Encoding utf8
        $fm = [PSCustomObject]@{ title = 'X' }
        { Set-FrontMatter -FilePath $path -FrontMatter $fm -As 'yaml' -ErrorAction Stop } | Should -Throw
    }

    It 'replaces existing front matter with new values, <Format>' -ForEach @(
        @{ Format = 'yaml' }
        @{ Format = 'toml' }
        @{ Format = 'json' }
    ) {
        $path = Join-Path $TestDrive "replace-fm-$Format.md"
        New-FrontMatterTestFile -Path $path -Format $Format -Body "Body content.`n"
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'Original' }) -As $Format
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'Replaced' }) -As $Format
        (Get-FrontMatter -FilePath $path).title | Should -Be 'Replaced'
    }

    It 'preserves the body content byte for byte, <Format>' -ForEach @(
        @{ Format = 'yaml' }
        @{ Format = 'toml' }
        @{ Format = 'json' }
    ) {
        $path = Join-Path $TestDrive "preserve-body-$Format.md"
        $body = "# A Heading`n`nSome paragraph with *emphasis* and a [link](http://example.com).`n`n- list item one`n- list item two`n"
        New-FrontMatterTestFile -Path $path -Format $Format -Body $body
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'X' }) -As $Format
        $fileContent = Get-Content -Path $path -Raw
        $fileContent.EndsWith($body) | Should -BeTrue
    }

    It 'writes without a byte order mark' {
        $path = Join-Path $TestDrive 'no-bom-write.md'
        New-FrontMatterTestFile -Path $path -Format 'yaml' -Body 'Body'
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'X' }) -As 'yaml'
        $bytes = [System.IO.File]::ReadAllBytes($path)
        # UTF-8 BOM is EF BB BF
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $hasBom | Should -BeFalse
    }

    It 'does not append a trailing newline beyond what NoNewline implies' {
        $path = Join-Path $TestDrive 'no-newline-write.md'
        New-FrontMatterTestFile -Path $path -Format 'yaml' -Body 'Body, no trailing newline'
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'X' }) -As 'yaml'
        $raw = Get-Content -Path $path -Raw
        $raw.EndsWith("Body, no trailing newline") | Should -BeTrue
    }
}
