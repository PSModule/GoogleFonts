﻿function Invoke-NativeCommand {
    <#
        .SYNOPSIS
        Executes a native command with arguments.
    #>
    [Alias('Exec', 'Run')]
    [CmdletBinding()]
    param (
        # The command to execute
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Command
    )
    $cmd = $Command[0]
    $arguments = $Command[1..$Command.Length]
    Write-Debug "Command: $cmd"
    Write-Debug "Arguments: $($arguments -join ', ')"
    $fullCommand = "$cmd $($arguments -join ' ')"

    try {
        Write-Verbose "Executing: $fullCommand"
        $output = & $cmd @arguments
        if ($LASTEXITCODE -ne 0) {
            $errorMessage = "Command failed with exit code $LASTEXITCODE`: $fullCommand"
            Write-Error $errorMessage -ErrorId 'NativeCommandFailed' -Category OperationStopped -TargetObject $fullCommand
        }
        if ($output -is [array] -and $output.Count -gt 1) {
            return $output -join "`n"
        } else {
            return $output
        }
    } catch {
        throw
    }
}

Connect-GitHubApp -Organization 'PSModule' -Default
$repo = Get-GitHubRepository -Owner 'PSModule' -Name 'GoogleFonts'

LogGroup 'Checkout' {
    $currentBranch = (Run git rev-parse --abbrev-ref HEAD).Trim()
    $defaultBranch = $repo.DefaultBranch

    Write-Output "Current branch: $currentBranch"
    Write-Output "Default branch: $defaultBranch"
    Run git fetch origin
    Run git checkout $defaultBranch
    Run git pull origin $defaultBranch

    $timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if ($currentBranch -eq $defaultBranch) {
        # Running on main/default branch - create new branch
        $targetBranch = "auto-update-font-$timeStamp"
        Write-Output "Running on default branch. Creating new branch: $targetBranch"
        Run git checkout -b $targetBranch
    } else {
        # Running on another branch (e.g., workflow_dispatch) - use current branch
        $targetBranch = $currentBranch
        Write-Output "Running on feature branch. Using existing branch: $targetBranch"
        Run git checkout $targetBranch
        # Merge latest changes from default branch
        Run git merge origin/$defaultBranch
    }
}

LogGroup 'Getting latest fonts' {
    $fontList = Invoke-RestMethod -Uri "https://www.googleapis.com/webfonts/v1/webfonts?key=$env:GOOGLE_DEVELOPER_API_KEY"
    $fontFamilies = $fontList.items
    $fonts = @()

    foreach ($fontFamily in $fontFamilies) {
        $variants = $fontFamily.files.PSObject.Properties
        foreach ($variant in $variants) {
            $fonts += [PSCustomObject]@{
                Name    = $fontFamily.family
                Variant = $variant.Name
                URL     = $variant.Value
            }
        }
    }

    $fonts | Sort-Object Name | Format-Table -AutoSize | Out-String
    $parentFolder = Split-Path -Path $PSScriptRoot -Parent
    $filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'
    $null = New-Item -Path $filePath -ItemType File -Force
    $fonts | ConvertTo-Json | Set-Content -Path $filePath -Force
}

$changes = Run git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
    Write-Output 'No updates available.'
    Write-GitHubNotice 'No updates available.'
    return
}
LogGroup 'Get changes' {
    Run git add .
    Run git commit -m "Update-FontsData via script on $timeStamp"
    Write-Output 'Changes in this commit:'
    $changes = Run git diff HEAD~1 HEAD -- src/FontsData.json
    Write-Output $changes
    Set-GitHubStepSummary @"
## Changes available

<details><summary>Details</summary>
<p>

``````diff
$changes
``````

</p>
</details>
"@

}

LogGroup 'Process changes' {
    # Push behavior depends on branch type
    if ($targetBranch -eq $currentBranch -and $currentBranch -ne $defaultBranch) {
        # Push to existing branch
        Run git push origin $targetBranch
        Write-Output "Changes committed and pushed to existing branch: $targetBranch"
    } else {
        # Push new branch and create PR
        Run git push --set-upstream origin $targetBranch

        Run gh pr create `
            --base $defaultBranch `
            --head $targetBranch `
            --title "Auto-Update: Google Fonts Data ($timeStamp)" `
            --body 'This PR updates FontsData.json with the latest Google Fonts metadata.'

        Write-Output "Changes detected and PR opened for branch: $targetBranch"
    }
}
