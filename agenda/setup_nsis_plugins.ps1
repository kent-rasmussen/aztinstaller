# Installs the two third-party NSIS plugins AZT_Installer_UI.nsi needs (Inetc, EnVar).
# Run once on the build machine, in PowerShell opened with "Run as administrator":
#   powershell -ExecutionPolicy Bypass -File agenda\setup_nsis_plugins.ps1
$ErrorActionPreference = 'Stop'
$nsis = "${env:ProgramFiles(x86)}\NSIS"
if (-not (Test-Path "$nsis\Include\nsDialogs.nsh")) { throw "NSIS install at $nsis is incomplete (no nsDialogs.nsh); reinstall NSIS first." }
$tmp = Join-Path $env:TEMP 'nsis_plugins'
New-Item -ItemType Directory -Force $tmp | Out-Null
$zips = [ordered]@{
  'Inetc'  = 'https://nsis.sourceforge.io/mediawiki/images/c/c9/Inetc.zip'
  'EnVar'  = 'https://nsis.sourceforge.io/mediawiki/images/7/7f/EnVar_plugin.zip'
}
foreach ($name in $zips.Keys) {
  $zip = Join-Path $tmp "$name.zip"
  $dir = Join-Path $tmp $name
  Invoke-WebRequest $zips[$name] -OutFile $zip -UseBasicParsing
  Expand-Archive $zip $dir -Force
  # The script compiles with "Unicode True", so it needs the 32-bit Unicode dll
  $dll = Get-ChildItem $dir -Recurse -Filter *.dll |
         Where-Object { $_.DirectoryName -match 'unicode' -and $_.DirectoryName -notmatch 'amd64' }
  if (-not $dll) { throw "${name}: no 32-bit Unicode dll in $zip; contents are in $dir" }
  Copy-Item $dll.FullName "$nsis\Plugins\x86-unicode\" -Force
  Get-ChildItem $dir -Recurse -Filter *.nsh | Copy-Item -Destination "$nsis\Include\" -Force
  Write-Host "${name}: installed $($dll.Name -join ', ')"
}
Write-Host "Done."
