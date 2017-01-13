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

function Compare-Directories
{
<#
.SYNOPSIS
Compare two directories to see if they are identical

.DESCRIPTION
This cmdlet will compare two directories and report if the files are identical 
by name, and optionally on content.
    
Symbol explanation:
=> - The file is in the -NewDir directory, not the -OriginalDir.
<= - The file is in the -OriginalDir directory and not the -NewDir.
!= - The file is in both directories, but the content is not identical.
    
If the directories are identical an empty hash table is returned.
    
Since sometimes filenames are long, you can pipe this output of this cmdlet 
into Format-Table -AutoSize to avoid truncating the filenames.

.PARAMETER OriginalDir
The original directory to use for the comparison.

.PARAMETER NewDir
The new directory to compare to.

.PARAMETER Excludes
 The array of exclusions, including wildcards, so you can filter out some of 
 the extraneous files.

.PARAMETER Recurse
Recurse the directory tree. The default is to just look at the directory.

.PARAMETER Force
Allows the cmdlet to get items that cannot otherwise not be accessed by the 
user, such as hidden or system files.

.PARAMETER Content
Check the content of matching filenames in both directories to see if they are 
equal. This is done through the Get-FileHash cmdlet from PowerShell 4.0.

.OUTPUTS 
HashTable
The name is the file, and the value is the difference indicator. If the 
directories are identical, an empty hash table is returned.

.EXAMPLE
C:\PS>Compare-Directories .\Original .\Copied -Content
    
    
Compares the original directory against a copied directory for both filenames 
and content.
    
This shows that both file a.pptx, and c.pptx are in both directories but the 
content is different. Files f.pptx and i.pptx are only in the .\Copied 
directory.    
    
Name                           Value
----                           -----
a.pptx                         !=
c.pptx                         !=
f.pptx                         =>
i.pptx                         =>

#>
    # I hate suppressing this warning, but I created this cmdlet long before the 
    # script analyzer came out. If someone has this in a script, changing the
    # cmdlet name will break them.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function")]
    param (
        [Parameter(Mandatory=$true)]
        [string] $OriginalDir,
        [Parameter(Mandatory=$true)]
        [string] $NewDir,
        [string[]] $Excludes="",
        [switch] $Recurse,
        [switch] $Force,
        [switch] $Content
        )

    if ((Test-Path -Path $OriginalDir) -eq $false)
    {
        throw "$OriginalDir does not exist"
    }

    if ((Test-Path -Path $NewDir) -eq $false)
    {
        throw "$NewDir does not exist"
    }
    
    # I need the real paths for the two input directories.
    $OriginalDir = (Resolve-Path -Path $OriginalDir).ToString().Trim("\")
    $NewDir = (Resolve-Path -Path $NewDir).ToString().Trim("\")
    # When you do a Resolve-Path on a network share you get the 
    # Microsoft.PowerShell.Core\FileSystem:: added to the name so 
    # yank it off if there.
    $OriginalDir = StripFileSystem -directory $OriginalDir
    $NewDir = StripFileSystem -directory $NewDir

    # Do the work to find all the files.
    $origFiles = Get-ChildItem -Path $OriginalDir -Recurse:$Recurse -Force:$Force -Exclude $Excludes
    $newFiles = Get-ChildItem -Path $NewDir -Recurse:$Recurse -Force:$Force -Exclude $Excludes

    # Here I'm going to strip off the initial directories and leave the names. Thus if		
    # the OriginalDir was C:\FOO and one of the files is C:\FOO\BAR.TXT, the result would		
    # be BAR.TXT (C:\FOO\BAZ\Z.TXT -> BAZ\Z.TXT. This will make it easier for content checking. 		
    # The issue is that by doing the content checking on the default return type from 		
    # Compare-Object, I'd lose the relativeness of the filenames. By forcing the data 		
    # to be the relative filenames from input I can do the content comparisons much easier.		
    $origFiles = $origFiles | ForEach-Object { $_.FullName.Remove(0,$OriginalDir.Length+1) }		
    $newFiles = $newFiles | ForEach-Object { $_.FullName.Remove(0,$NewDir.Length+1) }

    # If either return is empty, create an empty array so I can return correct data.
    if ($null -eq $origFiles)
    {
        $origFiles = @()
    }
    if ($null -eq $newFiles)
    {
        $newFiles = @()
    }

    # Now do the comparisons on the names only.
    $nameComp = Compare-Object -ReferenceObject $origFiles -DifferenceObject $newFiles

    # The hash we are going to return.
    $resultHash = @{}
    
    # If there's no differences, $nameComp is null.
    if ($null -ne $nameComp)
    {
        # Push the PSCustomObject type into a resultHash table so content checking can put it's custom
        # results into the table.
        $nameComp | ForEach-Object { $resultHash[$_.InputObject] = $_.SideIndicator}
    }

    # if comparing the content
    if ($Content)
    {
        # Get just the matching values by calling Compare-Object -ExcludeDifferent -IncludeEqual.
        # Note that I'm using -PassThru here because I want result to be the identical filenames, not the
        # normal custom object returned by Compare-Object.
        $sameFiles = Compare-Object -ReferenceObject $origFiles -DifferenceObject $newFiles -IncludeEqual -ExcludeDifferent -PassThru

        foreach($file in $sameFiles)
        {
        
            # Build up the paths to the original file and the new file.
            $orig = $OriginalDir
            $orig += "\" + $file 

            # Am I about to check a directory that's in both places? If so, skip it because the
            # hash will be different because the strings are different.
            if ((Get-Item -Path $orig) -is [System.IO.DirectoryInfo])
            {
                continue 
            }

            $new = $NewDir 
            $new += "\" + $file

            $origHash = Get-FileHash -Path $orig
            $newHash = Get-FileHash -Path $new

            if ($origHash.Hash -ne $newHash.Hash)
            {
                $resultHash[$file] = "!="
            }
        }
    }

    # Nice trick to get the hash sorted by Name so it's easier to read.
    $resultHash.GetEnumerator()  | Sort-Object -Property Name
}

function StripFileSystem([string]$directory="")
{
    $fsText = "Microsoft.PowerShell.Core\FileSystem::" 
    if ($directory.StartsWith($fsText))
    {
        $fsLen = $fsText.Length
        $dirLen = $directory.Length
        $directory = $directory.Substring($fsLen,$dirLen - $fsLen)
    }
    return $directory
}


# SIG # Begin signature block
# MIIUywYJKoZIhvcNAQcCoIIUvDCCFLgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUKQ2N+ER8FrZTCQrNCY1te+o8
# eQqggg+6MIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUVs7ALskhAejAR7kburHq
# +SlxTNIwDQYJKoZIhvcNAQEBBQAEggEAm3ZkxLaAI3mA6ZQjGYbEmswNeSdPxU4I
# 0Wr28PUKSySiOXnPxjpF7TqQzrsyXOyRV7Qu0aNNHhjRjYMxXIBYH+4AsXAxHX9b
# eesJPuv4xYX1ejZfF09AwJWgiAEVaAYvQ4BBrVGHHYnb0F3QvzjAAMDpYc/CAj5v
# b4IphCyTYUMx+rQieBgrzLd9dedtsEjO9PNQClXStCyKi/Y5rWjoVQy3bOMVem8p
# FgkNQYTryJ9Anz6SlnAigthqQ1pX3iS+RxUXv2bR3zslfdZemojv0+a0O6AwiTz9
# LTsGpfEYcFk41q7HsLtnzvD6Kd6nj85or6BwtrtvWllhlwbEwbG3xaGCAkMwggI/
# BgkqhkiG9w0BCQYxggIwMIICLAIBADCBqTCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0Ag8WiPA5JV5jjmkUOQfm
# MwswCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZI
# hvcNAQkFMQ8XDTE3MDExMjIzMDY1NVowIwYJKoZIhvcNAQkEMRYEFDcCcZgmPpj6
# Nwxe931PsI0bCqU7MA0GCSqGSIb3DQEBAQUABIIBAGtPGCxpIpEo6YNbW2dak4m+
# rAlA9XtzRPiN5RtiHJjiM5Ys6dKvmSJd7LkSOmlZ2F6hbL8QKXmnmvkhonWGhrBU
# 5a+cstVwAkpmmw6kwHwgzcQn42eN9YvW+hDrairBolljjHfGOfm+QqOQa6I0+Fvb
# 50SQ5King64xGv2+YQMAY+8hTdJWJX/yDf4beq+/iBEuV2A4IfIxg7+AkLIrImjm
# rE829XxvsnmTMISqQZ7OT8Gv6vURndiONDd7y+iilyknY8CAkTRPN+WQXXCfs/MG
# UkHPQ+RoVYBMHjgsdypBlljEsmFITMz4I0Y9sczgvSP3oeoC747O2peJUaxWFT0=
# SIG # End signature block
