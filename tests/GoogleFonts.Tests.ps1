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

        It '[Install-GoogleFont] - Skips an already-installed font' {
            { Install-GoogleFont -Name 'Akshar' } | Should -Not -Throw
            $verboseOutput = Install-GoogleFont -Name 'Akshar' -Verbose 4>&1
            ($verboseOutput | Out-String) | Should -Match 'Installing \[0\] fonts'
        }

        It '[Install-GoogleFont] - Supports wildcard names' {
            { Install-GoogleFont -Name 'ABee*' } | Should -Not -Throw
            Get-Font -Name 'ABee*' | Should -Not -BeNullOrEmpty
        }

        # It '[Install-GoogleFont] - Installs all fonts' {
        #     { Install-GoogleFont -All -Verbose } | Should -Not -Throw
        #     Get-Font -Name 'Nabla*' | Should -Not -BeNullOrEmpty
        # }
    }

    InModuleScope GoogleFonts {
        Context 'Function: Install-GoogleFont (mocked download paths)' {
            BeforeEach {
                $script:originalGoogleFonts = $script:GoogleFonts
                $script:originalDisableParallel = $env:PSMODULE_GOOGLEFONTS_DISABLE_PARALLEL
                $script:originalDisableParallelForTests = $script:DisableParallelDownloadsForTests
                $env:PSMODULE_GOOGLEFONTS_DISABLE_PARALLEL = '1'
                $script:DisableParallelDownloadsForTests = $true

                $script:GoogleFonts = @(
                    [pscustomobject]@{
                        Name    = 'UnitTestFont'
                        Variant = 'regular'
                        URL     = 'https://example.invalid/unittestfont.ttf'
                    }
                )

                Mock -CommandName Get-Font -MockWith { @() }
                Mock -CommandName Install-Font -MockWith { }
                Mock -CommandName Copy-Item -MockWith { }
                Mock -CommandName New-Item -MockWith { [pscustomobject]@{ FullName = 'mock' } }
                Mock -CommandName Test-Admin -MockWith { $true }
            }

            AfterEach {
                $script:GoogleFonts = $script:originalGoogleFonts
                $env:PSMODULE_GOOGLEFONTS_DISABLE_PARALLEL = $script:originalDisableParallel
                $script:DisableParallelDownloadsForTests = $script:originalDisableParallelForTests
            }

            It '[Install-GoogleFont] - Uses cache hit path without new download' {
                Mock -CommandName Test-Path -MockWith {
                    param(
                        [string] $Path,
                        [string] $LiteralPath,
                        [object] $PathType
                    )

                    if ($PSBoundParameters.ContainsKey('LiteralPath')) {
                        return $true
                    }

                    return $true
                }

                Mock -CommandName Invoke-WebRequest -MockWith {
                    throw 'Invoke-WebRequest should not be called when cache is used'
                }

                { Install-GoogleFont -Name 'UnitTestFont' -Confirm:$false } | Should -Not -Throw
                Assert-MockCalled -CommandName Invoke-WebRequest -Times 0 -Exactly
                Assert-MockCalled -CommandName Copy-Item -Times 1
                Assert-MockCalled -CommandName Install-Font -Times 1 -Exactly
            }

            It '[Install-GoogleFont] - Throws for AllUsers scope without admin rights' {
                Mock -CommandName Test-Admin -MockWith { $false }

                { Install-GoogleFont -Name 'UnitTestFont' -Scope AllUsers -Confirm:$false } | Should -Throw
            }
        }
    }
}
