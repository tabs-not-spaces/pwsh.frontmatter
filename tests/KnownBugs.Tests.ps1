#Requires -Module Pester
<#
    Regression tests for known bugs in pwsh.frontmatter: the JSON parsing bugs
    found while writing the initial test suite, plus everything from the
    2026-09-27 security audit (.agents/notes/security-audit-2026-09-27.md)
    that maps to Convert-FrontMatterValue / the read parsers. Audit findings
    about Set-FrontMatter itself (FM-001, FM-002, FM-004, FM-005, FM-009,
    FM-010, FM-013) live in SecurityAudit.Tests.ps1.

    All tests here are tagged 'KnownBug'. Where a test corresponds to a
    numbered audit finding, the Describe name says so (e.g. "FM-014").
    Where it does not have a number, it was found while writing this suite
    and reported directly to the audit/architecture owners as a bonus find.

    These tests are EXPECTED TO FAIL against current source. That is the
    point: they encode correct behavior and will go green when a fix lands.
    Do not weaken the assertions to make them pass, do not -Skip them.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'KnownBug FM-006 (read side): ConvertFrom-JsonFrontMatter reads without -Raw' -Tag 'KnownBug' {

    It 'calls Get-Content with -Raw so multi-line JSON is not silently space-joined' {
        # Root cause per architecture.md: Get-Content without -Raw returns a
        # string[] for any multi-line file. [regex]::Match then coerces that
        # array to a string by joining every element with a single space,
        # which quietly destroys the file's real line structure before the
        # regex ever runs, and makes the Singleline RegexOption a no-op.
        # Correct behavior: call Get-Content -Path $InputFile -Raw.
        InModuleScope 'pwsh.frontmatter' {
            Mock Get-Content { return "{`n  `"title`": `"X`"`n}" } -Verifiable
            $path = Join-Path $TestDrive 'raw-check.md'
            Set-Content -Path $path -Value "{`n  `"title`": `"X`"`n}`nBody" -NoNewline -Encoding utf8
            ConvertFrom-JsonFrontMatter -InputFile $path | Out-Null
            Should -Invoke Get-Content -ParameterFilter { $Raw -eq $true } -Times 1
        }
    }
}

Describe 'KnownBug FM-006: non-greedy {...} regex breaks on nested JSON objects' -Tag 'KnownBug' {

    Context 'Write side: Set-FrontMatter replacing existing nested JSON front matter' {
        It 'replaces the whole existing block cleanly, leaving no orphaned closing brace in the body' {
            $path = Join-Path $TestDrive 'set-nested.md'
            $initial = @'
{
  "title": "Old",
  "meta": {
    "nested": "value",
    "count": 3
  }
}
# Body text
Second line of body.
'@
            Set-Content -Path $path -Value $initial -NoNewline -Encoding utf8

            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'New' }) -As 'json'

            $finalContent = Get-Content -Path $path -Raw
            # Correct behavior: exactly the new front matter block, then the
            # untouched body, nothing else. Today an orphaned "}" from the old
            # nested block's un-replaced tail leaks into the body.
            $expected = "{`n  `"title`": `"New`"`n}`n# Body text`nSecond line of body."
            $finalContent | Should -Be $expected
        }
    }

    Context 'Read side: ConvertFrom-JsonFrontMatter on front matter that has a nested object' {
        It 'parses a JSON front matter block containing a nested object without throwing' {
            $path = Join-Path $TestDrive 'read-nested.md'
            $content = @'
{
  "title": "x",
  "meta": {
    "nested": "value",
    "count": 3
  }
}
Body.
'@
            Set-Content -Path $path -Value $content -NoNewline -Encoding utf8

            # Correct behavior: this should succeed and return both properties.
            # Today the non-greedy {...} match stops at the inner "}" that
            # closes "meta", leaving invalid, truncated JSON handed to
            # ConvertFrom-Json, which throws.
            { Get-FrontMatter -FilePath $path -ErrorAction Stop } | Should -Not -Throw
        }

        It 'returns the nested object values correctly when it does not throw' {
            $path = Join-Path $TestDrive 'read-nested-values.md'
            $content = @'
{
  "title": "x",
  "meta": {
    "nested": "value",
    "count": 3
  }
}
Body.
'@
            Set-Content -Path $path -Value $content -NoNewline -Encoding utf8
            $result = Get-FrontMatter -FilePath $path -ErrorAction Stop
            $result.title | Should -Be 'x'
            $result.meta.nested | Should -Be 'value'
            $result.meta.count | Should -Be 3
        }
    }
}

