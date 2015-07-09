#requires -version 2.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2014 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest

###############################################################################
# Script Global Variables
###############################################################################
$script:devTenDebuggerRegKey = "HKCU:\Software\Microsoft\VisualStudio\10.0\Debugger"
$script:devElevenDebuggerRegKey = "HKCU:\Software\Microsoft\VisualStudio\11.0\Debugger"
$script:devTwelveDebuggerRegKey = "HKCU:\Software\Microsoft\VisualStudio\12.0\Debugger"
$script:devFourteenDebuggerRegKey = "HKCU:\Software\Microsoft\VisualStudio\14.0\Debugger"

###############################################################################
# Module Only Functions
###############################################################################
function CreateDirectoryIfNeeded ([string] $directory="")
{
	if ( ! (Test-Path -Path $directory -type "Container"))
	{
		New-Item -type directory -Path $directory > $null
	}
}

# Just to hide PS errors when reading registry keys that don't exist.
function SmartGetRegProperty($regKey="",$regValue="")
{
    $key = Get-ItemProperty -Path $regKey -Name $regValue -ErrorAction SilentlyContinue
    if ($null -ne $key)
    {
        return $key.$regValue
    }
    return $null
}

# Reads the values from VS 2010+, and the environment.
function GetCommonSettings($regValue="", $envVariable="")
{
    $returnHash = @{}
    if (Test-Path -Path $devTenDebuggerRegKey)
    {
        $returnHash["VS 2010"] = SmartGetRegProperty -regKey $devTenDebuggerRegKey -regValue $regValue
    }
    if (Test-Path -Path $devElevenDebuggerRegKey)
    {
        $returnHash["VS 2012"] = SmartGetRegProperty -regKey $devElevenDebuggerRegKey -regValue $regValue
    }
    if (Test-Path -Path $devTwelveDebuggerRegKey)
    {
        $returnHash["VS 2013"] = SmartGetRegProperty -regKey $devTwelveDebuggerRegKey -regValue $regValue
    }
    if (Test-Path -Path $devFourteenDebuggerRegKey)
    {
        $returnHash["VS 2015"] = SmartGetRegProperty -regKey $devFourteenDebuggerRegKey -regValue $regValue
    }
    $envVal = Get-ItemProperty -Path HKCU:\Environment -Name $envVariable -ErrorAction SilentlyContinue
    if ($null -ne $envVal)
    {
        $returnHash[$envVariable] = $envVal.$envVariable
    }
    $returnHash
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

function SetInternalSymbolServer([string] $DbgRegKey="", 
                                 [string] $CacheDirectory="",
                                 [string] $SymPath="")
{

    CreateDirectoryIfNeeded -directory $CacheDirectory
    
    # Turn off Just My Code.
    Set-ItemPropertyScript -Path $dbgRegKey -Name JustMyCode -Value 0 -Type DWORD

    # Turn off .NET Framework Source stepping.
    Set-ItemPropertyScript -Path $DbgRegKey -Name FrameworkSourceStepping -Value 0 DWORD

    # Turn off using the Microsoft symbol servers.
    Set-ItemPropertyScript -Path $DbgRegKey -Name SymbolUseMSSymbolServers -Value 0 DWORD

    # Set the symbol cache dir to the same value as used in the environment
    # variable.
    Set-ItemPropertyScript -Path $DbgRegKey -Name SymbolCacheDir -Value $CacheDirectory
} 

function SetPublicSymbolServer([string] $DbgRegKey="", 
                               [string] $CacheDirectory="")
{
    CreateDirectoryIfNeeded -directory $CacheDirectory
        
    # Turn off Just My Code.
    Set-ItemPropertyScript $dbgRegKey JustMyCode 0 DWORD
    
    # Turn on .NET Framework Source stepping.
    Set-ItemPropertyScript $dbgRegKey FrameworkSourceStepping 1 DWORD
    
    # Turn on Source Server Support.
    Set-ItemPropertyScript $dbgRegKey UseSourceServer 1 DWORD
    
    # Turn on Source Server Diagnostics as that's a good thing. :)
    Set-ItemPropertyScript $dbgRegKey ShowSourceServerDiagnostics 1 DWORD
    
    # It's very important to turn off requiring the source to match exactly.
    # With this flag on, .NET Reference Source Stepping doesn't work.
    Set-ItemPropertyScript $dbgRegKey UseDocumentChecksum 0 DWORD
    
    # Turn off using the Microsoft symbol servers. 
    Set-ItemPropertyScript $dbgRegKey SymbolUseMSSymbolServers 0 DWORD
    
    # Set the VS SymbolPath setting.
    Set-ItemPropertyScript $dbgRegKey SymbolPath ""
    
    # Tell VS that all paths are empty.
    Set-ItemPropertyScript $dbgRegKey SymbolPathState ""
    
    # Set the symbol cache dir to the same value as used in the environment
    # variable.
    Set-ItemPropertyScript $dbgRegKey SymbolCacheDir $CacheDirectory
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
for VS 2010-2015, and the _NT_SOURCE_PATH enviroment variable 
used by WinDBG.

.OUTPUTS 
HashTable
The keys are, if all present, VS 2010, VS 2012, VS 2013, VS 2015, and WinDBG. 
The  values are those set for each debugger.

.LINK
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>
    GetCommonSettings SourceServerExtractToDirectory _NT_SOURCE_PATH
}

###############################################################################

function Set-SourceServer
{
<#
.SYNOPSIS
Sets the source server directory.

.DESCRIPTION
Sets the source server cache directory for VS 2010, VS 2012, VS 2013, VS 2015, 
and WinDBG  through the _NT_SOURCE_PATH environment variable to all reference 
the same location. This ensures you only download the file once no matter 
which debugger you use. Because this cmdlet sets an environment variable 
you need to log off to ensure it's properly set.

.PARAMETER Directory
The directory to use. If the directory does not exist, it will be created.

.PARAMETER CurrentEnvironmentOnly
If specified will only set the current PowerShell window _NT_SOURCE_PATH 
environment variable and not overwrite the global settings. This is primarily
for use with WinDBG as Visual Studio does not use this environment variable.

.LINK
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the source server cache directory")]
        [string] $Directory,
        [switch] $CurrentEnvironmentOnly
    ) 
    
    $sourceServExtractTo = "SourceServerExtractToDirectory"
    
    CreateDirectoryIfNeeded $Directory

    if ($CurrentEnvironmentOnly)
    {
        $env:_NT_SOURCE_PATH = "SRV*" + $Directory
    }
    else
    {
        if (Test-Path -Path $devTenDebuggerRegKey)
        {
            Set-ItemProperty -Path $devTenDebuggerRegKey -Name $sourceServExtractTo -Value $Directory 
        }
    
        if (Test-Path -Path $devElevenDebuggerRegKey)
        {
            Set-ItemProperty -Path $devElevenDebuggerRegKey -Name $sourceServExtractTo -Value $Directory 
        }
    
        if (Test-Path -Path $devTwelveDebuggerRegKey)
        {
            Set-ItemProperty -Path $devTwelveDebuggerRegKey -Name $sourceServExtractTo -Value $Directory 
        }

        if (Test-Path -Path $devFourteenDebuggerRegKey)
        {
            Set-ItemProperty -Path $devFourteenDebuggerRegKey -Name $sourceServExtractTo -Value $Directory 
        }

        # Always set the _NT_SOURCE_PATH value for WinDBG.
        Set-ItemProperty -Path HKCU:\Environment -Name _NT_SOURCE_PATH -Value "SRV*$Directory"
    }
        
}

