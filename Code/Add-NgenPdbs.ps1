#requires -version 5.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2013-2017 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest

###############################################################################
# Public Cmdlets
###############################################################################
function Add-NgenPdbs
{
<#
.SYNOPSIS
Create PDB files for NGEN'd images on a machine.

.DESCRIPTION
When running the Visual Studio profiler on Windows 8+ or Windows Server 2012+, 
you need the PDB files for any binaries that have been NGEN'd and put in the GAC 
so you can see the calls into those binaries. Fortunately NGEN.EXE can generate 
the PDB files after the fact and this script automates the process for so you
don't have to run NGEN on each binary.

Because each machine has it's own unique NGEN'd files, you will have to run this
script on the machine you are collecting the performance runs. After creating
the PDB files, you'll have to copy them into your symbol server on the machine
where you are analyzing the performance runs. 

Also note that not all files in the GAC can be NGEN'd so you might see some errors
about unable to create the PDB.

.PARAMETER CacheDirectory
The cache directory to place the resulting PDB files. If not specified, looks
at the Visual Studio 2013-2017 symbol settings and uses that as the cache 
directory.

On a machine without Visual Studio where you are using the command line profiling
tools, alway specify this parameter.

.PARAMETER DoAllGACFiles
By default, this command only does the NGEN'd binaries that are in the .NET 
framework directories for both x86 and x64. If you need other NGEN'd binaries
from 3rd pary tools, specify this switch. Some NGEN'd binaries, but not from the .NET 
framework, will report errors when attempting to build their PDB files.

.NOTES
To read more about using NGEN to produce PDB files after a binary has been precompiled
see this article: http://blogs.msdn.com/b/visualstudioalm/archive/2012/12/10/creating-ngen-pdbs-for-profiling-reports.aspx

For an alternative implementation to this one, see 
http://knagis.miga.lv/blog/post/2013/01/22/VS2012-Windows-8-profilesana-ar-NGEN-bibliotekam.aspx

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>
    # I hate suppressing this warning, but I created this cmdlet long before the 
    # script analyzer came out. If someone has this in a script, changing the
    # cmdlet name will break them.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function")]
    [CmdletBinding()]
    param 
    (
        [string]$CacheDirectory = "",
        [switch]$DoAllGACFiles
    )

    # If the CacheDirectory is empty, use the symbol path directory.
    if ($CacheDirectory.Length -eq 0)
    {
        # I have to look for the cache directory. First I'll start with the easy checks
        # by using Get-SymbolServer to pull out the VS versions. As a last resort, I have
        # to try and grab it from the _NT_SYMBOL_PATH environment variable.
        $symServs = Get-SymbolServer
        if ($symServs.Count -eq 0)
        {
            throw "You don't have a symbol server set"
        }

        $vsVersion = $null
        $symPath = $symServs["VS 2017"]
        if ($null -eq $symPath)
        {
            $symPath = $symServs["VS 2015"]
            if ($null -eq $symPath)
            {
                $symPath = $symServs["VS 2013"]
                if ($null -eq $symPath)
                {
                    # Pull it out of _NT_SYMBOL_PATH. Yes this is only looking at the
                    # first cache directory specified.
                    $symPath = $symServs["_NT_SYMBOL_PATH"]
                    if ($null -eq $symPath)
                    {
                        throw "No symbol server configured"
                    }
                    else
                    {
                        if ($symPath -match "SRV\*(?<SymCache>[^*]*)\*(?:.*)\;?")
                        {
                            $symPath = $Matches["SymCache"]
                        }
                        else
                        {
                            throw "_NT_SYMBOL_PATH environment variable does not specify a symbol cache"
                        }
                    }
                }
                else
                {
                    $vsVersion = "2013"
                }
            }
            else
            {
                $vsVersion = "2015"
            }
        }
        else
        {
            $vsVersion = "2017"
        }

        if ($null -ne $vsVersion)
        {
            [xml]$settings = OpenSettingsFile $vsVersion
            $xPathLookup = $script:dbgPropertyXPath -f "SymbolUseMSSymbolServers"
            $useMSFTSymbolServersNode = $settings | Select-Xml -XPath $xPathLookup

            # If using the public symbol servers I have to put PublicSymbols on the path.
            if ($useMSFTSymbolServersNode.Node.InnerText -eq "1")
            {
                $SymPath = Join-Path -Path $symPath -ChildPath "PublicSymbols"
            }
        }

        if ($symPath.Length -eq 0)
        {
            throw "The symbol path is empty"
        }

        $CacheDirectory = $symPath
    }
    else
    {
        if (-not (Test-Path -Path $CacheDirectory))
        {
            New-Item -Path $CacheDirectory -Type Directory | Out-Null
        }
    }

    # Get all the *.ni.dll files out of the 4.* GAC locations
    $gacSearchPath = $env:windir + "\assembly\NativeImages_v4*"
    $files = Get-ChildItem -Recurse -Path $gacSearchPath -Filter "*.ni.dll" -Exclude "*.resources.ni.dll"

    # I'll need this later to strip off the .ni.dll
    $niLength = ".ni.dll".Length

    foreach ($f in $files)
    {
        # Build up the command line to call NGEN.EXE on this binary.
        # Get the name of the DLL.
        $baseName = (Split-Path -Path $f -Leaf)
        $baseName = $baseName.SubString(0, $baseName.Length - $niLength)

        # Extract out the bit version of this compiled binary so I know if I'm supposed
        # to run the 32 or 64 bit version of NGEN.EXE and where to check if the file exists.
        # The replace looks weird but that's how you get \\ into the path. :)
        $pattern = $env:windir -replace '\\' , '\\'
        $pattern += "\\assembly\\NativeImages_(?<version>v4\.\d\.\d\d\d\d\d)_(?<bits>\d\d)"
        $f.FullName -match $pattern | Out-Null

        $bits = '64'
        if ($Matches.bits -eq '32')
        {
            $bits = ''
        }

        $fwVersion = $Matches.version
 
        # if doing the default of only framework files, check to see if this
        # file is in the appropriate directory.
        if ($DoAllGACFiles.IsPresent -eq $false)
        {
            # Build up the framework path.
            $fwPath = Join-Path -Path $env:windir -ChildPath "Microsoft.NET"
            $fwPath = Join-Path -Path $fwPath -ChildPath ("Framework" + $bits)
            $fwPath = Join-Path -Path $fwPath -ChildPath $fwVersion

            $fwFile = Get-ChildItem -Recurse -Path $fwPath -Filter ($baseName + ".dll")
            if ($null -eq $fwFile)
            {
                continue 
            }

        }

        $msgBitness = '(x86)'
        if ($bits -eq "64")
        {
            $msgBitness = "(x64)"
        }
        Write-Verbose -Message "Generating PDB file for $msgBitness $baseName.dll"
        
        $ngenCmd = $env:windir + "\Microsoft.NET\Framework" + $bits + "\" + $fwVersion + "\NGEN.EXE" 
        $ngenArgs = ' createPDB ' + '"' + $f.FullName + '"' + ' "' + $CacheDirectory +'"'

        # Start-Process can't capture output.
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $ngenCmd
        $pinfo.Arguments = $ngenArgs
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() | Out-Null
        $p.WaitForExit()
        $outputData = $p.StandardOutput.ReadToEnd()
        $outputData += $p.StandardError.ReadToEnd()


        if ($p.ExitCode -ne 0)
        {
            # This may look odd, but it's because Write-Warning is too dumb to write arrays.
            Write-Warning -Message ([String]::Join("`n", $outputData))
        }
    }
}


