<#PSScriptInfo

.VERSION 3.2.6

.GUID 3b581edb-5d90-4fa1-ba15-4f2377275463

.AUTHOR asheroto, 1ckov, MisterZeus, ChrisTitusTech, uffemcev

.COMPANYNAME asheroto

.TAGS PowerShell Windows winget win get install installer fix script setup

.PROJECTURI https://github.com/asheroto/winget-install

.RELEASENOTES
[Version 0.0.1] - Initial Release.
[Version 0.0.2] - Implemented function to get the latest version of winget and its license.
[Version 0.0.3] - Signed file for PSGallery.
[Version 0.0.4] - Changed URI to grab latest release instead of releases and preleases.
[Version 0.0.5] - Updated version number of dependencies.
[Version 1.0.0] - Major refactor code, see release notes for more information.
[Version 1.0.1] - Fixed minor bug where version 2.8 was hardcoded in URL.
[Version 1.0.2] - Hardcoded UI Xaml version 2.8.4 as a failsafe in case the API fails. Added CheckForUpdates, Version, Help functions. Various bug fixes.
[Version 1.0.3] - Added error message to catch block. Fixed bug where appx package was not being installed.
[Version 1.0.4] - MisterZeus optimized code for readability.
[Version 2.0.0] - Major refactor. Reverted to UI.Xaml 2.7.3 for stability. Adjusted script to fix install issues due to winget changes (thank you ChrisTitusTech). Added in all architecture support.
[Version 2.0.1] - Renamed repo and URL references from winget-installer to winget-install. Added extra space after the last line of output.
[Version 2.0.2] - Adjusted CheckForUpdates to include Install-Script instructions and extra spacing.
[Version 2.1.0] - Added alternate method/URL for dependencies in case the main URL is down. Fixed licensing issue when winget is installed on Server 2022.
[Version 2.1.1] - Switched primary/alternate methods. Added Cleanup function to avoid errors when cleaning up temp files. Added output of URL for alternate method. Suppressed Add-AppxProvisionedPackage output. Improved success message. Improved verbiage. Improve PS script comments. Added check if the URL is empty. Moved display of URL beneath the check.
[Version 3.0.0] - Major changes. Added OS version detection checks - detects OS version, release ID, ensures compatibility. Forces older file installation for Server 2022 to avoid issues after installing. Added DebugMode, DisableCleanup, Force. Renamed CheckForUpdates to CheckForUpdate. Improved output. Improved error handling. Improved comments. Improved code readability. Moved CheckForUpdate into function. Added PowerShellGalleryName. Renamed Get-OSVersion to Get-OSInfo. Moved architecture detection into Get-OSInfo. Renamed Get-NewestLink to Get-WingetDownloadUrl. Have Get-WingetDownloadUrl not get preview releases.
[Version 3.0.1] - Updated Get-OSInfo function to fix issues when used on non-English systems. Improved error handling of "resources in use" error.
[Version 3.0.2] - Added winget registration command for Windows 10 machines.
[Version 3.1.0] - Added support for one-line installation with irm and iex compatible with $Force session variable. Added UpdateSelf command to automatically update the script to the latest version. Created short URL asheroto.com/winget.
[Version 3.1.1] - Changed winget register command to run on all OS versions.
[Version 3.2.0] - Added -ForceClose logic to relaunch the script in conhost.exe and automatically end active processes associated with winget that could interfere with the installation. Improved verbiage on winget already installed.
[Version 3.2.1] - Fixed minor glitch when using -Version or -Help parameters.
[Version 3.2.2] - Improved script exit functionality.
[Version 3.2.3] - Improved -ForceClose window handling with x86 PowerShell process.
[Version 3.2.4] - Improved verbiage for incompatible systems. Added importing Appx module on Windows Server with PowerShell 7+ systems to avoid error message.
[Version 3.2.5] - Removed pause after script completion. Added optional Wait parameter to force script to wait several seconds for script output.
[Version 3.2.6] - Improved ExitWithDelay function. Sometimes PowerShell will close the window accidentally, even when using the proper 'exit' command. Adjusted several closures for improved readability. Improved error code checking. Fixed glitch with -Wait param.

#>

<#
.SYNOPSIS
	Downloads and installs the latest version of winget and its dependencies. Updates the PATH variable if needed.
.DESCRIPTION
	Downloads and installs the latest version of winget and its dependencies. Updates the PATH variable if needed.

This script is designed to be straightforward and easy to use, removing the hassle of manually downloading, installing, and configuring winget. To make the newly installed winget available for use, a system reboot may be required after running the script.

This function should be run with administrative privileges.
.EXAMPLE
	winget-install
.PARAMETER DebugMode
    Enables debug mode, which shows additional information for debugging.
.PARAMETER DisableCleanup
    Disables cleanup of the script and prerequisites after installation.
.PARAMETER Force
    Ensures installation of winget and its dependencies, even if already present.
.PARAMETER UpdateSelf
    Updates the script to the latest version on PSGallery.
.PARAMETER CheckForUpdate
    Checks if there is an update available for the script.
.PARAMETER Version
    Displays the version of the script.
.PARAMETER Help
    Displays the full help information for the script.
.NOTES
	Version      : 3.2.6
	Created by   : asheroto
.LINK
	Project Site: https://github.com/asheroto/winget-install
#>
[CmdletBinding()]
param (
    [switch]$DebugMode,
    [switch]$DisableCleanup,
    [switch]$Force,
    [switch]$ForceClose,
    [switch]$CheckForUpdate,
    [switch]$Wait,
    [switch]$UpdateSelf,
    [switch]$Version,
    [switch]$Help
)

# Version
$CurrentVersion = '3.2.6'
$RepoOwner = 'asheroto'
$RepoName = 'winget-install'
$PowerShellGalleryName = 'winget-install'

