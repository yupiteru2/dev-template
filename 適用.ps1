<#
.SYNOPSIS
  標準開発テンプレートの配布・回収。

.EXAMPLE
  .\適用.ps1 -Global                                   # ~/.claude へ配る（全プロジェクトに効く）
  .\適用.ps1 -Project C:\Claude\新規                    # 新規プロジェクトのひな型を用意する
  .\適用.ps1 -Project C:\Claude\新規 -Skill bugfix      # プロジェクト固有スキルのひな型を作る
  .\適用.ps1 -Collect                                   # ~/.claude の変更を global/ へ戻す
#>
[CmdletBinding()]
param(
    [switch]$Global,
    [string]$Project,
    [string]$Skill,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'

function Backup-Existing {
    param([string[]]$Paths)
    $existing = @($Paths | Where-Object { Test-Path $_ })
    if ($existing.Count -eq 0) { return $null }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir = Join-Path $ClaudeHome "_backup_$stamp"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($p in $existing) {
        Copy-Item $p -Destination $dir -Recurse -Force
    }
    return $dir
}

if (-not $Global -and -not $Collect -and -not $Project) {
    Write-Host 'いずれかを指定してください: -Global / -Project <パス> / -Collect'
    exit 1
}

# --- global/ を ~/.claude/ へ配る ---
if ($Global) {
    $targets = @(
        (Join-Path $ClaudeHome 'CLAUDE.md'),
        (Join-Path $ClaudeHome 'skills\requirement-driven')
    )
    $backup = Backup-Existing -Paths $targets
    if ($backup) { Write-Host "既存を退避しました: $backup" }

    New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeHome 'skills') | Out-Null
    Copy-Item (Join-Path $Root 'global\CLAUDE.md') -Destination $ClaudeHome -Force
    Copy-Item (Join-Path $Root 'global\skills\requirement-driven') `
        -Destination (Join-Path $ClaudeHome 'skills') -Recurse -Force
    Write-Host "適用しました: $ClaudeHome"
}

# --- ~/.claude/ の変更を global/ へ戻す ---
if ($Collect) {
    Copy-Item (Join-Path $ClaudeHome 'CLAUDE.md') `
        -Destination (Join-Path $Root 'global\CLAUDE.md') -Force
    Copy-Item (Join-Path $ClaudeHome 'skills\requirement-driven') `
        -Destination (Join-Path $Root 'global\skills') -Recurse -Force
    Write-Host '回収しました。git diff で差分を確認してからコミットしてください。'
}

# --- 新規プロジェクトのひな型 ---
if ($Project) {
    if (-not (Test-Path $Project)) {
        New-Item -ItemType Directory -Force -Path $Project | Out-Null
    }
    $claudeMd = Join-Path $Project 'CLAUDE.md'
    if (Test-Path $claudeMd) {
        Write-Host "既に存在するため CLAUDE.md は作成しません: $claudeMd"
    }
    else {
        Copy-Item (Join-Path $Root 'project\CLAUDE.md.template') -Destination $claudeMd -Force
        Write-Host "ひな型を作成しました: $claudeMd"
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $Project '.claude\skills') | Out-Null

    if ($Skill) {
        $skillDir = Join-Path $Project ".claude\skills\$Skill"
        $skillFile = Join-Path $skillDir 'SKILL.md'
        if (Test-Path $skillFile) {
            Write-Host "既に存在するため作成しません: $skillFile"
        }
        else {
            New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
            $tpl = Join-Path $Root 'project\skills\SKILL.md.template'
            $body = [System.IO.File]::ReadAllText($tpl, [System.Text.UTF8Encoding]::new($false))
            $body = $body.Replace('__SKILL_NAME__', $Skill)
            [System.IO.File]::WriteAllText($skillFile, $body, [System.Text.UTF8Encoding]::new($false))
            Write-Host "スキルのひな型を作成しました: $skillFile"
            Write-Host '  聖典を先に読ませる導線が入っています。消さないでください。'
        }
    }

    Write-Host '次にやること:'
    Write-Host '  1. CLAUDE.md の穴埋め箇所を実際の内容に置き換える'
    Write-Host '  2. プロジェクト固有スキルは -Skill で作る（手書きしない）'
    Write-Host '  3. 現場の改変が他でも通用すると分かったら global/ へ昇格させる'
}
