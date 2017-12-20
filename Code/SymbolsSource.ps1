#requires -version 5.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2017 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest

###############################################################################
# Script Global Variables
###############################################################################
# The array that contains all the versions.
$script:vsVersionArray = "2012", "2013", "2015", "2017" 

###############################################################################
# Module Only Functions
###############################################################################

# Does the lookups and builds the hash tables for Get-SourceServer, Get-SymbolServer
function GetCommonSettings($propertyValue="", $envVariable="")
{
    $returnHash = [ordered]@{}

    # The XPath to look for.
    $xPathLookup = $script:dbgPropertyXPath -f $propertyValue

    # Loop through all the VS versions.
    for ($i = 0; $i -lt $script:vsVersionArray.Length; $i++)
    {
        [xml]$settings = OpenSettingsFile $script:vsVersionArray[$i]

        if ($null -ne $settings)
        {
            # Look for the property itself.
            $propNode = $settings | Select-Xml -XPath $xPathLookup
            
            # Add the value to the hash table.
            $returnHash["VS " + $script:vsVersionArray[$i]] = $propNode.Node.InnerText
        }
    }

    # Do the environment variable, too.
    if ($envVariable -ne "")
    {
        $envVal = Get-ItemProperty -Path HKCU:\Environment -Name $envVariable -ErrorAction SilentlyContinue
        if ($null -ne $envVal)
        {
            $returnHash[$envVariable] = $envVal.$envVariable
        }    
    }

    return $returnHash
}

function CreateDirectoryIfNeeded
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
            [string] $directory=""
    )

    if ($PSCmdlet.ShouldProcess($directory,"Creating directory"))
    {
        if ( ! (Test-Path -Path $directory -type "Container"))
        {
            New-Item -type directory -Path $directory > $null
        }
    }
}

