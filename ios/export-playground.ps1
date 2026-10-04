$source = Join-Path $PSScriptRoot 'ERP'
$target = Join-Path $PSScriptRoot 'ERP-iPad.swiftpm'
$module = Join-Path $target 'Sources/ERP'
New-Item -ItemType Directory -Force $module | Out-Null
Get-ChildItem -LiteralPath $source -Filter '*.swift' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $module -Force }
New-Item -ItemType Directory -Force (Join-Path $module 'Resources') | Out-Null
Get-ChildItem -LiteralPath (Join-Path $source 'Resources') -Filter '*.json' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $module 'Resources') -Force }
$iconTarget = Join-Path $module 'Assets.xcassets/AppIcon.appiconset'
New-Item -ItemType Directory -Force $iconTarget | Out-Null
Get-ChildItem -LiteralPath (Join-Path $source 'Resources/Assets.xcassets/AppIcon.appiconset') | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $iconTarget -Force }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Playground.Package.swift') -Destination (Join-Path $target 'Package.swift') -Force
Write-Output $target
