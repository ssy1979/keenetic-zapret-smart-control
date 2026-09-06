[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^v\d+\.\d+\.\d+\.\d+-generic$')]
    [string]$Tag,
    [string]$MergeCommit,
    [int]$WatchSeconds = 0
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$git = (Get-Command git -ErrorAction Stop).Source
$gh = (Get-Command gh -ErrorAction Stop).Source
$safe = "safe.directory=$($repoRoot.Replace('\','/'))"
function Git([string[]]$Args) { & $git -c $safe -C $repoRoot @Args; if ($LASTEXITCODE) { throw "git failed: $($Args -join ' ')" } }
function Gh([string[]]$Args) { & $gh @Args; if ($LASTEXITCODE) { throw "gh failed: $($Args -join ' ')" } }
& $gh auth status --hostname github.com 2>$null | Out-Null
if ($LASTEXITCODE) { throw 'GitHub CLI authentication is missing. Run gh auth login.' }
$remote = (& $git -c $safe -C $repoRoot remote get-url origin 2>$null)
if ($remote -notmatch 'github.com[:/]ssy1979/keenetic-zapret-smart-control') { throw 'origin is not the expected KZSC repository.' }
Git @('fetch','origin','main','--tags')
if (-not $MergeCommit) { $MergeCommit = (& $git -c $safe -C $repoRoot rev-parse 'origin/main').Trim() }
& $git -c $safe -C $repoRoot cat-file -e "$MergeCommit^{commit}"; if ($LASTEXITCODE) { throw 'Merge commit is not available.' }
$canonical = ((Get-Content (Join-Path $repoRoot 'opt/kzsc/bin/kzsc-maintenance.sh') | Select-String '^VERSION="([^"]+)"$').Matches[0].Groups[1].Value)
if ($Tag -ne "v$canonical") { throw "Tag does not match canonical version v$canonical." }
$existing = (& $git -c $safe -C $repoRoot rev-parse "$Tag^{commit}" 2>$null)
if ($existing) { if ($existing.Trim() -ne $MergeCommit.Trim()) { throw "Tag $Tag already points elsewhere; refusing to retag." } } else { Git @('tag','-a',$Tag,$MergeCommit,'-m',"KZSC $Tag"); Git @('push','origin',$Tag) }
if ($WatchSeconds -gt 0) { Start-Sleep -Seconds ([Math]::Min($WatchSeconds,60)) }
Write-Host "Tag ready: $Tag ($MergeCommit)" -ForegroundColor Green
