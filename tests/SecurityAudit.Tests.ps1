#Requires -Module Pester
<#
    Regression tests for the 2026-09-27 security + correctness audit
    (.agents/notes/security-audit-2026-09-27.md). Covers the findings that
    touch Set-FrontMatter and Convert-FrontMatter directly:
    FM-001, FM-002, FM-004, FM-005, FM-009, FM-010, FM-013, plus a -WhatIf
    test for the SupportsShouldProcess addition the developer is adding
    alongside these fixes.

    All tests here are tagged 'KnownBug'. They are EXPECTED TO FAIL against
    current source, that is the point: they encode CORRECT behavior (the
    audit's fix intent, breaking changes approved) and go green when the fix
    lands. Do not weaken the assertions, do not -Skip.

    Findings NOT covered here on purpose, out of scope for this file:
    FM-003 (module load casing), FM-006 (non-greedy JSON regex, see
    KnownBugs.Tests.ps1), FM-007/FM-012 (build.ps1 / workflow, off limits,
    tests/ ownership only), FM-008 (manifest export list, build-time
    concern), FM-011 (YAML key-flattening parser correctness, not assigned
    this round), FM-014 (Convert-FrontMatterValue, see KnownBugs.Tests.ps1),
    FM-015 (LiteralPath on the read side, same root cause as FM-002, not
    assigned this round), FM-016/FM-017 (build/packaging hygiene).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'KnownBug FM-001: static Replace count arg binds to RegexOptions, replaces every marker block' -Tag 'KnownBug' {

    It 'leaves thematic breaks and everything after the front matter untouched' {
        # `[regex]::Replace($content, $pattern, $replacement, 1)` has no
        # 4-arg (string, string, string, int) static overload. The `1`
        # actually binds to the RegexOptions parameter (1 = IgnoreCase), so
        # "replace only the first match" never happens: every `---` block
        # anywhere in the file, including ordinary markdown thematic breaks
        # in the body, gets replaced. Today this permanently deletes
        # "body two after a thematic break" below.
        $path = Join-Path $TestDrive 'fm001.md'
        $initial = @'
---
title: hello
---
body one
---
body two after a thematic break
---
end
'@
        Set-Content -Path $path -Value $initial -NoNewline -Encoding utf8

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'NEW' }) -As 'yaml'

        $expected = @'
---
title: NEW
---
body one
---
body two after a thematic break
---
end
'@
        (Get-Content -Path $path -Raw) | Should -Be $expected
    }
}

Describe 'KnownBug FM-002: wildcard in -FilePath globs and cross-contaminates files' -Tag 'KnownBug' {

    It 'does not merge two distinct files into byte-identical copies when given a wildcard path' {
        # Get-Content -Path and Set-Content -Path both glob. A `*.md` path
        # reads BOTH matching files concatenated into one string, then
        # writes that merged blob back to BOTH files: two distinct files
        # become byte-identical and each one's original content is gone.
        # Correct behavior (breaking change approved): either refuse a
        # wildcard path outright, or touch exactly the one file the caller
        # meant. Either way the two files must not end up identical.
        $dir = Join-Path $TestDrive 'fm002'
        New-Item -ItemType Directory -Path $dir | Out-Null
        $one = Join-Path $dir 'one.md'
        $two = Join-Path $dir 'two.md'
        Set-Content -Path $one -Value "---`ntitle: One`n---`nBody one" -NoNewline -Encoding utf8
        Set-Content -Path $two -Value "---`ntitle: Two`n---`nBody two" -NoNewline -Encoding utf8

        $wildcardPath = Join-Path $dir '*.md'
        try {
            Set-FrontMatter -FilePath $wildcardPath -FrontMatter ([PSCustomObject]@{ title = 'X' }) -As 'yaml' -ErrorAction Stop
        }
        catch {
            # Erroring out on a wildcard path is an acceptable fix.
        }

        $hashOne = (Get-FileHash -Path $one).Hash
        $hashTwo = (Get-FileHash -Path $two).Hash
        $hashOne | Should -Not -Be $hashTwo
    }

    It 'refuses a non-.md file such as script.ps1 (write path must extension-check like the read path does)' {
        $path = Join-Path $TestDrive 'script.ps1'
        Set-Content -Path $path -Value "---`ntitle: X`n---`nWrite-Host 'not markdown'" -NoNewline -Encoding utf8
        { Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'Y' }) -As 'yaml' -ErrorAction Stop } |
            Should -Throw
    }
}