# Makes doing ShouldProcess easier.
function Set-ItemPropertyScript 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [Parameter(Mandatory=$true)]
        $path,
        [Parameter(Mandatory=$true)] 
        $name, 
        [Parameter(Mandatory=$true)] 
        $value,
        $type=$null 
    )

    $propString = "Item: " + $path.ToString() + " Property: " + $name
    if ($PSCmdLet.ShouldProcess($propString ,"Set Property"))
    {
        if ($null -eq $type)
        {
          Set-ItemProperty -Path $path -Name $name -Value $value
        }
        else
        {
          Set-ItemProperty -Path $path -Name $name -Value $value -Type $type
        }
    }
}

 function SetInternalSymbolServer([xml]$settings, $cacheDirectory, $symPath)
 {
    CreateDirectoryIfNeeded -directory $CacheDirectory

    # Turn off Just My Code.
    $xPathLookup = $script:dbgPropertyXPath -f "JustMyCode"
    $justMyCode = $settings | Select-Xml -XPath $xPathLookup
    $justMyCode.Node.InnerText = "0"

    # Turn on Source Server Diagnostics as that's a good thing. :)
    $xPathLookup = $script:dbgPropertyXPath -f "ShowSourceServerDiagnostics"
    $ssDiag = $settings | Select-Xml -XPath $xPathLookup
    $ssDiag.Node.InnerText = "1"

    # Turn off .NET Framework Source stepping.
    $xPathLookup = $script:dbgPropertyXPath -f "FrameworkSourceStepping"
    $noFramework = $settings | Select-Xml -XPath $xPathLookup
    $noFramework.Node.InnerText = "0"

    # Turn off using the Microsoft symbol servers.
    $xPathLookup = $script:dbgPropertyXPath -f "SymbolUseMSSymbolServers"
    $noMSSymServers = $settings | Select-Xml -XPath $xPathLookup
    $noMSSymServers.Node.InnerText = "0"

    # Set the symbol cache dir to the same value as used in the environment
    # variable.
    $xPathLookup = $script:dbgPropertyXPath -f "SymbolCacheDir"
    $cacheDir = $settings | Select-Xml -XPath $xPathLookup
    $cacheDir.Node.InnerText = $CacheDirectory
}

 function SetPublicSymbolServer([xml]$settings, $cacheDirectory, $symPath, $vsVersion)
 {
    CreateDirectoryIfNeeded -directory $CacheDirectory

    # Turn off Just My Code.
    $xPathLookup = $script:dbgPropertyXPath -f "JustMyCode"
    $justMyCode = $settings | Select-Xml -XPath $xPathLookup
    $justMyCode.Node.InnerText = "0"

    # Turn on .NET Framework Source stepping.
    $xPathLookup = $script:dbgPropertyXPath -f "FrameworkSourceStepping"
    $noFramework = $settings | Select-Xml -XPath $xPathLookup
    $noFramework.Node.InnerText = "1"

    # Turn on Source Server Support.
    $xPathLookup = $script:dbgPropertyXPath -f "UseSourceServer"
    $useSS = $settings | Select-Xml -XPath $xPathLookup
    $useSS.Node.InnerText = "1"

    # Turn on Source Server Diagnostics as that's a good thing. :)
    $xPathLookup = $script:dbgPropertyXPath -f "ShowSourceServerDiagnostics"
    $ssDiag = $settings | Select-Xml -XPath $xPathLookup
    $ssDiag.Node.InnerText = "1"

    # It's very important to turn off requiring the source to match exactly.
    # With this flag on, .NET Reference Source Stepping doesn't work.
    $xPathLookup = $script:dbgPropertyXPath -f "UseDocumentChecksum"
    $noDoc = $settings | Select-Xml -XPath $xPathLookup
    $noDoc.Node.InnerText = "0"

    # Turn off using the Microsoft symbol servers.
    $xPathLookup = $script:dbgPropertyXPath -f "SymbolUseMSSymbolServers"
    $noMSSymServers = $settings | Select-Xml -XPath $xPathLookup
    $noMSSymServers.Node.InnerText = "0"

     # Set the VS SymbolPath setting.
    $xPathLookup = $script:dbgPropertyXPath -f "SymbolPath"
    $symPath = $settings | Select-Xml -XPath $xPathLookup
    $symPath.Node.IsEmpty = $true
    
    # Tell VS that all paths are empty.
    $xPathLookup = $script:dbgPropertyXPath -f "SymbolPathState"
    $symPathState = $settings | Select-Xml -XPath $xPathLookup
    $symPathState.Node.IsEmpty = $true
    
    # Set the symbol cache dir to the same value as used in the environment
    # variable.
    $xPathLookup = $script:dbgPropertyXPath -f "SymbolCacheDir"
    $cacheDir = $settings | Select-Xml -XPath $xPathLookup
    $cacheDir.Node.InnerText = $CacheDirectory

    # Turn on the SourceLinking option new to VS 2017.
    if ($vsVersion -ge "2017")
    {
        $xPathLookup = $script:dbgPropertyXPath -f "UseSourceLink"
        $ssDiag = $settings | Select-Xml -XPath $xPathLookup
        $ssDiag.Node.InnerText = "1"
    }
}

###############################################################################
# Public Cmdlets
###############################################################################
function Get-SourceServer
{
<#
.SYNOPSIS
Returns a hashtable of the current source server settings.

.DESCRIPTION
Returns a hashtable with the current source server directories settings
for VS 2012-2017, and the _NT_SOURCE_PATH enviroment variable 
used by WinDBG.

.OUTPUTS 
HashTable
The keys are, if all present, VS 2012-2017, and WinDBG. 
The  values are those set for each debugger.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>
    GetCommonSettings SourceServerExtractToDirectory _NT_SOURCE_PATH
}

###############################################################################

function Get-SymbolServer
{
<#
.SYNOPSIS
Returns a hashtable of the current symbol server settings.

.DESCRIPTION
Returns a hashtable with the current source server directories settings
for VS 2012-2017, and the _NT_SYMBOL_PATH enviroment variable.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    GetCommonSettings SymbolCacheDir _NT_SYMBOL_PATH
}

