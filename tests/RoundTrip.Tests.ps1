#Requires -Module Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Round trip: Set-FrontMatter then Get-FrontMatter' {

    Context 'Common scalar and array values, <Format>' -ForEach @(
        @{ Format = 'yaml' }
        @{ Format = 'toml' }
        @{ Format = 'json' }
    ) {
        BeforeAll {
            $script:UnicodeSample = Get-UnicodeSample
            $script:Input = [PSCustomObject]@{
                title = 'Hello: World'
                count = 42
                tags  = @('alpha', 'beta', 'gamma')
                unicode = $script:UnicodeSample
            }
            $script:Path = Join-Path $TestDrive "roundtrip-$Format.md"
            New-FrontMatterTestFile -Path $script:Path -Format $Format -Body "# Body`nSome text.`n"
            Set-FrontMatter -FilePath $script:Path -FrontMatter $script:Input -As $Format
            $script:Result = Get-FrontMatter -FilePath $script:Path
        }

        It 'preserves a string with special characters' {
            $script:Result.title | Should -Be 'Hello: World'
        }

        It 'preserves an integer as a real number' {
            $script:Result.count | Should -Be 42
            # JSON deserializes whole numbers as [long] (native ConvertFrom-Json
            # behavior in PowerShell 7), YAML/TOML promote via a hand-rolled
            # [int] cast in Convert-FrontMatterValue. Either is a real integer
            # type, neither is a string, that is what we are proving here.
            if ($Format -eq 'json') {
                $script:Result.count | Should -BeOfType [long]
            }
            else {
                $script:Result.count | Should -BeOfType [int]
            }
        }

        It 'preserves a string array, values and order' {
            @($script:Result.tags) | Should -Be @('alpha', 'beta', 'gamma')
        }

        It 'preserves unicode content' {
            $script:Result.unicode | Should -Be $script:UnicodeSample
        }

        It 'leaves the body untouched' {
            (Get-Content -Path $script:Path -Raw) | Should -Match 'Some text\.'
        }
    }

    Context 'Empty string value' {
        It 'round trips an empty string in TOML' {
            $path = Join-Path $TestDrive 'empty-string.toml.md'
            New-FrontMatterTestFile -Path $path -Format 'toml' -Body 'Body'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ subtitle = '' }) -As 'toml'
            (Get-FrontMatter -FilePath $path).subtitle | Should -Be ''
        }

        It 'round trips an empty string in JSON' {
            $path = Join-Path $TestDrive 'empty-string.json.md'
            New-FrontMatterTestFile -Path $path -Format 'json' -Body 'Body'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ subtitle = '' }) -As 'json'
            (Get-FrontMatter -FilePath $path).subtitle | Should -Be ''
        }
    }

    Context 'Empty array value' {
        It 'round trips an empty array in YAML' {
            $path = Join-Path $TestDrive 'empty-array.yaml.md'
            New-FrontMatterTestFile -Path $path -Format 'yaml' -Body 'Body'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ tags = @() }) -As 'yaml'
            @((Get-FrontMatter -FilePath $path).tags).Count | Should -Be 0
        }

        It 'round trips an empty array in JSON' {
            $path = Join-Path $TestDrive 'empty-array.json.md'
            New-FrontMatterTestFile -Path $path -Format 'json' -Body 'Body'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ tags = @() }) -As 'json'
            @((Get-FrontMatter -FilePath $path).tags).Count | Should -Be 0
        }
    }

    Context 'Boolean type fidelity' {
        It 'JSON preserves a boolean as a real bool' {
            $path = Join-Path $TestDrive 'bool.json.md'
            New-FrontMatterTestFile -Path $path -Format 'json' -Body 'Body'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ active = $true }) -As 'json'
            $result = Get-FrontMatter -FilePath $path
            $result.active | Should -BeOfType [bool]
            $result.active | Should -BeTrue
        }
    }

    Context 'Boolean type fidelity, YAML and TOML (documented thin typing, not a bug to fix here)' -Tag 'KnownLimitation' {
        It 'YAML round trips a boolean as a plain string, not a bool' {
            $path = Join-Path $TestDrive 'bool.yaml.md'
            New-FrontMatterTestFile -Path $path -Format 'yaml' -Body 'Body'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ active = $true }) -As 'yaml'
            $result = Get-FrontMatter -FilePath $path
            # Documents architecture.md: "Booleans, dates, floats and nulls all stay strings."
            $result.active | Should -BeOfType [string]
            $result.active | Should -Be $true.ToString()
        }

        It 'TOML round trips a boolean as a plain string, not a bool' {
            $path = Join-Path $TestDrive 'bool.toml.md'
            New-FrontMatterTestFile -Path $path -Format 'toml' -Body 'Body'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ active = $true }) -As 'toml'
            $result = Get-FrontMatter -FilePath $path
            $result.active | Should -BeOfType [string]
            $result.active | Should -Be $true.ToString()
        }
    }

    Context 'Date handling' {
        It 'JSON round trips a date as a real [datetime] (ConvertFrom-Json auto-detects ISO-8601 strings)' {
            $path = Join-Path $TestDrive 'date.json.md'
            New-FrontMatterTestFile -Path $path -Format 'json' -Body 'Body'
            $date = [datetime]'2024-01-15'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ created = $date }) -As 'json'
            $result = Get-FrontMatter -FilePath $path
            $result.created | Should -BeOfType [datetime]
            $result.created | Should -Be $date
        }
    }

    Context 'Date handling, YAML and TOML (documented thin typing, not a bug to fix here)' -Tag 'KnownLimitation' {
        It 'YAML round trips a date as a string, not a date' {
            $path = Join-Path $TestDrive 'date.yaml.md'
            New-FrontMatterTestFile -Path $path -Format 'yaml' -Body 'Body'
            $date = [datetime]'2024-01-15'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ created = $date }) -As 'yaml'
            $result = Get-FrontMatter -FilePath $path
            $result.created | Should -BeOfType [string]
            # The emitter bare-interpolates non-string values ("$key`: $value"),
            # so the exact text is whatever PowerShell's string interpolation
            # produces for a [datetime], which is a fixed format independent
            # of the current culture (unlike calling .ToString() directly).
            # Comparing against that same interpolation keeps this
            # deterministic without hard-coding a culture-specific literal.
            $result.created | Should -Be "$date"
        }

        It 'TOML round trips a date as a string, not a date' {
            $path = Join-Path $TestDrive 'date.toml.md'
            New-FrontMatterTestFile -Path $path -Format 'toml' -Body 'Body'
            $date = [datetime]'2024-01-15'
            Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ created = $date }) -As 'toml'
            $result = Get-FrontMatter -FilePath $path
            $result.created | Should -BeOfType [string]
            $result.created | Should -Be "$date"
        }
    }


    # Nested-object round trip for JSON is covered in KnownBugs.Tests.ps1: the
    # non-greedy {...} regex used by both ConvertFrom-JsonFrontMatter and
    # Set-FrontMatter breaks on any nested object, so it is not a clean
    # "should just work" case today.
}