Describe 'KnownBug FM-004: regex replacement-token injection from front matter values' -Tag 'KnownBug' {

    It 'writes $&, $0 and $1 in a value literally, not as expanded regex replacement tokens' {
        # The replacement argument to [regex]::Replace is NOT literal: $&,
        # $0, $1, $_ and $` all expand. A front matter value containing
        # these splices in match text (in practice, the OLD front matter
        # block) instead of writing the value the caller actually gave.
        $path = Join-Path $TestDrive 'fm004.md'
        Set-Content -Path $path -Value "---`ntitle: old`n---`nbody" -NoNewline -Encoding utf8

        $dangerousValue = 'has $& and $1 tokens'
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = $dangerousValue }) -As 'yaml'

        (Get-FrontMatter -FilePath $path).title | Should -Be $dangerousValue
    }
}

Describe 'KnownBug FM-005: front matter key injection via an unescaped newline in a value' -Tag 'KnownBug' {

    It 'does not let a newline in a YAML value forge new top-level keys' {
        # Both emitters only escape a literal double quote. A newline in the
        # value is never escaped or rejected, so a value like
        # "benign`nrole: admin`npublished: true" breaks out of its own
        # scalar line and becomes two new, real, top-level YAML keys.
        $injected = "benign`nrole: admin`npublished: true"
        $path = Join-Path $TestDrive 'fm005.yaml.md'
        Set-Content -Path $path -Value "---`n---`nbody" -NoNewline -Encoding utf8
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = $injected }) -As 'yaml'

        $result = Get-FrontMatter -FilePath $path
        $result.PSObject.Properties.Name | Should -Not -Contain 'role'
        $result.PSObject.Properties.Name | Should -Not -Contain 'published'
        $result.title | Should -Be $injected
    }

    It 'does not let a newline in a TOML value forge new top-level keys' {
        $injected = "benign`nrole: admin`npublished: true"
        $path = Join-Path $TestDrive 'fm005.toml.md'
        Set-Content -Path $path -Value "+++`n+++`nbody" -NoNewline -Encoding utf8
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = $injected }) -As 'toml'

        $result = Get-FrontMatter -FilePath $path
        $result.PSObject.Properties.Name | Should -Not -Contain 'role'
        $result.PSObject.Properties.Name | Should -Not -Contain 'published'
        $result.title | Should -Be $injected
    }

    It 'does not let a newline plus a marker line in a value close the front matter block early' {
        # Variant from the audit (H2): a value of "a`n---`nINJECTED BODY
        # TEXT" emits a literal '---' inside the block, closing the front
        # matter early and pushing attacker text into the document body.
        $injected = "a`n---`nINJECTED BODY TEXT"
        $path = Join-Path $TestDrive 'fm005.yaml-body-injection.md'
        Set-Content -Path $path -Value "---`n---`nreal body, unchanged" -NoNewline -Encoding utf8
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = $injected }) -As 'yaml'

        (Get-Content -Path $path -Raw) | Should -Not -Match 'INJECTED BODY TEXT'
        (Get-FrontMatter -FilePath $path).title | Should -Be $injected
    }
}

Describe 'KnownBug FM-009: BOM and CRLF are destroyed on write' -Tag 'KnownBug' {

    It 'keeps a UTF-8 BOM through a write' {
        $path = Join-Path $TestDrive 'fm009-bom.md'
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($path, "---`r`ntitle: old`r`n---`r`nbody`r`n", $utf8Bom)

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'new' }) -As 'yaml'

        $bytes = [System.IO.File]::ReadAllBytes($path)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $hasBom | Should -BeTrue
    }

    It 'does not turn a pure-CRLF file into a mixed-line-ending file' {
        $path = Join-Path $TestDrive 'fm009-crlf.md'
        [System.IO.File]::WriteAllText($path, "---`r`ntitle: old`r`n---`r`nbody one`r`nbody two`r`n")

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'new' }) -As 'yaml'

        $text = [System.IO.File]::ReadAllText($path)
        $bareLfCount = ([regex]::Matches($text, '(?<!\r)\n')).Count
        $bareLfCount | Should -Be 0
    }
}

