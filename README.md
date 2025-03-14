# GoogleFonts

This is a PowerShell module for installing GoogleFonts on your system. This module and repository does not contain the fonts themselves,
but rather a way to install them on your system.

🎉 Kudos to the GoogleFonts community for keeping the library going! 🎉
For any issues with the fonts themselves, please refer to the [GoogleFonts](https://github.com/google/fonts) repository.

## Prerequisites

This module depends on the [Fonts](https://psmodule.io/Fonts) module to manage fonts on the system.

## Installation

To install the module simply run the following command in a PowerShell terminal.

```powershell
Install-PSResource -Name GoogleFonts
Import-Module -Name GoogleFonts
```

## Usage

### Install a GoogleFont

To install a GoogleFont on the system you can use the following command.

```powershell
Install-GoogleFont -Name 'Roboto' # Tab completion works on name
```

To download the font from the GoogleFonts repository and install it on the system, run the following command.

```powershell
Install-GoogleFont -Name 'Roboto' -Scope AllUsers #Tab completion works on Scope too
```

### Install all GoogleFonts

To install all GoogleFonts on the system you can use the following command.

This will download and install all GoogleFonts to the current user.
```powershell
Install-GoogleFont -All
```

To install all GoogleFonts on the system for all users, run the following command.
This requires the shell to run in an elevated context (sudo or run as administrator).

```powershell
Install-GoogleFont -All -Scope AllUsers
```

## Contributing

Coder or not, you can contribute to the project! We welcome all contributions.

### For Users

If you don't code, you still sit on valuable information that can make this project even better. If you experience that the
product does unexpected things, throw errors or is missing functionality, you can help by submitting bugs and feature requests.
Please see the issues tab on this project and submit a new issue that matches your needs.

### For Developers

If you do code, we'd love to have your contributions. Please read the [Contribution guidelines](CONTRIBUTING.md) for more information.
You can either help by picking up an existing issue or submit a new one if you have an idea for a new feature or improvement.

## Links

- GoogleFonts | [GitHub](https://github.com/google/fonts) | [Web](https://fonts.google.com/)
