[CmdletBinding()]
param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot
try {
    $tool = 'tools/kzsc-hazirlayici'
    & $Python -m pip install -r "$tool/requirements.txt" pyinstaller==6.22.1
    if ($LASTEXITCODE -ne 0) { throw 'Preparer build dependencies failed.' }
    & $Python -m unittest discover -s "$tool/tests" -v
    if ($LASTEXITCODE -ne 0) { throw 'Preparer regression tests failed.' }
    $pyiArgs = @('--noconfirm', '--clean', '--onedir', '--windowed',
        '--name', 'KZSC-Hazirlayici', '--specpath', 'build', '--add-data', "$tool/profile.json;.",
        '--runtime-hook', "$tool/pyi_tk_runtime.py")
    $iconSource = 'tools/kzsc-assets/keenetic-manager.avif'
    if (Test-Path -LiteralPath $iconSource) {
        $iconIco = Join-Path $repoRoot 'build/kzsc-preparer.ico'
        New-Item -ItemType Directory -Path (Split-Path $iconIco) -Force | Out-Null
        $magick = Get-Command magick -ErrorAction Stop
        & $magick.Source $iconSource '-define' 'icon:auto-resize=16,24,32,48,64,128,256' $iconIco
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $iconIco)) { throw 'Application icon conversion failed.' }
        $pyiArgs += @('--icon', $iconIco)
    }
    $pyiArgs += "$tool/app.py"
    & $Python -m PyInstaller @pyiArgs
    if ($LASTEXITCODE -ne 0) { throw 'Windows executable build failed.' }
    $packageRoot = Join-Path $repoRoot 'dist/KZSC-Hazirlayici'
    Copy-Item "$tool/profile.json" "$packageRoot/kzsc-profile.json"
    Copy-Item 'docs/KURULUM.md' "$packageRoot/KULLANIM.md"
    Copy-Item 'docs/INSTALLATION.md' "$packageRoot/INSTALLATION.md"
    Copy-Item 'docs/images' "$packageRoot/images" -Recurse -Force
    Copy-Item 'LICENSE' "$packageRoot/LICENSE"
    Copy-Item 'THIRD_PARTY_NOTICES.md' "$packageRoot/THIRD_PARTY_NOTICES.md"
    $exe = Join-Path $packageRoot 'KZSC-Hazirlayici.exe'
    $smoke = Start-Process -FilePath $exe -ArgumentList '--smoke-test' -WindowStyle Hidden -PassThru
    if (-not $smoke.WaitForExit(60000)) {
        $smoke.Kill()
        throw 'Packaged preparer smoke test timed out.'
    }
    if ($smoke.ExitCode -ne 0) { throw "Packaged preparer smoke test failed: $($smoke.ExitCode)" }
    $match = Select-String -Path "$tool/core.py" -Pattern '^APP_VERSION = "([^"]+)"$'
    if (@($match).Count -ne 1) { throw 'APP_VERSION could not be read uniquely.' }
    $version = $match.Matches[0].Groups[1].Value
    $asset = Join-Path $repoRoot "KZSC-Hazirlayici-v$version.zip"
    Compress-Archive -LiteralPath $packageRoot -DestinationPath $asset -CompressionLevel Optimal -Force
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $asset).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($asset))" | Set-Content -LiteralPath "$asset.sha256" -Encoding ascii
    Write-Output "Verified Windows package: $asset"
} finally {
    Pop-Location
}
