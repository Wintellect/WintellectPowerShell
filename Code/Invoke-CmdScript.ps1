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
# MIIYTQYJKoZIhvcNAQcCoIIYPjCCGDoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUOies5EvLnvzNvELgB3Qk25ds
# fo6gghM9MIIEhDCCA2ygAwIBAgIQQhrylAmEGR9SCkvGJCanSzANBgkqhkiG9w0B
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
# MCMGCSqGSIb3DQEJBDEWBBTOxQY4mC7nTsighK+vsaG4R6kYuzANBgkqhkiG9w0B
# AQEFAASCAQCPI8AIuViEubAmGhue4ttDTFUFGZIZtDxP0JFrFbj3R6ngo9iTVMOa
# g68WZJAfJkesttjODuq1l6wlVI1AqkI3deOklFVxmUdJxS0YeUR1aTqnPsXeFbkl
# MeYKCO9NKHGW9id1H77RsekoCbZ3+H970mxAOhnsmIwzPmy4mdzWSU5XYMX8R2Pv
# GvLqZfRVNoCY8sUbF2XdrBowVMkC5sAWeuKQueIjcI8BBGRM2/gmHAtdbxvk/BN2
# ngDBfnyVwOJMJwrZ9mvSUtFb6u24DoUuP42pVLy2b3bdS9B4AK+UaCzaHozLQzpC
# ewjToWuTKQr122ASrD6/KmB6iEkOBCiDoYICRTCCAkEGCSqGSIb3DQEJBjGCAjIw
# ggIuAgEAMIGrMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcT
# DlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# ITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVRO
# LVVTRVJGaXJzdC1PYmplY3QCEQCf6sgRsPFiR6X8INgFI6zmMAkGBSsOAwIaBQCg
# XTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTA3
# MDkxNzIwMDZaMCMGCSqGSIb3DQEJBDEWBBT1kHyuaKnGIrNK5EjT1Peugu9aADAN
# BgkqhkiG9w0BAQEFAASCAQAUrbC4JWRrsyw4h7De0H2+0RWaKIq566zcNt4iO+pN
# hzN+MFC4640Ow6ajXN9mD/soQUuUTEoAyfkFGxTG0wLIOfy7VMs6anVrozSSmkVO
# h2uweNgickVl6ri0E14El/L2XW0v1VCISQVf5D8EuJycEktKGrMT60W7+iVdUuPR
# Q3zXHe9/egm6DvYiXcC/sCPDygOVy6eFqz7DYMDy3bHszi8E/LhcOBC28xkJXKfT
# 9QeaZmhjtJet+PCFaVM7Dsbo5kquC7KW1V/K601Qoz/ALkAA6G42i/S2pOBgdzGs
# Ca/wHteQUEG/wsECWhB1JigHu1lZ4+KRfaGnVm+X+409
# SIG # End signature block