###############################################################################
function Set-SourceServer
{
<#
.SYNOPSIS
Sets the source server directory.

.DESCRIPTION
Sets the source server cache directory for VS 2012-2017, and WinDBG  
through the _NT_SOURCE_PATH environment variable to all reference the same 
location. This ensures you only download the file once no matter which 
debugger you use. Because this cmdlet sets an environment variable you need 
to log off to ensure it's properly set.

.PARAMETER CacheDirectory
The directory to use. If the directory does not exist, it will be created.

.PARAMETER CurrentEnvironmentOnly
If specified will only set the current PowerShell window _NT_SOURCE_PATH 
environment variable and not overwrite the global settings. This is primarily
for use with WinDBG as Visual Studio does not use this environment variable.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    # This triggers on the environment variable setting ($env:_NT_SOURCE_PATH = "SRV*" + $CacheDirectory) 
    # That seems like an issue in the rule.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Scope="Function")]
    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the source server cache directory")]
        [string] $CacheDirectory,
        [switch] $CurrentEnvironmentOnly
    ) 

    # Check if VS is running if we are going to be setting the global stuff. 
    if (($CurrentEnvironmentOnly -eq $false) -and (Get-Process -Name 'devenv' -ErrorAction SilentlyContinue))
    {
        throw "Visual Studio is running. Please close all instances before executing Set-SourceServer"
    }

    # Does the cache directory exist or need to be created?    
    CreateDirectoryIfNeeded $CacheDirectory

    # If just setting the current environment, that's easy.
    if ($CurrentEnvironmentOnly)
    {
        $env:_NT_SOURCE_PATH = "SRV*" + $CacheDirectory
    }
    else
    {
        # The XPath to look for.
        $xPathLookup = $script:dbgPropertyXPath -f "SourceServerExtractToDirectory"

        # Loop through all VS versions.        
        for ($i = 0; $i -lt $script:vsVersionArray.Length; $i++)
        {
            [xml]$settings = OpenSettingsFile $script:vsVersionArray[$i]

            if ($null -ne $settings)
            {
                if ($PSCmdlet.ShouldProcess("VS " + $script:vsVersionArray[$i], "Setting Source Server"))
                {
                    # Grab the SourceServerExtractToDirectory element
                    $extractDirNode = $settings | Select-Xml -XPath $xPathLookup
                
                    # Set it.
                    $extractDirNode.Node.InnerXml = $CacheDirectory

                    WriteSettingsFile $script:vsVersionArray[$i] $settings
                }
            }
        }

        # Always set the _NT_SOURCE_PATH value for WinDBG.
        Set-ItemProperty -Path HKCU:\Environment -Name _NT_SOURCE_PATH -Value "SRV*$CacheDirectory"
    }   

    if ($CurrentEnvironmentOnly)
    {
        Write-Verbose -Message "`nThe _NT_SOURCE_PATH environment variable was updated for this window only`n"
    }
    else
    {
        Write-Verbose -Message "`nPlease log out to activate the new source server settings`n"
    }

}

###############################################################################

