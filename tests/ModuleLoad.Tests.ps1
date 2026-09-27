#Requires -Module Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    $script:ManifestPath = Get-FrontMatterModuleManifestPath
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Module manifest' {
    It 'is a valid manifest' {
        { Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'declares the expected root module' {
        $manifest = Test-ModuleManifest -Path $script:ManifestPath
        $manifest.RootModule | Should -Be 'pwsh.frontmatter.psm1'
    }
}

Describe 'Module import' {
    It 'imports without writing to the error stream' {
        Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
        $errors = @()
        Import-Module -Name $script:ManifestPath -Force -ErrorAction Stop -ErrorVariable errors 2>$null
        $errors.Count | Should -Be 0
    }

    It 'exports the three public functions' -ForEach @(
        @{ FunctionName = 'Get-FrontMatter' }
        @{ FunctionName = 'Set-FrontMatter' }
        @{ FunctionName = 'Convert-FrontMatter' }
    ) {
        Get-Command -Name $FunctionName -Module 'pwsh.frontmatter' -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'loads private helpers into module scope' -ForEach @(
        @{ FunctionName = 'Get-FrontMatterType' }
        @{ FunctionName = 'ConvertFrom-FrontMatter' }
        @{ FunctionName = 'ConvertFrom-YamlFrontMatter' }
        @{ FunctionName = 'ConvertFrom-TomlFrontMatter' }
        @{ FunctionName = 'ConvertFrom-JsonFrontMatter' }
        @{ FunctionName = 'ConvertTo-YamlFrontMatter' }
        @{ FunctionName = 'ConvertTo-TomlFrontMatter' }
        @{ FunctionName = 'ConvertTo-JsonFrontMatter' }
        @{ FunctionName = 'Convert-FrontMatterValue' }
        @{ FunctionName = 'Find-FrontMatterPositionBounds' }
    ) {
        InModuleScope 'pwsh.frontmatter' -Parameters @{ FunctionName = $FunctionName } {
            Get-Command -Name $FunctionName -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }
}