###############################################################################

function Get-SymbolServer
{
<#
.SYNOPSIS
Returns a hashtable of the current symbol server settings.

.DESCRIPTION
Returns a hashtable with the current source server directories settings
for VS 2010, VS 2012, VS 2013, VS 2015, and the _NT_SYMBOL_PATH enviroment 
variable.

.LINK
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    GetCommonSettings SymbolCacheDir _NT_SYMBOL_PATH
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

.OUTPUTS 
HashTable
The keys are, if all present, VS 2010, VS 2012, VS 2013, VS 2015, and WinDBG. 
The values are those set for each debugger.

.LINK
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
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

function Set-SymbolServer
{
<#
.SYNOPSIS
Sets up a computer to use a symbol server.

DESCRIPTION
Sets up both the _NT_SYMBOL_PATH environment variable as well as VS 2010, VS 2012, 
VS 2013, and VS 2015 (if installed) to use a common symbol cache directory as well 
as common symbol servers. Optionally can be used to only set _NT_SYMBOL_PATH for 
an individual PowerShell window.

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
environment variable and not overwrite the global settings. This is primarily
for use with WinDBG as Visual Studio requires registry settings for the
cache directory.

.LINK
http://www.wintellect.com/blogs/jrobbins
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
        throw "Visual Studio is running. Please close all instances before running this script"
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
            Set-ItemPropertyScript HKCU:\Environment _NT_SYMBOL_PATH $symPath

            if (Test-Path -Path $devTenDebuggerRegKey)
            {
        
                SetInternalSymbolServer $devTenDebuggerRegKey $CacheDirectory $symPath
            }

            if (Test-Path -Path $devElevenDebuggerRegKey)
            {
        
                SetInternalSymbolServer $devElevenDebuggerRegKey $CacheDirectory $symPath
            }

            if (Test-Path -Path $devTwelveDebuggerRegKey)
            {
        
                SetInternalSymbolServer $devTwelveDebuggerRegKey $CacheDirectory $symPath
            }

            if (Test-Path -Path $devFourteenDebuggerRegKey)
            {
        
                SetInternalSymbolServer $devFourteenDebuggerRegKey $CacheDirectory $symPath
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
    
            if (Test-Path -Path $devTenDebuggerRegKey)
            {
                SetPublicSymbolServer $devTenDebuggerRegKey $CacheDirectory
            }
        
            if (Test-Path -Path $devElevenDebuggerRegKey)
            {
                SetPublicSymbolServer $devElevenDebuggerRegKey $CacheDirectory
            }

            if (Test-Path -Path $devTwelveDebuggerRegKey)
            {
                SetPublicSymbolServer $devTwelveDebuggerRegKey $CacheDirectory
            }

            if (Test-Path -Path $devFourteenDebuggerRegKey)
            {
                SetPublicSymbolServer $devFourteenDebuggerRegKey $CacheDirectory
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
# SIG # Begin signature block
# MIIYTQYJKoZIhvcNAQcCoIIYPjCCGDoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUZqGKKzf0UDEaWZmhs6DeENtK
# At+gghM9MIIEhDCCA2ygAwIBAgIQQhrylAmEGR9SCkvGJCanSzANBgkqhkiG9w0B
# AQUFADBvMQswCQYDVQQGEwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNV
# BAsTHUFkZFRydXN0IEV4dGVybmFsIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRU
# cnVzdCBFeHRlcm5hbCBDQSBSb290MB4XDTA1MDYwNzA4MDkxMFoXDTIwMDUzMDEw
# NDgzOFowgZUxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJVVDEXMBUGA1UEBxMOU2Fs
# dCBMYWtlIENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEhMB8G
# A1UECxMYaHR0cDovL3d3dy51c2VydHJ1c3QuY29tMR0wGwYDVQQDExRVVE4tVVNF
# UkZpcnN0LU9iamVjdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM6q
# gT+jo2F4qjEAVZURnicPHxzfOpuCaDDASmEd8S8O+r5596Uj71VRloTN2+O5bj4x
# 2AogZ8f02b+U60cEPgLOKqJdhwQJ9jCdGIqXsqoc/EHSoTbL+z2RuufZcDX65OeQ
# w5ujm9M89RKZd7G3CeBo5hy485RjiGpq/gt2yb70IuRnuasaXnfBhQfdDWy/7gbH
# d2pBnqcP1/vulBe3/IW+pKvEHDHd17bR5PDv3xaPslKT16HUiaEHLr/hARJCHhrh
# 2JU022R5KP+6LhHC5ehbkkj7RwvCbNqtMoNB86XlQXD9ZZBt+vpRxPm9lisZBCzT
# bafc8H9vg2XiaquHhnUCAwEAAaOB9DCB8TAfBgNVHSMEGDAWgBStvZh6NLQm9/rE
# JlTvA73gJMtUGjAdBgNVHQ4EFgQU2u1kdBScFDyr3ZmpvVsoTYs8ydgwDgYDVR0P
# AQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEQG
# A1UdHwQ9MDswOaA3oDWGM2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9BZGRUcnVz
# dEV4dGVybmFsQ0FSb290LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGG
# GWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEFBQADggEBAE1C
# L6bBiusHgJBYRoz4GTlmKjxaLG3P1NmHVY15CxKIe0CP1cf4S41VFmOtt1fcOyu9
# 08FPHgOHS0Sb4+JARSbzJkkraoTxVHrUQtr802q7Zn7Knurpu9wHx8OSToM8gUmf
# ktUyCepJLqERcZo20sVOaLbLDhslFq9s3l122B9ysZMmhhfbGN6vRenf+5ivFBjt
# pF72iZRF8FUESt3/J90GSkD2tLzx5A+ZArv9XQ4uKMG+O18aP5cQhLwWPtijnGMd
# ZstcX9o+8w8KCTUi29vAPwD55g1dZ9H9oB4DK9lA977Mh2ZUgKajuPUZYtXSJrGY
# Ju6ay0SnRVqBlRUa9VEwggSUMIIDfKADAgECAhEAn+rIEbDxYkel/CDYBSOs5jAN
# BgkqhkiG9w0BAQUFADCBlTELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAlVUMRcwFQYD
# VQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3
# b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5jb20xHTAbBgNVBAMT
# FFVUTi1VU0VSRmlyc3QtT2JqZWN0MB4XDTE1MDUwNTAwMDAwMFoXDTE1MTIzMTIz
# NTk1OVowfjELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQx
# JDAiBgNVBAMTG0NPTU9ETyBUaW1lIFN0YW1waW5nIFNpZ25lcjCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBALw1oDZwIoERw7KDudMoxjbNJWupe7Ic9ptR
# nO819O0Ijl44CPh3PApC4PNw3KPXyvVMC8//IpwKfmjWCaIqhHumnbSpwTPi7x8X
# SMo6zUbmxap3veN3mvpHU0AoWUOT8aSB6u+AtU+nCM66brzKdgyXZFmGJLs9gpCo
# VbGS06CnBayfUyUIEEeZzZjeaOW0UHijrwHMWUNY5HZufqzH4p4fT7BHLcgMo0kn
# gHWMuwaRZQ+Qm/S60YHIXGrsFOklCb8jFvSVRkBAIbuDlv2GH3rIDRCOovgZB1h/
# n703AmDypOmdRD8wBeSncJlRmugX8VXKsmGJZUanavJYRn6qoAcCAwEAAaOB9DCB
# 8TAfBgNVHSMEGDAWgBTa7WR0FJwUPKvdmam9WyhNizzJ2DAdBgNVHQ4EFgQULi2w
# CkRK04fAAgfOl31QYiD9D4MwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAw
# FgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwQgYDVR0fBDswOTA3oDWgM4YxaHR0cDov
# L2NybC51c2VydHJ1c3QuY29tL1VUTi1VU0VSRmlyc3QtT2JqZWN0LmNybDA1Bggr
# BgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5j
# b20wDQYJKoZIhvcNAQEFBQADggEBAA27rWARG7XwDczmSDp6Pg4z3By56tYg/qNN
# 0Mx2TugY2Hnf00+aQmQjiilyijpsZqY8OheocEVlxnPD0M6JVPusaQ9YsBnLhp9+
# uX7rUZK/m93r0WXwJXuIfN69pci1FFG8wIEwioU4e+Z5/mdVk4f+T+iNDu3zcpK1
# womAbdFZ4x0N6rE47gOdABmlqyGbecPMwj5ofr3JTWlNtGRR+7IodOJTic6d+q3i
# 286re34GRHT9CqPJt6cwzUnSkmTxIqa4KEV0eemnzjsz+YNQlH1owB1Jx2B4ejxk
# JtW++gpt5B7hCVOPqcUjrMedYUIh8CwWcUk7EK8sbxrmMfEU/WwwggTnMIIDz6AD
# AgECAhAQcJ1P9VQI1zBgAdjqkXW7MA0GCSqGSIb3DQEBBQUAMIGVMQswCQYDVQQG
# EwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYD
# VQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cu
# dXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QwHhcN
# MTEwODI0MDAwMDAwWhcNMjAwNTMwMTA0ODM4WjB7MQswCQYDVQQGEwJHQjEbMBkG
# A1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYD
# VQQKExFDT01PRE8gQ0EgTGltaXRlZDEhMB8GA1UEAxMYQ09NT0RPIENvZGUgU2ln
# bmluZyBDQSAyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy/jnp+jx
# lyhAaIA30sg/jpKKkjeHR4DqTJnPbvkVR73udfRErNDD1E33GcDTPE3BR7lZZRaT
# jNkKhJuf6PZqY1j+X9zRf0tRnwAcAIdUIAdXoILJL5ivM4q7e4AiJWpsr8IsbHkT
# vaMqSNa1jmFV6WvoPYC/FAOFGI5+TOnCGYhzknLN+v9QTcsspnsac7EAkCzZMuL7
# /ayVQjbsNMUTU2iywZ9An9p7yJ1ibJOiQtd5n5dPMVtQIaGrr9kcss51vlssVgAk
# jRHBdR/w/tKV/vDhMSMYZ8BbE/1amJSU//9ZAh8ArObx8vo6c7MdQvxUdc9RMS/j
# 24HZdyMqT1nOIwIDAQABo4IBSjCCAUYwHwYDVR0jBBgwFoAU2u1kdBScFDyr3Zmp
# vVsoTYs8ydgwHQYDVR0OBBYEFB7FsSx9h9oCaHwlvAwHhD+2z97xMA4GA1UdDwEB
# /wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMD
# MBEGA1UdIAQKMAgwBgYEVR0gADBCBgNVHR8EOzA5MDegNaAzhjFodHRwOi8vY3Js
# LnVzZXJ0cnVzdC5jb20vVVROLVVTRVJGaXJzdC1PYmplY3QuY3JsMHQGCCsGAQUF
# BwEBBGgwZjA9BggrBgEFBQcwAoYxaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VU
# TkFkZFRydXN0T2JqZWN0X0NBLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL29jc3Au
# dXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQUFAAOCAQEAlYl3k2gBXnzZLTcHkF1a
# Ql4MZLQ2tQ/2q9U5J94iRqRJHGZLRhlZLnlJA/ackt9tUDVcDJEuYANZ0PFk92kJ
# 9n7+6zSzbbG/ZpyjujF4uYc1YT2SMRvv9Oie1qxF+gw2PIBnu73vLsKQ4T1xLzvB
# sFh+RcNScQMH9vM5TYs2IRsB39naXivrDpeAHkQcUIj1xhIzSqhNpY0vlAx7xr+a
# LMMyzb2MJybw4TADUAaCvPQ7s4N1Bsbvuu7TgPhSxqzLefI4nnuwklhCkQXIliGt
# uUsWgRRp8Tew/jT33LDfl/VDEJt2j7Rl9eifE7cerG/EaYpfujxhfl5JhiMTLq8V
# SDCCBS4wggQWoAMCAQICEHF/qKkhW4DS4HFGfg8Z8PIwDQYJKoZIhvcNAQEFBQAw
# ezELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4G
# A1UEBxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxITAfBgNV
# BAMTGENPTU9ETyBDb2RlIFNpZ25pbmcgQ0EgMjAeFw0xMzEwMjgwMDAwMDBaFw0x
# ODEwMjgyMzU5NTlaMIGdMQswCQYDVQQGEwJVUzEOMAwGA1UEEQwFMzc5MzIxCzAJ
# BgNVBAgMAlROMRIwEAYDVQQHDAlLbm94dmlsbGUxEjAQBgNVBAkMCVN1aXRlIDMw
# MjEfMB0GA1UECQwWMTAyMDcgVGVjaG5vbG9neSBEcml2ZTETMBEGA1UECgwKV2lu
# dGVsbGVjdDETMBEGA1UEAwwKV2ludGVsbGVjdDCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAMFQoSYu2olPhQGXgsuq0HBwHsQBoFbuAoYfX3WVp2w8dvji
# kqS+486CmTx2EMH/eKbgarVP0nGIA266BNQ5GXxziGKGk5Y+g74dB269i8G2B24X
# WXZQcw0NTch6oUcXuq2kOkcp1srh4Pp+HQB/qR33qQWzEW7yMlpoI+SwNoa9p1WQ
# aOPzoAfJdiSgInWGgrlAxVwcET0AmVQQKQ2lgJyzQkXIAiRxyJPSgKbZrhTa7/BM
# m33SWmG9K5GlFaw76HFV1e49v8hrTDFJJ7CAQz65IcazjqHTaKOfYhsPhiFrm/Ap
# kPUuJb45MeEPms8DzD8lTSQfo7eLkG2hNtxkRmcCAwEAAaOCAYkwggGFMB8GA1Ud
# IwQYMBaAFB7FsSx9h9oCaHwlvAwHhD+2z97xMB0GA1UdDgQWBBQEi+PkyNipSO6M
# 0oxTXEhobEPaWzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUE
# DDAKBggrBgEFBQcDAzARBglghkgBhvhCAQEEBAMCBBAwRgYDVR0gBD8wPTA7Bgwr
# BgEEAbIxAQIBAwIwKzApBggrBgEFBQcCARYdaHR0cHM6Ly9zZWN1cmUuY29tb2Rv
# Lm5ldC9DUFMwQQYDVR0fBDowODA2oDSgMoYwaHR0cDovL2NybC5jb21vZG9jYS5j
# b20vQ09NT0RPQ29kZVNpZ25pbmdDQTIuY3JsMHIGCCsGAQUFBwEBBGYwZDA8Bggr
# BgEFBQcwAoYwaHR0cDovL2NydC5jb21vZG9jYS5jb20vQ09NT0RPQ29kZVNpZ25p
# bmdDQTIuY3J0MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20w
# DQYJKoZIhvcNAQEFBQADggEBAB4m8FXuYk3D2mVYZ3vvghqRSRVgEqJmG7YBBv2e
# QCk9CYML37ubpYigH3JDzWMIDS8sfv6hzJzY4tgRuY29rJBMyaWRw228IEOLkLZq
# Si/JOxOT4NOyLYacOSD1DHH63YFnlDFpt+ZRAOKbPavG7muW97FZT3ebCvLCJYrL
# lYSym4E8H/y7ICSijbaIBt/zHtFX8RJvV7bijvxZI1xqqKyx9hyF/4gNWMq9uQiE
# wIG13VT/UmNCc3KcCsy9fqnWreFh76EuI9arj1VROG2FaYQdaxD2O+9nl+uxFmOM
# eOHqhQWlv57eO9do7PI6PiVGMTkiC2eFTeBEHWylCUFDkDIxggR6MIIEdgIBATCB
# jzB7MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAw
# DgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEhMB8G
# A1UEAxMYQ09NT0RPIENvZGUgU2lnbmluZyBDQSAyAhBxf6ipIVuA0uBxRn4PGfDy
# MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3
# DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEV
# MCMGCSqGSIb3DQEJBDEWBBTOLgKrJ9/Em4CuSUwV+a9h5LzqAjANBgkqhkiG9w0B
# AQEFAASCAQC6D+fGPeeJHmguB0NEde2qEqpvSHcc0X4sza1RuSxKw4M6nyYvTueh
# capsp3CEy6P1DShOY2yNBE/DdCOK9mBtk8qAyvyLfzrA58cv6hJLk89PCSQkPh6R
# hP/nbbrt3fQE1PHylDy+74Ex1oTJXxe/IolfJLqFUBZiYqtDA6r1tmCXtc0jgX7G
# QG6f6FPm9MOd9S3u6VO8puJwa1PgzkPrTg8oiVzjlZ7ky/5tHGlVGTQqeUIyisa8
# xUWyFOYtzPuPGh0JLOq7cRp65X62miGZ0oBxcAPq8Ou4DvhdHpDW2XHDl4jI2J0u
# Mr5oXs9p/oHcNfyuyxiGzMNMN4Rnx33KoYICRTCCAkEGCSqGSIb3DQEJBjGCAjIw
# ggIuAgEAMIGrMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcT
# DlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# ITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVRO
# LVVTRVJGaXJzdC1PYmplY3QCEQCf6sgRsPFiR6X8INgFI6zmMAkGBSsOAwIaBQCg
# XTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTA3
# MDkxNzIwMThaMCMGCSqGSIb3DQEJBDEWBBShkiMY80DjPRARBmzNPUxLMLf7RzAN
# BgkqhkiG9w0BAQEFAASCAQAoH5imjbfVA+XUoCpNavDZFABBhgIJH/HfxcJIsipS
# nWJCqoXrH4GESJGykuBjKocldbumpS2yEDmi1MkOLPTp19VpwGYssYuzOlFRRZzk
# MsFVS+Nd6ZT6eFaqMD7cpIW3djXx+3z9h7xqmcPB2Lb480hCAUP5Xyh9f4wjMffj
# 5MdnoEXD995t1zzTFDSvYsHPlYsO3bN6ra/6ZzXK2hkSm+ldERHLBPY0oxN4CXWV
# 5fykFzX23yw1l7J9itFO+M+qOihRbeykPBdGeUaC+ZS2PmOKD16dWq/arxrhr46i
# RAeigyGfzkswRz67p6Ij6KgcG0+5LYPrPLflyLBz0MZv
# SIG # End signature block
