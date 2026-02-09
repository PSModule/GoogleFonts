Connect-GitHubApp -Organization 'PSModule' -Default

Write-Output "Checking for remaining open Auto-Update PRs after merge..."
$existingPRs = Get-GitHubPullRequest -Owner 'PSModule' -Name 'GoogleFonts' -State 'open' |
    Where-Object { $_.Title -like 'Auto-Update*' }

if ($existingPRs) {
    Write-Output "Found $($existingPRs.Count) existing Auto-Update PR(s) to close."
    foreach ($pr in $existingPRs) {
        Write-Output "Closing PR #$($pr.Number): $($pr.Title)"

        # Add a comment explaining the supersedence
        $mergedPRNumber = $env:MERGED_PR_NUMBER
        $commentLines = @(
            "This PR has been superseded by PR #$mergedPRNumber which has been merged."
            ""
            "The font data has been updated in the merged PR. This PR is now obsolete and will be closed automatically."
        )
        $comment = $commentLines -join "`n"
        New-GitHubPullRequestComment -Owner 'PSModule' -Name 'GoogleFonts' -Number $pr.Number -Body $comment

        # Close the PR
        Set-GitHubPullRequest -Owner 'PSModule' -Name 'GoogleFonts' -Number $pr.Number -State 'closed'

        Write-Output "Successfully closed PR #$($pr.Number)"
    }
} else {
    Write-Output "No remaining open Auto-Update PRs to close."
}
