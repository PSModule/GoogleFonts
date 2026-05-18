#Requires -Version 7.0
[CmdletBinding()]
param(
    [int] $PullRequestNumber,

    [string] $Owner = 'PSModule',

    [string] $Repository = 'GoogleFonts',

    [ValidateRange(5, 3600)]
    [int] $PollIntervalSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitHubJson {
    <#
    .SYNOPSIS
    Runs a GitHub CLI command and parses JSON output.
    #>
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    $output = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $joined = $output -join [Environment]::NewLine
        throw "gh $($Arguments -join ' ') failed with exit code $LASTEXITCODE.`n$joined"
    }

    $text = $output -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

function Get-ItemCount {
    <#
    .SYNOPSIS
    Returns a safe count for null, scalar, or array inputs.
    #>
    param([object] $InputObject)

    return @($InputObject).Count
}

function Get-ActivePullRequestNumber {
    <#
    .SYNOPSIS
    Returns the active pull request number for a repository.
    #>
    param([string] $Repo)

    $pr = Invoke-GitHubJson -Arguments @('pr', 'view', '--repo', $Repo, '--json', 'number')
    if ($null -eq $pr -or $null -eq $pr.number) {
        throw 'Could not detect an active pull request. Provide -PullRequestNumber explicitly.'
    }

    return [int] $pr.number
}

function Get-UnresolvedCopilotThread {
    <#
    .SYNOPSIS
    Returns unresolved review threads that contain Copilot comments.
    #>
    param(
        [string] $RepoOwner,
        [string] $RepoName,
        [int] $PrNumber
    )

    $query = @(
        'query($owner:String!, $repo:String!, $pr:Int!, $threadCursor:String) {'
        '  repository(owner:$owner, name:$repo) {'
        '    pullRequest(number:$pr) {'
        '      reviewThreads(first:50, after:$threadCursor) {'
        '        pageInfo {'
        '          hasNextPage'
        '          endCursor'
        '        }'
        '        nodes {'
        '          isResolved'
        '          comments(last:50) {'
        '            nodes {'
        '              author { login }'
        '              body'
        '              url'
        '              createdAt'
        '            }'
        '          }'
        '        }'
        '      }'
        '    }'
        '  }'
        '}'
    ) -join [Environment]::NewLine

    $copilotThreads = [System.Collections.Generic.List[object]]::new()
    $threadCursor = $null

    do {
        $arguments = @(
            'api',
            'graphql',
            '-f', "query=$query",
            '-F', "owner=$RepoOwner",
            '-F', "repo=$RepoName",
            '-F', "pr=$PrNumber"
        )
        if (-not [string]::IsNullOrWhiteSpace($threadCursor)) {
            $arguments += @('-F', "threadCursor=$threadCursor")
        }

        $payload = Invoke-GitHubJson -Arguments $arguments

        $reviewThreads = $payload.data.repository.pullRequest.reviewThreads
        $threads = @($reviewThreads.nodes)

        foreach ($thread in $threads) {
            if ($thread.isResolved) {
                continue
            }

            $comments = @($thread.comments.nodes)
            if (-not $comments) {
                continue
            }

            $hasCopilotComment = $false
            foreach ($comment in $comments) {
                $author = $comment.author.login
                if ($author -match 'copilot') {
                    $hasCopilotComment = $true
                    break
                }
            }

            if ($hasCopilotComment) {
                $latestComment = $comments | Sort-Object createdAt -Descending | Select-Object -First 1
                $preview = if ($latestComment.body.Length -gt 120) {
                    "$($latestComment.body.Substring(0, 120))..."
                } else {
                    $latestComment.body
                }

                $copilotThreads.Add([pscustomobject]@{
                        Url       = $latestComment.url
                        CreatedAt = $latestComment.createdAt
                        Preview   = $preview
                    })
            }
        }

        if ($reviewThreads.pageInfo.hasNextPage) {
            $threadCursor = $reviewThreads.pageInfo.endCursor
        } else {
            $threadCursor = $null
        }
    } while ($threadCursor)

    return @($copilotThreads.ToArray())
}

function Get-PullRequestSnapshot {
    <#
    .SYNOPSIS
    Collects CI and Copilot status signals for a pull request.
    #>
    param(
        [string] $RepoOwner,
        [string] $RepoName,
        [int] $PrNumber
    )

    $repo = "$RepoOwner/$RepoName"
    $pr = Invoke-GitHubJson -Arguments @(
        'pr',
        'view',
        "$PrNumber",
        '--repo',
        $repo,
        '--json',
        'url,headRefOid,reviewRequests,reviews'
    )

    $headSha = $pr.headRefOid
    $commit = Invoke-GitHubJson -Arguments @('api', "repos/$repo/commits/$headSha")
    $headCommitTime = [DateTimeOffset]::Parse($commit.commit.committer.date)

    $allReviews = @($pr.reviews)
    $copilotReviews = @($allReviews | Where-Object {
            $_.author.login -match 'copilot'
        })
    $latestCopilotReview = $copilotReviews | Sort-Object submittedAt -Descending | Select-Object -First 1

    $reviewRequests = @($pr.reviewRequests)
    $pendingCopilotRequest = @($reviewRequests | Where-Object { $_.login -match 'copilot' })

    $latestCopilotReviewTime = $null
    if ($latestCopilotReview) {
        $latestCopilotReviewTime = [DateTimeOffset]::Parse($latestCopilotReview.submittedAt)
    }

    $copilotReviewedCurrentHead = $false
    if ($null -ne $latestCopilotReviewTime -and $latestCopilotReviewTime -ge $headCommitTime) {
        $copilotReviewedCurrentHead = $true
    }

    $unresolvedCopilotThreads = Get-UnresolvedCopilotThread -RepoOwner $RepoOwner -RepoName $RepoName -PrNumber $PrNumber

    $checks = @()
    try {
        $checks = @(Invoke-GitHubJson -Arguments @(
                'pr',
                'checks',
                "$PrNumber",
                '--repo',
                $repo,
                '--json',
                'name,state,bucket,workflow,link'
            ))
    } catch {
        # Some repositories can briefly return no checks while workflow data is still being prepared.
        $checks = @()
    }

    $pendingStates = @('PENDING', 'IN_PROGRESS', 'QUEUED', 'WAITING', 'REQUESTED')
    $failedStates = @('FAILURE', 'ERROR', 'TIMED_OUT', 'ACTION_REQUIRED', 'CANCELLED', 'STARTUP_FAILURE')

    $pendingChecks = @($checks | Where-Object {
            $_.bucket -eq 'pending' -or $pendingStates -contains $_.state
        })
    $failedChecks = @($checks | Where-Object {
            $_.bucket -eq 'fail' -or $failedStates -contains $_.state
        })

    $checkCount = Get-ItemCount -InputObject $checks
    $pendingCheckCount = Get-ItemCount -InputObject $pendingChecks
    $failedCheckCount = Get-ItemCount -InputObject $failedChecks
    $copilotThreadCount = Get-ItemCount -InputObject $unresolvedCopilotThreads
    $pendingCopilotRequestCount = Get-ItemCount -InputObject $pendingCopilotRequest

    $ciGreen = ($checkCount -gt 0 -and $pendingCheckCount -eq 0 -and $failedCheckCount -eq 0)
    $copilotNoComments = ($copilotThreadCount -eq 0)
    $copilotReviewComplete = ($pendingCopilotRequestCount -eq 0)

    [pscustomobject]@{
        PullRequestNumber          = $PrNumber
        PullRequestUrl             = $pr.url
        HeadSha                    = $headSha
        HeadCommitTime             = $headCommitTime
        LatestCopilotReviewTime    = $latestCopilotReviewTime
        CopilotReviewedCurrentHead = $copilotReviewedCurrentHead
        PendingCopilotRequests     = @($pendingCopilotRequest)
        UnresolvedCopilotThreads   = @($unresolvedCopilotThreads)
        Checks                     = @($checks)
        PendingChecks              = @($pendingChecks)
        FailedChecks               = @($failedChecks)
        CiGreen                    = $ciGreen
        CopilotNoComments          = $copilotNoComments
        CopilotReviewComplete      = $copilotReviewComplete
        Ready                      = ($ciGreen -and $copilotNoComments -and $copilotReviewComplete)
    }
}

$repoRef = "$Owner/$Repository"
if (-not $PullRequestNumber) {
    $PullRequestNumber = Get-ActivePullRequestNumber -Repo $repoRef
}

Write-Output "Watching PR #$PullRequestNumber in $repoRef"
Write-Output 'This loop only exits when CI is green and Copilot has no unresolved comments for the latest head commit.'

$round = 0
while ($true) {
    $round++
    $now = (Get-Date).ToString('u')
    Write-Output ''
    Write-Output "[$now] Poll round $round"

    $snapshot = Get-PullRequestSnapshot -RepoOwner $Owner -RepoName $Repository -PrNumber $PullRequestNumber

    Write-Output "PR: $($snapshot.PullRequestUrl)"
    Write-Output "Head SHA: $($snapshot.HeadSha)"
    Write-Output "CI green: $($snapshot.CiGreen)"
    Write-Output "Copilot review complete for head: $($snapshot.CopilotReviewComplete)"
    Write-Output "Copilot unresolved thread count: $($snapshot.UnresolvedCopilotThreads.Count)"

    if ($snapshot.FailedChecks.Count -gt 0) {
        Write-Output 'Failing checks:'
        foreach ($check in $snapshot.FailedChecks) {
            Write-Output "  - $($check.name) [$($check.state)]"
        }
    }

    if ($snapshot.PendingChecks.Count -gt 0) {
        Write-Output 'Pending checks:'
        foreach ($check in $snapshot.PendingChecks) {
            Write-Output "  - $($check.name) [$($check.state)]"
        }
    }

    if (-not $snapshot.CopilotReviewComplete) {
        if ($snapshot.PendingCopilotRequests.Count -gt 0) {
            Write-Output 'Copilot review is still requested and pending.'
        }

        if (-not $snapshot.CopilotReviewedCurrentHead) {
            if ($null -eq $snapshot.LatestCopilotReviewTime) {
                Write-Output 'Copilot has not posted a review yet for this PR.'
            } else {
                Write-Output "Latest Copilot review: $($snapshot.LatestCopilotReviewTime.ToString('u'))"
                Write-Output "Latest head commit:    $($snapshot.HeadCommitTime.ToString('u'))"
            }
        }
    }

    if ($snapshot.UnresolvedCopilotThreads.Count -gt 0) {
        Write-Output 'Unresolved Copilot threads:'
        foreach ($thread in $snapshot.UnresolvedCopilotThreads) {
            Write-Output "  - $($thread.Url)"
        }
    }

    if ($snapshot.Ready) {
        Write-Output ''
        Write-Output 'All gates are green. CI is successful and Copilot has no unresolved comments.'
        break
    }

    Write-Output "Waiting $PollIntervalSeconds seconds before checking comments and pipeline status again..."
    Start-Sleep -Seconds $PollIntervalSeconds
}