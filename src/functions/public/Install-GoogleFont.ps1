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
        if ($Scope -eq 'AllUsers' -and -not (IsAdmin)) {
            $errorMessage = @'
Administrator rights are required to install fonts.
Please run the command again with elevated rights (Run as Administrator) or provide '-Scope CurrentUser' to your command."
'@
            throw $errorMessage
        }
        $previousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $googleFontsToInstall = [System.Collections.Generic.List[object]]::new()
        $seenUrls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        $guid = (New-Guid).Guid
        $tempPath = Join-Path -Path $HOME -ChildPath "GoogleFonts-$guid"
        if (-not (Test-Path -Path $tempPath -PathType Container)) {
            Write-Verbose "Create folder [$tempPath]"
            $null = New-Item -Path $tempPath -ItemType Directory
        }
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
            $toProcess = [System.Collections.Generic.List[object]]::new()
            foreach ($googleFont in $googleFontsToInstall) {
                $fontName = $googleFont.Name
                $skip = $false
                foreach ($family in $installedFamilies) {
                    if ($family -like "$fontName*") { $skip = $true; break }
                }
                if (-not $skip) { $toProcess.Add($googleFont) }
            }
            $googleFontsToInstall = $toProcess
        }

        Write-Verbose "[$Scope] - Installing [$($googleFontsToInstall.Count)] fonts"

        if ($IsWindows) {
            $cacheRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PSModule/GoogleFonts/cache'
        } else {
            $cacheRoot = Join-Path $HOME '.cache/PSModule/GoogleFonts'
        }
        if (-not (Test-Path -Path $cacheRoot -PathType Container)) {
            $null = New-Item -Path $cacheRoot -ItemType Directory -Force
        }

        $sha = [System.Security.Cryptography.SHA1]::Create()
        $httpClient = [System.Net.Http.HttpClient]::new()
        $httpClient.Timeout = [TimeSpan]::FromMinutes(5)
        $throttle = [Environment]::ProcessorCount
        try {
            $pending = [System.Collections.Generic.List[object]]::new()
            foreach ($googleFont in $googleFontsToInstall) {
                $URL = $googleFont.URL
                $fontName = $googleFont.Name
                $fontVariant = $googleFont.Variant
                $fileExtension = $URL.Split('.')[-1]
                $downloadFileName = "$fontName-$fontVariant.$fileExtension"
                $downloadPath = Join-Path -Path $tempPath -ChildPath $downloadFileName
                $urlHash = ([System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($URL)))).Replace('-', '')
                $cachePath = Join-Path -Path $cacheRoot -ChildPath "$urlHash.$fileExtension"

                $pending.Add([pscustomobject]@{
                        Name         = $fontName
                        URL          = $URL
                        DownloadPath = $downloadPath
                        CachePath    = $cachePath
                        FromCache    = (Test-Path -LiteralPath $cachePath)
                    })
            }

            foreach ($item in $pending) {
                if ($item.FromCache) {
                    Write-Verbose "[$($item.Name)] - Cache hit, copying from [$($item.CachePath)]"
                    Copy-Item -LiteralPath $item.CachePath -Destination $item.DownloadPath -Force
                }
            }

            $toDownload = @($pending | Where-Object { -not $_.FromCache })
            for ($i = 0; $i -lt $toDownload.Count; $i += $throttle) {
                $chunk = $toDownload[$i..([math]::Min($i + $throttle - 1, $toDownload.Count - 1))]
                $tasks = foreach ($item in $chunk) {
                    Write-Verbose "[$($item.Name)] - Downloading to [$($item.DownloadPath)]"
                    [pscustomobject]@{ Item = $item; Task = $httpClient.GetByteArrayAsync($item.URL) }
                }
                foreach ($t in $tasks) {
                    try {
                        $bytes = $t.Task.GetAwaiter().GetResult()
                        [System.IO.File]::WriteAllBytes($t.Item.DownloadPath, $bytes)
                        try {
                            [System.IO.File]::WriteAllBytes($t.Item.CachePath, $bytes)
                        } catch {
                            Write-Verbose "Cache write failed: $($_.Exception.Message)"
                        }
                    } catch {
                        Write-Warning "[$($t.Item.Name)] - Download failed: $($_.Exception.Message)"
                    }
                }
            }

            foreach ($item in $pending) {
                if (-not (Test-Path -LiteralPath $item.DownloadPath)) { continue }
                Write-Verbose "[$($item.Name)] - Install to [$Scope]"
                if ($PSCmdlet.ShouldProcess("[$($item.Name)] to [$Scope]", 'Install font')) {
                    Install-Font -Path $item.DownloadPath -Scope $Scope -Force:$Force
                    Remove-Item -Path $item.DownloadPath -Force -Recurse
                }
            }
        } finally {
            $httpClient.Dispose()
            $sha.Dispose()
        }
        Write-Verbose "Remove folder [$tempPath]"
    }

    clean {
        Remove-Item -Path $tempPath -Force
        if ($previousProgressPreference) {
            $ProgressPreference = $previousProgressPreference
        }
    }
}