function Set-SymbolServer
{
<#
.SYNOPSIS
Sets up a computer to use a symbol server.

DESCRIPTION
Sets up both the _NT_SYMBOL_PATH environment variable as well as VS 2012-2017, 
(for all installed) to use a common symbol cache directory as well as common 
symbol servers. Optionally can be used to only set _NT_SYMBOL_PATH for an 
individual PowerShell window.

.PARAMETER Internal
Sets the symbol server to use to http://SymWeb. Visual Studio will not use the 
public symbol servers. This will turn off the .NET Framework Source Stepping. 
This switch is intended for internal Microsoft use only. You must specify either 
-Internal or -Public to the script.

.PARAMETER Public
Sets the symbol server to use as the two public symbol servers from Microsoft. 
All the appropriate settings are configured to properly have .NET Reference 
Source stepping working and for VS 2017 and above, Source Linking turned on
so you can debug GitHub-based repositories, like .NET Core, etc.

.PARAMETER CacheDirectory
Defaults to C:\SYMBOLS\PUBLIC for -Public and C:\SYMBOLS\INTERNAL for -Internal.

.PARAMETER SymbolServers
A string array of additional symbol servers to use. If -Internal is set, these 
additional symbol servers will appear before HTTP://SYMWEB. If -Public is set, 
these symbol servers will appear before the public symbol servers so both the 
environment variable and Visual Studio have the same search order.

.PARAMETER CurrentEnvironmentOnly
If specified will only set the current PowerShell window _NT_SYMBOL_PATH 
environment variable and not overwrite the global settings. This is primarily
for use with WinDBG as Visual Studio requires settings files for the
cache directory.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param ( [switch]   $Internal,
            [switch]   $Public,
            [string]   $CacheDirectory="",
            [string[]] $SymbolServers=@(),
            [switch]   $CurrentEnvironmentOnly)
            
    # Do the parameter checking.
    if ($Internal -eq $Public)
    {
        throw "You must specify either -Internal or -Public"
    }

    # Check if VS is running if we are going to be setting the global stuff. 
    if (($CurrentEnvironmentOnly -eq $false) -and (Get-Process -Name 'devenv' -ErrorAction SilentlyContinue))
    {
        throw "Visual Studio is running. Please close all instances before running Set-SymbolServer"
    }
    
    if ($Internal)
    {
        if ($CacheDirectory.Length -eq 0)
        {
            $CacheDirectory = "C:\SYMBOLS\INTERNAL" 
        }
        
        $symPath = ""

        for ($i = 0 ; $i -lt $SymbolServers.Length ; $i++)
        {
            $symPath += "SRV*$CacheDirectory*"
            $symPath += $SymbolServers[$i]
            $symPath += ";"
        }
        
        $symPath += "SRV*$CacheDirectory*http://SYMWEB"

        if ($CurrentEnvironmentOnly)
        {
            CreateDirectoryIfNeeded -directory $CacheDirectory
            $env:_NT_SYMBOL_PATH = $symPath
        }
        else
        {
            # Set the environment variable.
            Set-ItemPropertyScript HKCU:\Environment _NT_SYMBOL_PATH $symPath
        
            for ($i = 0; $i -lt $script:vsVersionArray.Length; $i++)
            {
                [xml]$settings = OpenSettingsFile $script:vsVersionArray[$i]

                if ($null -ne $settings)
                {
                    if ($PSCmdlet.ShouldProcess("VS "+ $script:vsVersionArray[$i], "Symbol Server settings for internal usage"))
                    {
                        SetInternalSymbolServer $settings $CacheDirectory $symPath

                        WriteSettingsFile $script:vsVersionArray[$i] $settings
                    }
                }
            }
        }
    }
    else
    {
    
        if ($CacheDirectory.Length -eq 0)
        {
            $CacheDirectory = "C:\SYMBOLS\PUBLIC" 
        }

        # It's public so we have a little different processing to do as there are
        # two public symbol servers where MSFT provides symbols.
        $refSrcPath = "$CacheDirectory*http://referencesource.microsoft.com/symbols"
        $msdlPath = "$CacheDirectory*https://msdl.microsoft.com/download/symbols"
        $extraPaths = ""
        
        # Poke on any additional symbol servers. I've keeping everything the
        # same between VS as WinDBG.
        for ($i = 0 ; $i -lt $SymbolServers.Length ; $i++)
        {
            $extraPaths += "SRV*$CacheDirectory*"
            $extraPaths += $SymbolServers[$i]
            $extraPaths += ";"
        }

        $envPath = "$extraPaths" + "SRV*$refSrcPath;SRV*$msdlPath"
    
        if ($CurrentEnvironmentOnly)
        {
            CreateDirectoryIfNeeded -directory $CacheDirectory
            $env:_NT_SYMBOL_PATH = $envPath
        }
        else
        {
            Set-ItemPropertyScript HKCU:\Environment _NT_SYMBOL_PATH $envPath
    
            for ($i = 0; $i -lt $script:vsVersionArray.Length; $i++)
            {
                [xml]$settings = OpenSettingsFile $script:vsVersionArray[$i]

                if ($null -ne $settings)
                {
                    if ($PSCmdlet.ShouldProcess("VS "+ $script:vsVersionArray[$i], "Symbol Server settings for public usage"))
                    {
                        SetPublicSymbolServer $settings $CacheDirectory $envPath $script:vsVersionArray[$i]

                        WriteSettingsFile $script:vsVersionArray[$i] $settings
                    }
                }
            }
        }
    }

    if ($CurrentEnvironmentOnly)
    {
        Write-Verbose -Message "`nThe _NT_SYMBOL_PATH environment variable was updated for this window only`n"
    }
    else
    {
        Write-Verbose -Message "`nPlease log out to activate the new symbol server settings`n"
    }
}

###############################################################################

