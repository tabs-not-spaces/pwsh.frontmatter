#Requires -Module Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Get-FrontMatter' {

    It 'reads a file that has front matter, <Format>' -ForEach @(
        @{ Format = 'yaml' }
        @{ Format = 'toml' }
        @{ Format = 'json' }
    ) {
        $path = Join-Path $TestDrive "has-fm-$Format.md"
        New-FrontMatterTestFile -Path $path -Format $Format -Body "# Heading`nBody text.`n"
        $initial = [PSCustomObject]@{ title = 'Has Front Matter' }
        Set-FrontMatter -FilePath $path -FrontMatter $initial -As $Format
        (Get-FrontMatter -FilePath $path).title | Should -Be 'Has Front Matter'
    }

    It 'throws for a file with no front matter markers' {
        $path = Join-Path $TestDrive 'no-fm.md'
        Set-Content -Path $path -Value "# Just a heading`nSome text, no markers." -NoNewline -Encoding utf8
        { Get-FrontMatter -FilePath $path } | Should -Throw
    }

    It 'throws for a completely empty file' {
        $path = Join-Path $TestDrive 'empty.md'
        Set-Content -Path $path -Value '' -NoNewline -Encoding utf8
        { Get-FrontMatter -FilePath $path } | Should -Throw
    }

    It 'parses a file that is front matter only, with no body' {
        $path = Join-Path $TestDrive 'fm-only.md'
        Set-Content -Path $path -Value "---`ntitle: OnlyFrontMatter`n---" -NoNewline -Encoding utf8
        (Get-FrontMatter -FilePath $path).title | Should -Be 'OnlyFrontMatter'
    }

    It 'is not confused by a YAML-style delimiter line appearing later in the body' {
        # The parser scans for the SECOND '---' line and stops (breaks) there, so
        # a horizontal rule further down in the body must not be mistaken for the
        # closing marker as long as it comes after the true close.
        $path = Join-Path $TestDrive 'delimiter-in-body.md'
        $content = @'
---
title: Test
---
Some body text.

---

More text after a horizontal rule.
'@
        Set-Content -Path $path -Value $content -NoNewline -Encoding utf8
        $result = Get-FrontMatter -FilePath $path
        $result.title | Should -Be 'Test'
    }

    It 'is not confused by a brace character appearing later in the body, JSON' {
        $path = Join-Path $TestDrive 'json-delimiter-in-body.md'
        $content = @'
{
  "title": "Test"
}
Some body text with a stray brace: }
And another: {
'@
        Set-Content -Path $path -Value $content -NoNewline -Encoding utf8
        $result = Get-FrontMatter -FilePath $path
        $result.title | Should -Be 'Test'
    }

    Context 'Line endings' {
        It 'reads a file with CRLF line endings' {
            $path = Join-Path $TestDrive 'crlf.md'
            [System.IO.File]::WriteAllText($path, "---`r`ntitle: CRLFTest`r`n---`r`nBody`r`n")
            (Get-FrontMatter -FilePath $path).title | Should -Be 'CRLFTest'
        }

        It 'reads a file with LF line endings' {
            $path = Join-Path $TestDrive 'lf.md'
            [System.IO.File]::WriteAllText($path, "---`ntitle: LFTest`n---`nBody`n")
            (Get-FrontMatter -FilePath $path).title | Should -Be 'LFTest'
        }
    }

    Context 'Byte order mark' {
        It 'reads a file that has a UTF-8 BOM' {
            $path = Join-Path $TestDrive 'bom.md'
            $utf8Bom = New-Object System.Text.UTF8Encoding($true)
            [System.IO.File]::WriteAllText($path, "---`ntitle: BomTest`n---`nBody`n", $utf8Bom)
            (Get-FrontMatter -FilePath $path).title | Should -Be 'BomTest'
        }

        It 'reads a file that has no BOM' {
            $path = Join-Path $TestDrive 'no-bom.md'
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($path, "---`ntitle: NoBomTest`n---`nBody`n", $utf8NoBom)
            (Get-FrontMatter -FilePath $path).title | Should -Be 'NoBomTest'
        }
    }

    Context 'File extension validation' {
        It 'rejects a non-.md extension even with valid front matter content' {
            $path = Join-Path $TestDrive 'not-markdown.txt'
            Set-Content -Path $path -Value "---`ntitle: X`n---`nBody" -NoNewline -Encoding utf8
            { Get-FrontMatter -FilePath $path } | Should -Throw
        }
    }
}
