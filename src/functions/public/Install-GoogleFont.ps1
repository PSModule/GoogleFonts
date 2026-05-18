#Requires -Modules @{ ModuleName = 'Fonts'; RequiredVersion = '1.1.21' }
#Requires -Modules @{ ModuleName = 'Admin'; RequiredVersion = '1.1.6' }

function Install-GoogleFont {
    <#
        .SYNOPSIS
        Installs Google Fonts to the system.

        .DESCRIPTION
        Installs Google Fonts to the system.

        .EXAMPLE
        Install-GoogleFont -Name 'Roboto'

        Installs the font 'Roboto' to the current user.

        .EXAMPLE
        Install-GoogleFont -Name Zen*

        Installs all fonts that match the pattern 'Zen*' to the current user.

        .EXAMPLE
        Install-GoogleFont -Name 'Roboto' -Scope AllUsers

        Installs the font 'Roboto' to all users. This requires to be run as administrator.

        .EXAMPLE
        Install-GoogleFont -All

        Installs all Google Fonts to the current user.

        .LINK
        https://psmodule.io/GoogleFonts/Functions/Install-GoogleFont

        .NOTES
        More information about the GoogleFonts can be found at:
        [GoogleFonts](https://fonts.google.com/) | [GitHub](https://github.com/google/fonts)
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'ByName',
        SupportsShouldProcess
    )]
    [Alias('Install-GoogleFonts')]
    param(
        # Specify the name of the GoogleFont(s) to install.
        [Parameter(
            ParameterSetName = 'ByName',
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [SupportsWildcards()]
        [string[]] $Name,

        # Specify to install all GoogleFont(s).
        [Parameter(
            ParameterSetName = 'All',
            Mandatory
        )]
        [switch] $All,

        # Specify the scope of where to install the font(s).
        [Parameter()]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'CurrentUser',

        # Force will overwrite existing fonts
        [Parameter()]
        [switch] $Force
    )

    begin {
        $previousProgressPreference = $ProgressPreference
        if ($Scope -eq 'AllUsers' -and -not (Test-Admin)) {
            $errorMessage = @'
Administrator rights are required to install fonts.
Please run the command again with elevated rights (Run as Administrator) or provide '-Scope CurrentUser' to your command.
'@
            throw $errorMessage
        }
        $googleFontsToInstall = [System.Collections.Generic.List[object]]::new()
        $seenUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        $guid = (New-Guid).Guid
        $tempPath = Join-Path -Path $HOME -ChildPath "GoogleFonts-$guid"
    }

    process {
        if ($All) {
            foreach ($googleFont in $script:GoogleFonts) {
                if ($seenUrls.Add($googleFont.URL)) {
                    $googleFontsToInstall.Add($googleFont)
                }
            }
            return
        }
        foreach ($fontName in $Name) {
            foreach ($googleFont in $script:GoogleFonts) {
                if ($googleFont.Name -like $fontName -and $seenUrls.Add($googleFont.URL)) {
                    $googleFontsToInstall.Add($googleFont)
                }
            }
        }
    }

    end {
        Write-Verbose "[$Scope] - Requested [$($googleFontsToInstall.Count)] fonts"

        if (-not $Force) {
            $installedNames = [string[]](Get-Font -Scope $Scope -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
            $installedFamilies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($n in $installedNames) {
                if ($n) { [void]$installedFamilies.Add($n) }
            }
            $knownFamilies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($gf in $script:GoogleFonts) {
                [void]$knownFamilies.Add($gf.Name)
            }
            $toProcess = [System.Collections.Generic.List[object]]::new()
            foreach ($googleFont in $googleFontsToInstall) {
                $fontName = $googleFont.Name
                $skip = $false
                if ($installedFamilies.Contains($fontName)) {
                    $skip = $true
                } else {
                    $prefix = "$fontName "
                    foreach ($family in $installedFamilies) {
                        if ($family.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and
                            -not $knownFamilies.Contains($family)) {
                            $skip = $true; break
                        }
                    }
                }
                if ($skip) {
                    Write-Verbose "[$fontName] - Already installed, skipping"
                    continue
                }
                $toProcess.Add($googleFont)
            }
            $googleFontsToInstall = $toProcess
        }

        Write-Verbose "[$Scope] - Installing [$($googleFontsToInstall.Count)] fonts"

        $isWin = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
        $isMac = ($PSVersionTable.PSVersion.Major -ge 6) -and $IsMacOS
        if ($isWin) {
            $cacheRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PSModule/GoogleFonts/cache'
        } elseif ($isMac) {
            $cacheRoot = Join-Path $HOME 'Library/Caches/PSModule/GoogleFonts'
        } else {
            $linuxCacheBase = if ([string]::IsNullOrWhiteSpace($env:XDG_CACHE_HOME)) {
                Join-Path $HOME '.cache'
            } else {
                $env:XDG_CACHE_HOME
            }
            $cacheRoot = Join-Path $linuxCacheBase 'PSModule/GoogleFonts'
        }
        Write-Verbose "[$Scope] - Cache root: [$cacheRoot]"

        $throttle = [Environment]::ProcessorCount
        $maxRetryCount = 5
        $retryDelaySeconds = 5
        $downloadFailures = [System.Collections.Generic.List[string]]::new()

        $pending = [System.Collections.Generic.List[object]]::new()
        foreach ($googleFont in $googleFontsToInstall) {
            $URL = $googleFont.URL
            $fontName = $googleFont.Name
            if (-not $PSCmdlet.ShouldProcess("[$fontName] to [$Scope]", 'Install font')) {
                continue
            }
            $fontVariant = $googleFont.Variant
            $fileExtension = $URL.Split('.')[-1]
            $downloadFileName = "$fontName-$fontVariant.$fileExtension"
            $downloadPath = Join-Path -Path $tempPath -ChildPath $downloadFileName
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            try {
                $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($URL))
            } finally {
                $sha256.Dispose()
            }
            $urlHash = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant().Substring(0, 16)
            $safeDownloadFileName = ($downloadFileName -replace '[^a-zA-Z0-9._-]', '_')
            $cachePath = Join-Path -Path $cacheRoot -ChildPath "$urlHash-$safeDownloadFileName"

            $pending.Add([pscustomobject]@{
                    Name         = $fontName
                    URL          = $URL
                    DownloadPath = $downloadPath
                    CachePath    = $cachePath
                    FromCache    = (-not $Force) -and (Test-Path -LiteralPath $cachePath)
                })
        }

        if ($pending.Count -eq 0) {
            return
        }

        if (-not (Test-Path -Path $tempPath -PathType Container)) {
            Write-Verbose "Create folder [$tempPath]"
            $null = New-Item -Path $tempPath -ItemType Directory
        }
        if (-not (Test-Path -Path $cacheRoot -PathType Container)) {
            $null = New-Item -Path $cacheRoot -ItemType Directory -Force
        }

        foreach ($item in $pending) {
            if ($item.FromCache) {
                try {
                    Write-Verbose "[$($item.Name)] - Cache hit, copying from [$($item.CachePath)]"
                    Copy-Item -LiteralPath $item.CachePath -Destination $item.DownloadPath -Force -ErrorAction Stop
                } catch {
                    Write-Verbose "[$($item.Name)] - Cache copy failed, will download instead: $($_.Exception.Message)"
                    $item.FromCache = $false
                }
            }
        }

        $toDownload = @($pending | Where-Object { -not $_.FromCache })
        if ($toDownload.Count -gt 0) {
            foreach ($item in $toDownload) {
                Write-Verbose "[$($item.Name)] - Cache miss, downloading from [$($item.URL)]"
            }
            $disableParallelDownloads = (
                $script:DisableParallelDownloadsForTests -eq $true -or
                $env:PSMODULE_GOOGLEFONTS_DISABLE_PARALLEL -eq '1'
            )
            $useParallelDownloads = (
                $PSVersionTable.PSVersion.Major -ge 7 -and
                -not $disableParallelDownloads
            )

            if ($useParallelDownloads) {
                $downloadResults = @(
                    $toDownload | ForEach-Object -Parallel {
                        $item = $_
                        $downloadSucceeded = $false
                        $lastError = $null

                        for ($attempt = 1; $attempt -le $using:maxRetryCount -and -not $downloadSucceeded; $attempt++) {
                            try {
                                $currentProgressPreference = $ProgressPreference
                                $ProgressPreference = 'SilentlyContinue'
                                try {
                                    Invoke-WebRequest -Uri $item.URL -OutFile $item.DownloadPath -ErrorAction Stop
                                } finally {
                                    $ProgressPreference = $currentProgressPreference
                                }

                                try {
                                    Copy-Item -LiteralPath $item.DownloadPath -Destination $item.CachePath -Force -ErrorAction Stop
                                } catch {
                                    Write-Verbose "[$($item.Name)] - Cache write failed: $($_.Exception.Message)"
                                }

                                $downloadSucceeded = $true
                            } catch {
                                $lastError = $_.Exception.Message
                                if ($attempt -lt $using:maxRetryCount) {
                                    Start-Sleep -Seconds $using:retryDelaySeconds
                                }
                            }
                        }

                        [pscustomobject]@{
                            Name    = $item.Name
                            URL     = $item.URL
                            Success = $downloadSucceeded
                            Error   = $lastError
                        }
                    } -ThrottleLimit $throttle
                )
            } else {
                $downloadResults = foreach ($item in $toDownload) {
                    $downloadSucceeded = $false
                    $lastError = $null

                    for ($attempt = 1; $attempt -le $maxRetryCount -and -not $downloadSucceeded; $attempt++) {
                        try {
                            $currentProgressPreference = $ProgressPreference
                            $ProgressPreference = 'SilentlyContinue'
                            try {
                                Invoke-WebRequest -Uri $item.URL -OutFile $item.DownloadPath -ErrorAction Stop
                            } finally {
                                $ProgressPreference = $currentProgressPreference
                            }

                            try {
                                Copy-Item -LiteralPath $item.DownloadPath -Destination $item.CachePath -Force -ErrorAction Stop
                            } catch {
                                Write-Verbose "[$($item.Name)] - Cache write failed: $($_.Exception.Message)"
                            }

                            $downloadSucceeded = $true
                        } catch {
                            $lastError = $_.Exception.Message
                            if ($attempt -lt $maxRetryCount) {
                                Start-Sleep -Seconds $retryDelaySeconds
                            }
                        }
                    }

                    [pscustomobject]@{
                        Name    = $item.Name
                        URL     = $item.URL
                        Success = $downloadSucceeded
                        Error   = $lastError
                    }
                }
            }

            foreach ($result in $downloadResults) {
                if (-not $result.Success) {
                    $downloadFailures.Add("$($result.Name): $($result.Error)")
                    Write-Warning "[$($result.Name)] - Download failed after $maxRetryCount attempts: $($result.Error)"
                }
            }
        }

        foreach ($item in $pending) {
            if (-not (Test-Path -LiteralPath $item.DownloadPath)) { continue }
            Write-Verbose "[$($item.Name)] - Install to [$Scope]"
            Install-Font -Path $item.DownloadPath -Scope $Scope -Force:$Force
            Remove-Item -Path $item.DownloadPath -Force -ErrorAction SilentlyContinue
        }

        if ($downloadFailures.Count -gt 0) {
            $failureSummary = $downloadFailures -join '; '
            throw "One or more font downloads failed: $failureSummary"
        }
    }

    clean {
        try {
            if ($tempPath -and (Test-Path -Path $tempPath -PathType Container)) {
                Write-Verbose "Remove folder [$tempPath]"
                Remove-Item -Path $tempPath -Force -Recurse -ErrorAction SilentlyContinue
            }
        } finally {
            $ProgressPreference = $previousProgressPreference
        }
    }
}
