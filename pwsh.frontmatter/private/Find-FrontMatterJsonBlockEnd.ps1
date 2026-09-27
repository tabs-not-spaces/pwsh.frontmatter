function Find-FrontMatterJsonBlockEnd {
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [int]$StartIndex
    )

    # Character level brace counting that skips braces inside JSON strings.
    # This is the single brace matching implementation in the module.
    $depth = 0
    $inString = $false
    $escaped = $false

    for ($i = $StartIndex; $i -lt $Content.Length; $i++) {
        $char = $Content[$i]
        if ($inString) {
            if ($escaped) {
                $escaped = $false
            }
            elseif ($char -eq '\') {
                $escaped = $true
            }
            elseif ($char -eq '"') {
                $inString = $false
            }
            continue
        }

        if ($char -eq '"') {
            $inString = $true
        }
        elseif ($char -eq '{') {
            $depth++
        }
        elseif ($char -eq '}') {
            $depth--
            if ($depth -le 0) {
                return $i
            }
        }
    }

    return -1
}
