param(
  [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")

function Get-IsccPath {
  $fromPath = Get-Command iscc -ErrorAction SilentlyContinue
  if ($fromPath) {
    return $fromPath.Source
  }

  $candidates = @(
    "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  return $null
}

Push-Location $repoRoot
try {
  $pubspecPath = Join-Path $repoRoot "pubspec.yaml"
  $versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*(.+)$' | Select-Object -First 1
  if (-not $versionLine) {
    throw "Unable to find version in pubspec.yaml"
  }

  $rawVersion = $versionLine.Matches[0].Groups[1].Value.Trim()
  $appVersion = $rawVersion.Split('+')[0]
  if ([string]::IsNullOrWhiteSpace($appVersion)) {
    throw "Parsed empty app version from pubspec.yaml"
  }

  if (-not $SkipFlutterBuild) {
    flutter build windows --release
  }

  $isccPath = Get-IsccPath
  if (-not $isccPath) {
    throw "Inno Setup compiler 'iscc' not found in PATH. Install Inno Setup first."
  }

  $env:APP_VERSION = $appVersion
  & $isccPath (Join-Path $scriptDir "apptrace.iss")

  Write-Host "Installer built: build\\installer\\AppTraceSetup-$appVersion.exe"
}
finally {
  Pop-Location
}
