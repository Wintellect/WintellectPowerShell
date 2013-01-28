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

###############################################################################
# Public Cmdlets
###############################################################################
function Remove-IntelliTraceFiles
{
<#
.SYNOPSIS
Removes extra IntelliTrace files that may have been left over from your 
debugging sessions.

.DESCRIPTION
Best practice with day to day debugging with IntelliTrace is to have the 
debugger store the IntelliTrace files. This is important because you will gain 
the ability to open the files after debugging. This option is not on by default, 
but can be turned on by going to the VS Options dialog, IntelliTrace, Advanced 
property page and checking "Store IntelliTrace recordings in this directory." 

Once you have your IntelliTrace files being saved you have a small issue that 
VS does not always properly clean up the files after shutting down. This 
cmdlet checks to see if you are storing the files and if you are, deletes any 
files found in the storage directory. Since IntelliTrace files can take up a 
lot of disk space, it's good to clean out that directory every once in a while.

By default, this script works with Visual Studio 2012, but if you need to 
delete the IntelliTrace files for Visual Studio 2010, pass the -VS2010 switch.

.PARAMETER VS2010
Removes the stored IntelliTrace files for VS 2010. If not specified, does the 
deletions for VS 2012.

.LINK
http://www.wintellect.com/cs/blogs/jrobbins/default.aspx
https://github.com/Wintellect/WintellectPowerShell

#>
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param ( [switch] $VS2010 )

    # First check if VS is running. If so, we can't continue as it may be using
    # the .iTrace files.
    $proc = Get-Process devenv -ErrorAction SilentlyContinue
    if ($proc -ne $null)
    {
        throw "Visual Studio is running. Please close all instances."
    }

    # Default to VS 2012.
    $vsVersion = "11.0"
    if ($VS2010)
    {
        $vsVersion = "10.0"
    }

    $regKey = "HKCU:\Software\Microsoft\VisualStudio\" + 
              $vsVersion + 
              "\DialogPage\Microsoft.VisualStudio.TraceLogPackage.ToolsOptionAdvanced"

    # Check to see if the user has set the options to save files. If not bail out.
    if ( ((Test-PathReg $regKey "SaveRecordings") -eq $false) -or ((Get-ItemProperty $regKey).SaveRecordings -eq "False"))
    {
        throw "You have not configured IntelliTrace to save recordings. " +
              "In the Options dialog, IntelliTtrace Advanced page, check the " +
              "Store IntelliTrace recordings in this directory check box."
    }
    
    $storageDir = ""
    if ((Test-PathReg $regKey "RecordingPath") -ne $false)
    {
        # Get the storage directory for those files.
        $storageDir = (Get-ItemProperty $regKey).RecordingPath
    }

    if ($storageDir.Length -eq 0)
    {
        throw "The IntelliTrace recording directory is empty. Check the " +
              "Options dialog, IntelliTrace Advanced page to set the "+
              "directory."
    }

    # Clean up those files but only do the ones in the main directory so if the
    # user may have created paths and put other files there we don't delete those.
    Get-ChildItem -Path $storageDir -Filter "*.iTrace" | Remove-Item -Force
}

# SIG # Begin signature block
# MIIO0QYJKoZIhvcNAQcCoIIOwjCCDr4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUiISbgW8IUNeJiH4Oly0WJTYG
# kAmgggmnMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQPcP3nCKfuKUWj
# dnYnpEo0+zzzSDANBgkqhkiG9w0BAQEFAASCAQBjN2GLP4dJSblT4a8IpzG9+l+M
# mjf4VMH9alc7L73ERFjsR7Oun3hDLXf70ra+lM5xAMyMeJk6kxOyjv5reLR3oK8E
# LDX+zVvkthGJd8oDTLHn32XROSmGIFshWhekiWItZKcpzHFolg2AwSdU4NF/T6Pu
# F1eHnb+SYYoi/jwT7dP2Yk6RdMw2JlDst3U1r7C2+XFQo/yd/NTrqjT+ZrfU+Nmw
# GVVYieCXcliLPCDLB3j4qzFVPmFd4dBzE74WAcRfZ97aUFEGX7IUzHB6tclNkwqi
# Ol+KCM9uzduhBy9wESM5M2zfdrv2OSba0h2JeGk5UtkS9lXbG7RaUMv6i+BgoYIC
# RDCCAkAGCSqGSIb3DQEJBjGCAjEwggItAgEAMIGqMIGVMQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRy
# dXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QCEEeKjvtZ4dg/
# DOFC0qKHB74wCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEzMDEyNzA4MDEzMlowIwYJKoZIhvcNAQkEMRYEFPEu
# VoxkMBziqPaXiROUSsn45uc9MA0GCSqGSIb3DQEBAQUABIIBAHCl8GvQE26CAQhO
# VXOUTjPOksl/vpbTGDsSqjdFm6UgGsQdlZbeo+Kvs+FB3lGdg0aVZvB1GqQmp3AQ
# Em+x5MG0WJmBRZXt2Oz5YwfXmDcFsjDZY5pPFRpG+mG7tnPXgQnQq7Sjz8+twjAb
# BEjOx3RSezW+oP3Bd2v5SPFllE449v6xZC5iCIMC3uhj1KVwhxfpj7X/rOJxA7/q
# jm+rvp7eO5To2ZHMopAjN2DRaRHOR0ezOIMt0AklULEw44mQvhTwxlIplDlHMQsz
# d1NuF3CJRLn2jNPuxhvT1OqTG+p+TfZ1cUT+ndl8gXAwrZxH+Xzi4a10aLSNEdbo
# LEK1Tjo=
# SIG # End signature block
