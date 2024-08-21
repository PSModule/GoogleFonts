[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

Write-Verbose "Path to the module: [$Path]" -Verbose

Describe 'GoogleFonts' {
    Context 'Get-PSModule' {
        It 'should greet the world' {
            $Name = 'World'
            $Expected = "Hello, $Name!"
            $Actual = Get-PSModule -Name $Name
            $Actual | Should -Be $Expected
        }
    }
}