# SIG # Begin signature block
# MIIUywYJKoZIhvcNAQcCoIIUvDCCFLgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUWADTS+Kh9RHb/DuFxinocl7n
# KeKggg+6MIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUWY1SX8vpMCUnc8YA6CNG
# JV8k6JQwDQYJKoZIhvcNAQEBBQAEggEAQqHgs/WECL2v7QzEHfHE3ZFzCDh+ztOe
# F9zF0enFackTxjOzFrwR6BCaVSVI+Tr0R8GFyXK1X48gp60fuisoRDskcEG2tDg1
# yJEAA1p8PJLD5Ywma8ZQdVSP4U/RpMgSHMeh4K+FLbMRcR+lyXM17c3SYigZ2ndq
# 04XdrM15c0FV1Y4OuW6A+RXz4tL+sfwYLXspfxtEoWt9L9DZcFczyN9O2ftME+/t
# FLYTNh1k+jdEcHr+wZ1CRATvI4FIkonKSI5YtNzTy4Qy/b4yPzAAOVyz4/3LKXoK
# /5w0YcvE1f0JHAGic3g00Tdngwh1xR23TKihwe7NZUmayI0M4PJmkKGCAkMwggI/
# BgkqhkiG9w0BCQYxggIwMIICLAIBADCBqTCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0Ag8WiPA5JV5jjmkUOQfm
# MwswCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZI
# hvcNAQkFMQ8XDTE3MDExMjIzMDY1MlowIwYJKoZIhvcNAQkEMRYEFMaZTfrwmy+N
# Oh9eL6d8+nT/f4jXMA0GCSqGSIb3DQEBAQUABIIBABjOuYir8Qz87TjB0TEZ6LrK
# L0J/glNk4FtEGV9OXb8UVoTkWFe86qXqB11+RqyQ9pan2gTxoaSX3zbPmJ8K1WY9
# iiNf6rI1S1aVX7BUKb8wLYUXlLAtf4lJgUS8gAyToLpw3/vSVQa4smN2GzaRoyjM
# nN86F4pf8/3xAzIq8LhONpaKWJlkV8rxEqibtCmzHc9mortnAJheAkbVqrXaRL4d
# vgvzUASl7Lrf4c8QVCjPnU6JUp7jLLKkbXiKgQuaGyunzoL5/ho5/KWgHGXG7kcs
# lrvYPiUhCr6KaIQZOAvhwjmQtfbT+GT2Dlnw143hEKgP9HjT9mU03NMepu6gc64=
# SIG # End signature block
