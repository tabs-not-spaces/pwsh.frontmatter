[cmdletbinding()]
param (
    [parameter(Mandatory = $false)]
    [System.IO.FileInfo]$ModulePath = "$PSScriptRoot/pwsh.frontmatter",

    [parameter(Mandatory = $false)]
    [switch]$BuildLocal,

    [parameter(Mandatory = $false)]
    [bool]$CleanBuildDirectory = $true
)

try {
    #region Generate a new version number
    $moduleName = Split-Path -Path $ModulePath -Leaf
    $PreviousVersion = Find-Module -Name $moduleName -ErrorAction SilentlyContinue | Select-Object *
    [Version]$exVer = $PreviousVersion ? $PreviousVersion.Version : $null
    if ($CleanBuildDirectory -and $(Test-Path "$PSScriptRoot/bin/release/*")) {
        Write-Host "Cleaning build directory.."
        $null = Remove-Item -Path "$PSScriptRoot/bin/release/*" -Recurse -Force
    }
    if ($BuildLocal) {
        [int]$rev = ((Get-ChildItem -Path "$PSScriptRoot/bin/release/" -ErrorAction SilentlyContinue).Name | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum) + 1
        $newVersion = New-Object -TypeName Version -ArgumentList 1, 0, 0, $rev
    }
    else {
        $newVersion = if ($exVer) {
            [int]$rev = ($exVer.Revision + 1)
            New-Object version -ArgumentList $exVer.Major, $exVer.Minor, $exVer.Build, $rev
        }
        elseif (-not ([string]::IsNullOrEmpty($env:BUILD_BUILDID))) {
            Write-Verbose 'We are in Azure DevOps it seems...'
            [int]$rev = $env:BUILD_BUILDID
            New-Object Version -ArgumentList 1, 0, 0, $rev
        }
        else {
            Write-Verbose 'Assume GitHub'
            [int]$rev = $env:GITHUB_RUN_NUMBER
            New-Object Version -ArgumentList 1, 0, 0, $rev
        }
    }
    $releaseNotes = (Get-Content "$ModulePath/ReleaseNotes.txt" -Raw -ErrorAction SilentlyContinue).Replace("{{NewVersion}}", $newVersion)
    if ($PreviousVersion) {
        $releaseNotes = @"
$releaseNotes

$($previousVersion.releaseNotes)
"@
    }
    #endregion

    #region Build out the release
    if ($BuildLocal) {
        $relPath = "$PSScriptRoot/bin/release/$rev/$moduleName"
    }
    else {
        $relPath = "$PSScriptRoot/bin/release/$moduleName"
    }
    "Version is $newVersion"
    "Module Path is $ModulePath"
    "Module Name is $moduleName"
    "Release Path is $relPath"
    if (!(Test-Path -Path $relPath)) {
        New-Item -Path $relPath -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path "$ModulePath/*" -Destination "$relPath" -Recurse -Exclude ".gitKeep", "releaseNotes.txt", "description.txt"

    $Manifest = @{
        Path              = "$relPath/$moduleName.psd1"
        ModuleVersion     = $newVersion
        Description       = (Get-Content "$ModulePath/description.txt" -Raw).ToString()
        FunctionsToExport = (Get-ChildItem -Path "$relPath/public/*.ps1" -Recurse).BaseName
        ReleaseNotes      = $releaseNotes
    }
    Update-ModuleManifest @Manifest
}
catch {
    $_
}