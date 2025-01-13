#Requires -Modules @{ ModuleName = 'Admin'; RequiredVersion = '1.1.1' }
#Requires -Modules @{ ModuleName = 'Fonts'; RequiredVersion = '1.1.11' }

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
        Install-GoogleFont -Name 'Roboto' -Scope AllUsers

        Installs the font 'Roboto' to all users. This requires to be run as administrator.

        .EXAMPLE
        Install-GoogleFont -All

        Installs all Google Fonts to the current user.
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'Name',
        SupportsShouldProcess
    )]
    [Alias('Install-GoogleFonts')]
    param(
        # Specify the name of the Google Font(s) to install.
        [Parameter(
            ParameterSetName = 'Name',
            Mandatory
        )]
        [string[]] $Name,

        # Specify to install all Google Font(s).
        [Parameter(ParameterSetName = 'All', Mandatory)]
        [switch] $All,

        # Specify the scope of where to install the font(s).
        [Parameter()]
        [Scope] $Scope = 'CurrentUser'
    )

    begin {
        if ($Scope -eq 'AllUsers' -and -not (IsAdmin)) {
            $errorMessage = @'
Administrator rights are required to install fonts.
Please run the command again with elevated rights (Run as Administrator) or provide '-Scope CurrentUser' to your command."
'@
            throw $errorMessage
        }
        $GoogleFontsToInstall = @()

        $guid = (New-Guid).Guid
        $tempPath = Join-Path -Path $HOME -ChildPath "GoogleFonts-$guid"
        if (-not (Test-Path -Path $tempPath -PathType Container)) {
            Write-Verbose "Create folder [$tempPath]"
            $null = New-Item -Path $tempPath -ItemType Directory
        }
    }

    process {
        if ($All) {
            $GoogleFontsToInstall = $script:GoogleFonts
        } else {
            $fontList = @()
            foreach ($fontName in $Name) {
                Write-Verbose "[$fontName] - Searching for font"
                $filteredFonts = $script:GoogleFonts | Where-Object { $_.Name -like $fontName }
                Write-Verbose "[$fontName] - Found [$($filteredFonts.count)] fonts"
                $fontList += $filteredFonts
            }
        }

        Write-Verbose "[$Scope] - Installing [$($GoogleFontsToInstall.count)] fonts"

        foreach ($GoogleFont in $GoogleFontsToInstall) {
            $URL = $GoogleFont.URL
            $fontName = $GoogleFont.Name
            $fontVariant = $GoogleFont.Variant
            $fileName = "$fontName-$fontVariant.ttf"
            $downloadPath = Join-Path -Path $tempPath -ChildPath "$fileName"

            Write-Verbose "[$fontName] - Downloading to [$downloadPath]"
            if ($PSCmdlet.ShouldProcess($fontName, "Download $fontName")) {
                Invoke-WebRequest -Uri $URL -OutFile $downloadPath -Verbose:$false -RetryIntervalSec 5 -MaximumRetryCount 5
            }

            Write-Verbose "[$fontName] - Install to [$Scope]"
            if ($PSCmdlet.ShouldProcess($fontName, 'Install font')) {
                Install-Font -Path $downloadPath -Scope $Scope
                Remove-Item -Path $downloadPath -Force -Recurse
            }
        }
    }

    end {
        Write-Verbose "Remove folder [$tempPath]"
        Remove-Item -Path $tempPath -Force
    }
}
