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
