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
function Get-Hash
{
<#
.SYNOPSIS
Returns the cryptographic hash of a file or string.

.DESCRIPTION
This cmdlet accepts either files or strings and will return the cryptographic 
hash. You may choose the cryptographic provider, and in the case of strings the
encoding.

Files may be passed through the pipeline. If an item passed in is not a file, 
specifically a FileInfo type, it will be treated as a string. Note this means 
directories are not enumerated, but the directory name hash will be calculated.

.PARAMETER Path
The array of files to calculate hashes for.

.PARAMETER LiteralPath
Specifies a path to the file. Unlike Path, the value of LiteralPath is used 
exactly as it is typed. No characters are interpreted as wildcards. If the path 
includes escape characters, enclose it in single quotation marks.

.PARAMETER HashType
The cryptographic hash algorithm to use. This parameter can only be one of the 
following: SHA1, MD5, SHA256, SHA384, or SHA512.

.PARAMETER Encoding
When passing strings into Get-Hash you may need to specify the string encoding. 
This parameter can only be one of the following: ASCII, BigEndianUnicode, 
Default, Unicode, UTF32, UTF7, or UTF8.

.INPUTS 
File or String
The file or string to calculate the hash.

.OUTPUTS 
String
The cryptographic hash of the input item.

.NOTES
This function was influenced by Bill Stewart's Get-FileHash: 
http://www.windowsitpro.com/article/scripting/calculate-file-hashes-powershell-139518

.EXAMPLE
C:\PS>get-hash c:\foo\bar.ps1
    
Gets the cryptographic hash of the file c:\foo\bar.ps1
    
7D03C594BE2AA6CD1E2683ADF99BF89F
    
.EXAMPLE
C:\PS>dir *.p*1 | Get-Hash
    
Pipe in all files matching the wildcard *.p*1 and show their cryptographic hash.
    
7D03C594BE2AA6CD1E2683ADF99BF89F
5EACBB36CF72AAFD24E5A5DCE17BED20
B86207D455D3330B851A10A6F7B4E5B9

.EXAMPLE
C:\PS>"Now is the time for all good men..." | Get-Hash -HashType SHA256

Shows piping in a string to Get-Hash to calculate it's SHA256 hash.
        
A3499FF85214D8A1B2FB28A71B6D8885BB1D296D4DB6624B51580D12EBB7CEC0

.LINK
http://www.wintellect.com/cs/blogs/jrobbins/default.aspx
https://github.com/Wintellect/WintellectPowerShell

#>

# Influenced by Bill Stewart: http://www.windowsitpro.com/article/scripting/calculate-file-hashes-powershell-139518
    [CmdletBinding(DefaultParameterSetName = "Path")] 
    param( 
    [Parameter(ParameterSetName="Path",
               Position = 0,
               Mandatory = $true,
               ValueFromPipeline = $true,
               ValueFromPipelineByPropertyName = $true)] 
    [String[]] $Path, 
    
    [Parameter(ParameterSetName = "LiteralPath",
               Position = 0,
               Mandatory = $true)] 
    [String[]] $LiteralPath, 
    
    [Parameter(Position = 1)] 
    [ValidateSet("SHA1","MD5","SHA256","SHA384","SHA512")]
    [String] $HashType = "MD5", 

    [Parameter(Position=2)]
    [ValidateSet("ASCII","BigEndianUnicode","Default","Unicode","UTF32","UTF7","UTF8")]
    [String] $Encoding = "Default"

    ) 

    begin
    {
        if ($PSCMDLET.ParameterSetName -eq "Path") 
        { 
            $PipeLineInput = -not $PSBOUNDPARAMETERS.ContainsKey("Path")
        } 

        $cryptoAlgo = [System.Security.Cryptography.HashAlgorithm]::Create($HashType)

        function GetEncoding()
        {
            switch($Encoding)
            {
                "ASCII" { return [System.Text.Encoding]::ASCII }
                "BigEndianUnicode" { return [System.Text.Encoding]::BigEndianUnicode }
                "Default" { return [System.Text.Encoding]::Default }
                "Unicode" { return [System.Text.Encoding]::Unicode }
                "UTF32" { return [System.Text.Encoding]::UTF32 }
                "UTF7" { return [System.Text.Encoding]::UTF7 }
                "UTF8" { return [System.Text.Encoding]::UTF8 }
            }
        }

        function DoHash($val)
        {
            $sb = New-Object System.Text.StringBuilder

            if ($val -is [System.IO.FileInfo])
            {
                $stream = [System.IO.File]::OpenRead($val.FullName)

                try
                {
                    $cryptoAlgo.ComputeHash($stream) | ForEach-Object { [void]$sb.Append($_.ToString("X2")) }
                }
                finally
                {
                    if ($stream -ne $null)
                    {
                        $stream.Close()
                    }
                }

            }
            else
            {
                # Treat it at a string.
                [string]$stringVal = $val
                $enc = GetEncoding
                $bytes = $enc.GetBytes($stringVal)

                $cryptoAlgo.ComputeHash($bytes) | ForEach-Object { [void]$sb.Append($_.ToString("X2")) }
            
            }
            $sb.ToString();
        }
    }
    process
    {
        if ($PSCMDLET.ParameterSetName -eq "Path") 
        { 
            if ($PipeLineInput) 
            {
                DoHash $_
            }
            else
            {
                get-item $Path -force | foreach-object { DoHash $_ } 
            } 
        }
        else
        {
            $file = get-item -literalpath $LiteralPath 
            if ($file) 
            {
                DoHash $file
            }
        }
    }
}

