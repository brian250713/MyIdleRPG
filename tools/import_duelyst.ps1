param(
    [string]$SourceRoot = "D:\Tools\Godot_v4.7.1\asset-pack\Game_Kits\Duelyst\duelyst_animated_sprites"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ListPath = Join-Path $PSScriptRoot "duelyst_assets.txt"
$DestinationRoot = Join-Path $ProjectRoot "addons\duelyst_animated_sprites"

if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "Duelyst source directory not found: $SourceRoot"
}

New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null
$copied = 0

foreach ($rawLine in Get-Content -LiteralPath $ListPath -Encoding UTF8) {
    $entry = $rawLine.Trim()
    if ([string]::IsNullOrWhiteSpace($entry) -or $entry.StartsWith("#")) {
        continue
    }

    $parts = $entry -split "/"
    if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
        throw "Invalid asset entry: $entry (expected units/name or fx/name)"
    }

    $category = $parts[0]
    $name = $parts[1]
    $relativeFiles = @(
        "spritesheets/$category/$name.png",
        "spritesheets/$category/$name.png.import",
        "spriteframes/$category/$name.tres"
    )

    foreach ($relativeFile in $relativeFiles) {
        $sourcePath = Join-Path $SourceRoot $relativeFile
        $destinationPath = Join-Path $DestinationRoot $relativeFile
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Missing source asset: $sourcePath"
        }

        $destinationDirectory = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        $copied = $copied + 1
    }
}

$licenseSource = Join-Path $SourceRoot "LICENSE"
$licenseDestination = Join-Path $DestinationRoot "LICENSE"
if (-not (Test-Path -LiteralPath $licenseSource -PathType Leaf)) {
    throw "Missing LICENSE: $licenseSource"
}
Copy-Item -LiteralPath $licenseSource -Destination $licenseDestination -Force
$copied = $copied + 1

Write-Host "Duelyst P1 asset import complete: $copied files -> $DestinationRoot"