Describe 'KnownBug FM-014: Convert-FrontMatterValue integer coercion is wrong at both ends' -Tag 'KnownBug' {

    It 'keeps a quoted digit-only string as a string, not an [int]' {
        # Convert-FrontMatterValue strips surrounding quotes BEFORE checking
        # for a digit-only string, so a deliberately-quoted value like "123"
        # (meant by the author to stay a string, e.g. a zip code or version
        # segment) gets silently promoted to [int] exactly the same as an
        # unquoted 123 would. Quoting should be able to opt a value out of
        # numeric promotion; today it cannot.
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '"123"'
            $result | Should -BeOfType [string]
            $result | Should -Be '123'
        }
    }

    It 'does not lose leading zeros from a quoted numeric-looking string' {
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '"007"'
            $result | Should -Be '007'
        }
    }

    It 'does not lose leading zeros from an UNQUOTED numeric-looking string either' {
        # Audit repro: [007] -> [7] (Int32), a real data mutation, not just a
        # quoting edge case. Zip codes, IDs and version segments break.
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '007'
            $result | Should -Be '007'
        }
    }

    It 'converts a plain "0" to [int] 0, not a string (the -as [int] truthiness bug)' {
        # `$value -as [int]` on "0" produces the [int] 0, which is falsy in a
        # boolean context, so `-and` short-circuits and "0" is treated as if
        # the cast had failed. Audit repro: [0] -> [0] (String), should be
        # Int32.
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '0'
            $result | Should -BeOfType [int]
            $result | Should -Be 0
        }
    }

    It 'converts a negative number to [int], not a string' {
        # The `^\d+$` anchor has no sign class, so "-9" never matches and
        # stays a string. Audit repro: [-9] stays a string.
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '-9'
            $result | Should -BeOfType [int]
            $result | Should -Be (-9)
        }
    }
}

Describe 'KnownBug: YAML round trip of an empty string returns an empty array' -Tag 'KnownBug' {

    It 'preserves an empty string as a string, not as an empty array' {
        # ConvertTo-YamlFrontMatter emits "key:" with nothing after the colon
        # for an empty string, exactly the same shape it emits for the start
        # of a block array. ConvertFrom-YamlFrontMatter cannot tell the two
        # apart and always assumes "array coming", so subtitle = "" comes
        # back as subtitle = @() instead of subtitle = "".
        InModuleScope 'pwsh.frontmatter' {
            $path = Join-Path $TestDrive 'yaml-empty-string.md'
            Set-Content -Path $path -Value "---`nsubtitle:`n---`nBody" -NoNewline -Encoding utf8
            $result = ConvertFrom-YamlFrontMatter -InputFile $path
            # Use -ActualValue, not a pipe: if $result.subtitle is the buggy
            # empty array, piping a 0-element array to Should invokes it zero
            # times and reports a misleading "$null", not the array it is.
            Should -ActualValue $result.subtitle -BeOfType ([string])
            Should -ActualValue $result.subtitle -Be ''
        }
    }
}

Describe 'KnownBug: TOML round trip of an empty array throws' -Tag 'KnownBug' {

    It 'reads an empty array back as an empty array instead of throwing' {
        # ConvertTo-TomlFrontMatter happily emits "tags = [  ]" for an empty
        # array. ConvertFrom-TomlFrontMatter splits the inner "" on ',' and
        # gets one empty-string element, then calls Convert-FrontMatterValue
        # with an empty string. That parameter is Mandatory, and PowerShell
        # treats an empty string as "no value" for a mandatory [string]
        # parameter, so the call throws instead of yielding an empty array.
        InModuleScope 'pwsh.frontmatter' {
            $path = Join-Path $TestDrive 'toml-empty-array.md'
            Set-Content -Path $path -Value "+++`ntags = [  ]`n+++`nBody" -NoNewline -Encoding utf8
            { ConvertFrom-TomlFrontMatter -InputFile $path -ErrorAction Stop } | Should -Not -Throw
        }
    }
}

Describe 'KnownBug: empty-file error message is swallowed by a ValidateSet failure' -Tag 'KnownBug' {

    It 'throws the intended "Front matter type not detected." message for an empty file' {
        # Get-Content -Raw on a zero-byte file returns $null. PowerShell's
        # switch statement enumerates $null as zero items, so neither any
        # case NOR the default arm runs: Get-FrontMatterType returns $null
        # without throwing. Get-FrontMatter then passes that $null/empty
        # value into ConvertFrom-FrontMatter's -FrontMatterType parameter,
        # which fails a ValidateSet check instead, producing a confusing
        # unrelated error message.
        $path = Join-Path $TestDrive 'empty-message-check.md'
        Set-Content -Path $path -Value '' -NoNewline -Encoding utf8
        { Get-FrontMatter -FilePath $path -ErrorAction Stop } | Should -Throw 'Front matter type not detected.'
    }
}

