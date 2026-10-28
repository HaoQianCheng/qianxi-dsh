# 富江破甲卸载脚本

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$pluginName     = 'fujiang-armor'
$pluginLabel    = '富江破甲'
$targetPlugins  = @($pluginName)

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "    [OK] $Msg" -ForegroundColor Green }

$dshRoot     = if ($env:DSH_HOME) { [IO.Path]::GetFullPath($env:DSH_HOME) } else { Join-Path $env:USERPROFILE '.dsh' }
$pluginsDir  = Join-Path $dshRoot 'plugins'

Write-Step '查找 profile 配置'
if ($env:DSH_PROFILE -and ($env:DSH_PROFILE -match '[/\\]' -or $env:DSH_PROFILE -in @('.', '..'))) { throw 'DSH_PROFILE 必须是单个配置目录名。' }
$names = if ($env:DSH_PROFILE) { @($env:DSH_PROFILE) } else { @(Get-ChildItem -LiteralPath (Join-Path $dshRoot 'profiles') -Directory | ForEach-Object { $_.Name }) }
$dirs = @($names | ForEach-Object { Join-Path (Join-Path $dshRoot 'profiles') $_ } | Where-Object { Test-Path (Join-Path $_ 'package.json') })
if ($dirs.Count -eq 0) { throw "未找到目标 DSH 配置 $env:DSH_PROFILE，已停止卸载。" }
$keepSharedPlugin = $false
if ($env:DSH_PROFILE) {
    $others = @(Get-ChildItem -LiteralPath (Join-Path $dshRoot 'profiles') -Directory | Where-Object { $_.Name -ne $env:DSH_PROFILE })
    foreach ($other in $others) {
        $otherPkgPath = Join-Path $other.FullName 'package.json'
        if (Test-Path -LiteralPath $otherPkgPath) {
            $otherPkg = Get-Content -LiteralPath $otherPkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($otherPkg.dependencies -and $otherPkg.dependencies.PSObject.Properties.Name -contains $pluginName) {
                $keepSharedPlugin = $true
            }
        }
    }
}

foreach ($pDir in $dirs) {
    $pName = Split-Path $pDir -Leaf
    $pkgPath = Join-Path $pDir 'package.json'
    $pkg = Get-Content -LiteralPath $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $changed = $false
    foreach ($p in $targetPlugins) {
        if ($pkg.dependencies -and $pkg.dependencies.PSObject.Properties.Name -contains $p) {
            $pkg.dependencies.PSObject.Properties.Remove($p)
            $changed = $true
        }
        if ($pkg.dsh -and $pkg.dsh.profile -and $pkg.dsh.profile.bundles -contains $p) {
            $pkg.dsh.profile.bundles = @($pkg.dsh.profile.bundles | Where-Object { $_ -ne $p })
            $changed = $true
        }
    }
    if ($changed) {
        $json = $pkg | ConvertTo-Json -Depth 10
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($pkgPath, $json + [Environment]::NewLine, $utf8NoBom)
        Write-Ok "[$pName] 已从 package.json 移除插件配置"
    }

    # 清理 cordis.patch.yml
    $patchPath = Join-Path $pDir 'cordis.patch.yml'
    if (Test-Path $patchPath) {
        $patchContent = [System.IO.File]::ReadAllText($patchPath, [System.Text.Encoding]::UTF8)
        $cleanedPatch = $patchContent
        foreach ($old in $targetPlugins) {
            $cleanedPatch = $cleanedPatch -replace "(?m)^([ \t]*)-[ \t]+insert:[ \t]*\r?\n[ \t]+-[ \t]+id:[ \t]+$old[ \t]*(?:\r?\n|\z)[\s\S]*?(?=^\1-[ \t]|\z)", ""
        }
        $cleanedPatch = $cleanedPatch.Trim()
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($patchPath, $cleanedPatch + [Environment]::NewLine, $utf8NoBom)
        Write-Ok "[$pName] 已从 cordis.patch.yml 移除插件挂载"
    }

    # 清除 node_modules 中的软链/拷贝
    foreach ($old in $targetPlugins) {
        $nmEntry = Join-Path $pDir "node_modules\$old"
        if (Test-Path $nmEntry) {
            try {
                if ((Get-Item $nmEntry).LinkType -eq 'Junction') {
                    Remove-Item -LiteralPath $nmEntry -Force
                } else {
                    Remove-Item -LiteralPath $nmEntry -Recurse -Force
                }
            } catch {
                Remove-Item -LiteralPath $nmEntry -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Ok "[$pName] 已清理 node_modules\$old"
        }
    }

    if ($changed) {
        Push-Location $pDir
        try {
            if (Get-Command pnpm.cmd -ErrorAction SilentlyContinue) { & pnpm.cmd install | Out-Null }
            elseif (Get-Command npm.cmd -ErrorAction SilentlyContinue) { & npm.cmd exec --yes --package=pnpm@10 -- pnpm install | Out-Null }
            else { Write-Host '    已清理插件注册；未找到 npm/pnpm，依赖锁文件需在下次安装依赖时同步。' }
            if ($LASTEXITCODE -ne 0) { throw "依赖同步失败，退出码 $LASTEXITCODE。" }
        } finally { Pop-Location }
    }
}

foreach ($p in $targetPlugins) {
    $tDir = Join-Path $pluginsDir $p
    if (-not $keepSharedPlugin -and (Test-Path $tDir)) {
        if ((Get-Item -LiteralPath $tDir).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw '插件目录是链接，请先检查。' }
        if ([IO.Path]::GetFullPath($tDir) -ne (Join-Path ([IO.Path]::GetFullPath($pluginsDir)) $pluginName)) { throw '插件目录路径校验失败。' }
        Remove-Item -LiteralPath $tDir -Recurse -Force
        Write-Ok "已删除插件目录：$p"
    }
}

Write-Ok "$pluginLabel 卸载完成，请重启 DeepSeek Harness。"