# Versions
$ProgressPreference = 'SilentlyContinue' # Suppress progress bar (makes downloading super fast)
$ConfirmPreference = 'None' # Suppress confirmation prompts

# Display version if -Version is specified
if ($Version.IsPresent) {
    $CurrentVersion
    exit 0
}

# Display full help if -Help is specified
if ($Help) {
    Get-Help -Name $MyInvocation.MyCommand.Source -Full
    exit 0
}

# Display $PSVersionTable and Get-Host if -Verbose is specified
if ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose']) {
    $PSVersionTable
    Get-Host
}

function Get-TempFolder {
    <#
        .SYNOPSIS
        Gets the path of the current user's temp folder.

        .DESCRIPTION
        This function retrieves the path of the current user's temp folder.

        .EXAMPLE
        Get-TempFolder
    #>
    return [System.IO.Path]::GetTempPath()
}

function Get-OSInfo {
    <#
        .SYNOPSIS
        Retrieves detailed information about the operating system version and architecture.

        .DESCRIPTION
        This function queries both the Windows registry and the Win32_OperatingSystem class to gather comprehensive information about the operating system. It returns details such as the release ID, display version, name, type (Workstation/Server), numeric version, edition ID, version (object that includes major, minor, and build numbers), and architecture (OS architecture, not processor architecture).

        .EXAMPLE
        Get-OSInfo

        This example retrieves the OS version details of the current system and returns an object with properties like ReleaseId, DisplayVersion, Name, Type, NumericVersion, EditionId, Version, and Architecture.

        .EXAMPLE
        (Get-OSInfo).Version.Major

        This example retrieves the major version number of the operating system. The Get-OSInfo function returns an object with a Version property, which itself is an object containing Major, Minor, and Build properties. You can access these sub-properties using dot notation.

        .EXAMPLE
        $osDetails = Get-OSInfo
        Write-Output "OS Name: $($osDetails.Name)"
        Write-Output "OS Type: $($osDetails.Type)"
        Write-Output "OS Architecture: $($osDetails.Architecture)"

        This example stores the result of Get-OSInfo in a variable and then accesses various properties to print details about the operating system.
    #>
    [CmdletBinding()]
    param ()

    try {
        # Get registry values
        $registryValues = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $releaseIdValue = $registryValues.ReleaseId
        $displayVersionValue = $registryValues.DisplayVersion
        $nameValue = $registryValues.ProductName
        $editionIdValue = $registryValues.EditionId

        # Strip out "Server" from the $editionIdValue if it exists
        $editionIdValue = $editionIdValue -replace "Server", ""

        # Get OS details using Get-CimInstance because the registry key for Name is not always correct with Windows 11
        $osDetails = Get-CimInstance -ClassName Win32_OperatingSystem
        $nameValue = $osDetails.Caption

        # Get architecture details of the OS (not the processor)
        # Get only the numbers
        $architecture = ($osDetails.OSArchitecture -replace "[^\d]").Trim()

        # If 32-bit or 64-bit replace with x32 and x64
        if ($architecture -eq "32") {
            $architecture = "x32"
        } elseif ($architecture -eq "64") {
            $architecture = "x64"
        }

        # Get OS version details (as version object)
        $versionValue = [System.Environment]::OSVersion.Version

        # Determine product type
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.producttype?view=powershellsdk-1.1.0
        if ($osDetails.ProductType -eq 1) {
            $typeValue = "Workstation"
        } elseif ($osDetails.ProductType -eq 2 -or $osDetails.ProductType -eq 3) {
            $typeValue = "Server"
        } else {
            $typeValue = "Unknown"
        }

        # Extract numerical value from Name
        $numericVersion = ($nameValue -replace "[^\d]").Trim()

        # Create and return custom object with the required properties
        $result = [PSCustomObject]@{
            ReleaseId      = $releaseIdValue
            DisplayVersion = $displayVersionValue
            Name           = $nameValue
            Type           = $typeValue
            NumericVersion = $numericVersion
            EditionId      = $editionIdValue
            Version        = $versionValue
            Architecture   = $architecture
        }

        return $result
    } catch {
        Write-Error "Unable to get OS version details.`nError: $_"
        ExitWithDelay 1
    }
}

