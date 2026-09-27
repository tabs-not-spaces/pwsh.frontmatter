function Assert-FrontMatterKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [ValidateSet('yaml', 'toml')]
        [string]$Format
    )

    # Keys are written unquoted, so any character the parser treats as
    # structure would let a property name forge keys or close the block.
    # TOML follows the bare key rule. YAML must start with a letter, digit or
    # underscore so '- ' cannot open a list, and also allows dots and single
    # inner spaces, which ConvertFrom-YamlFrontMatter reads back unchanged.
    $pattern = switch ($Format) {
        'toml' { '^[A-Za-z0-9_-]+$' }
        'yaml' { '^[A-Za-z0-9_][A-Za-z0-9_.-]*( [A-Za-z0-9_.-]+)*$' }
    }

    if ($Key -cnotmatch $pattern) {
        throw "Front matter key '$($Key -replace '[\x00-\x1F]', '?')' is not valid for $Format. Use letters, digits, underscores and hyphens."
    }
}
