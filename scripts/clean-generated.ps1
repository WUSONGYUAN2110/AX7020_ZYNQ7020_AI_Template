<#
.SYNOPSIS
    Remove build outputs without deleting Vivado or Vitis projects.

.DESCRIPTION
    Removes only known caches, run outputs, logs, captures, and Vitis build
    directories. Vivado XPR/srcs/gen and the complete Vitis workspace/project
    metadata are always preserved. Published bit/XSA/LTX/ELF/BIN/manifests are
    preserved unless -IncludePublished is explicitly supplied.
#>
[CmdletBinding()]
param(
    [switch]$IncludePublished,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\', '/')
$RepoPrefix = $RepoRoot + [IO.Path]::DirectorySeparatorChar
$PrjRoot = Join-Path $RepoRoot 'prj'
$VitisRoot = Join-Path $RepoRoot 'vitis'
$script:RemovedPaths = 0
$script:RemovedBytes = [UInt64]0

function Get-ConfigValue {
    param([Parameter(Mandatory)][string]$Name)

    $config = Join-Path $RepoRoot 'config.tcl'
    $line = Select-String -LiteralPath $config -Pattern ('^\s*set\s+template_config\({0}\)\s+"([^"]+)"' -f [regex]::Escape($Name)) |
        Select-Object -First 1
    if ($null -eq $line) { throw "Missing template_config($Name) in config.tcl." }
    return $line.Matches[0].Groups[1].Value
}

function Assert-SafeGeneratedTarget {
    param([Parameter(Mandatory)][IO.FileSystemInfo]$Item)

    $full = [IO.Path]::GetFullPath($Item.FullName)
    if ($full.Equals($RepoRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not $full.StartsWith($RepoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing cleanup target outside the repository: $full"
    }
    return $full
}

function Get-GeneratedSize {
    param([Parameter(Mandatory)][IO.FileSystemInfo]$Item)

    if (-not $Item.PSIsContainer) { return [UInt64]$Item.Length }
    $sum = [UInt64]0
    foreach ($file in Get-ChildItem -LiteralPath $Item.FullName -File -Force -Recurse -ErrorAction Stop) {
        $sum += [UInt64]$file.Length
    }
    return $sum
}

function Remove-GeneratedItem {
    param([Parameter(Mandatory)][IO.FileSystemInfo]$Item)

    $full = Assert-SafeGeneratedTarget $Item
    $bytes = Get-GeneratedSize $Item
    Write-Host "CLEAN: path=$full bytes=$bytes dry_run=$([int][bool]$DryRun)"
    $script:RemovedPaths++
    $script:RemovedBytes += $bytes
    if ($DryRun) { return }

    Remove-Item -LiteralPath $full -Recurse -Force
    if (Test-Path -LiteralPath $full) {
        throw "Generated path still exists after cleanup: $full"
    }
}

function Remove-GeneratedPath {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-GeneratedItem (Get-Item -LiteralPath $Path -Force)
    }
}

try {
    foreach ($relative in @('.Xil', 'logs', 'captures')) {
        $path = Join-Path $RepoRoot $relative
        if (Test-Path -LiteralPath $path) {
            Remove-GeneratedItem (Get-Item -LiteralPath $path -Force)
        }
    }

    # Keep *.xpr, *.srcs, and *.gen: together they are the reusable Vivado
    # project. Only implementation/simulation outputs and caches are removed.
    $workspacePattern = '^(?:\.Xil|aie_primitive\.json|ps7_init.*|\..*\.(?:bit|tmp)|.*\.(?:structure\.manifest|mark_debug\.xdc|ila_debug\.xdc|ila_post\.tcl|cache|hw|incremental|ioplanning|ip_user_files|runs|sim))$'
    $publishedPattern = '^.*\.(?:bit|xsa|ltx|hardware\.manifest)$'
    foreach ($item in Get-ChildItem -LiteralPath $PrjRoot -Force) {
        if ($item.Name -match $workspacePattern -or
            ($IncludePublished -and $item.Name -match $publishedPattern)) {
            Remove-GeneratedItem $item
        }
    }

    # Keep the Vitis workspace, platform, application, domains, metadata, and
    # project descriptors. Remove only known build products inside the projects.
    $appName = Get-ConfigValue 'app_name'
    $platformName = Get-ConfigValue 'platform_name'
    foreach ($path in @(
            (Join-Path $VitisRoot 'logs'),
            (Join-Path $VitisRoot 'boot'),
            (Join-Path $VitisRoot '.Xil'),
            (Join-Path $VitisRoot '.managed_build_required'),
            (Join-Path $VitisRoot '.metadata\.log'),
            (Join-Path $VitisRoot "$appName\Debug"),
            (Join-Path $VitisRoot "$appName\Release"),
            (Join-Path $VitisRoot "$platformName\export")
        )) {
        Remove-GeneratedPath $path
    }
    foreach ($item in Get-ChildItem -LiteralPath $VitisRoot -File -Force) {
        if ($item.Extension -in @('.log', '.jou', '.str')) {
            Remove-GeneratedItem $item
        }
    }

    if ($IncludePublished) {
        foreach ($item in Get-ChildItem -LiteralPath $VitisRoot -File -Force) {
            if ($item.Name -match '^.*\.(?:elf|bin|manifest)$') {
                Remove-GeneratedItem $item
            }
        }
    }

    if ($IncludePublished) {
        $sdBoot = Join-Path $RepoRoot 'sd_boot'
        if (Test-Path -LiteralPath $sdBoot) {
            Remove-GeneratedItem (Get-Item -LiteralPath $sdBoot -Force)
        }
    }

    Write-Host "SUCCESS: Build-output cleanup completed; Vivado and Vitis projects were preserved."
    Write-Host "RESULT: status=PASS action=clean-generated paths=$script:RemovedPaths bytes=$script:RemovedBytes dry_run=$([int][bool]$DryRun) include_published=$([int][bool]$IncludePublished)"
    Write-Host "NEXT: Re-run only the required build step."
}
catch {
    Write-Host "RESULT: status=FAIL action=clean-generated paths=$script:RemovedPaths bytes=$script:RemovedBytes"
    Write-Host "DIAGNOSTIC: $($_.Exception.Message)"
    exit 1
}
