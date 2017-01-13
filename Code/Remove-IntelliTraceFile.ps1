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

By default, this script works with Visual Studio 2013, 2015 and 2017 with the 
default being VS 2017.

.PARAMETER VSVersion
Removes the stored IntelliTrace files for VS 2017 by default, specify VS 2013 or 
VS 2015 for those versions.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>
    [CmdLetBinding(SupportsShouldProcess=$true)]
    # I hate suppressing this warning, but I created this cmdlet long before the 
    # script analyzer came out. If someone has this in a script, changing the
    # cmdlet name will break them.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function")]
    param ( 
            [ValidateSet("VS2013", "VS2015", "VS2017", "Latest")]
            [string] $VSVersion = "Latest"
          )

    # First check if VS is running. If so, we can't continue as it may be using
    # the .iTrace files.
    $proc = Get-Process -Name devenv -ErrorAction SilentlyContinue
    if ($null -ne $proc)
    {
        throw "Visual Studio is running. Please close all instances."
    }

    # Default to VS 2017.
    $regVer = "15.0"

    switch ($VSVersion)
    {
        "VS2013" { $regVer = "12.0" }
        "VS2015" { $regVer = "14.0" }
        "VS2017" { $regVer = "15.0" }
        "Latest" { $regVer = LatestVSRegistryKeyVersion }
    }

    [string]$storageDir = ""
    
    # Am I supposed to look for VS 2017 or higher? If so, we have work to do because VS 2017 completely changed the 
    # way version detection and the registry are handled. These changes are excellent for performance, but cause
    # more work on my side. Oh well. :)

    if ($regVer -lt "15.0")
    {
        # Handle older versions of Visual Studio.
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
    }
    else 
    {
        # OK, I'm supposed to do the spiffy new versions. 
        # 1. See if any VS 2017 versions are installed and if any are Enterprise versions
        # Load my helper that wraps the VS 2017+ setup configuration component.
        $loadResult = Get-ChildItem -Path $PSScriptRoot -File "WintellectPowerShellHelper.DLL" -ErrorAction Stop | ForEach-Object {[Reflection.Assembly]::LoadFile($_.FullName)}

        if ($null -eq $loadResult)
        {
            throw "Unable to find the required WintellectPowerShellHelper.DLL in the WintellectPowerShell module directory"
        }

        $vsInstalls = [WintellectPowerShellHelper.VisualStudioSetup]::GetInstalledInstances()
        if ($vsInstalls.Count -eq 0)
        {
            throw "No Visual Studio 2017+ instances installed on this computer"
        }

        # 2. Get the instance ID for the Enterprise version that matches the one the user want to clean up.
        $vsToProcess = $null
        for ($i = 0; $i -lt $vsInstalls.Count; $i++) 
        {
            if (($vsInstalls[$i].ProductName.Contains("Enterprise")) -and 
               ($vsInstalls[$i].InstalledVersionNumber.Substring(0,2) -eq $regVer.SubString(0,2)))
            {
                $vsToProcess = $vsInstalls[$i]
                break
            }
        }
        
        if ($null -eq $vsToProcess)
        {
            throw "The Visual Studio version you requested is not an Enterprise edition"
        }

        # 3. Open the registry file in privateregistry.bin and read the value.
        $regFilePath = $env:LOCALAPPDATA + "\Microsoft\VisualStudio\" + $regVer + "_" + $vsToProcess.InstanceId + "\privateregistry.bin"

        if (! (Test-Path $regFilePath))
        {
            throw "The privateregistry.bin file does not exist"
        }

        $regKey = "Software\Microsoft\VisualStudio\15.0_" + $vsToProcess.InstanceId + "\ApplicationPrivateSettings\Microsoft\VisualStudio\TraceLogPackage\ToolsOptionAdvanced"

        $storageDir = [WintellectPowerShellHelper.PrivateRegistry]::ReadValue($regFilePath, $regKey, "RecordingPath")

        if ($storageDir.StartsWith("1*System.String*"))
        {
            $storageDir = $storageDir.Substring("1*System.String*".Length)
        }

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
# MIIUywYJKoZIhvcNAQcCoIIUvDCCFLgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUGFtrotEPc58Tn6zgjTibodby
# PZ2ggg+6MIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUlo3+yd8djr4Z8DqYSlGV
# fYEsSiMwDQYJKoZIhvcNAQEBBQAEggEALLg9AywkktL0bDZeeRxboCyK3ew3doYA
# jN+Ghpf6A4/5oBX2m4Qt6/mUVlVJ1fqisPYJp6gSOmQPP3Nk4CuKb0fPDoX6doBI
# Ep1JiTaCTMIgJEXJORVuxf7URU4+BV8zOP4lvCakb7/uJH40l+IenwecaBCrRfO7
# ztoHyh+HXatuoymXnS1HpX6F6J88RKo6pxpIcaGxJ48MGRkJD4EU3LY9KCpzHt0P
# sxI4hZiKmTQuAC6VeV1bndNAGfBEIa8SwIoQhhfD4v/HoTBsXyMDbE+N/6LRA3Ut
# WjI0DkppZGjYVK7CJESl1pXPAvvyPh6GETr6xjNs1pW54eJTg595WqGCAkMwggI/
# BgkqhkiG9w0BCQYxggIwMIICLAIBADCBqTCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0Ag8WiPA5JV5jjmkUOQfm
# MwswCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZI
# hvcNAQkFMQ8XDTE3MDExMjIzMDcyMlowIwYJKoZIhvcNAQkEMRYEFLZ0o44SlFOg
# cay4JDW9b6LqooFaMA0GCSqGSIb3DQEBAQUABIIBAAVHzb7gvhK2e7NIGQ84xrbi
# 7FfGjheBcYU7G2icZRjzSBtnYhHI50RDiqui33s2MOQuxevZueWaLIt0FPOBFXeH
# hUQHf1Dlt9jz0dYya6/pbndPpHmBzdLdW2NbieHGy9GF+17/QsvEt/uZDcP7XdB+
# HhrWWSlghgEcazQpe0u/OixbjDjXo88M1UvDpVMKldldAqaw6KObuOpBQWi/+j1H
# wKHQJrF2Lh4szccNXqa8AkMLB0AqD+FuS/j5d6ahbLcW46auYLi4iE23luKzbOKf
# KuER/fYoUgmWr26fXJ+yVGKLnWGUgv9JtIONi6xq36VrBh/s2Ss2Xv00FjUMtCI=
# SIG # End signature block
