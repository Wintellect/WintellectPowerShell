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
function Expand-ZipFile
{
<#
.SYNOPSIS
Expands a .ZIP file to the specified directory.

.DESCRIPTION
Using no external ZIP utilities, expands a .ZIP file to a specified directory.

.PARAMETER ZipFile
The .ZIP file to expand.

.PARAMETER Destination
The output directory for the ZipFile. If this directory does not exist, it will
be created.

.LINK
http://www.wintellect.com/cs/blogs/jrobbins/default.aspx
https://github.com/Wintellect/WintellectPowerShell

#>

    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the zip file to expand")]
        [string] $ZipFile ,
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the directory to expand into")]
        [string] $Destination
    ) 
    # Basic idea found here 
    # http://ochoco.blogspot.com/2009/04/quick-bytes-unzipping-zip-file-using.html.
    # Tweaked to be more usable.
    
    if (! (Test-Path $ZipFile))
    {
        throw "The zip file must exist."
    }
    
    New-Item -ItemType Directory -Path $Destination -ErrorAction SilentlyContinue > $null
    
    # It's important you get the full path at the shell application fails if 
    # you're using a relative path.
    $Destination = Resolve-Path $Destination
    
    $shellApplication = new-object -com shell.application 
    $zipPackage = $shellApplication.NameSpace($ZipFile) 
    $destinationFolder = $shellApplication.NameSpace($Destination) 
    # The first parameter to CopyHere are all the files, the second parameter
    # of 20 says to turn off the default UI of the progress dialog and say 
    # yes to all dialog boxes.
    # All the codes can be found here:
    # http://social.technet.microsoft.com/Forums/en-US/winserverpowershell/thread/b77840b8-459d-4509-8cc8-8fc7f6603e86
    $destinationFolder.CopyHere($zipPackage.Items(),20) 
}

# SIG # Begin signature block
# MIIO0QYJKoZIhvcNAQcCoIIOwjCCDr4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDCDSaynh/bGreypIWZZ7XocY
# NXWgggmnMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRB5IvDo6YwSzdn
# YGnL1/Nw3MvORjANBgkqhkiG9w0BAQEFAASCAQCTNid8UU0Gs5CQBcrDse41ODlL
# F+uorTIjMM0cq52DPe+HE3VXZMjNUagS6wGshacfYzUBEwffC474weTYWfhNO80/
# PUlG4rb7MLC0oHdJStVKJERpPcDo+Il2MOIjsvCaqaJofRXNb8XzgvYXhUba/xJU
# dXqqlmF3Ak1KTvnd8Kv/e15ilAy3oLq4I0ooTg8bEKBVU/GkEkcr7kdHC4+w9MQb
# 2ZYh74YsI6tH4zrParXXboABdviZBygJ5igMdl5JNejxANcuJGQbjtlNRn9BEZwL
# smUxnWRmqUWIZma/+umdEhz7ZDjOG7qaqcaXY+hm8XxBR5/0r+nYepoHfC7zoYIC
# RDCCAkAGCSqGSIb3DQEJBjGCAjEwggItAgEAMIGqMIGVMQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRy
# dXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QCEEeKjvtZ4dg/
# DOFC0qKHB74wCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEzMDEyNzA4MDEzMVowIwYJKoZIhvcNAQkEMRYEFJqo
# vG6sDmQGPxFXR4Jlq3RbD2t3MA0GCSqGSIb3DQEBAQUABIIBAHbxuipkLYOeTT7J
# 7G1DpuYXXnrnp0vLFO59FZeoi0Iaq9GpOP6seK3/Ed1SrTDJ3sx9Mk3pl/Vn2HCf
# o+8m4+K321J+7F7rFz0xZVi/FUEL5m0dz2WNH30GRvRSHFWVbOKthfWizQ92QQY5
# 1MPWegKcR0q8C7sWcRxQ2hNBwADQCkGaDqUJ/kirfi+va3hIOVv2Xds8TnmWyBj0
# bWo/8fGePQFdiqun+LkmqYqh4PzqE2MfHrlMxBB9R0WHbDlye5yna5AxHq+TIid4
# vA9F3fOMTiHld78VD9av8l6oSBMQH5lEQfOqh7w/cngHV+ZFRKAgig8WgVIf0LMP
# hEiCTsw=
# SIG # End signature block
