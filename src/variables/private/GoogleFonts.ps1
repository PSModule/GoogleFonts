﻿$script:GoogleFonts = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'FontsData.json') | ConvertFrom-Json