function Get-GitHubRelease {
    <#
        .SYNOPSIS
        Fetches the latest release information of a GitHub repository.

        .DESCRIPTION
        This function uses the GitHub API to get information about the latest release of a specified repository, including its version and the date it was published.

        .PARAMETER Owner
        The GitHub username of the repository owner.

        .PARAMETER Repo
        The name of the repository.

        .EXAMPLE
        Get-GitHubRelease -Owner "asheroto" -Repo "winget-install"
        This command retrieves the latest release version and published datetime of the winget-install repository owned by asheroto.
    #>
    [CmdletBinding()]
    param (
        [string]$Owner,
        [string]$Repo
    )
    try {
        $url = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop

        $latestVersion = $response.tag_name
        $publishedAt = $response.published_at

        # Convert UTC time string to local time
        $UtcDateTime = [DateTime]::Parse($publishedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        $PublishedLocalDateTime = $UtcDateTime.ToLocalTime()

        [PSCustomObject]@{
            LatestVersion     = $latestVersion
            PublishedDateTime = $PublishedLocalDateTime
        }
    } catch {
        Write-Error "Unable to check for updates.`nError: $_"
        exit 1
    }
}

function CheckForUpdate {
    param (
        [string]$RepoOwner,
        [string]$RepoName,
        [version]$CurrentVersion,
        [string]$PowerShellGalleryName
    )

    $Data = Get-GitHubRelease -Owner $RepoOwner -Repo $RepoName

    Write-Output ""
    Write-Output ("Repository:       {0,-40}" -f "https://github.com/$RepoOwner/$RepoName")
    Write-Output ("Current Version:  {0,-40}" -f $CurrentVersion)
    Write-Output ("Latest Version:   {0,-40}" -f $Data.LatestVersion)
    Write-Output ("Published at:     {0,-40}" -f $Data.PublishedDateTime)

    if ($Data.LatestVersion -gt $CurrentVersion) {
        Write-Output ("Status:           {0,-40}" -f "A new version is available.")
        Write-Output "`nOptions to update:"
        Write-Output "- Download latest release: https://github.com/$RepoOwner/$RepoName/releases"
        if ($PowerShellGalleryName) {
            Write-Output "- Run: $RepoName -UpdateSelf"
            Write-Output "- Run: Install-Script $PowerShellGalleryName -Force"
        }
    } else {
        Write-Output ("Status:           {0,-40}" -f "Up to date.")
    }
    exit 0
}

function UpdateSelf {
    try {
        # Get PSGallery version of script
        $psGalleryScriptVersion = (Find-Script -Name $PowerShellGalleryName).Version

        # If the current version is less than the PSGallery version, update the script
        if ($CurrentVersion -lt $psGalleryScriptVersion) {
            Write-Output "Updating script to version $psGalleryScriptVersion..."

            # Install NuGet PackageProvider if not already installed
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name "NuGet" -Force
            }

            # Trust the PSGallery if not already trusted
            $repo = Get-PSRepository -Name 'PSGallery'
            if ($repo.InstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            }

            # Update the script
            Install-Script $PowerShellGalleryName -Force

            Write-Output "Script updated to version $psGalleryScriptVersion."
            exit 0
        } else {
            Write-Output "Script is already up to date."
            exit 0
        }
    } catch {
        Write-Output "An error occurred: $_"
        exit 1
    }
}

function Write-Section($text) {
    <#
        .SYNOPSIS
        Prints a text block surrounded by a section divider for enhanced output readability.

        .DESCRIPTION
        This function takes a string input and prints it to the console, surrounded by a section divider made of hash characters.
        It is designed to enhance the readability of console output.

        .PARAMETER text
        The text to be printed within the section divider.

        .EXAMPLE
        Write-Section "Downloading Files..."
        This command prints the text "Downloading Files..." surrounded by a section divider.
    #>
    Write-Output ""
    Write-Output ("#" * ($text.Length + 4))
    Write-Output "# $text #"
    Write-Output ("#" * ($text.Length + 4))
    Write-Output ""
}

function Get-WingetDownloadUrl {
    <#
        .SYNOPSIS
        Retrieves the download URL of the latest release asset that matches a specified pattern from the GitHub repository.

        .DESCRIPTION
        This function uses the GitHub API to get information about the latest release of the winget-cli repository.
        It then retrieves the download URL for the release asset that matches a specified pattern.

        .PARAMETER Match
        The pattern to match in the asset names.

        .EXAMPLE
        Get-WingetDownloadUrl "msixbundle"
        This command retrieves the download URL for the latest release asset with a name that contains "msixbundle".
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Match
    )

    $uri = "https://api.github.com/repos/microsoft/winget-cli/releases"
    Write-Debug "Getting information from $uri"
    $releases = Invoke-RestMethod -uri $uri -Method Get -ErrorAction stop

    Write-Debug "Getting latest release..."
    foreach ($release in $releases) {
        if ($release.name -match "preview") {
            continue
        }
        $data = $release.assets | Where-Object name -Match $Match
        if ($data) {
            return $data.browser_download_url
        }
    }

    Write-Debug "Falling back to the latest release..."
    $latestRelease = $releases | Select-Object -First 1
    $data = $latestRelease.assets | Where-Object name -Match $Match
    return $data.browser_download_url
}

function Get-WingetStatus {
    <#
        .SYNOPSIS
        Checks if winget is installed.

        .DESCRIPTION
        This function checks if winget is installed.

        .EXAMPLE
        Get-WingetStatus
    #>

    # Check if winget is installed
    $winget = Get-Command -Name winget -ErrorAction SilentlyContinue

    # If winget is installed, return $true
    if ($null -ne $winget) {
        return $true
    }

    # If winget is not installed, return $false
    return $false
}

function Update-PathEnvironmentVariable {
    <#
        .SYNOPSIS
        Updates the PATH environment variable with a new path for both the User and Machine levels.

        .DESCRIPTION
        The function will add a new path to the PATH environment variable, making sure it is not a duplicate.
        If the new path is already in the PATH variable, the function will skip adding it.
        This function operates at both User and Machine levels.

        .PARAMETER NewPath
        The new directory path to be added to the PATH environment variable.

        .EXAMPLE
        Update-PathEnvironmentVariable -NewPath "C:\NewDirectory"
        This command will add the directory "C:\NewDirectory" to the PATH variable at both the User and Machine levels.
    #>
    param(
        [string]$NewPath
    )

    foreach ($Level in "Machine", "User") {
        # Get the current PATH variable
        $path = [Environment]::GetEnvironmentVariable("PATH", $Level)

        # Check if the new path is already in the PATH variable
        if (!$path.Contains($NewPath)) {
            if ($DebugMode) {
                Write-Output "Adding $NewPath to PATH variable for $Level..."
            } else {
                Write-Output "Adding PATH variable for $Level..."
            }

            # Add the new path to the PATH variable
            $path = ($path + ";" + $NewPath).Split(';') | Select-Object -Unique
            $path = $path -join ';'

            # Set the new PATH variable
            [Environment]::SetEnvironmentVariable("PATH", $path, $Level)
        } else {
            if ($DebugMode) {
                Write-Output "$NewPath already present in PATH variable for $Level, skipping."
            } else {
                Write-Output "PATH variable already present for $Level, skipping."
            }
        }
    }
}

