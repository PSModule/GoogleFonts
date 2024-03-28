[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

Describe 'GoogleFonts' {
    Context 'Module' {
        It 'The module should be available' {
            Get-Module -Name 'GoogleFonts' -ListAvailable | Should -Not -BeNullOrEmpty
            Write-Verbose (Get-Module -Name 'GoogleFonts' -ListAvailable | Out-String) -Verbose
        }
        It 'The module should be importable' {
            { Import-Module -Name 'GoogleFonts' -Verbose -RequiredVersion 999.0.0 -Force } | Should -Not -Throw
        }
    }
}
