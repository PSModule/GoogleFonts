function Get-GoogleFont {
    <#
        .SYNOPSIS
        Get GoogleFonts asset list

        .DESCRIPTION
        Get GoogleFonts asset list, filtered by name, from the latest release.

        .EXAMPLE
        Get-GoogleFonts -Name 'Roboto'

        Get the GoogleFont asset with the name 'Roboto'.

        .EXAMPLE
        Get-GoogleFonts -Name 'Roboto' -Variant 'regular'

        Get the GoogleFont asset with the name 'Roboto' and the variant 'regular'.

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
        [string] $Name = '*',

        # Variant of the font to get
        [Parameter()]
        [SupportsWildcards()]
        [string] $Variant = '*'
    )

    Write-Verbose 'Selecting assets by:'
    Write-Verbose "Name:    [$Name]"
    Write-Verbose "Variant: [$Variant]"
    $script:GoogleFonts | Where-Object { $_.Name -like $Name -and $_.Variant -like $Variant }
}