function Handle-Error {
    <#
        .SYNOPSIS
            Handles common errors that may occur during an installation process.

        .DESCRIPTION
            This function takes an ErrorRecord object and checks for certain known error codes.
            Depending on the error code, it writes appropriate warning messages or throws the error.

        .PARAMETER ErrorRecord
            The ErrorRecord object that represents the error that was caught. This object contains
            information about the error, including the exception that was thrown.

        .EXAMPLE
            try {
                # Some code that may throw an error...
            } catch {
                Handle-Error $_
            }
            This example shows how you might use the Handle-Error function in a try-catch block.
            If an error occurs in the try block, the catch block catches it and calls Handle-Error,
            passing the error (represented by the $_ variable) to the function.
    #>
    param($ErrorRecord)

    # Store current value
    $OriginalErrorActionPreference = $ErrorActionPreference

    # Set to silently continue
    $ErrorActionPreference = 'SilentlyContinue'

    if ($ErrorRecord.Exception.Message -match '0x80073D06') {
        Write-Warning "Higher version already installed."
        Write-Warning "That's okay, continuing..."
    } elseif ($ErrorRecord.Exception.Message -match '0x80073CF0') {
        Write-Warning "Same version already installed."
        Write-Warning "That's okay, continuing..."
    } elseif ($ErrorRecord.Exception.Message -match '0x80073D02') {
        # Stop execution and return the ErrorRecord so that the calling try/catch block throws the error
        Write-Warning "Resources modified are in-use. Try closing Windows Terminal / PowerShell / Command Prompt and try again."
        Write-Warning "Windows Terminal sometimes has trouble installing winget. If you are using Windows Terminal and the problem persists, run the script with the -ForceClose parameter which will relaunch the script in conhost.exe and automatically end active processes associated with winget that could interfere with the installation. Please note that using the -ForceClose parameter will close the PowerShell window and could break custom scripts that rely on the current PowerShell session."
        return $ErrorRecord
    } elseif ($ErrorRecord.Exception.Message -match '0x80073CF3') {
        # Prerequisite not detected, tell user to run it again
        Write-Warning "Problem with one of the prerequisites."
        Write-Warning "Try running the script again which usually fixes the issue. If the problem persists, try running the script with the -ForceClose parameter which will relaunch the script in conhost.exe and automatically end active processes associated with winget that could interfere with the installation. Please note that using the -ForceClose parameter will close the PowerShell window and could break custom scripts that rely on the current PowerShell session."
        return $ErrorRecord
    } elseif ($ErrorRecord.Exception.Message -match 'Unable to connect to the remote server') {
        Write-Warning "Cannot connect to the Internet to download the required files."
        Write-Warning "Try running the script again and make sure you are connected to the Internet."
        Write-Warning "Sometimes the nuget.org server is down, so you may need to try again later."
        return $ErrorRecord
    } elseif ($ErrorRecord.Exception.Message -match "The remote name could not be resolved") {
        Write-Warning "Cannot connect to the Internet to download the required files."
        Write-Warning "Try running the script again and make sure you are connected to the Internet."
        Write-Warning "Make sure DNS is working correctly on your computer."
    } else {
        # For other errors, we should stop the execution and return the ErrorRecord so that the calling try/catch block throws the error
        return $ErrorRecord
    }

    # Reset to original value
    $ErrorActionPreference = $OriginalErrorActionPreference
}

function Cleanup {
    <#
        .SYNOPSIS
            Deletes a file or directory specified without prompting for confirmation or displaying errors.

        .DESCRIPTION
            This function takes a path to a file or directory and deletes it without prompting for confirmation or displaying errors.
            If the path is a directory, the function will delete the directory and all its contents.

        .PARAMETER Path
            The path of the file or directory to be deleted.

        .PARAMETER Recurse
            If the path is a directory, this switch specifies whether to delete the directory and all its contents.

        .EXAMPLE
            Cleanup -Path "C:\Temp"
            This example deletes the directory "C:\Temp" and all its contents.

        .EXAMPLE
            Cleanup -Path "C:\Temp" -Recurse
            This example deletes the directory "C:\Temp" and all its contents.

        .EXAMPLE
            Cleanup -Path "C:\Temp\file.txt"
            This example deletes the file "C:\Temp\file.txt".
    #>
    param (
        [string]$Path,
        [switch]$Recurse
    )

    try {
        if (Test-Path -Path $Path) {
            if ($Recurse -and (Get-Item -Path $Path) -is [System.IO.DirectoryInfo]) {
                Get-ChildItem -Path $Path -Recurse | Remove-Item -Force -Recurse
                Remove-Item -Path $Path -Force -Recurse
            } else {
                Remove-Item -Path $Path -Force
            }
        }
        if ($DebugMode) {
            Write-Output "Deleted: $Path"
        }
    } catch {
        # Errors are ignored
    }
}

