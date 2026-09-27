@{
    ModuleVersion = '1.0.0'
    GUID = 'ebdeca48-0372-4204-a85b-add3b759925c'
    Author = 'Ben Reader'
    CompanyName = 'Powers Hell'
    Copyright = 'Copyright (c) 2025 Ben Reader'
    Description = 'Read, write and convert yaml, toml and json front matter blocks in markdown files.'
    RootModule = 'pwsh.frontmatter.psm1'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Convert-FrontMatter', 'Get-FrontMatter', 'Set-FrontMatter')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('frontmatter', 'pwsh')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/tabs-not-spaces/pwsh.frontmatter'
        }
    }
}