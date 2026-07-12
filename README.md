# GoogleFonts

GoogleFonts is a PowerShell module for downloading and installing fonts from Google Fonts. The module does not
ship the fonts themselves; it fetches them from the [google/fonts](https://github.com/google/fonts) repository and
installs them on your system.

## Prerequisites

`Install-GoogleFont` requires the `Fonts` module version 1.1.21 and the `Admin` module version 1.1.6.

## Installation

Install the module from the PowerShell Gallery:

```powershell
Install-PSResource -Name GoogleFonts
Import-Module -Name GoogleFonts
```

## Usage

### List available fonts

List the fonts available from Google Fonts. Filter by name with wildcards:

```powershell
Get-GoogleFont
Get-GoogleFont -Name 'Noto*'
```

### Install a font

Install a font for the current user. Name tab-completion is supported:

```powershell
Install-GoogleFont -Name 'Roboto'
```

Install a font for all users. This requires an elevated session (sudo or run as administrator):

```powershell
Install-GoogleFont -Name 'Roboto' -Scope AllUsers
```

### Install every font

Download and install all Google Fonts for the current user:

```powershell
Install-GoogleFont -All
```

## Documentation

Documentation is published at [psmodule.io/GoogleFonts](https://psmodule.io/GoogleFonts/).

Use PowerShell help and command discovery for module details:

```powershell
Get-Command -Module GoogleFonts
Get-Help Install-GoogleFont -Examples
```

## Related links

- [google/fonts on GitHub](https://github.com/google/fonts)
- [Google Fonts](https://fonts.google.com/)
