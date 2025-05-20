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
        [GoogleFonts | GitHub](https://github.com/google/fonts)
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
        $googleFontsToInstall = @()

        $guid = (New-Guid).Guid
        $tempPath = Join-Path -Path $HOME -ChildPath "GoogleFonts-$guid"
        if (-not (Test-Path -Path $tempPath -PathType Container)) {
            Write-Verbose "Create folder [$tempPath]"
            $null = New-Item -Path $tempPath -ItemType Directory
        }
    }

    process {
        if ($All) {
            $googleFontsToInstall = $script:GoogleFonts
        } else {
            foreach ($fontName in $Name) {
                $googleFontsToInstall += $script:GoogleFonts | Where-Object { $_.Name -like $fontName }
            }
        }

        Write-Verbose "[$Scope] - Installing [$($googleFontsToInstall.count)] fonts"

        foreach ($googleFont in $googleFontsToInstall) {
            $URL = $googleFont.URL
            $fontName = $googleFont.Name
            $fontVariant = $GoogleFont.Variant
            $fileExtension = $URL.Split('.')[-1]
            $downloadFileName = "$fontName-$fontVariant.$fileExtension"
            $downloadPath = Join-Path -Path $tempPath -ChildPath $downloadFileName

            Write-Verbose "[$fontName] - Downloading to [$downloadPath]"
            if ($PSCmdlet.ShouldProcess("[$fontName] to [$downloadPath]", 'Download')) {
                Invoke-WebRequest -Uri $URL -OutFile $downloadPath -RetryIntervalSec 5 -MaximumRetryCount 5
            }

            Write-Verbose "[$fontName] - Install to [$Scope]"
            if ($PSCmdlet.ShouldProcess("[$fontName] to [$Scope]", 'Install font')) {
                Install-Font -Path $downloadPath -Scope $Scope -Force:$Force
                Remove-Item -Path $downloadPath -Force -Recurse
            }
        }
    }

    end {
        Write-Verbose "Remove folder [$tempPath]"
    }

    clean {
        Remove-Item -Path $tempPath -Force
    }
}