function Install-Prerequisite {
    <#
        .SYNOPSIS
        Downloads and installs a prerequisite for winget.

        .DESCRIPTION
        This function takes a name, version, URL, alternate URL, content type, and body and downloads and installs the prerequisite.

        .PARAMETER Name
        The name of the prerequisite.

        .PARAMETER Version
        The version of the prerequisite.

        .PARAMETER Url
        The URL of the prerequisite.

        .PARAMETER AlternateUrl
        The alternate URL of the prerequisite.

        .PARAMETER ContentType
        The content type of the prerequisite.

        .PARAMETER Body
        The body of the prerequisite.

        .PARAMETER NupkgVersion
        The nupkg version of the prerequisite.

        .PARAMETER AppxFileVersion
        The appx file version of the prerequisite.

        .EXAMPLE
        Install-Prerequisite -Name "VCLibs" -Version "14.00" -Url "https://store.rg-adguard.net/api/GetFiles" -AlternateUrl "https://aka.ms/Microsoft.VCLibs.$arch.14.00.Desktop.appx" -ContentType "application/x-www-form-urlencoded" -Body "type=PackageFamilyName&url=Microsoft.VCLibs.140.00_8wekyb3d8bbwe&ring=RP&lang=en-US"

        Where $arch is the architecture type of the current system.
    #>
    param (
        [string]$Name,
        [string]$Url,
        [string]$AlternateUrl,
        [string]$ContentType,
        [string]$Body,
        [string]$NupkgVersion,
        [string]$AppxFileVersion
    )

    $osVersion = Get-OSInfo
    $arch = $osVersion.Architecture

    Write-Section "Downloading & installing ${arch} ${Name}..."

    $ThrowReason = @{
        Message = ""
        Code    = 0
    }
    try {
        # ============================================================================ #
        # Import Appx module on Windows Server and PowerShell version 7+
        # ============================================================================ #
        # This is to avoid the following error:
        #       The 'Add-AppxPackage' command was found in the module 'Appx', but the module could not be loaded due to the following error:
        #       [Operation is not supported on this platform. (0x80131539)]
        if ($osVersion.Type -eq "Server" -and $PSVersionTable.PSVersion.Major -ge 7) {
            if ($DebugMode) { Write-Output "Server OS with PowerShell 7+ was detected, importing Appx module..." }
            Import-Module Appx -UseWindowsPowerShell *>$null;
        } else {
            if ($DebugMode) { Write-Output "Server OS with PowerShell 7+ was not detected, skipping Appx module import..." }
        }
        if ($DebugMmode) { Write-Output "" }

        # ============================================================================ #
        # Windows 10 / Server 2022 detection
        # ============================================================================ #

        # Function to extract domain from URL
        function Get-DomainFromUrl($url) {
            $uri = [System.Uri]$url
            $domain = $uri.Host -replace "^www\."
            return $domain
        }

        # If Server 2022 or Windows 10, force non-store version of VCLibs (return true)
        $messageTemplate = "{OS} detected. Using {DOMAIN} version of {NAME}."

        # Determine the OS-specific information
        $osType = $osVersion.Type
        $osNumericVersion = $osVersion.NumericVersion

        if (($osType -eq "Server" -and $osNumericVersion -eq 2022) -or ($osType -eq "Workstation" -and $osNumericVersion -eq 10)) {
            if ($osType -eq "Server") {
                $osName = "Server 2022"
            } else {
                $osName = "Windows 10"
            }
            $domain = Get-DomainFromUrl $AlternateUrl
            $ThrowReason.Message = ($messageTemplate -replace "{OS}", $osName) -replace "{NAME}", $Name -replace "{DOMAIN}", $domain
            $ThrowReason.Code = 1
            throw
        }

        # ============================================================================ #
        # Primary method
        # ============================================================================ #

        $url = Invoke-WebRequest -Uri $Url -Method "POST" -ContentType $ContentType -Body $Body -UseBasicParsing | ForEach-Object Links | Where-Object outerHTML -match "$Name.+_${arch}__8wekyb3d8bbwe.appx" | ForEach-Object href

        # If the URL is empty, try the alternate method
        if ($url -eq "") {
            $ThrowReason.Message = "URL is empty"
            $ThrowReason.Code = 2
            throw
        }

        if ($DebugMode) {
            Write-Output "URL: ${url}`n"
        }
        Write-Output "Installing ${arch} ${Name}..."
        if ($ForceClose) {
            Add-AppxPackage $url -ErrorAction Stop -ForceApplicationShutdown
        } else {
            Add-AppxPackage $url -ErrorAction Stop
        }
        Write-Output "`n$Name installed successfully."
    } catch {
        # Alternate method
        if ($_.Exception.Message -match '0x80073D02') {
            # If resources in use exception, fail immediately
            Handle-Error $_
            throw
        }

        try {
            $url = $AlternateUrl

            # Throw reason if alternate method is required
            if ($ThrowReason.Code -eq 0) {
                Write-Warning "Error when trying to download or install $Name. Trying alternate method..."
            } else {
                Write-Warning $ThrowReason.Message
            }
            Write-Output ""

            # If the URL is empty, throw error
            if ($url -eq "") {
                throw "URL is empty"
            }

            # Specific logic for VCLibs alternate method
            if ($Name -eq "VCLibs") {
                if ($DebugMode) {
                    Write-Output "URL: $($url)`n"
                }
                Write-Output "Installing ${arch} ${Name}..."
                if ($ForceClose) {
                    Add-AppxPackage $url -ErrorAction Stop -ForceApplicationShutdown
                } else {
                    Add-AppxPackage $url -ErrorAction Stop
                }
                Write-Output "`n$Name installed successfully."
            }

            # Specific logic for UI.Xaml
            if ($Name -eq "UI.Xaml") {
                $TempFolder = Get-TempFolder

                $uiXaml = @{
                    url           = $url
                    appxFolder    = "tools/AppX/$arch/Release/"
                    appxFilename  = "Microsoft.UI.Xaml.$AppxFileVersion.appx"
                    nupkgFilename = Join-Path -Path $TempFolder -ChildPath "Microsoft.UI.Xaml.$NupkgVersion.nupkg"
                    nupkgFolder   = Join-Path -Path $TempFolder -ChildPath "Microsoft.UI.Xaml.$NupkgVersion"
                }

                # Debug
                if ($DebugMode) {
                    $formattedDebugOutput = ($uiXaml | ConvertTo-Json -Depth 10 -Compress) -replace '\\\\', '\'
                    Write-Output "uiXaml:"
                    Write-Output $formattedDebugOutput
                    Write-Output ""
                }

                # Downloading
                Write-Output "Downloading UI.Xaml..."
                if ($DebugMode) {
                    Write-Output "URL: $($uiXaml.url)"
                }
                Invoke-WebRequest -Uri $uiXaml.url -OutFile $uiXaml.nupkgFilename

                # Check if folder exists and delete if needed (will occur whether DisableCleanup is $true or $false)
                Cleanup -Path $uiXaml.nupkgFolder -Recurse

                # Extracting
                Write-Output "Extracting...`n"
                if ($DebugMode) {
                    Write-Output "Into folder: $($uiXaml.nupkgFolder)`n"
                }
                Add-Type -Assembly System.IO.Compression.FileSystem
                [IO.Compression.ZipFile]::ExtractToDirectory($uiXaml.nupkgFilename, $uiXaml.nupkgFolder)

                # Prep for install
                Write-Output "Installing ${arch} ${Name}..."
                $XamlAppxFolder = Join-Path -Path $uiXaml.nupkgFolder -ChildPath $uiXaml.appxFolder
                $XamlAppxPath = Join-Path -Path $XamlAppxFolder -ChildPath $uiXaml.appxFilename

                # Debugging
                if ($DebugMode) { Write-Output "Installing appx Packages in: $XamlAppxFolder" }

                # Install
                Get-ChildItem -Path $XamlAppxPath -Filter *.appx | ForEach-Object {
                    if ($DebugMode) { Write-Output "Installing appx Package: $($_.Name)" }
                    if ($ForceClose) {
                        Add-AppxPackage $_.FullName -ErrorAction Stop -ForceApplicationShutdown
                    } else {
                        Add-AppxPackage $_.FullName -ErrorAction Stop
                    }
                }
                Write-Output "`nUI.Xaml installed successfully."

                # Cleanup
                if ($DisableCleanup -eq $false) {
                    if ($DebugMode) { Write-Output "" } # Extra line break for readability if DebugMode is enabled
                    Cleanup -Path $uiXaml.nupkgFilename
                    Cleanup -Path $uiXaml.nupkgFolder -Recurse $true
                }
            }
        } catch {
            # If unable to connect to remote server and Windows 10 or Server 2022, display warning message
            $ShowOldVersionMessage = $False
            if ($_.Exception.Message -match "Unable to connect to the remote server") {
                # Determine the correct Windows caption and set $ShowOutput to $True if conditions are met
                if ($osVersion.Type -eq "Workstation" -and $osVersion.NumericVersion -eq 10) {
                    $WindowsCaption = "Windows 10"
                    $ShowOldVersionMessage = $True
                } elseif ($osVersion.Type -eq "Server" -and $osVersion.NumericVersion -eq 2022) {
                    $WindowsCaption = "Server 2022"
                    $ShowOldVersionMessage = $True
                }

                # Output the warning message if $ShowOldVersionMessage is $True, otherwise output the generic error message
                if ($ShowOldVersionMessage) {
                    $OldVersionMessage = "There is an issue connecting to the server to download $Name. Unfortunately this is a known issue with the prerequisite server URLs - sometimes they are down. Since you're using $WindowsCaption you must use the non-store versions of the prerequisites, the prerequisites from the Windows store will not work, so you may need to try again later or install manually."
                    Write-Warning $OldVersionMessage
                } else {
                    Write-Warning "Error when trying to download or install $Name. Please try again later or manually install $Name."
                }
            }

            $errorHandled = Handle-Error $_
            if ($null -ne $errorHandled) {
                throw $errorHandled
            }
            $errorHandled = $null
        }
    }
}

