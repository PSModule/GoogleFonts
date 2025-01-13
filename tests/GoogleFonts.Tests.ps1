Describe 'Module' {
    Context 'Function: Get-GoogleFont' {
        It 'Returns all fonts' {
            $fonts = Get-GoogleFont
            Write-Verbose ($fonts | Out-String) -Verbose
            $fonts | Should -Not -BeNullOrEmpty
        }

        It 'Returns a specific font' {
            $font = Get-GoogleFont -Name 'Roboto'
            Write-Verbose ($font | Out-String) -Verbose
            $font | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Function: Install-GoogleFont' {
        It '[Install-GoogleFont] - Installs a font' {
            { Install-GoogleFont -Name 'Akshar' } | Should -Not -Throw
            Get-Font -Name 'Akshar*' | Should -Not -BeNullOrEmpty
        }
    }
}
