param(
    [string]$FlutterProject = (Join-Path $PSScriptRoot 'Archivix'),
    [string]$WebsiteProject = (Join-Path $PSScriptRoot 'archivxi-web')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-EnvValue {
    param(
        [string]$FilePath,
        [string]$Name
    )

    $line = Get-Content $FilePath | Where-Object {
        $_ -match "^\s*$Name\s*="
    } | Select-Object -First 1

    if (-not $line) {
        throw "Missing $Name in $FilePath"
    }

    $value = ($line -split '=', 2)[1].Trim()

    if (
        ($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))
    ) {
        $value = $value.Substring(1, $value.Length - 2)
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name in $FilePath is empty"
    }

    return $value
}

function Get-AppVersion {
    param([string]$PubspecPath)

    $versionLine = Get-Content $PubspecPath | Where-Object {
        $_ -match '^\s*version:\s*'
    } | Select-Object -First 1

    if (-not $versionLine) {
        return 'latest'
    }

    $rawVersion = ($versionLine -replace '^\s*version:\s*', '').Trim()
    return ($rawVersion -split '\+')[0]
}

$envFile = Join-Path $FlutterProject '.env'
$keyProperties = Join-Path $FlutterProject 'android\key.properties'
$pubspec = Join-Path $FlutterProject 'pubspec.yaml'
$downloadDir = Join-Path $WebsiteProject 'public\downloads'
$releaseApk = Join-Path $FlutterProject 'build\app\outputs\flutter-apk\app-release.apk'

if (-not (Test-Path $envFile)) {
    throw "Flutter env file not found: $envFile"
}

if (-not (Test-Path $keyProperties)) {
    throw "Missing signing config: $keyProperties. Copy android/key.properties.example and fill in the real keystore values first."
}

$supabaseUrl = Get-EnvValue -FilePath $envFile -Name 'SUPABASE_URL'
$supabaseAnonKey = Get-EnvValue -FilePath $envFile -Name 'SUPABASE_ANON_KEY'
$version = Get-AppVersion -PubspecPath $pubspec

Push-Location $FlutterProject
try {
    flutter build apk --release `
        "--dart-define=SUPABASE_URL=$supabaseUrl" `
        "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
}
finally {
    Pop-Location
}

if (-not (Test-Path $releaseApk)) {
    throw "Release APK was not generated at $releaseApk"
}

New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

$latestTarget = Join-Path $downloadDir 'archivix-android-latest.apk'
$versionedTarget = Join-Path $downloadDir "archivix-android-$version.apk"

Copy-Item $releaseApk $latestTarget -Force
Copy-Item $releaseApk $versionedTarget -Force

Write-Output "Published Android release:"
Write-Output "  $latestTarget"
Write-Output "  $versionedTarget"