function Get-CurrentProcess {
    <#
        .SYNOPSIS
            Retrieves the current PowerShell process information.

        .DESCRIPTION
            The Get-CurrentProcess function identifies the current PowerShell process by temporarily changing the console window title. It then filters the list of running processes to find the one with the matching window title. The function returns a custom object containing the Name and Id of the current process.

        .EXAMPLE
            PS C:\> $result = Get-CurrentProcess
            PS C:\> Write-Output $result

            This example demonstrates how to call the Get-CurrentProcess function and store its output in a variable named $result. The output is then displayed using Write-Output.

        .NOTES
            The function temporarily changes the console window title. Ensure no other scripts or processes are dependent on the window title during execution. The function uses a 1-second sleep to allow time for the window title change to take effect. This may vary based on system performance.
    #>
    $oldTitle = $host.ui.RawUI.WindowTitle
    $tempTitle = ([Guid]::NewGuid())
    $host.ui.RawUI.WindowTitle = $tempTitle
    Start-Sleep 1
    $currentProcess = Get-Process | Where-Object { $_.MainWindowTitle -eq $tempTitle }
    $currentProcess = [PSCustomObject]@{
        Name = $currentProcess.Name
        Id   = $currentProcess.Id
    }
    $host.ui.RawUI.WindowTitle = $oldTitle
    return $currentProcess
}

