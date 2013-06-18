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

    if ([IntPtr]::size -eq 8)
    {
        $versionSearchKey = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7"
    }
    else
    {
        $versionSearchKey = "HKLM:\SOFTWARE\Microsoft\VisualStudio\SxS\VS7"
    }
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
# SIG # Begin signature block
# MIIO0QYJKoZIhvcNAQcCoIIOwjCCDr4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWHWKAUhmRfdNUidzis/G4nXz
# 5dKgggmnMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
# AQUFADCBlTELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAlVUMRcwFQYDVQQHEw5TYWx0
# IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMSEwHwYD
# VQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5jb20xHTAbBgNVBAMTFFVUTi1VU0VS
# Rmlyc3QtT2JqZWN0MB4XDTEwMDUxMDAwMDAwMFoXDTE1MDUxMDIzNTk1OVowfjEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BxMHU2FsZm9yZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxJDAiBgNVBAMT
# G0NPTU9ETyBUaW1lIFN0YW1waW5nIFNpZ25lcjCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBALw1oDZwIoERw7KDudMoxjbNJWupe7Ic9ptRnO819O0Ijl44
# CPh3PApC4PNw3KPXyvVMC8//IpwKfmjWCaIqhHumnbSpwTPi7x8XSMo6zUbmxap3
# veN3mvpHU0AoWUOT8aSB6u+AtU+nCM66brzKdgyXZFmGJLs9gpCoVbGS06CnBayf
# UyUIEEeZzZjeaOW0UHijrwHMWUNY5HZufqzH4p4fT7BHLcgMo0kngHWMuwaRZQ+Q
# m/S60YHIXGrsFOklCb8jFvSVRkBAIbuDlv2GH3rIDRCOovgZB1h/n703AmDypOmd
# RD8wBeSncJlRmugX8VXKsmGJZUanavJYRn6qoAcCAwEAAaOB9DCB8TAfBgNVHSME
# GDAWgBTa7WR0FJwUPKvdmam9WyhNizzJ2DAdBgNVHQ4EFgQULi2wCkRK04fAAgfO
# l31QYiD9D4MwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwQgYDVR0fBDswOTA3oDWgM4YxaHR0cDovL2NybC51c2Vy
# dHJ1c3QuY29tL1VUTi1VU0VSRmlyc3QtT2JqZWN0LmNybDA1BggrBgEFBQcBAQQp
# MCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZI
# hvcNAQEFBQADggEBAMj7Y/gLdXUsOvHyE6cttqManK0BB9M0jnfgwm6uAl1IT6TS
# IbY2/So1Q3xr34CHCxXwdjIAtM61Z6QvLyAbnFSegz8fXxSVYoIPIkEiH3Cz8/dC
# 3mxRzUv4IaybO4yx5eYoj84qivmqUk2MW3e6TVpY27tqBMxSHp3iKDcOu+cOkcf4
# 2/GBmOvNN7MOq2XTYuw6pXbrE6g1k8kuCgHswOjMPX626+LB7NMUkoJmh1Dc/VCX
# rLNKdnMGxIYROrNfQwRSb+qz0HQ2TMrxG3mEN3BjrXS5qg7zmLCGCOvb4B+MEPI5
# ZJuuTwoskopPGLWR5Y0ak18frvGm8C6X0NL2KzwwggUMMIID9KADAgECAhA/+9To
# TVeBHv2GK8w5hdxbMA0GCSqGSIb3DQEBBQUAMIGVMQswCQYDVQQGEwJVUzELMAkG
# A1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVUaGUg
# VVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRydXN0
# LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QwHhcNMTAxMTE3MDAw
# MDAwWhcNMTMxMTE2MjM1OTU5WjCBnTELMAkGA1UEBhMCVVMxDjAMBgNVBBEMBTM3
# OTMyMQswCQYDVQQIDAJUTjESMBAGA1UEBwwJS25veHZpbGxlMRIwEAYDVQQJDAlT
# dWl0ZSAzMDIxHzAdBgNVBAkMFjEwMjA3IFRlY2hub2xvZ3kgRHJpdmUxEzARBgNV
# BAoMCldpbnRlbGxlY3QxEzARBgNVBAMMCldpbnRlbGxlY3QwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCkXroYjDClgcwb0IBbzJNPgxvmbD9p/y3KsFml
# OCUaSufECEh0nKtVqN+3sfdlXytYuBxZP4lDsEbwfp1ppBfeemIiXWDh0ZQYEJYq
# u3/YWqrYNyMJKeeJz7KRvN8pV4N2u+nAIDPVJFfjSqA17ZYRVZs8FigRDgcYJpnA
# GkBDjIWTKkBwc/Nhk9w1XKhDFfZwvvnYeCnNZkvPxslEOu/5p5WWJW0nWpvT9BY/
# b9PR/JDRsdnFrlvZuzrk7NDyNvDMczKCUzSnHHZh60ttRV13Raq0gDaKsSrcPk6p
# AN/HsPJQAUQNBWP+3BWmV6YFfQbCfKmZZBF4Sf/q5SdXsDA7AgMBAAGjggFMMIIB
# SDAfBgNVHSMEGDAWgBTa7WR0FJwUPKvdmam9WyhNizzJ2DAdBgNVHQ4EFgQU5qYw
# jjsOnxQvFZoWoZfp6sy4XuIwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4QgEBBAQDAgQQMEYGA1UdIAQ/
# MD0wOwYMKwYBBAGyMQECAQMCMCswKQYIKwYBBQUHAgEWHWh0dHBzOi8vc2VjdXJl
# LmNvbW9kby5uZXQvQ1BTMEIGA1UdHwQ7MDkwN6A1oDOGMWh0dHA6Ly9jcmwudXNl
# cnRydXN0LmNvbS9VVE4tVVNFUkZpcnN0LU9iamVjdC5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEFBQADggEBAEh+3Rs/AOr/Ie/qbnzLg94yHfIipxX7z1OCyhW7YNTOCs48
# EIXXzaJxvQD57O+S3HoHB2ZGA1cZokli6oAQNnLeP51kxQJKcTVyL2sSkKSV/2ev
# YtImhRTRCZMXe0OrGdL3Ry7x9EaaiRrhwfVJBGbqeeWc6cprFGkkDm7KpKKoCxjv
# DF3fkQ1V0QEJXQLTnEndQB+cLKIlP+swWQQxYLhfg+P8tQ+qwAbnBNYZ7+L5TiwZ
# 8Pp0S6+T94SiuoG85E1oaQUtNT1SO8FLQa4M3bO5xdGA2GL1Vti/W8Gp8tIPr/wM
# Ak4Xt++emsid5THDZkjSrFMqbCHmaxoTmtcutr4xggSUMIIEkAIBATCBqjCBlTEL
# MAkGA1UEBhMCVVMxCzAJBgNVBAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0
# eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRw
# Oi8vd3d3LnVzZXJ0cnVzdC5jb20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2Jq
# ZWN0AhA/+9ToTVeBHv2GK8w5hdxbMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQK3UzimzopTXwD
# 0nGy5tNMyk6gLzANBgkqhkiG9w0BAQEFAASCAQAX/yTwoPeakagFKthY0PKcJsYn
# m3ljn5Dk4UdPtGUAo6QdQc2DDmQFd3ZfHqi11UP5vKde1L1/O1AEZ6i1AXt502wH
# uGSk2+H7xHCB6lR5P6IADgaBtKcVPZQG5P6bVJC1KbkmgUwdHBmCijscIaucSSM3
# XjssWO48d+AK0Cp8E9JqLyw57h6hCp5yAgs2Oz0qqcZ7x6xPf6VyKy5W48N9Hk+f
# qfc2CDPN0liUKu6LtJGGEZEhYf0s+A55zb9lrNBqoqfAw7oX91IqZbCsAbr4hNi4
# cvDKbxT6eC9g1goxrpvBhU1z+/PDMHb2GLQXKPZVCZI1YAsSIJD6oqCtsRU/oYIC
# RDCCAkAGCSqGSIb3DQEJBjGCAjEwggItAgEAMIGqMIGVMQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRy
# dXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QCEEeKjvtZ4dg/
# DOFC0qKHB74wCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEzMDUyMjA2MDYzMlowIwYJKoZIhvcNAQkEMRYEFIe0
# ZxAydoFLHVFc/rxZ4sNqNOQoMA0GCSqGSIb3DQEBAQUABIIBAAu6f8SyOv7oK5mR
# g3swNI+6O28OBDNpuXboi2P7mHeHN7pNjh1wWZBfCjLNHNojhakic/BUkdtwspYY
# Bris1ucdpPKJ8FZxQd3yhyOgyd+1zn8m1PA2OpghMBi5Dg077+z2SEQ1dOk4l1kK
# ztefgVcDTXeyQL/O8oCmPaIwrtw7NpdSauTmx7vAEXh+MdI7FIsEmA3Eh44R6dVw
# cgaYNgy3MNBCiSA/DuZ+2S9mC4xf/B3QQLuILAEHKSGwhdbBIdPfSxlp6OjcUfKs
# 9sWCJppxC6k0kk+OdQNYSFC95LNEZTMpovTN1WuRJr96bs/m3pGii76uz8cWJidj
# +g3jrvw=
# SIG # End signature block
