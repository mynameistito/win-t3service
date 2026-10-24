[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$installRoot = Join-Path $HOME '.t3service'
$t3Command = Join-Path $HOME '.t3\bin\t3.cmd'
$shimSource = Join-Path $PSScriptRoot 't3service.cmd'
$shimTarget = Join-Path $HOME '.t3\bin\t3service.cmd'

if ([IO.Path]::GetFullPath($PSScriptRoot) -ne [IO.Path]::GetFullPath($installRoot)) {
    throw "Clone this repository to $installRoot, then run .\install.ps1."
}
if (-not (Test-Path $t3Command)) {
    throw "T3 CLI not found at $t3Command. Install T3 Code and its t3 command first."
}
if (-not (Test-Path (Join-Path $PSScriptRoot 'run-t3-hidden.vbs'))) {
    throw 'The hidden launcher is missing from this checkout.'
}

Copy-Item -Path $shimSource -Destination $shimTarget -Force
& (Join-Path $PSScriptRoot 't3service.ps1') install
Write-Host "Installed t3service shim at $shimTarget"
