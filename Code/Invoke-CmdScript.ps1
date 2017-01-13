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

function Invoke-CmdScript 
{
<#
.SYNOPSIS
Executes the specified command script and imports the environment into current
PowerShell instance.

.DESCRIPTION
Running development tools at the command line in PowerShell can be a hassle since 
they rely on environment varibles and those are set through batch files. This 
cmdlet runs those batch files and imports any set environment variables into
the running PowerShell instance. 

.PARAMETER script
The required batch file to run.

.PARAMETER parameters
The optional parameters to pass to the batch file.

.NOTES
The original script is by Lee Holmes. I updated the script to make removing environment variables
work.

.LINK
http://www.leeholmes.com/blog/2006/05/11/nothing-solves-everything-%e2%80%93-powershell-and-other-technologies/
https://github.com/Wintellect/WintellectPowerShell
#>
    param
    (
        [Parameter(Mandatory=$true,
                   Position=0,
                   HelpMessage="Please specify the command script to execute.")]
        [string] $script, 
        [Parameter(Position=1)]
        [string] $parameters=""
    )  

    # Save off the current environment variables in case there's an issue
    $oldVars = $(Get-ChildItem -Path env:\)
    $tempFile = [IO.Path]::GetTempFileName()  
    
    try
    {
        ## Store the output of cmd.exe.  We also ask cmd.exe to output   
        ## the environment table after the batch file completes  
        cmd /c " `"$script`" $parameters && set > `"$tempFile`" "

        if ($LASTEXITCODE -ne 0)
        {
            throw "Error executing CMD.EXE: $LASTEXITCODE"
        }
        
        # Before we delete the environment variables get the output into a string
        # array.
        $vars = Get-Content -Path $tempFile
    
        # Clear out all current environment variables in PowerShell.
        Get-ChildItem -Path env:\ | Foreach-Object { 
                        set-item -force -path "ENV:\$($_.Name)" -value "" 
                    }
 

        ## Go through the environment variables in the temp file.  
        ## For each of them, set the variable in our local environment.  
        $vars | Foreach-Object {   
                            if($_ -match "^(.*?)=(.*)$")  
                            { 
                                Set-Content -Path "env:\$($matches[1])" -Value $matches[2]
                            } 
                        }
    }
    catch
    {
        "ERROR: $_"

        # Any problems, restore the old environment variables.
        $oldVars | ForEach-Object { Set-Item -Force -Path "ENV:\$($_.Name)" -value $_.Value }
    }
    finally
    {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
}

# SIG # Begin signature block
# MIIUywYJKoZIhvcNAQcCoIIUvDCCFLgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUlhxOeyiqn+j3naljdmd2FjUx
# okCggg+6MIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUqwZWxRoTeTp1OMWH28Ne
# yGKn//AwDQYJKoZIhvcNAQEBBQAEggEA3vvv9s596np4+qcfGxDShL8YdWLZvqgP
# GLL7IkING4psISTx/bLAF2kQn6nRLxIyAJDh3lSMGoMexgr4xobPxwaTFRZNOq5V
# 6trJ1YWyhQbcSpwb8GpW65nSvA1T5vEUybByTX5p/Lem2FMw/CkkevvKOxvDMFGw
# O3Z6Hgd4k3gdl6Jwkt1sFbZjt+n0VFylYuHcnUzLjHxFUiM0/swoXuTxczT20EG1
# dp931UIJJkhWzJ9befyJ4HIsnUTO96ACXWN2g12E3OaHQmVQxNQmTj0T4UqlYqkZ
# mL4IZYcKGeS/TByTMXiRlejpGjucnT+RdO/iIpHE0Ng3mzZQnILeYaGCAkMwggI/
# BgkqhkiG9w0BCQYxggIwMIICLAIBADCBqTCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0Ag8WiPA5JV5jjmkUOQfm
# MwswCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZI
# hvcNAQkFMQ8XDTE3MDExMjIzMDcxNlowIwYJKoZIhvcNAQkEMRYEFAPoxifmSmGt
# xpYtKjQRTV8xNHPoMA0GCSqGSIb3DQEBAQUABIIBALUKY/dOOOkcih/jiTXaUk5V
# II5IZbX+WcMupkgI9gd2T4HuwA3waUec3kzNPlawo9qjoImMdqRFiAozm34Cwo8V
# 22Mc8OwRwwr8hfKDa7/UFt//0FWYEQ8ULs/VTeF3LzMapzATtCCmejYcscm2QRJ1
# GSD241DAIl5sS8HAeEGO0c0ncu/BYJ3wToV2X2J8Enx6hJC+dEmngAQNcySyb7kl
# fVbAJY8XWMgsJam1efdWJ2fG/Sr3eyCbNRaHYJXlI29xVgwU+PopWljuff8YHu7s
# QG1Wor9Lr2lW26sQEPr9X0YNkaAmAO00eqXy0cw1cw9WDJzwmQskkk58QCKsS1o=
# SIG # End signature block
