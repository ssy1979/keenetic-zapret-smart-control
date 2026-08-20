[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+\.\d+-generic$')]
    [string]$Tag,
    [string]$MergeCommit,
    [switch]$ForceTag,
    [int]$WatchSeconds = 15
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$git = (Get-Command git -ErrorAction Stop).Source
$gh = (Get-Command gh -ErrorAction Stop).Source

function Invoke-Git([string[]]$GitArgs) {
    & $git -c credential.helper= -C $repoRoot @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git failed: $($GitArgs -join ' ')" }
}
function Invoke-Gh([string[]]$GhArgs) {
    & $gh @GhArgs
    if ($LASTEXITCODE -ne 0) { throw "gh failed: $($GhArgs -join ' ')" }
}

$savedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$authStatusOutput = & $gh auth status --hostname github.com 2>$null | Out-String
$authStatusExitCode = $LASTEXITCODE
$ErrorActionPreference = $savedErrorActionPreference
if ($authStatusExitCode -ne 0) {
    throw 'GitHub CLI authentication is missing. Run gh auth login once; do not paste a token into this script.'
}

# GitHub CLI may be authenticated while Git's credential helper is empty.
# Bridge the already-authenticated CLI token to Git for this process only;
# never print or persist it.
$cliToken = (& $gh auth token).Trim()
if (-not $cliToken) { throw 'GitHub CLI returned no token.' }
$tokenBytes = [Text.Encoding]::ASCII.GetBytes("x-access-token:$cliToken")
$basic = [Convert]::ToBase64String($tokenBytes)
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'http.https://github.com/.extraheader'
$env:GIT_CONFIG_VALUE_0 = "AUTHORIZATION: basic $basic"
$env:GIT_TERMINAL_PROMPT = '0'

# Windows may mark the shared workspace as dubious when PowerShell and the
# desktop app use different owners. Trust only this exact repository path.
& $git config --global --add safe.directory $repoRoot
if ($LASTEXITCODE -ne 0) { throw 'Unable to register the repository as safe.' }

$remote = (& $git -C $repoRoot remote get-url github 2>$null)
if ($LASTEXITCODE -ne 0 -or $remote -notmatch 'github.com[:/]ssy1979/keenetic-zapret-smart-control') {
    throw 'The github remote is not configured for ssy1979/keenetic-zapret-smart-control.'
}

Invoke-Git @('fetch', 'github', 'main', '--tags')
if (-not $MergeCommit) { $MergeCommit = (& $git -C $repoRoot rev-parse 'github/main') }
& $git -C $repoRoot cat-file -e "$MergeCommit^{commit}"
if ($LASTEXITCODE -ne 0) { throw "Merge commit not found locally: $MergeCommit" }

$existing = (& $git -C $repoRoot tag -l $Tag)
if ($existing) {
    $existingSha = (& $git -C $repoRoot rev-list -n 1 $Tag)
    $targetSha = (& $git -C $repoRoot rev-list -n 1 $MergeCommit)
    if ($existingSha -ne $targetSha) {
        if (-not $ForceTag) { throw "Tag $Tag already points to another commit. Re-run with -ForceTag only when retagging a failed release." }
        Invoke-Git @('tag', '-f', '-a', $Tag, $MergeCommit, '-m', "KZSC $Tag")
        Invoke-Git @('push', '--force', 'github', $Tag)
    } else {
        Write-Host "Tag $Tag already points to the requested commit; continuing." -ForegroundColor Yellow
    }
} else {
    Invoke-Git @('tag', '-a', $Tag, $MergeCommit, '-m', "KZSC $Tag")
    Invoke-Git @('push', 'github', $Tag)
}

Start-Sleep -Seconds $WatchSeconds
$runsJson = & $gh run list --repo ssy1979/keenetic-zapret-smart-control --workflow 'KZSC Release' --limit 20 --json databaseId,headBranch,status,conclusion,createdAt
if ($LASTEXITCODE -ne 0) { throw 'Unable to query the KZSC Release workflow.' }
$runs = $runsJson | ConvertFrom-Json
$run = $runs | Where-Object { $_.headBranch -eq $Tag } | Sort-Object createdAt -Descending | Select-Object -First 1
if (-not $run) { throw "No KZSC Release run found for $Tag yet." }
Write-Host "Watching KZSC Release run $($run.databaseId)..." -ForegroundColor Cyan
Invoke-Gh @('run', 'watch', "$($run.databaseId)", '--repo', 'ssy1979/keenetic-zapret-smart-control', '--exit-status')
Write-Host "Release completed successfully: $Tag" -ForegroundColor Green
