# pwsh.frontmatter

A PowerShell module for reading, writing and converting the front matter block
at the top of a markdown file.

Front matter is the metadata block that static site generators such as Hugo,
Jekyll and Astro read from the start of a content file. This module parses that
block into a PowerShell object so you can script bulk edits, migrations and
reports across a content folder.

Supports yaml (`---`), toml (`+++`) and json (`{ ... }`) blocks. Requires
PowerShell 7.0 or later. No other dependencies.

## Install

```powershell
Install-Module -Name pwsh.frontmatter -Scope CurrentUser
```

## Usage

```powershell
Import-Module pwsh.frontmatter

# Read the block as an object.
$frontMatter = Get-FrontMatter -FilePath ./post.md

# Edit a key and write it back.
$frontMatter.title = 'Renamed post'
Set-FrontMatter -FilePath ./post.md -FrontMatter $frontMatter -As yaml

# Convert the same file to toml. The body is left alone.
Set-FrontMatter -FilePath ./post.md -FrontMatter $frontMatter -As toml

# Render a block as a string without touching the file.
Convert-FrontMatter -FrontMatter $frontMatter -OutputType json
```

`Set-FrontMatter` rewrites the file in place and keeps no backup. It supports
`ShouldProcess`, so run it with `-WhatIf` first if you want to see what it would
change.

For the full function reference, the supported-formats table and the known
limitations, read
[pwsh.frontmatter/README.md](pwsh.frontmatter/README.md). In a session, run
`Get-Help Get-FrontMatter -Full`.

## Run the tests

The Pester suite lives in `tests/`. From the repository root:

```powershell
Invoke-Pester tests
```

Install Pester first if you do not have it:

```powershell
Install-Module -Name Pester -Scope CurrentUser
```

## Build locally

`build.ps1` stages the module into `bin/release/` and rewrites the manifest with
a generated version number. From the repository root:

```powershell
pwsh -File build.ps1 -BuildLocal
```

`-BuildLocal` numbers the build from the contents of `bin/release/` instead of
querying the PowerShell Gallery, and writes to `bin/release/<revision>/`. Import
that folder to test the packaged layout:

```powershell
Import-Module ./bin/release/1/pwsh.frontmatter -Force
```

Without `-BuildLocal`, the script calls `Find-Module` against the Gallery to
work out the next version, so it needs network access. That path is what CI
runs before publishing.

## Contributing

Open an issue or a pull request. Keep the Pester suite green and keep `.ps1`,
`.psd1` and `.psm1` files ASCII only, because PSScriptAnalyzer flags non-ASCII
characters.

## License

MIT. See [LICENSE](LICENSE).
