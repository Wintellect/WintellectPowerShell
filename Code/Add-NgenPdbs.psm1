#requires -version 2.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2013 - John Robbins/Wintellect
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
When running the Visual Studio profiler on Windows 8 or Windows Server 2012, 
you need the PDB files for any binaries that have been NGEN'd and put in the GAC 
so you can see the calls into those binaries. Fortunately NGEN.EXE can generate 
the PDB files after the fact and this script automates the process for so you
don't have to run NGEN on each binary.

Because each machine has it's own unique NGEN'd files, you will have to run this
script on the machine you are collecting the performance runs. After creating
the PDB files, you'll have to copy them into your symbol server on the machine
where you are analyzing the performance runs. 

.PARAMETER CacheDirectory
The cache directory to place the resulting PDB files. If not specified, looks
at the Visual Studio 2012 symbol settings and uses that as the cache directory.

On a machine without Visual Studio where you are using the command line profiling
tools, alway specify this parameter.

.PARAMETER DoAllGACFiles
By default, this command only does the NGEN'd binaries that are in the .NET 
framework directories for both x86 and x64. If you need other NGEN'd binaries
from 3rd pary tools, specify this switch. Some NGEN'd binaries, but not from the .NET 
framework, will report errors when attempting to build their PDB files.

.PARAMETER Quiet
Because it can take a long while for this function to produce all the PDB files
it reports the assembly being processed. If this is annoying to you, specifing 
-Quiet will turn off that output. Any warnings about PDB creation will still be
reported.

.NOTES
To read more about using NGEN to produce PDB files after a binary has been precompiled
see this article: http://blogs.msdn.com/b/visualstudioalm/archive/2012/12/10/creating-ngen-pdbs-for-profiling-reports.aspx

For an alternative implementation to this one, see 
http://knagis.miga.lv/blog/post/2013/01/22/VS2012-Windows-8-profilesana-ar-NGEN-bibliotekam.aspx

.LINK
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>
    param 
    (
        [string]$CacheDirectory = "",
        [switch]$DoAllGACFiles,
        [switch]$Quiet
    )

    # If the CacheDirectory is empty, use the symbol path directory.
    if ($CacheDirectory.Length -eq 0)
    {
        $symServs = Get-SymbolServer
        if ($symServs.Count -eq 0)
        {
            throw "You don't have a symbol server set"
        }
        
        $symPath = $symServs["VS 2012"]
        if ($symPath -eq $null)
        {
            throw "You don't have VS 2012 installed"
        }

        # If using the public symbol servers I have to put PublicSymbols on the path.
        if ((Get-ItemProperty "HKCU:\Software\Microsoft\VisualStudio\11.0\Debugger").SymbolUseMSSymbolServers -eq 1)
        {
            $SymPath = Join-Path $symPath "PublicSymbols"
        }

        $CacheDirectory = $symPath
    }
    else
    {
        if (-not (Test-Path $CacheDirectory))
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
        $baseName = (Split-Path $f -Leaf)
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
            $fwPath = Join-Path $env:windir "Microsoft.NET"
            $fwPath = Join-Path $fwPath ("Framework" + $bits)
            $fwPath = Join-Path $fwPath $fwVersion

            $fwFile = Get-ChildItem -Recurse -Path $fwPath -Filter ($baseName + ".dll")
            if ($fwFile -eq $null)
            {
                continue 
            }

        }

        if ($Quiet.IsPresent -eq $false)
        {
            $msgBitness = '(x86)'
            if ($bits -eq "64")
            {
                $msgBitness = "(x64)"
            }
            Write-Host "Generating PDB file for $msgBitness $baseName.dll"
        }
        
        $ngenCmd = $env:windir + "\Microsoft.NET\Framework" + $bits + "\" + $fwVersion + "\NGEN.EXE" + ' createPDB ' + '"' + $f.FullName + '"' + ' "' + $CacheDirectory +'"'

        $outputData = Invoke-Expression $ngenCmd

        if ($LASTEXITCODE -ne 0)
        {
            # This may look odd, but it's because Write-Warning is too dumb to write arrays.
            Write-Warning ([String]::Join("`n", $outputData))
        }
    }
}

Get-Help -Full Add-NgenPdbs
# SIG # Begin signature block
# MIIO0QYJKoZIhvcNAQcCoIIOwjCCDr4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQURh7OxUcxVO77cyxiNGhhI3MK
# Bb6gggmnMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQPAKD72LKfwg0R
# WLjQJ4GZs7n23zANBgkqhkiG9w0BAQEFAASCAQBNUGrdSR0Fvf8kIpk+k9l6Nyvq
# 8jry8VdlYZa9WbPwNh0mKawC71gjuL8Pig7z4YuGQFAo++yowuOihZBNF8+4U5Dm
# 8QRAQBfsbHE8RI1jaL/O+Ect4q3W4SkAbjLTqcDTjDUZ5ipJEUTG2W26nAzAnT0a
# Fk76729ZAwG4xdHP+MayjOKSimIDMsoUgm59t3hdKNome5o6K2XUP6KwIVN3I8km
# x7bAjCOOvcEojxSJA81paPb+RYgn2Oda8szOBdQUxh+VoylTElDtMW1NAh1XEIhj
# uewBLV7tGlGDqHizZXIDgbPK5PdT4Iynv6acRt8qLT0RXITGNLiTnHXYeaxKoYIC
# RDCCAkAGCSqGSIb3DQEJBjGCAjEwggItAgEAMIGqMIGVMQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRy
# dXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QCEEeKjvtZ4dg/
# DOFC0qKHB74wCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEzMDUyMTA2Mjc1N1owIwYJKoZIhvcNAQkEMRYEFLt3
# 2KB/gB8Fjk1u+TOmBfPm1R24MA0GCSqGSIb3DQEBAQUABIIBADaZYbNS5p3iVKte
# wCCyy5Ro3ysQpInW5NvffA06xGJY6Kuthm8zAnlytR5Bfte1NqFOnOVrugySvG2l
# PUFsEMYTeAB0mK7ufW1pr6eoIUw/xjp40Txp+YIFgx5NrGwjYHDNOFrfI4ojQXgp
# 7YzocUIURy5X/97EtggOJmjf49+zfb9Y4Z922rTnw3zU3qNBppQac9PIb63hrfFx
# jv4N6R6OB/sWrcNIBmK4AO8z90wSRXaiCFN3+osp1fhgV630QtSsm/RKXdOxOdZQ
# eH7OqkV4EQME221IJzQ9NO0qFA9k7Ac3Y9aTd9Jv3tndmd8ev8jR5r4BHUHkPC9X
# En0sotc=
# SIG # End signature block
