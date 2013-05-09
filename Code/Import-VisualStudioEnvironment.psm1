#requires -version 2.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2013 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest

Function Get-RegistryKeyPropertiesAndValues

{
  <#
   .Synopsis
    This function accepts a registry path and returns all reg key properties and values

   .Description
    This function returns registry key properies and values.

   .Example
    Get-RegistryKeyPropertiesAndValues -path 'HKCU:\Volatile Environment'

    Returns all of the registry property values under the \volatile environment key

   .Parameter path
    The path to the registry key

   .Notes
    NAME:  Get-RegistryKeyPropertiesAndValues
    AUTHOR: ed wilson, msft
    LASTEDIT: 05/09/2012 15:18:41
    KEYWORDS: Operating System, Registry, Scripting Techniques, Getting Started
    HSG: 5-11-12
   .Link
     Http://www.ScriptingGuys.com/blog
 #>

    Param( [Parameter(Mandatory=$true)]
           [string]$path)

     Push-Location
     Set-Location -Path $path
     Get-Item . |
        Select-Object -ExpandProperty property |
            ForEach-Object {
                New-Object psobject -Property @{"property"=$_;
                    "Value" = (Get-ItemProperty -Path . -Name $_).$_}}
     Pop-Location

} 

###############################################################################
# Public Cmdlets
###############################################################################
function Import-VisualStudioEnvironment
{
<#
.SYNOPSIS
Sets up the current PowerShell instance with the Visual Studio environment
variables so you can use those tools at the command line.

.DESCRIPTION
Command line usage is the way to go, but Visual Studio requires numerous 
environment variables set in order to properly work. Since those are controlled
by the vcvarsall.bat cmd script, it's a pain to get working. This script
does the work of calling the specific vscarsall.bat file for the specific version
of Visual Studio you want to use.

This implementation uses the registry to look up the installed Visual Studio 
versions and does not rely on any preset environment variables such as 
VS110COMNTOOLS. 

.PARAMETER VSVersion
The version of Visual Studio you want to use. If left to the default, Latest, the
script will look for the latest version of Visual Studio installed on the computer
as the tools to use. Specify 2008, 2010, 2012, or 2014 for a specific version.

.PARAMETER Architecture
The tools architecture to use. This defaults to the $env:PROCESSOR_ARCHITECTURE 
environment variable so x86 and x64 are automatically handled. The valid architecture 
values are x86, amd64, x64, arm, x86_arm, and x86_amd64.

.LINK
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>

    param
    (
        [Parameter(Position=0)]
        [ValidateSet("Latest", "2008", "2010", "2012", "2014")]
        [string] $VSVersion = "Latest", 
        [Parameter(Position=1)]
        [ValidateSet("x86", "amd64", "x64", "arm", "x86_arm", "x86_amd64")]
        [string] $Architecture = ($Env:PROCESSOR_ARCHITECTURE)
    )  

    $versionSearchKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\SxS\VS7"
    $vsDirectory = ""

    if ($VSVersion -eq 'Latest')
    {
        # Find the largest number in the install lookup directory and that will
        # be the latest version.
        $biggest = 0.0
        Get-RegistryKeyPropertiesAndValues $versionSearchKey  | 
            ForEach-Object { 
                                if ([System.Convert]::ToDecimal($_.Property) -gt [System.Convert]::ToDecimal($biggest))
                                {
                                    $biggest = $_.Property
                                    $vsDirectory = $_.Value 
                                }
                            }  
    }
    else
    {
        $propVal = switch($VSVersion)
                    {
                        "2008" { "9.0" }
                        "2010" { "10.0" }
                        "2012" { "11.0" }
                        # I have no idea if this is the next version of VS. It's just a guess!
                        "2014" { "12.0" }
                        default { throw "Unknown version of Visual Studio!" }
                    }

        $vsDirectory = (Get-ItemProperty $versionSearchKey).$propVal
    }

    if ([String]::IsNullOrEmpty($vsDirectory))
    {
        throw "The requested Visual Studio version is not installed"
    }  

    # Got the VS directory, now setup to make the call.
    Invoke-CmdScript -script "$vsDirectory\vc\vcvarsall.bat" -parameters "$Architecture"
}

Export-ModuleMember Import-VisualStudioEnvironment
###############################################################################