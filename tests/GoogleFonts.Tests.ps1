#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0'; MaximumVersion = '6.*' }

Describe 'Module' {
    Context 'Function: Get-GoogleFont' {
        It 'Returns all fonts' {
            $fonts = Get-GoogleFont
            Write-Verbose ($fonts | Out-String) -Verbose
            $fonts | Should-NotBeNull
        }

        It 'Returns a specific font' {
            $font = Get-GoogleFont -Name 'Roboto'
            Write-Verbose ($font | Out-String) -Verbose
            $font | Should-NotBeNull
        }
    }

    Context 'Function: Install-GoogleFont' {
        It '[Install-GoogleFont] - Installs a font' {
            Install-GoogleFont -Name 'Akshar'
            Get-Font -Name 'Akshar*' | Should-NotBeNull
        }

        # It '[Install-GoogleFont] - Installs all fonts' {
        #     Install-GoogleFont -All -Verbose
        #     Get-Font -Name 'Nabla*' | Should-NotBeNull
        # }
    }
}