function ExitWithDelay {
    <#
        .SYNOPSIS
            Exits the script with a specified exit code after a specified delay, 10 seconds by default.

        .DESCRIPTION
            This function takes an exit code as an argument, waits for 10 seconds unless specified, and then exits the script with the given exit code.

        .PARAMETER ExitCode
            The exit code to use when exiting the script.

        .EXAMPLE
            ExitWithDelay -ExitCode 1
            Waits for 10 seconds (default) and then exits the script with an exit code of 1.

       .EXAMPLE
            ExitWithDelay -ExitCode 2 -Seconds 5
            Waits for 5 seconds and then exits the script with an exit code of 2.
        .NOTES
            Use this function to introduce a delay before exiting the script, allowing time for any cleanup or logging activities.
    #>

    param (
        [int]$ExitCode,
        [int]$Seconds = 10
    )

    # Debug mode output
    if ($DebugMode -and $Wait) {
        Write-Warning "Wait specified, waiting several seconds..."
    } elseif ($DebugMode -and !$Wait) {
        Write-Warning "Wait not specified, exiting immediately..."
    }

    # If Wait is specified, wait for x seconds before exiting
    if ($Wait) {
        # Waiting for x seconds output
        Write-Output "`nWaiting for $Seconds seconds before exiting..."
        Start-Sleep -Seconds $Seconds
    }

    # Exit the script with error code
    # Some systems may accidentally close the window, but that's a PowerShell bug
    # https://stackoverflow.com/questions/67593504/why-wont-the-exit-function-work-in-my-powershell-code
    Exit $ExitCode
}

function Import-GlobalVariable {
    <#
        .SYNOPSIS
        This function checks if a specified global variable exists and imports its value into a script scope variable of the same name.

        .DESCRIPTION
        The Import-GlobalVariable function allows you to specify the name of a variable. It checks if a global variable with that name exists, and if it does, it imports its value into a script scope variable with the same name.

        .PARAMETER VariableName
        The name of the variable to check and import if it exists in the global scope.

    #>

    [CmdletBinding()]
    param(
        [string]$VariableName
    )

    # Check if the specified global variable exists; if yes, import its value
    try {
        $globalValue = Get-Variable -Name $VariableName -ValueOnly -Scope Global -ErrorAction Stop
        Set-Variable -Name $VariableName -Value $globalValue -Scope Script
    } catch {
        # If the variable does not exist, do nothing
    }
}

# ============================================================================ #
# Initial checks
# ============================================================================ #

# Use global variables if specified by user
Import-GlobalVariable -VariableName "DebugMode"
Import-GlobalVariable -VariableName "ForceClose"
Import-GlobalVariable -VariableName "Force"

# First heading
Write-Output "winget-install $CurrentVersion"

# Check for updates if -CheckForUpdate is specified
if ($CheckForUpdate) { CheckForUpdate -RepoOwner $RepoOwner -RepoName $RepoName -CurrentVersion $CurrentVersion -PowerShellGalleryName $PowerShellGalleryName }

# Update the script if -UpdateSelf is specified
if ($UpdateSelf) { UpdateSelf }

# Heading
Write-Output "To check for updates, run winget-install -CheckForUpdate"

# Get OS version
$osVersion = Get-OSInfo

# Get architecture type
$arch = $osVersion.Architecture

# Get current process module name to determine if launched in conhost
$currentProcess = Get-CurrentProcess

# If it's a workstation, make sure it is Windows 10+
if ($osVersion.Type -eq "Workstation" -and $osVersion.NumericVersion -lt 10) {
    Write-Error "winget requires Windows 10 or later on workstations. Your version of Windows is not supported."
    ExitWithDelay 1
}

# If it's a workstation with Windows 10, make sure it's version 1809 or greater
if ($osVersion.Type -eq "Workstation" -and $osVersion.NumericVersion -eq 10 -and $osVersion.ReleaseId -lt 1809) {
    Write-Error "winget requires Windows 10 version 1809 or later on workstations. Please update Windows to a compatible version."
    ExitWithDelay 1
}

# If it's a server, it needs to be 2022+
if ($osVersion.Type -eq "Server" -and $osVersion.NumericVersion -lt 2022) {
    Write-Error "winget requires Windows Server 2022 or newer on server platforms. Your version of Windows Server is not supported."
    ExitWithDelay 1
}

# Check if winget is already installed
if (Get-WingetStatus) {
    if ($Force -eq $false) {
        Write-Warning "winget is already installed, exiting..."
        Write-Warning "If you want to reinstall winget, run the script with the -Force parameter."
        ExitWithDelay 0 5
    }
}

# Check if ForceClose parameter is specified. If terminal detected, so relaunch in conhost
if ($ForceClose) {
    Write-Warning "ForceClose parameter is specified. Conflicting processes will be closed automatically!"
    if ($currentProcess.Name -eq "WindowsTerminal") {
        Write-Warning "Terminal detected, relaunching in conhost in 10 seconds..."
        Write-Warning "It may break your custom batch files and ps1 scripts with extra commands!"
        Start-Sleep -Seconds 10

        # Prepare the command to relaunch
        $command = "cd '$pwd'; $($MyInvocation.Line)"

        # Append parameters if their corresponding variables are $true and not already in the command
        if ($Force -and !($command -imatch '\s-Force\b')) { $command += " -Force" }
        if ($ForceClose -and !($command -imatch '\s-ForceClose\b')) { $command += " -ForceClose" }
        if ($DebugMode -and !($command -imatch '\s-DebugMode\b')) { $command += " -DebugMode" }

        # Relaunch in conhost
        if ([Environment]::Is64BitOperatingSystem) {
            if ([Environment]::Is64BitProcess) {
                Start-Process -FilePath "conhost.exe" -ArgumentList "powershell -ExecutionPolicy Bypass -Command &{$command}" -Verb RunAs
            } else {
                Start-Process -FilePath "$env:windir\sysnative\conhost.exe" -ArgumentList "powershell -ExecutionPolicy Bypass -Command &{$command}" -Verb RunAs
            }
        } else {
            Start-Process -FilePath "conhost.exe" -ArgumentList "powershell -ExecutionPolicy Bypass -Command &{$command}" -Verb RunAs
        }

        # Stop the current process module
        Stop-Process -id $currentProcess.Id
    }
}

