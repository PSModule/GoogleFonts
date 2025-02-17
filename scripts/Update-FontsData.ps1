Connect-GitHubApp -Organization PSModule

git checkout main
git pull

# 2. Retrieve the date-time to create a unique branch name.
$timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$branchName = "auto-font-update-$timeStamp"

# 3. Create a new branch for the changes.
git checkout -b $branchName

# 4. Retrieve the latest font data from Google Fonts.
$GOOGLE_DEVELOPER_API_KEY = $env:GOOGLE_DEVELOPER_API_KEY
$fontList = Invoke-RestMethod -Uri "https://www.googleapis.com/webfonts/v1/webfonts?key=$GOOGLE_DEVELOPER_API_KEY"
$fontFamilies = $fontList.items
$fonts = @()

foreach ($fontFamily in $fontFamilies) {
    $variants = $fontFamily.files.PSObject.Properties
    foreach ($variant in $variants) {
        $fonts += [ordered]@{
            Name    = $fontFamily.family
            Variant = $variant.Name
            URL     = $variant.Value
        }
    }
}

# 5. Write results to FontsData.json.
$parentFolder = Split-Path -Path $PSScriptRoot -Parent
$filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'

# Make sure file exists (or overwrite).
$null = New-Item -Path $filePath -ItemType File -Force
$fonts | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Force

# 6. Check if anything actually changed.
#    If git status --porcelain is empty, there are no new changes to commit.
$changes = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($changes)) {
    # 7. Commit and push changes.
    git add .
    git commit -m "Update-FontsData via script on $timeStamp"
    git push --set-upstream origin $branchName

    # 8. Create a PR via GitHub CLI.
    gh pr create `
        --base main `
        --head $branchName `
        --title "Auto-Update: Google Fonts Data ($timeStamp)" `
        --body 'This PR updates FontsData.json with the latest Google Fonts metadata.'

    Write-Output 'Changes detected and PR opened.'
} else {
    Write-Output 'No changes to commit.'
}
