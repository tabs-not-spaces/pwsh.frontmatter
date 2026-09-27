#Requires -Module Pester

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Convert-FrontMatterValue (private, type inference)' {

    It 'promotes an unquoted digit-only string to [int]' {
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '123'
            $result | Should -BeOfType [int]
            $result | Should -Be 123
        }
    }

    It 'unquotes a plain quoted string and leaves it a string' {
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '"hello"'
            $result | Should -BeOfType [string]
            $result | Should -Be 'hello'
        }
    }

    It 'leaves the literal word true as a string, not a boolean' {
        # architecture.md: "Booleans ... all stay strings." Convert-FrontMatterValue
        # has no boolean branch at all.
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value 'true'
            $result | Should -BeOfType [string]
            $result | Should -Be 'true'
        }
    }

    It 'leaves the literal word false as a string, not a boolean' {
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value 'false'
            $result | Should -BeOfType [string]
            $result | Should -Be 'false'
        }
    }

    It 'leaves the literal word null as a string, not $null' {
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value 'null'
            $result | Should -BeOfType [string]
            $result | Should -Be 'null'
        }
    }

    It 'leaves an ISO date string as a plain string, not a [datetime]' {
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '2024-01-15'
            $result | Should -BeOfType [string]
            $result | Should -Be '2024-01-15'
        }
    }

    It 'leaves a float-looking string as a plain string (only digit-only strings are promoted)' {
        InModuleScope 'pwsh.frontmatter' {
            $result = Convert-FrontMatterValue -value '3.14'
            $result | Should -BeOfType [string]
            $result | Should -Be '3.14'
        }
    }
}
