function Invoke-NativeCommand {
    <#
        .SYNOPSIS
        Executes a native command with arguments.
    #>
    [Alias('Exec', 'Run')]
    [CmdletBinding()]
    param (
        # The command to execute
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$InputObject
    )

    process {
        Write-Debug "InputObject: $InputObject"
        foreach ($item in $InputObject) {
            Write-Debug "Processing item: $item"
            $commandwitharguments = $InputObject -join ' '
        }
    }

    end {
        $command = $inputObject[0]
        $arguments = $inputObject[1..$inputObject.Length]
        Write-Debug "Command: $command"
        Write-Debug "Arguments: $($arguments -join ', ')"
        $fullCommand = "$command $($arguments -join ' ')"

        try {
            Write-Verbose "Executing: $fullCommand"
            & $command @arguments
            if ($LASTEXITCODE -ne 0) {
                $errorMessage = "Command failed with exit code $LASTEXITCODE`: $fullCommand"
                Write-Error $errorMessage -ErrorId 'NativeCommandFailed' -Category OperationStopped -TargetObject $fullCommand
            }
        } catch {
            throw
        }
    }
}

# Get the current branch and default branch information
$currentBranch = (Invoke-NativeCommand git rev-parse --abbrev-ref HEAD).Trim()
$defaultBranch = (Invoke-NativeCommand git remote show origin | Select-String 'HEAD branch:' | ForEach-Object { $_.ToString().Split(':')[1].Trim() })

Write-Output "Current branch: $currentBranch"
Write-Output "Default branch: $defaultBranch"

# Fetch latest changes from remote
Invoke-NativeCommand git fetch origin

# Get the head branch (latest default branch)
Invoke-NativeCommand git checkout $defaultBranch
Invoke-NativeCommand git pull origin $defaultBranch

$timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Determine target branch based on current context
if ($currentBranch -eq $defaultBranch) {
    # Running on main/default branch - create new branch
    $targetBranch = "auto-font-update-$timeStamp"
    Write-Output "Running on default branch. Creating new branch: $targetBranch"
    Invoke-NativeCommand git checkout -b $targetBranch
} else {
    # Running on another branch (e.g., workflow_dispatch) - use current branch
    $targetBranch = $currentBranch
    Write-Output "Running on feature branch. Using existing branch: $targetBranch"
    Invoke-NativeCommand git checkout $targetBranch
    # Merge latest changes from default branch
    Invoke-NativeCommand git merge origin/$defaultBranch
}

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

LogGroup 'Latest Fonts' {
    $fonts | Sort-Object Name | Format-Table -AutoSize | Out-String
}

$parentFolder = Split-Path -Path $PSScriptRoot -Parent
$filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'
$null = New-Item -Path $filePath -ItemType File -Force
$fonts | ConvertTo-Json | Set-Content -Path $filePath -Force

$changes = Invoke-NativeCommand git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($changes)) {
    Write-Output 'Changes detected:'
    Write-Output $changes

    # Show what will be committed
    Write-Output 'Diff of changes to be committed:'
    Invoke-NativeCommand git diff --cached HEAD -- src/FontsData.json 2>$null
    if ($LASTEXITCODE -ne 0) {
        # If --cached doesn't work (no staged changes), show unstaged diff
        Invoke-NativeCommand git diff HEAD -- src/FontsData.json
    }

    Invoke-NativeCommand git add .
    Invoke-NativeCommand git commit -m "Update-FontsData via script on $timeStamp"

    # Show the commit that was just created
    Write-Output 'Commit created:'
    Invoke-NativeCommand git log -1 --oneline

    # Show diff between HEAD and previous commit
    Write-Output 'Changes in this commit:'
    Invoke-NativeCommand git diff HEAD~1 HEAD -- src/FontsData.json

    # Push behavior depends on branch type
    if ($targetBranch -eq $currentBranch -and $currentBranch -ne $defaultBranch) {
        # Push to existing branch
        Invoke-NativeCommand git push origin $targetBranch
        Write-Output "Changes committed and pushed to existing branch: $targetBranch"
    } else {
        # Push new branch and create PR
        Invoke-NativeCommand git push --set-upstream origin $targetBranch

        Invoke-NativeCommand gh pr create `
            --base $defaultBranch `
            --head $targetBranch `
            --title "Auto-Update: Google Fonts Data ($timeStamp)" `
            --body 'This PR updates FontsData.json with the latest Google Fonts metadata.'

        Write-Output "Changes detected and PR opened for branch: $targetBranch"
    }
} else {
    Write-Output 'No changes to commit.'
}