Describe 'Round trip: Convert-FrontMatter format pairs' {
    BeforeAll {
        $script:Input = [PSCustomObject]@{
            title = 'Cross Format'
            count = 7
            tags  = @('x', 'y')
        }
    }

    It 'converts <From> to <To> and the result parses back to the same scalar/array shape' -ForEach @(
        @{ From = 'yaml'; To = 'yaml' }
        @{ From = 'yaml'; To = 'toml' }
        @{ From = 'yaml'; To = 'json' }
        @{ From = 'toml'; To = 'yaml' }
        @{ From = 'toml'; To = 'toml' }
        @{ From = 'toml'; To = 'json' }
        @{ From = 'json'; To = 'yaml' }
        @{ From = 'json'; To = 'toml' }
        @{ From = 'json'; To = 'json' }
    ) {
        # Convert-FrontMatter takes a PSCustomObject and emits a delimited string
        # for the target format directly, it does not round-trip through the
        # source format first. We prove the emitted text parses back correctly
        # by writing it to a file and reading it with the matching parser.
        $emitted = Convert-FrontMatter -FrontMatter $script:Input -OutputType $To
        $path = Join-Path $TestDrive "convert-$From-to-$To.md"
        Set-Content -Path $path -Value ($emitted + "`nBody") -NoNewline -Encoding utf8
        $result = Get-FrontMatter -FilePath $path
        $result.title | Should -Be 'Cross Format'
        $result.count | Should -Be 7
        @($result.tags) | Should -Be @('x', 'y')
    }
}