# ============================================================================ #
# Beginning of installation process
# ============================================================================ #

try {
    # ============================================================================ #
    # Install prerequisites
    # ============================================================================ #

    # VCLibs
    Install-Prerequisite -Name "VCLibs" -Version "14.00" -Url "https://store.rg-adguard.net/api/GetFiles" -AlternateUrl "https://aka.ms/Microsoft.VCLibs.$arch.14.00.Desktop.appx" -ContentType "application/x-www-form-urlencoded" -Body "type=PackageFamilyName&url=Microsoft.VCLibs.140.00_8wekyb3d8bbwe&ring=RP&lang=en-US"

    # UI.Xaml
    Install-Prerequisite -Name "UI.Xaml" -Version "2.7.3" -Url "https://store.rg-adguard.net/api/GetFiles" -AlternateUrl "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.7.3" -ContentType "application/x-www-form-urlencoded" -Body "type=ProductId&url=9P5VK8KZB5QZ&ring=RP&lang=en-US" -NupkgVersion "2.7.3" -AppxFileVersion "2.7"

    # ============================================================================ #
    # Install winget
    # ============================================================================ #

    $TempFolder = Get-TempFolder

    # Output
    Write-Section "Downloading & installing winget..."

    Write-Output "Retrieving download URL for winget from GitHub..."
    $wingetUrl = Get-WingetDownloadUrl -Match "msixbundle"
    $wingetPath = Join-Path -Path $tempFolder -ChildPath "winget.msixbundle"
    $wingetLicenseUrl = Get-WingetDownloadUrl -Match "License1.xml"
    $wingetLicensePath = Join-Path -Path $tempFolder -ChildPath "license1.xml"

    # If the URL is empty, throw error
    if ($wingetUrl -eq "") {
        throw "URL is empty"
    }

    Write-Output "Downloading winget..."
    if ($DebugMode) {
        Write-Output "`nURL: $wingetUrl"
        Write-Output "Saving as: $wingetPath"
    }
    Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPath

    Write-Output "Downloading license..."
    if ($DebugMode) {
        Write-Output "`nURL: $wingetLicenseUrl"
        Write-Output "Saving as: $wingetLicensePath"
    }
    Invoke-WebRequest -Uri $wingetLicenseUrl -OutFile $wingetLicensePath

    Write-Output "`nInstalling winget..."

    # Debugging
    if ($DebugMode) {
        Write-Output "wingetPath: $wingetPath"
        Write-Output "wingetLicensePath: $wingetLicensePath"
    }

    # Try to install winget
    try {
        # Add-AppxPackage will throw an error if the app is already installed or higher version installed, so we need to catch it and continue
        Add-AppxProvisionedPackage -Online -PackagePath $wingetPath -LicensePath $wingetLicensePath -ErrorAction SilentlyContinue | Out-Null
        Write-Output "`nwinget installed successfully."
    } catch {
        $errorHandled = Handle-Error $_
        if ($null -ne $errorHandled) {
            throw $errorHandled
        }
        $errorHandled = $null
    }

    # Cleanup
    if ($DisableCleanup -eq $false) {
        if ($DebugMode) { Write-Output "" } # Extra line break for readability if DebugMode is enabled
        Cleanup -Path $wingetPath
        Cleanup -Path $wingetLicensePath
    }

    # ============================================================================ #
    # PATH environment variable
    # ============================================================================ #

    # Add the WindowsApps directory to the PATH variable
    Write-Section "Checking and adding WindowsApps directory to PATH variable for current user if not present..."
    $WindowsAppsPath = [IO.Path]::Combine([Environment]::GetEnvironmentVariable("LOCALAPPDATA"), "Microsoft", "WindowsApps")
    Update-PathEnvironmentVariable -NewPath $WindowsAppsPath

    # ============================================================================ #
    # Register winget
    # ============================================================================ #
    Write-Section "Registering winget..."
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        Write-Output "`winget command registered successfully."
    } catch {
        Write-Warning "Unable to register winget. You may need to restart your computer for winget to work."
    }

    # ============================================================================ #
    # Finished
    # ============================================================================ #

    Write-Section "Installation complete!"

    # Timeout for 5 seconds to check winget
    Write-Output "Checking if winget is installed and working..."
    Start-Sleep -Seconds 3

    # Check if winget is installed
    if (Get-WingetStatus -eq $true) {
        Write-Output "winget is installed and working now, you can go ahead and use it."
    } else {
        Write-Warning "winget is installed but is not detected as a command. Try using winget now. If it doesn't work, wait about 1 minute and try again (it is sometimes delayed). Also try restarting your computer."
        Write-Warning "If you restart your computer and the command still isn't recognized, please read the Troubleshooting section`nof the README: https://github.com/asheroto/winget-install#troubleshooting`n"
        Write-Warning "Make sure you have the latest version of the script by running this command: $PowerShellGalleryName -CheckForUpdate"
    }

    ExitWithDelay 0
} catch {
    # ============================================================================ #
    # Error handling
    # ============================================================================ #

    Write-Section "WARNING! An error occurred during installation!"
    Write-Warning "If messages above don't help and the problem persists, please read the Troubleshooting section`nof the README: https://github.com/asheroto/winget-install#troubleshooting"
    Write-Warning "Make sure you have the latest version of the script by running this command: $PowerShellGalleryName -CheckForUpdate"

    # If it's not 0x80073D02 (resources in use), show error
    if ($_.Exception.Message -notmatch '0x80073D02') {
        if ($DebugMode) {
            Write-Warning "Line number : $($_.InvocationInfo.ScriptLineNumber)"
        }
        Write-Warning "Error: $($_.Exception.Message)`n"
    }

    ExitWithDelay 1
}