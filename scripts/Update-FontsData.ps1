﻿$GOOGLE_DEVELOPER_API_KEY = $env:GOOGLE_DEVELOPER_API_KEY
$fontList = Invoke-RestMethod -Uri "https://www.googleapis.com/webfonts/v1/webfonts?key=$GOOGLE_DEVELOPER_API_KEY"
$fontFamilies = $fontList.items
$fonts = @()
foreach ($fontFamily in $fontFamilies) {
    $variants = $fontFamily.files.PSObject.Properties
    foreach ($variant in $variants) {
        $fonts += [ordered]@{
            Name    = $fontFamily.family
            Variant = $variant.Name
            URL     = $variant.Value
        }
    }
}

New-Item -Path 'data/GoogleFonts.json' -ItemType File -Force
$fonts | ConvertTo-Json | Set-Content -Path 'data/GoogleFonts.json' -Encoding utf8BOM -Force

git add .
git commit -m 'Update-FontsData'
git push
