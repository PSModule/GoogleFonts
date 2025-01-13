function Get-GoogleFont {
    <#
        .SYNOPSIS
        Get GoogleFonts asset list

        .DESCRIPTION
        Get GoogleFonts asset list, filtered by name, from the latest release.

        .EXAMPLE
        Get-GoogleFonts

        Get all the GoogleFonts.

        .EXAMPLE
        Get-GoogleFonts -Name 'Roboto'

        Get the GoogleFont asset with the name 'Roboto'.

        .EXAMPLE
        Get-GoogleFonts -Name 'Noto*'

        Get the GoogleFont asset with the name starting with 'Noto'.
    #>
    [Alias('Get-GoogleFonts')]
    [CmdletBinding()]
    param (
        # Name of the GoogleFont to get
        [Parameter()]
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    Write-Verbose 'Selecting assets by:'
    Write-Verbose "Name:    [$Name]"
    $script:GoogleFonts | Where-Object { $_.Name -like $Name }
}