# SIG # Begin signature block
# MIIO0QYJKoZIhvcNAQcCoIIOwjCCDr4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtKaI5Ihe2xYsutaihvfBk4Ro
# nZGgggmnMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBT0Avxr63X2XM4A
# 3vTRTGHCidRRtTANBgkqhkiG9w0BAQEFAASCAQBGEJVynF2rAEYYuLq8anr6XVfa
# +v9E4pPk5tUmTPfSq2Nxm4zr9ho92JlmVlkgc0lawkW1HwPMzRFObCfRLYG7dSOv
# QsB8NQrA/vuUhDRK9vbxjOLQfq1Ll7cvwL1BpbPrcVHpUhy8utpJf8eVopkPyqJO
# gFGR+53EcO0v3dgjCWfGZqrcdkdQLw8INGCqeixpzgl6tAtTVdqZDt2WH/DbjP5u
# NpsFyBzvq55u0spglTSp4chREKy/FxMYrJp4YnaFrU5adMl0XoOZeMR0nk11Nu2U
# JBPZbKVlN2B61XUviX8HogYjsTTfnzrOYDDkp7RbLMUqFu1jng5d8h29e8nmoYIC
# RDCCAkAGCSqGSIb3DQEJBjGCAjEwggItAgEAMIGqMIGVMQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRy
# dXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QCEEeKjvtZ4dg/
# DOFC0qKHB74wCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEzMDEyNzA4MDEzMlowIwYJKoZIhvcNAQkEMRYEFJet
# igdl7brjJRrHBDlOAVVg/fWkMA0GCSqGSIb3DQEBAQUABIIBAFJeTksxosiHhepF
# XQfUMc4zN3+Hn/WA1BkaXzc4nI/Bm6Dm8qudElZJRbpzm7swQNvGTTUEoa9BUePV
# 02jX4d7jbmLhn8kr8FHyhmFK9anDudpQiGsKUAsH6F7IwNYMiOD56diqSuCPE3mW
# iLCpEjxb55rgyHDmPTGV6V2tpoQdCXITGNcykIpmciTp6gNqK46O+LUFc+ik1xP2
# pLWTTF33LrN+zk7FJaHS24qcMYsO2xOLS/TbEbPHfIWlNl1voAXQ1WKKtIHJT0yt
# iH2DCcnB6n6DKZGO9bdslE/0dpnI8gazMxwTdEYWlb1PLFOm1LhCbB4m+VLmevXy
# E+tuQv8=
# SIG # End signature block
