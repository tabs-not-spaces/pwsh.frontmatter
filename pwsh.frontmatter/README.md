# pwsh.frontmatter

Read, write and convert the front matter block at the top of a markdown file
from PowerShell.

Front matter is the metadata block that static site generators such as Hugo,
Jekyll and Astro read from the start of a content file. This module parses that
block into a PowerShell object, hands it back to you as a string in any of the
three supported formats, or rewrites it in place.

Requires PowerShell 7.0 or later. There are no other dependencies. The parsers
and emitters are written in PowerShell, not bound to a yaml or toml library.

## Install

```powershell
Install-Module -Name pwsh.frontmatter -Scope CurrentUser
```

Then import it:

```powershell
Import-Module pwsh.frontmatter
```

## Public functions

| Function | What it does |
|----------|--------------|
| `Get-FrontMatter` | Parses the front matter block of a markdown file and returns it as a `PSCustomObject`. |
| `Convert-FrontMatter` | Renders a front matter object as a yaml, toml or json block and returns it as a string. |
| `Set-FrontMatter` | Rewrites the front matter block of a markdown file in place, in the format you choose. |

Run `Get-Help <function> -Full` for parameters and more examples.

## Quick start

### YAML

```powershell
# post.md starts with:
# ---
# title: My first post
# draft: false
# ---

$frontMatter = Get-FrontMatter -FilePath ./post.md
$frontMatter.title = 'Renamed post'
Set-FrontMatter -FilePath ./post.md -FrontMatter $frontMatter -As yaml
```

```yaml
---
title: Renamed post
draft: false
---
```

### TOML

Pass a different value to `-As` to convert the file. The body is left alone.

```powershell
Get-FrontMatter -FilePath ./post.md |
    Set-FrontMatter -FilePath ./post.md -As toml
```

```toml
+++
title = "Renamed post"
draft = "false"
+++
```

### JSON

```powershell
Get-FrontMatter -FilePath ./post.md |
    Convert-FrontMatter -OutputType json
```

```json
{
  "title": "Renamed post",
  "draft": "false"
}
```

## Supported formats

| Format | Markers | Read | Write | Arrays | Nested objects |
|--------|---------|------|-------|--------|----------------|
| yaml | `---` ... `---` | yes | yes | block sequence, or `[]` when empty | no |
| toml | `+++` ... `+++` | yes | yes | inline `[ a, b ]` | no |
| json | `{` ... `}` | yes | yes | yes | yes |

Detection reads the first non-empty line of the file. Anything that does not
start with one of those markers is an error.

## Limitations

Know these before you run the module over content you care about.

- yaml and toml are flat. Nested mappings are not parsed and are not emitted.
  Use json if your front matter has nested objects.
- Round tripping drops comments and multi-line strings, because the parsers do
  not read them.
- Typing is thin. A whole number comes back as `[int]`; everything else comes
  back as `[string]`, including `true`, `false`, dates and floats. Quote a value
  in the source file to keep it a string.
- Property lookup on the returned object is case insensitive, so two keys that
  differ only by case collide. Key order is preserved.
- yaml and toml keys are written unquoted, so `Set-FrontMatter` and
  `Convert-FrontMatter` reject keys that could change the block structure. toml keys allow only letters, digits,
  `_` and `-`. yaml keys must start with a letter, digit or `_` and may also
  contain `.`, `-` and single spaces. json keys are not restricted.
- `Set-FrontMatter` requires a `.md` extension. `.markdown` and `.mdx` are
  rejected.
- `-FilePath` rejects the wildcard metacharacters `*` and `?` on both read and
  write. Pass one literal path.

## Safety

`Set-FrontMatter` rewrites a file in place and keeps no backup.

- It supports `ShouldProcess`, so run it with `-WhatIf` to see what it would
  change, or `-Confirm` to be prompted.
- It only replaces a block that starts on the first non-empty line, so a
  thematic break further down the body is never mistaken for front matter.
- It writes to a temporary file and then moves that file over the original, so
  an interrupted write cannot leave a half rewritten document.
- It preserves the original byte order mark and the dominant line ending.

## License

MIT. See the LICENSE file in the repository.

## About this file

This file documents the module for readers on GitHub. `build.ps1` excludes it
from the published package, so it is not part of the Gallery release.
