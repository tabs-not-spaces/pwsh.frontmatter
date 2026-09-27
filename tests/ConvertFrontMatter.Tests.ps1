#Requires -Module Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Convert-FrontMatter' {

    BeforeAll {
        $script:Input = [PSCustomObject]@{ title = 'Shape Test'; count = 3 }
    }

    It 'emits a block starting and ending with the correct markers, <Format>' -ForEach @(
        @{ Format = 'yaml'; StartMarker = '---'; EndMarker = '---' }
        @{ Format = 'toml'; StartMarker = '+++'; EndMarker = '+++' }
        @{ Format = 'json'; StartMarker = '{'; EndMarker = '}' }
    ) {
        $emitted = Convert-FrontMatter -FrontMatter $script:Input -OutputType $Format
        $lines = $emitted -split "`r?`n"
        $lines[0].Trim() | Should -Be $StartMarker
        $lines[-1].Trim() | Should -Be $EndMarker
    }

    It 'rejects an unsupported output type' {
        { Convert-FrontMatter -FrontMatter $script:Input -OutputType 'xml' } | Should -Throw
    }

    It 'requires a FrontMatter object' {
        (Get-Command Convert-FrontMatter).Parameters['FrontMatter'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            ForEach-Object { $_.Mandatory } | Should -Contain $true
    }

    It 'converting to the format it is already in is idempotent in shape' -ForEach @(
        @{ Format = 'yaml' }
        @{ Format = 'toml' }
        @{ Format = 'json' }
    ) {
        $first = Convert-FrontMatter -FrontMatter $script:Input -OutputType $Format
        # Re-parse then re-emit: the second emission should carry the same
        # scalar values even though key order is not guaranteed (parsers build
        # a hashtable, see conventions.md).
        $path = Join-Path $TestDrive "identity-$Format.md"
        Set-Content -Path $path -Value ($first + "`nBody") -NoNewline -Encoding utf8
        $parsedBack = Get-FrontMatter -FilePath $path
        $second = Convert-FrontMatter -FrontMatter $parsedBack -OutputType $Format
        $secondPath = Join-Path $TestDrive "identity-$Format-second.md"
        Set-Content -Path $secondPath -Value ($second + "`nBody") -NoNewline -Encoding utf8
        $final = Get-FrontMatter -FilePath $secondPath
        $final.title | Should -Be 'Shape Test'
        $final.count | Should -Be 3
    }
}
