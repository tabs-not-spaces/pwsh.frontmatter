#Requires -Module Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Find-FrontMatterPositionBounds (private)' {

    Context 'Dead code check: is it actually called by the read parsers?' {
        It 'is never invoked by ConvertFrom-YamlFrontMatter' {
            InModuleScope 'pwsh.frontmatter' {
                Mock Find-FrontMatterPositionBounds { }
                $path = Join-Path $TestDrive 'yaml-dead-check.md'
                Set-Content -Path $path -Value "---`ntitle: X`n---`nBody" -NoNewline -Encoding utf8
                ConvertFrom-YamlFrontMatter -InputFile $path | Out-Null
                Should -Invoke Find-FrontMatterPositionBounds -Times 0
            }
        }

        It 'is never invoked by ConvertFrom-TomlFrontMatter' {
            InModuleScope 'pwsh.frontmatter' {
                Mock Find-FrontMatterPositionBounds { }
                $path = Join-Path $TestDrive 'toml-dead-check.md'
                Set-Content -Path $path -Value "+++`ntitle = `"X`"`n+++`nBody" -NoNewline -Encoding utf8
                ConvertFrom-TomlFrontMatter -InputFile $path | Out-Null
                Should -Invoke Find-FrontMatterPositionBounds -Times 0
            }
        }

        It 'is never invoked by ConvertFrom-JsonFrontMatter' {
            InModuleScope 'pwsh.frontmatter' {
                Mock Find-FrontMatterPositionBounds { }
                $path = Join-Path $TestDrive 'json-dead-check.md'
                Set-Content -Path $path -Value "{`n  `"title`": `"X`"`n}`nBody" -NoNewline -Encoding utf8
                ConvertFrom-JsonFrontMatter -InputFile $path | Out-Null
                Should -Invoke Find-FrontMatterPositionBounds -Times 0
            }
        }
    }

    Context 'It is live/reachable and functionally correct for the simple (non-JSON) marker case' {
        It 'finds start and end indexes for a YAML-style marker pair' {
            InModuleScope 'pwsh.frontmatter' {
                $lines = @('---', 'title: x', '---', 'body')
                $bounds = Find-FrontMatterPositionBounds -Content $lines -StartMarker '---' -EndMarker '---'
                $bounds[0] | Should -Be 0
                $bounds[1] | Should -Be 2
            }
        }

        It 'brace-counts a JSON block with no other braces correctly' {
            InModuleScope 'pwsh.frontmatter' {
                $lines = @('{', '  "title": "x"', '}', 'body')
                $bounds = Find-FrontMatterPositionBounds -Content $lines -StartMarker '{' -EndMarker '}'
                $bounds[0] | Should -Be 0
                $bounds[1] | Should -Be 2
            }
        }
    }

    Context 'Its brace counter only recognizes a brace that is ALONE on its trimmed line' -Tag 'KnownBug' {
        It 'FM-006-related: gets the end index WRONG for realistic pretty-printed nested JSON (key and brace share a line)' {
            # Found while writing the initial suite (not a numbered audit finding,
            # but directly relevant to FM-006's fix sketch, which proposes wiring
            # this function in to fix nested-object JSON parsing). This is the
            # shape ConvertTo-JsonFrontMatter/ConvertTo-Json -Depth 100 actually
            # produces: the nested object's opening brace sits on the same line
            # as its key ("meta": {), not alone. The counter's
            # `$line -eq $startMarker` check requires the WHOLE trimmed line to
            # be just "{", so it never sees this open, and returns the INNER
            # closing brace as the end of the block instead of the outer one.
            # This directly contradicts architecture.md's claim that this
            # function is "exactly what JSON needs" for nested objects: as
            # written, it is not. If FM-006 is fixed by wiring this function in,
            # it needs its own character-level brace-counting fix first, or the
            # fix just moves the bug rather than closing it.
            InModuleScope 'pwsh.frontmatter' {
                $lines = @(
                    '{',
                    '  "title": "x",',
                    '  "meta": {',
                    '    "nested": "value",',
                    '    "count": 3',
                    '  }',
                    '}'
                )
                $bounds = Find-FrontMatterPositionBounds -Content $lines -StartMarker '{' -EndMarker '}'
                $bounds[0] | Should -Be 0
                $bounds[1] | Should -Be 6
            }
        }
    }
}