Describe 'KnownBug FM-010: read and write disagree on JSON marker detection' -Tag 'KnownBug' {

    It 'round trips single-line JSON front matter through Set-FrontMatter' {
        # Get-FrontMatterType matches a PREFIX ('^{'). Set-FrontMatter
        # requires the ENTIRE first non-empty line to equal '{' exactly.
        # Single-line JSON like `{ "title": "x" }` is readable by
        # Get-FrontMatter but Set-FrontMatter throws "Unknown front matter
        # format" on the very same file, so the documented
        # read-modify-write workflow is impossible for the single most
        # common way people write JSON front matter.
        $path = Join-Path $TestDrive 'fm010.md'
        Set-Content -Path $path -Value '{ "title": "x" }' -NoNewline -Encoding utf8
        Add-Content -Path $path -Value "`nbody" -NoNewline -Encoding utf8

        { Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'NEW' }) -As 'json' -ErrorAction Stop } |
            Should -Not -Throw
        (Get-FrontMatter -FilePath $path).title | Should -Be 'NEW'
    }

    It 'accepts a marker line with trailing whitespace, same as a bare marker' {
        # Strict string equality on the first non-empty line also rejects
        # legal, common trailing whitespace after a marker.
        $path = Join-Path $TestDrive 'fm010-trailing-ws.md'
        Set-Content -Path $path -Value "---  `ntitle: old`n---`nbody" -NoNewline -Encoding utf8

        { Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'NEW' }) -As 'yaml' -ErrorAction Stop } |
            Should -Not -Throw
        (Get-FrontMatter -FilePath $path).title | Should -Be 'NEW'
    }
}

Describe 'KnownBug FM-013: ValueFromPipeline with no process block drops all but the last piped item' -Tag 'KnownBug' {

    It 'Convert-FrontMatter returns one output per piped object, not just the last' {
        $objects = 1..3 | ForEach-Object { [PSCustomObject]@{ n = $_ } }
        $results = $objects | Convert-FrontMatter -OutputType 'yaml'
        @($results).Count | Should -Be 3
    }

    It 'Set-FrontMatter processes every piped object, not just the last' {
        # Set-FrontMatter has no return value, so we cannot count outputs.
        # Also, because it re-reads then rewrites the SAME target file for
        # each piped object, a fixed (process-block) implementation and the
        # current buggy (end-block-only) implementation can coincidentally
        # leave the file in the SAME final state (the last object always
        # "wins" either way for a single fixed -FilePath). The bug is that
        # it does not run once per input, so we assert on that directly: it
        # must read the file once per piped object, not once total.
        InModuleScope 'pwsh.frontmatter' {
            Mock Get-Content { return "---`ntitle: stub`n---`nbody" }
            $path = Join-Path $TestDrive 'fm013.md'
            Set-Content -Path $path -Value "---`n---`nbody" -NoNewline -Encoding utf8
            $objects = 1..3 | ForEach-Object { [PSCustomObject]@{ n = $_ } }
            $objects | Set-FrontMatter -FilePath $path -As 'yaml'
            Should -Invoke Get-Content -Times 3
        }
    }
}

Describe 'KnownBug: Set-FrontMatter needs -WhatIf support (SupportsShouldProcess)' -Tag 'KnownBug' {

    It 'leaves the file completely unchanged when called with -WhatIf' {
        # Set-FrontMatter has no SupportsShouldProcess today, so -WhatIf does
        # not exist as a parameter at all: this currently fails at parameter
        # binding, not at the assertion. Once ShouldProcess is added, -WhatIf
        # must genuinely no-op: no write, no partial write, no temp file left
        # behind, byte-for-byte identical file before and after.
        $path = Join-Path $TestDrive 'whatif.md'
        $original = "---`ntitle: original`n---`nbody, unchanged`n"
        Set-Content -Path $path -Value $original -NoNewline -Encoding utf8
        $beforeBytes = [System.IO.File]::ReadAllBytes($path)

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'should-not-appear' }) -As 'yaml' -WhatIf

        $afterBytes = [System.IO.File]::ReadAllBytes($path)
        [System.Convert]::ToBase64String($afterBytes) | Should -Be ([System.Convert]::ToBase64String($beforeBytes))
    }
}
