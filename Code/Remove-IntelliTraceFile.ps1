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

By default, this script works with Visual Studio 2010, 2012, 2013, and 2015
with the default being VS 2015.

.PARAMETER VSVersion
Removes the stored IntelliTrace files for VS 2013 by default, specify VS 2010 or VS 2012
for those versions.

.LINK
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param ( 
            [ValidateSet("VS2010", "VS2012", "VS2013", "VS2015", "Latest")]
            [string] $VSVersion = "Latest"
          )

    # First check if VS is running. If so, we can't continue as it may be using
    # the .iTrace files.
    $proc = Get-Process -Name devenv -ErrorAction SilentlyContinue
    if ($null -ne $proc)
    {
        throw "Visual Studio is running. Please close all instances."
    }

    $regVer = "14.0"
    # Default to VS 2015.
    switch ($VSVersion)
    {
        "VS2010" { $regVer = "10.0" }
        "VS2012" { $regVer = "11.0" }
        "VS2013" { $regVer = "12.0" }
        "VS2015" { $regVer = "14.0" }
        "Latest" { $regVer = LatestVSRegistryKeyVersion }
    }

    [string]$storageDir = ""
    $regKey = "HKCU:\SOFTWARE\Microsoft\VisualStudio\$regVer\ApplicationPrivateSettings\Microsoft\VisualStudio\TraceLogPackage\ToolsOptionAdvanced"

    if ($regVer -lt "14.0")
    {
        $regKey = "HKCU:\Software\Microsoft\VisualStudio\" + 
                  $regVer + 
                  "\DialogPage\Microsoft.VisualStudio.TraceLogPackage.ToolsOptionAdvanced"
    }

    # Check to see if the user has set the options to save files. If not bail out.
    if (((Test-PathReg -Path $regKey -Property "SaveRecordings") -eq $false) -or 
        ((Get-ItemProperty -Path $regKey).SaveRecordings -match "False"))
    {
        throw "You have not configured IntelliTrace to save recordings. " +
                "In the Options dialog, IntelliTtrace Advanced page, check the " +
                "Store IntelliTrace recordings in this directory check box."
    }

    if ((Test-PathReg -Path $regKey -Property "RecordingPath") -ne $false)
    {
        # Get the storage directory for those files.
        $storageDir = (Get-ItemProperty -Path $regKey).RecordingPath
    }

    # If this is version 14.0 or greater it will have some gunk on the beginning.
    if ($storageDir.StartsWith("1*System.String*"))
    {
        $storageDir = $storageDir.Substring("1*System.String*".Length)
    }
        

    if ($storageDir.Length -eq 0)
    {
        throw "The IntelliTrace recording directory is empty. Check the " +
              "Options dialog, IntelliTrace Advanced page to set the "+
              "directory."
    }

    if ($PSCmdlet.ShouldProcess($storageDir,"Deleting files in"))
    {

        # Clean up those files but only do the ones in the main directory so if the
        # user may have created paths and put other files there we don't delete those.
        Get-ChildItem -Path $storageDir -Filter "*.iTrace" | Remove-Item -Force
    }
}

# SIG # Begin signature block
# MIIYTQYJKoZIhvcNAQcCoIIYPjCCGDoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU0Vc69sZvWsCKBLPdW2NDJqpt
# Lu2gghM9MIIEhDCCA2ygAwIBAgIQQhrylAmEGR9SCkvGJCanSzANBgkqhkiG9w0B
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
# MCMGCSqGSIb3DQEJBDEWBBQ67FtXxwwbVEgmk38toLykVa0fDDANBgkqhkiG9w0B
# AQEFAASCAQCIfIf4p0c4mxw6mAwurXCZtQngVVYGxMJHzOr7k9fE6hzY1Hdws87J
# zl/mmeF8WspvhJ3m8P9EUuMQJsSAWsn+Ven16RTS72K7GslVDkORWUnvThEasgp9
# O00nxrME+afuFa/7O9th9bnMuREaRK9fzscRLms6I9Dmaz5x36RmY84orREkT+Mx
# ubzLNonrGr3EMbNZLdpn/N8WVPwr+KX59IlnT5cY3EhUHKjkRx5uvIhZMsDRpMup
# iO2qbGIXHr2h1lz3j9vZ9059ntiaFZADqVAWSIC8a0ub5wY2w0aU6mEGBq4zTIpJ
# ti0/vJiulrmG0JWWmcVQM2WYgSD9EK0foYICRTCCAkEGCSqGSIb3DQEJBjGCAjIw
# ggIuAgEAMIGrMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcT
# DlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# ITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVRO
# LVVTRVJGaXJzdC1PYmplY3QCEQCf6sgRsPFiR6X8INgFI6zmMAkGBSsOAwIaBQCg
# XTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTEw
# MjIwMTMwMDNaMCMGCSqGSIb3DQEJBDEWBBSS/Dh83Sw57/PoxNUranqZL3mLgzAN
# BgkqhkiG9w0BAQEFAASCAQCmGyCyZjWtf1/zaE2bsMJHk2ia6nvP1uHPf5tlKfHR
# tJcBn9O3kbRKC+Q8qOGsUi5f0DTYPgp7NZchJyR2XAAqxKkr/dgjwApGQnIBLGBG
# NJr7xvUILkpI8WFQGMptfkju6NP/G2iUiYLAy7IvRskbQBvsPs9zXKApwa60sSr2
# H5qjJp/YMkvXIS57OvVOC8X1ds7tjMh88ORgJI8pS72Px5585IChuFAeT7idfYaF
# N6GhYC7HQCTMPkGUO+sOy4djYsl1enXxN1Ggn8SJj42RS0oIkkoWalQPIJU3iYyW
# 5bfqA+gLJ0LL6pgbr0/l0Q1tDODPwtgXVtR9a1zM+UyW
# SIG # End signature block
