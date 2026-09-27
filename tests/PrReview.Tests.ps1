#Requires -Module Pester
<#
    Regression tests for the Copilot review of pull request 8
    (https://github.com/tabs-not-spaces/pwsh.frontmatter/pull/8).
    Covers key injection in the YAML and TOML emitters, quoted commas in TOML
    arrays, the shared temp file in Set-FrontMatter, and line ending choice.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'Helpers.ps1')
    Import-FrontMatterModuleFresh
}

AfterAll {
    Remove-Module -Name 'pwsh.frontmatter' -Force -ErrorAction SilentlyContinue
}

Describe 'Emitters reject keys that could forge front matter' {

    It 'rejects a <Format> key containing <Label>' -ForEach @(
        @{ Format = 'yaml'; Label = 'a newline'; Key = "title`nrole" }
        @{ Format = 'yaml'; Label = 'a colon'; Key = 'role: admin' }
        @{ Format = 'yaml'; Label = 'a leading hyphen and space'; Key = '- item' }
        @{ Format = 'toml'; Label = 'a newline'; Key = "title`nrole" }
        @{ Format = 'toml'; Label = 'an equals sign'; Key = 'role = "admin"' }
        @{ Format = 'toml'; Label = 'a dot'; Key = 'a.b' }
    ) {
        $path = New-FrontMatterTestFile -Path (Join-Path $TestDrive "key-$Format.md") -Format $Format -Body "body`n" -InitialFrontMatterBody ''
        $before = [System.IO.File]::ReadAllBytes($path)
        $fm = [PSCustomObject]@{ $Key = 'value' }

        { Set-FrontMatter -FilePath $path -FrontMatter $fm -As $Format -ErrorAction Stop } | Should -Throw '*not valid*'
        [System.IO.File]::ReadAllBytes($path) | Should -Be $before
    }

    It 'still accepts <Format> key <Key>' -ForEach @(
        @{ Format = 'yaml'; Key = 'og.image' }
        @{ Format = 'yaml'; Key = 'my key' }
        @{ Format = 'toml'; Key = 'last-modified_at' }
    ) {
        $path = New-FrontMatterTestFile -Path (Join-Path $TestDrive "okkey-$Format.md") -Format $Format -Body "body`n"
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ $Key = 'v' }) -As $Format
        (Get-FrontMatter -FilePath $path).$Key | Should -Be 'v'
    }
}

Describe 'TOML arrays keep commas and quotes inside strings' {

    It 'round trips an item containing a comma as one item' {
        $path = New-FrontMatterTestFile -Path (Join-Path $TestDrive 'toml-comma.md') -Format 'toml' -Body "body`n"
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ tags = @('a,b', 'c') }) -As 'toml'

        $tags = @((Get-FrontMatter -FilePath $path).tags)
        $tags.Count | Should -Be 2
        $tags[0] | Should -BeExactly 'a,b'
        $tags[1] | Should -BeExactly 'c'
    }

    It 'round trips an item containing an escaped quote followed by a comma' {
        $path = New-FrontMatterTestFile -Path (Join-Path $TestDrive 'toml-quote.md') -Format 'toml' -Body "body`n"
        $item = 'say "hi", then leave'
        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ tags = @($item, 'x') }) -As 'toml'

        $tags = @((Get-FrontMatter -FilePath $path).tags)
        $tags.Count | Should -Be 2
        $tags[0] | Should -BeExactly $item
    }

    It 'splits a hand written array with single quoted items' {
        $path = Join-Path $TestDrive 'toml-single.md'
        Set-Content -LiteralPath $path -Value "+++`ntags = [ 'a,b', `"c`", 3 ]`n+++`nbody`n" -NoNewline -Encoding utf8

        $tags = @((Get-FrontMatter -FilePath $path).tags)
        $tags.Count | Should -Be 3
        $tags[0] | Should -BeExactly 'a,b'
        $tags[2] | Should -Be 3
    }
}

Describe 'Set-FrontMatter temp file handling' {

    It 'leaves an unrelated <name>.tmp file untouched' {
        $path = New-FrontMatterTestFile -Path (Join-Path $TestDrive 'stale.md') -Format 'yaml' -Body "body`n" -InitialFrontMatterBody 'title: old'
        $sidecar = "$path.tmp"
        Set-Content -LiteralPath $sidecar -Value 'unrelated data' -NoNewline

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'new' }) -As 'yaml'

        Get-Content -LiteralPath $sidecar -Raw | Should -BeExactly 'unrelated data'
        (Get-FrontMatter -FilePath $path).title | Should -Be 'new'
    }

    It 'leaves no temp files behind after a write' {
        $dir = Join-Path $TestDrive 'clean'
        $null = New-Item -ItemType Directory -Path $dir
        $path = New-FrontMatterTestFile -Path (Join-Path $dir 'doc.md') -Format 'yaml' -Body "body`n" -InitialFrontMatterBody 'title: old'

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'new' }) -As 'yaml'

        @(Get-ChildItem -LiteralPath $dir -Force).Name | Should -Be @('doc.md')
    }
}

Describe 'Set-FrontMatter line ending choice' {

    It 'uses LF when LF lines outnumber a single CRLF line' {
        $path = Join-Path $TestDrive 'mixed.md'
        $content = "---`ntitle: old`n---`nline one`r`nline two`nline three`nline four`n"
        [System.IO.File]::WriteAllText($path, $content)

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'new'; tag = 'x' }) -As 'yaml'

        $after = [System.IO.File]::ReadAllText($path)
        [regex]::Matches($after, "`r`n").Count | Should -Be 1
    }

    It 'uses CRLF when CRLF lines outnumber LF lines' {
        $path = Join-Path $TestDrive 'mostly-crlf.md'
        $content = "---`r`ntitle: old`r`n---`r`nline one`r`nline two`n"
        [System.IO.File]::WriteAllText($path, $content)

        Set-FrontMatter -FilePath $path -FrontMatter ([PSCustomObject]@{ title = 'new'; tag = 'x' }) -As 'yaml'

        $after = [System.IO.File]::ReadAllText($path)
        [regex]::Matches($after, "(?<!`r)`n").Count | Should -Be 1
    }
}
