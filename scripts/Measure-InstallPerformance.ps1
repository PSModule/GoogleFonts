#Requires -Version 7.0
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Performance script intentionally uses Write-Host')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ResultsPath', Justification = 'Used via splatting')]
param(
    [Parameter(Mandatory)]
    [string] $Iteration,

    [string[]] $Subset = @('Roboto', 'Open Sans', 'Inter'),

    [switch] $IncludeAll,

    [string] $ResultsPath = (Join-Path $PSScriptRoot 'perf-results.jsonl')
)

function Invoke-Uninstall {
    <#
    .SYNOPSIS
    Uninstalls matching Google Fonts before a measurement run.
    #>
    param([string[]] $Names)
    foreach ($n in $Names) {
        $installed = Get-Font -Scope CurrentUser -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$n*" }
        if ($installed) {
            Uninstall-Font -Name $installed.Name -Scope CurrentUser -ErrorAction SilentlyContinue
        }
    }
}

function Measure-Scenario {
    <#
    .SYNOPSIS
    Measures a single install scenario and records the result.
    #>
    param(
        [string] $Name,
        [scriptblock] $Setup,
        [scriptblock] $Action
    )
    Write-Host "[$Iteration] Setup    : $Name"
    & $Setup | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Host "[$Iteration] Measure  : $Name"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $err = $null
    try { & $Action | Out-Null } catch { $err = $_.Exception.Message }
    $sw.Stop()
    $obj = [pscustomobject]@{
        Iteration  = $Iteration
        Scenario   = $Name
        DurationMs = [int]$sw.Elapsed.TotalMilliseconds
        DurationS  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        Timestamp  = (Get-Date).ToString('o')
        Error      = $err
        Module     = (Get-Module GoogleFonts | Select-Object -First 1 -ExpandProperty Version).ToString()
    }
    ($obj | ConvertTo-Json -Compress) | Add-Content -LiteralPath $ResultsPath
    Write-Host "[$Iteration] Result   : $Name -> $($obj.DurationS)s"
    return $obj
}

$results = @()

$results += Measure-Scenario -Name 'Single-Roboto' `
    -Setup { Invoke-Uninstall -Names 'Roboto' } `
    -Action { Install-GoogleFont -Name 'Roboto' }

$results += Measure-Scenario -Name "Subset-$($Subset -join '+')" `
    -Setup { Invoke-Uninstall -Names $Subset } `
    -Action { Install-GoogleFont -Name $Subset }

$results += Measure-Scenario -Name 'Subset-AlreadyInstalled' `
    -Setup { } `
    -Action { Install-GoogleFont -Name $Subset }

if ($IncludeAll) {
    $results += Measure-Scenario -Name 'All' `
        -Setup { } `
        -Action { Install-GoogleFont -All }
}

Write-Host ''
Write-Host "Summary for iteration '$Iteration':"
$results | Format-Table -AutoSize Iteration, Scenario, DurationS, Module
