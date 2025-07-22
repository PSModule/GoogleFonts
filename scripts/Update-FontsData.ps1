function Invoke-NativeCommand {
    <#
        .SYNOPSIS
        Executes a native command with arguments.
    #>
    [Alias('Exec', 'Run')]
    [CmdletBinding()]
    param (
        # The command to execute
        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        # The arguments to pass to the command
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    Write-Debug "Command: $Command"
    Write-Debug "Arguments: $($Arguments -join ', ')"
    $fullCommand = "$Command $($Arguments -join ' ')"

    try {
        Write-Verbose "Executing: $fullCommand"
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            $errorMessage = "Command failed with exit code $LASTEXITCODE`: $fullCommand"
            Write-Error $errorMessage -ErrorId 'NativeCommandFailed' -Category OperationStopped -TargetObject $fullCommand
        }
    } catch {
        throw
    }
}

Invoke-NativeCommand git checkout main
Invoke-NativeCommand git pull
$timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$branchName = "auto-font-update-$timeStamp"
Invoke-NativeCommand git checkout -b $branchName

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
    Invoke-NativeCommand git add .
    Invoke-NativeCommand git commit -m "Update-FontsData via script on $timeStamp"
    Invoke-NativeCommand git push --set-upstream origin $branchName
    Invoke-NativeCommand gh pr create `
        --base main `
        --head $branchName `
        --title "Auto-Update: Google Fonts Data ($timeStamp)" `
        --body 'This PR updates FontsData.json with the latest Google Fonts metadata.'

    Write-Output 'Changes detected and PR opened.'
} else {
    Write-Output 'No changes to commit.'
}
