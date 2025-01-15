function Get-GoogleFont {
    <#
        .SYNOPSIS
        Get GoogleFonts list

        .DESCRIPTION
        Get GoogleFonts list, filtered by name, from the latest release.

        .EXAMPLE
        Get-GoogleFonts

        Get all the GoogleFonts.

        .EXAMPLE
        Get-GoogleFonts -Name 'Roboto'

        Get the GoogleFont with the name 'Roboto'.

        .EXAMPLE
        Get-GoogleFonts -Name 'Noto*'

        Get the GoogleFont with the name starting with 'Noto'.
    #>
    [Alias('Get-GoogleFonts')]
    [OutputType([System.Object[]])]
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
