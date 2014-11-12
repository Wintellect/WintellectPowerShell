
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

function LatestVSRegistryKeyVersion
{
    $versionSearchKey = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7"
    if ([IntPtr]::size -ne 8)
    {
        $versionSearchKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\SxS\VS7"    
    }
    $biggest = 0.0
    Get-RegistryKeyPropertiesAndValues $versionSearchKey  | 
        ForEach-Object { 
                            if ([System.Convert]::ToDecimal($_.Property) -gt [System.Convert]::ToDecimal($biggest))
                            {
                                $biggest = $_.Property
                            }
                        }  

    $biggest
}
