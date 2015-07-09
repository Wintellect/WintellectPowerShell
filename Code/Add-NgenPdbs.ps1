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
at the Visual Studio 2012/2013/2015 symbol settings and uses that as the cache 
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
http://www.wintellect.com/blogs/jrobbins
https://github.com/Wintellect/WintellectPowerShell

#>
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
        $symPath = $symServs["VS 2015"]
        if ($null -eq $symPath)
        {
            $symPath = $symServs["VS 2013"]
            if ($null -eq $symPath)
            {
                $symPath = $symServs["VS 2012"]
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
                    $vsVersion = "11.0"
                }
            }
            else
            {
                $vsVersion = "12.0"
            }
        }
        else
        {
            $vsVersion = "14.0"
        }

        if ($null -eq $vsVersion)
        {
            # If using the public symbol servers I have to put PublicSymbols on the path.
            if ((Get-ItemProperty -Path "HKCU:\Software\Microsoft\VisualStudio\$vsVersion\Debugger").SymbolUseMSSymbolServers -eq 1)
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
        
        $ngenCmd = $env:windir + "\Microsoft.NET\Framework" + $bits + "\" + $fwVersion + "\NGEN.EXE" + ' createPDB ' + '"' + $f.FullName + '"' + ' "' + $CacheDirectory +'"'

        $outputData = Invoke-Expression -Command $ngenCmd

        if ($LASTEXITCODE -ne 0)
        {
            # This may look odd, but it's because Write-Warning is too dumb to write arrays.
            Write-Warning -Message ([String]::Join("`n", $outputData))
        }
    }
}


# SIG # Begin signature block
# MIIYTQYJKoZIhvcNAQcCoIIYPjCCGDoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUNuacj1lW3tJMkrNKzo9Kwv5y
# 3oigghM9MIIEhDCCA2ygAwIBAgIQQhrylAmEGR9SCkvGJCanSzANBgkqhkiG9w0B
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
# MCMGCSqGSIb3DQEJBDEWBBTvjwoXxkKbnEKT4Tj3viuCyh3KADANBgkqhkiG9w0B
# AQEFAASCAQAAxj7Lwnrsn3DKsPT0Kms9QyxjdykgXrT1SxMq3Ira6KQiMTzpl00l
# 9cBXZQm5kHNP5Jrm9VsG6+eggu/c7WCTzKPw+yqbe7MNWIs7/tiW0NOjZb76RxHJ
# wLupY2Ev+TbjLMlFRUntbM/VIpWqqLpf08I3JEhuwx/TDPezjcJLzRMWr0kksC7w
# +ebafFDJUSuKNf0bOxSzFEfCxiDXS+0ymYr9ErqYrINpoD2P240ZU6InH0dJNcKQ
# 2ZP8ciKz4LvzA3Uo5Nzn0WI5g9wi21sTFEqz582RhVVMBgu5lx2+tyu0gM/lJLOe
# IAM725V2/RaKr2H7cQCAlKtzEPk4+/dmoYICRTCCAkEGCSqGSIb3DQEJBjGCAjIw
# ggIuAgEAMIGrMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcT
# DlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# ITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVRO
# LVVTRVJGaXJzdC1PYmplY3QCEQCf6sgRsPFiR6X8INgFI6zmMAkGBSsOAwIaBQCg
# XTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTA3
# MDkxNzE5NTRaMCMGCSqGSIb3DQEJBDEWBBSYuj8ZOqclzAWc+UxvlLeQ0P6vVDAN
# BgkqhkiG9w0BAQEFAASCAQAb6ecWmWVhB/T7r7mgxPvxnJJWwuFzGqx2KND7+M83
# F7Bi/5fTKwn72rH1CmB0vEohW9pEhYh6xA4E13y0WpJtqRfc5RJM/+n2B1YzUFtV
# fnk0tU4IjGPQVAPXoeIcGvZmumq4m999XDQV6NXakJdflMqxQUmfPbmY6J7ET891
# sMRq1eVz2YDPIYv31QUKAFTYTg4bfBVmnv9SqVThn9S5ZtDHtFUKULmEGrGHomYJ
# 8L4XeWqd5ln22EN0dXcIpmP7oJ023W9KW5NI0Mk6Y/vAvrhHA/NcyHqaqcZqvtUB
# J4tiPBfTZq0I6ka56CLz8HGCJiRrGUB9+5zXGKigfNIk
# SIG # End signature block
