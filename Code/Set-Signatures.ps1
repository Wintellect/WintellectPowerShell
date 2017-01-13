#requires -version 5.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2014-2017 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest

function Set-Signatures
{
<#
.SYNOPSIS
Simple wrapper script for digitally signing files
.DESCRIPTION
Automatically grabs the first code signing certificate in CurrentUser\My and 
uses the Comodo time stamp server so you just have to worry about the files.
.PARAMETER Files
The files to digitally sign. Any files that can be normally digitally
signed can be passed here.
.PARAMETER Certificate
Defaults to first code signing certificate in the cert:\CurrentUser\My 
certificate storage that does not have Azure in the name.
.PARAMETER TimeStampServer
The timestamp server to use. Defaults to 
http://timestamp.comodoca.com/authenticode
.LINK
http://www.wintellectnow.com
http://www.wintellect.com/devcenter/author/jrobbins
#>

    # I hate suppressing this warning, but I created this cmdlet long before the 
    # script analyzer came out. If someone has this in a script, changing the
    # cmdlet name will break them.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function")]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Mandatory=$true,
                   HelpMessage="Please enter the PowerShell files to sign")]
        [Alias('FullName')]
        $Files,
        [ValidateNotNull()]
        $Certificate = @(Get-ChildItem -Path cert:\CurrentUser\My -CodeSigning | 
                            Where-Object { $_.Subject -notlike "*Azure*" } |
                                Select-Object -First 1)[0],
        [ValidateNotNull()]
        $TimeStampServer = "http://timestamp.comodoca.com/authenticode"
    )

    begin
    {
        # Because this is a script file, nothing can come between the params 
        # and begin statements. Interestingly, if something does PowerShell
        # ignores the begin and when it hits the process, treats it as the 
        # alias Get-Process. :)
        Set-StrictMode -Version Latest
    }
    process
    {
        foreach ($file in $Files)
        {
            # Always support -whatif
            if ($PSCmdlet.ShouldProcess("$_", "Set-AuthenticodeSignature"))   
            {
                Set-AuthenticodeSignature -FilePath $file `
                                          -Certificate $Certificate `
                                          -TimestampServer $TimeStampServer 
            }
        }
    }
}


# SIG # Begin signature block
# MIIUywYJKoZIhvcNAQcCoIIUvDCCFLgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAzgWOPFu1fk3xov62Ov/YjTF
# BMOggg+6MIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU4JPa1NrM1WTu13t+7zk0
# OSIvwmMwDQYJKoZIhvcNAQEBBQAEggEAIlpHn6bTOSH7zy/wdJRevo5sdl/Ebf4c
# MOGNx3B7pMhBv4vBfYiJQDYt3FvLgJQOBo5CDCmuAiBBozLsJAZgeiI9cECNdcZH
# wYJOHk3To5N5HgrDwk9BKK3R4+4V3khBAgK8u0x1UatEqW4A3gkWgsVyafWTfLF8
# d+0FxUK67sAk2lJfUxnKH1CvXHpB2965p9+PzaIt7riSTHG6I9A620uXdqiykuio
# ba7qWNMzK3R5LN5Zywe4RhmiqU2PAVUMA0feZQcWaiwNjeQru5VRiCl/LYbJ9EWo
# gOsJztzrLh02psBcvQDQhg/KSzi9lCeaFEYCCYonCSP4dlei9CZyOqGCAkMwggI/
# BgkqhkiG9w0BCQYxggIwMIICLAIBADCBqTCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0Ag8WiPA5JV5jjmkUOQfm
# MwswCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZI
# hvcNAQkFMQ8XDTE3MDExMjIzMDczMVowIwYJKoZIhvcNAQkEMRYEFCod9TMUaa2H
# i0n3y1nf/ul4oRk8MA0GCSqGSIb3DQEBAQUABIIBAAPaYhjkmZgZynaRJUt13C/T
# 1TN/vtviJVje9FDW+VHNSgDzoZWyII83XLhf4L2743ym1HR4dAhvWExLYC7Xe1bF
# nxmPvSh2SMoIoLTS4vj0GvwARxwq5iSjdXuRNW9A/R1c8ywb0Aj1msru7lBODdhf
# RIpaQtdJ/DcpOgHn4H8Wx/F2svBHHpQ3aFHq0XaIUTEUVj78SQCXDdN9Umi40Joe
# BUCjIoDgsmR4yoYGG+kIXghKmeU7lih/P0vQgUFxUN5z/XVlHaS0GshYqVNUQNri
# aO17sczBlCusMBm6xRnMi9ive9mr0cBxe2hF0GE8Og59ma8PsOJyi+vEzCelSEQ=
# SIG # End signature block