function Get-SourceServerFiles
{
<#
.SYNOPSIS
Prepopulate your symbol cache with all your Source Server extracted source
code.

.DESCRIPTION
Recurses the specified symbol cache directory for PDB files with Source Server
sections and extracts the source code. This script is a simple wrapper around
SRCTOOl.EXE from the Debugging Tools for Windows (AKA WinDBG). If WinDBG is in 
the PATH this script will find SRCTOOL.EXE. If WinDBG is not in your path, use 
the SrcTool parameter to specify the complete path to the tool.

.PARAMETER CacheDirectory 
The required cache directory for the local machine.

.PARAMETER SrcTool
The optional parameter to specify where SRCTOOL.EXE resides.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    # I hate suppressing this warning, but I created this cmdlet long before the 
    # script analyzer came out. If someone has this in a script, changing the
    # cmdlet name will break them.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function")]
    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the source server directory")]
        [string] $CacheDirectory ,
        [Parameter(HelpMessage="The optional full path to SCRTOOL.EXE")]
        [string] $SrcTool = ""
    ) 
    
    if ($SrcTool -eq "")
    {
        # Go with the default of looking up WinDBG in the path.
        $windbg = Get-Command -Name windbg.exe -ErrorAction SilentlyContinue
        if ($null -eq $windbg)
        {
            throw "Please use the -SrcTool parameter or have WinDBG in the path"
        }
        
        $windbgPath = Split-Path -Path ($windbg.Definition)
        $SrcTool = $windbgPath + "\SRCSRV\SRCTOOL.EXE"
    }
    
    if ($null -eq (Get-Command -Name $SrcTool -ErrorAction SilentlyContinue))
    {
        throw "SRCTOOL.EXE does not exist."
    }
    
    if ((Test-Path -Path $CacheDirectory) -eq $false)
    {
        throw "The specified cache directory does not exist."
    }
    
    # Get all the PDB files, execute SRCTOOL.EXE on each one.
    Get-ChildItem -Recurse -Include *.pdb -Path $cacheDirectory | `
        ForEach-Object { &$SrcTool -d:$CacheDirectory -x $_.FullName }

}

###############################################################################

function Set-SymbolAndSourceServer
{
<#
.SYNOPSIS
Sets up a computer to use a symbol and source server.

.DESCRIPTION
Sets up both the _NT_SYMBOL_PATH and _NT_SOURCE_PATH environment variable as 
well as VS 2012-2017 (for each installed) to use a common symbol and source 
cache directory as well as common symbol servers. Optionally can be used to 
only set _NT_SYMBOL_PATH and _NT_SOURCE_PATH for an individual PowerShell window.

This is a wrapper around Set-SymbolServer and Set-SourceServer. These have been
a single command anyway.

.PARAMETER Internal
Sets the symbol server to use to http://SymWeb. Visual Studio will not use the 
public symbol servers. This will turn off the .NET Framework Source Stepping. 
This switch is intended for internal Microsoft use only. You must specify either 
-Internal or -Public to the script.

.PARAMETER Public
Sets the symbol server to use as the two public symbol servers from Microsoft. 
All the appropriate settings are configured to properly have .NET Reference 
Source stepping working.

.PARAMETER CacheDirectory
Defaults to C:\SYMBOLS\PUBLIC for -Public and C:\SYMBOLS\INTERNAL for -Internal.

.PARAMETER SymbolServers
A string array of additional symbol servers to use. If -Internal is set, these 
additional symbol servers will appear before HTTP://SYMWEB. If -Public is set, 
these symbol servers will appear before the public symbol servers so both the 
environment variable and Visual Studio have the same search order.

.PARAMETER CurrentEnvironmentOnly
If specified will only set the current PowerShell window _NT_SYMBOL_PATH 
and _NT_SOURCE_PATH environment variable and not overwrite the global 
settings. This is primarily for use with WinDBG as Visual Studio requires 
settings files for the cache directory and other settings.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param ( [switch]   $Internal,
            [switch]   $Public,
            [string]   $CacheDirectory="",
            [string[]] $SymbolServers=@(),
            [switch]   $CurrentEnvironmentOnly)
            
    # Splatting is just so cool...
    Set-SymbolServer  @psBoundParameters

    if ($CacheDirectory.Length -eq 0)
    {
        if ($Public)
        {
            $CacheDirectory = "C:\SYMBOLS\PUBLIC" 
        }
        else 
        {
            $CacheDirectory = "C:\SYMBOLS\INTERNAL"
        }
    }

    Set-SourceServer -CacheDirectory $CacheDirectory 
}


# SIG # Begin signature block
# MIIUywYJKoZIhvcNAQcCoIIUvDCCFLgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUSuGi+KKJWA7wS5bKuvdgdtJB
# aTCggg+6MIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
# BQUAMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQg
# TGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNV
# BAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJG
# aXJzdC1PYmplY3QwHhcNMTUxMjMxMDAwMDAwWhcNMTkwNzA5MTg0MDM2WjCBhDEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKjAoBgNVBAMT
# IUNPTU9ETyBTSEEtMSBUaW1lIFN0YW1waW5nIFNpZ25lcjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAOnpPd/XNwjJHjiyUlNCbSLxscQGBGue/YJ0UEN9
# xqC7H075AnEmse9D2IOMSPznD5d6muuc3qajDjscRBh1jnilF2n+SRik4rtcTv6O
# KlR6UPDV9syR55l51955lNeWM/4Og74iv2MWLKPdKBuvPavql9LxvwQQ5z1IRf0f
# aGXBf1mZacAiMQxibqdcZQEhsGPEIhgn7ub80gA9Ry6ouIZWXQTcExclbhzfRA8V
# zbfbpVd2Qm8AaIKZ0uPB3vCLlFdM7AiQIiHOIiuYDELmQpOUmJPv/QbZP7xbm1Q8
# ILHuatZHesWrgOkwmt7xpD9VTQoJNIp1KdJprZcPUL/4ygkCAwEAAaOB9DCB8TAf
# BgNVHSMEGDAWgBTa7WR0FJwUPKvdmam9WyhNizzJ2DAdBgNVHQ4EFgQUjmstM2v0
# M6eTsxOapeAK9xI1aogwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYD
# VR0lAQH/BAwwCgYIKwYBBQUHAwgwQgYDVR0fBDswOTA3oDWgM4YxaHR0cDovL2Ny
# bC51c2VydHJ1c3QuY29tL1VUTi1VU0VSRmlyc3QtT2JqZWN0LmNybDA1BggrBgEF
# BQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20w
# DQYJKoZIhvcNAQEFBQADggEBALozJEBAjHzbWJ+zYJiy9cAx/usfblD2CuDk5oGt
# Joei3/2z2vRz8wD7KRuJGxU+22tSkyvErDmB1zxnV5o5NuAoCJrjOU+biQl/e8Vh
# f1mJMiUKaq4aPvCiJ6i2w7iH9xYESEE9XNjsn00gMQTZZaHtzWkHUxY93TYCCojr
# QOUGMAu4Fkvc77xVCf/GPhIudrPczkLv+XZX4bcKBUCYWJpdcRaTcYxlgepv84n3
# +3OttOe/2Y5vqgtPJfO44dXddZhogfiqwNGAwsTEOYnB9smebNd0+dmX+E/CmgrN
# Xo/4GengpZ/E8JIh5i15Jcki+cPwOoRXrToW9GOUEB1d0MYwggU1MIIEHaADAgEC
# AhEA+CGT8y+uLXmA2UBOFe5VGzANBgkqhkiG9w0BAQsFADB9MQswCQYDVQQGEwJH
# QjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3Jk
# MRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJT
# QSBDb2RlIFNpZ25pbmcgQ0EwHhcNMTYwMjE4MDAwMDAwWhcNMTgxMDI4MjM1OTU5
# WjCBnTELMAkGA1UEBhMCVVMxDjAMBgNVBBEMBTM3OTMyMQswCQYDVQQIDAJUTjES
# MBAGA1UEBwwJS25veHZpbGxlMRIwEAYDVQQJDAlTdWl0ZSAzMDIxHzAdBgNVBAkM
# FjEwMjA3IFRlY2hub2xvZ3kgRHJpdmUxEzARBgNVBAoMCldpbnRlbGxlY3QxEzAR
# BgNVBAMMCldpbnRlbGxlY3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDfLujuIe3yrrTfTOdYfstwFDZrI7XezoeFPA33GRxY/MSbKuUvPcN8XqU8Jpg4
# NUkByzoSjPsq9Yjx3anHflcNendqa/8gbkPdiEMg+6kRVmtv1QHfGt+UbEMfrUk0
# Ltm0DE+6OIZFx8hjsxifJvWrQ/jG9lat6e2YwIdNAqyG2htqCrmBN90lW+0+zU9s
# YJIVD0ZfyZJVkvbeay+HwlbojW7JQyyhdGOSa61zUqlD85RX6HzcCbb1WHf5bZRO
# 2idaVNAOw1YHqJAUjY4oJY4lqWwg5Inza4f33Wt82zJAgKY4S01bddkvjPi6iMnG
# y8bI1EfWAdFFC+UM2qKsNc2/AgMBAAGjggGNMIIBiTAfBgNVHSMEGDAWgBQpkWD/
# ik366/mmarjP+eZLvUnOEjAdBgNVHQ4EFgQUZdNFdxzRtMVCZCvcFV4g7vsL8vgw
# DgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwEQYJYIZIAYb4QgEBBAQDAgQQMEYGA1UdIAQ/MD0wOwYMKwYBBAGyMQECAQMC
# MCswKQYIKwYBBQUHAgEWHWh0dHBzOi8vc2VjdXJlLmNvbW9kby5uZXQvQ1BTMEMG
# A1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0NPTU9ET1JT
# QUNvZGVTaWduaW5nQ0EuY3JsMHQGCCsGAQUFBwEBBGgwZjA+BggrBgEFBQcwAoYy
# aHR0cDovL2NydC5jb21vZG9jYS5jb20vQ09NT0RPUlNBQ29kZVNpZ25pbmdDQS5j
# cnQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTANBgkqhkiG
# 9w0BAQsFAAOCAQEAnSVG6TXbazSxczonyo/Q+pjX+6JERtMZ0sz3Fc3PTMDcb9DS
# tALjZiZhOgOoRNC+5OHgE3tTPLCT6ZGktfedzp6J9mICzoJIIBelfdiIwJNkPTzR
# I2krUn/6ld5coh0zyM85lCjXkqzZmyQmRRNQoycWtxUwxsNlkiGlRIiIJHztbg1I
# lv9C90zCZ1nAhfOpv+maUohLtz22F9wXCJuIUQapOhPG5n/opM/AUQV2WuDa3AZP
# VYleK90zOgHLDgLICxrx57z2JRlXyW2ga2N5J6DXzwGmxpCe0LbzYCj4h42SjUuf
# 9hOQtORlSjYEj8RFpxatyxcmIIpej9/NDNXgIzCCBeAwggPIoAMCAQICEC58h8wO
# k0pS/pT9HLfNNK8wDQYJKoZIhvcNAQEMBQAwgYUxCzAJBgNVBAYTAkdCMRswGQYD
# VQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNV
# BAoTEUNPTU9ETyBDQSBMaW1pdGVkMSswKQYDVQQDEyJDT01PRE8gUlNBIENlcnRp
# ZmljYXRpb24gQXV0aG9yaXR5MB4XDTEzMDUwOTAwMDAwMFoXDTI4MDUwODIzNTk1
# OVowfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQ
# MA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxIzAh
# BgNVBAMTGkNPTU9ETyBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAppiQY3eRNH+K0d3pZzER68we/TEds7liVz+TvFvj
# nx4kMhEna7xRkafPnp4ls1+BqBgPHR4gMA77YXuGCbPj/aJonRwsnb9y4+R1oOU1
# I47Jiu4aDGTH2EKhe7VSA0s6sI4jS0tj4CKUN3vVeZAKFBhRLOb+wRLwHD9hYQqM
# otz2wzCqzSgYdUjBeVoIzbuMVYz31HaQOjNGUHOYXPSFSmsPgN1e1r39qS/AJfX5
# eNeNXxDCRFU8kDwxRstwrgepCuOvwQFvkBoj4l8428YIXUezg0HwLgA3FLkSqnmS
# Us2HD3vYYimkfjC9G7WMcrRI8uPoIfleTGJ5iwIGn3/VCwIDAQABo4IBUTCCAU0w
# HwYDVR0jBBgwFoAUu69+Aj36pvE8hI6t7jiY7NkyMtQwHQYDVR0OBBYEFCmRYP+K
# Tfrr+aZquM/55ku9Sc4SMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/
# AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBEGA1UdIAQKMAgwBgYEVR0gADBMBgNV
# HR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLmNvbW9kb2NhLmNvbS9DT01PRE9SU0FD
# ZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDBxBggrBgEFBQcBAQRlMGMwOwYIKwYB
# BQUHMAKGL2h0dHA6Ly9jcnQuY29tb2RvY2EuY29tL0NPTU9ET1JTQUFkZFRydXN0
# Q0EuY3J0MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJ
# KoZIhvcNAQEMBQADggIBAAI/AjnD7vjKO4neDG1NsfFOkk+vwjgsBMzFYxGrCWOv
# q6LXAj/MbxnDPdYaCJT/JdipiKcrEBrgm7EHIhpRHDrU4ekJv+YkdK8eexYxbiPv
# VFEtUgLidQgFTPG3UeFRAMaH9mzuEER2V2rx31hrIapJ1Hw3Tr3/tnVUQBg2V2cR
# zU8C5P7z2vx1F9vst/dlCSNJH0NXg+p+IHdhyE3yu2VNqPeFRQevemknZZApQIvf
# ezpROYyoH3B5rW1CIKLPDGwDjEzNcweU51qOOgS6oqF8H8tjOhWn1BUbp1JHMqn0
# v2RH0aofU04yMHPCb7d4gp1c/0a7ayIdiAv4G6o0pvyM9d1/ZYyMMVcx0DbsR6HP
# y4uo7xwYWMUGd8pLm1GvTAhKeo/io1Lijo7MJuSy2OU4wqjtxoGcNWupWGFKCpe0
# S0K2VZ2+medwbVn4bSoMfxlgXwyaiGwwrFIJkBYb/yud29AgyonqKH4yjhnfe0gz
# Htdl+K7J+IMUk3Z9ZNCOzr41ff9yMU2fnr0ebC+ojwwGUPuMJ7N2yfTm18M04oyH
# IYZh/r9VdOEhdwMKaGy75Mmp5s9ZJet87EUOeWZo6CLNuO+YhU2WETwJitB/vCgo
# E/tqylSNklzNwmWYBp7OSFvUtTeTRkF8B93P+kPvumdh/31J4LswfVyA4+YWOUun
# MYIEezCCBHcCAQEwgZIwfTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIg
# TWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENB
# IExpbWl0ZWQxIzAhBgNVBAMTGkNPTU9ETyBSU0EgQ29kZSBTaWduaW5nIENBAhEA
# +CGT8y+uLXmA2UBOFe5VGzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAig
# AoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgEL
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUBDGLLv6NedAy/CnSAWXV
# KeeVaH4wDQYJKoZIhvcNAQEBBQAEggEAjliMcs/L+7u7frv/sONu953tNOFjmnmv
# OxwbhL/RijnQ3LHiP6iKqWufkW7d0yuc+fm9N1jeymqp6WmLc9H/kP2DRQlD5T5s
# fsAc9tmcpP2pcIjvGczL0vwERODXFLilE9foJecJJD/JdbfgjjLWzsznsFmSiM3P
# G53Y2y/pXCFy12rm3YMvceDbeYjd3shmTRoe8RD1Blv96qdPw8+hB+MFKpAosE4l
# ckglvVjsvsFAJPzVlvmsBhdsbaS2JkFMQUl3yGV3tWQ6sx/agloFzVXJpIbCpvuR
# KGMnT1uRNhPu8KD5YkRlci4a/6gQxt+2GsbBFZVgCCcU4H/RaPaMIaGCAkMwggI/
# BgkqhkiG9w0BCQYxggIwMIICLAIBATCBqTCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0Ag8WiPA5JV5jjmkUOQfm
# MwswCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZI
# hvcNAQkFMQ8XDTE3MTIyMDIwMjUwMVowIwYJKoZIhvcNAQkEMRYEFOC4JDfKoI52
# RchFiM735/M70X5AMA0GCSqGSIb3DQEBAQUABIIBACraObHBWueI84hEe6WvAwSw
# LcsvXSrHBlnmrFsvJf0YMgCAonG6NUrPaIiWAiNy901/rf4Pn/4kadmfG/o79tZI
# tHaMUXP0nLJLm11QapFeZ0JHLj3Z7KrZLHeQSYnCACGwwnllZ+bqjrwT0KcZahf1
# yJW6YI6pUilley9TtEkpaSx/Qp5HKGzzESuf7o0+dnxce6Tr5w2PMgjjV9t9L2YP
# rq+f9koTCha71sEbT2aFmRigMyyXg+aUfqUwxXjJB/PC6cAPLUHPZAhc8OXeVW+u
# Z3em63Z44Zw8N9X1/KNult8fzlEoNHfmdNAeDZIpa0czTkXsCKNtssQbAsHQX7s=
# SIG # End signature block
