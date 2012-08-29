#requires -version 2.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2012 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest

###############################################################################
# Script Global Variables
###############################################################################
$script:devTenDebuggerRegKey = "HKCU:\Software\Microsoft\VisualStudio\10.0\Debugger"
$script:devElevenDebuggerRegKey = "HKCU:\Software\Microsoft\VisualStudio\11.0\Debugger"

###############################################################################
# Module Only Functions
###############################################################################
function CreateDirectoryIfNeeded ( [string] $directory )
{
	if ( ! ( Test-Path $directory -type "Container" ) )
	{
		New-Item -type directory -Path $directory > $null
	}
}

# Reads the values from VS 2010, Dev 11, and the environment.
function GetCommonSettings($regValue, $envVariable)
{
    $returnHash = @{}
    if (Test-Path $devTenDebuggerRegKey)
    {
        $returnHash["VS 2010"] = 
                (Get-ItemProperty $devTenDebuggerRegKey).$regValue
    }
    if (Test-Path $devElevenDebuggerRegKey)
    {
        $returnHash["Dev 11"] = 
                (Get-ItemProperty $devElevenDebuggerRegKey).$regValue
    }
    $envVal = Get-ItemProperty HKCU:\Environment $envVariable -ErrorAction SilentlyContinue
    if ($envVal -ne $null)
    {
        $returnHash[$envVariable] = $envVal.$envVariable
    }
    $returnHash
}

# Makes doing ShouldProcess easier.
function Set-ItemPropertyScript ( $path , $name , $value , $type )
{
    if ( $path -eq $null )
    {
        throw "Set-ItemPropertyScript path param cannot be null!"
    }
    if ( $name -eq $null )
    {
        throw "Set-ItemPropertyScript name param cannot be null!"
    }
	$propString = "Item: " + $path.ToString() + " Property: " + $name
	if ($PSCmdLet.ShouldProcess($propString ,"Set Property"))
	{
        if ($type -eq $null)
        {
		  Set-ItemProperty -Path $path -Name $name -Value $value
        }
        else
        {
		  Set-ItemProperty -Path $path -Name $name -Value $value -Type $type
        }
	}
}

function SetInternalSymbolServer([string] $DbgRegKey , 
                                 [string] $CacheDirectory ,
                                 [string] $SymPath )
{

    CreateDirectoryIfNeeded $CacheDirectory
    
    # Turn off Just My Code.
    Set-ItemPropertyScript $dbgRegKey JustMyCode 0 DWORD

    # Turn off .NET Framework Source stepping.
    Set-ItemPropertyScript $DbgRegKey FrameworkSourceStepping 0 DWORD

    # Turn off using the Microsoft symbol servers.
    Set-ItemPropertyScript $DbgRegKey SymbolUseMSSymbolServers 0 DWORD

    # Set the symbol cache dir to the same value as used in the environment
    # variable.
    Set-ItemPropertyScript $DbgRegKey SymbolCacheDir $CacheDirectory
} 

function SetPublicSymbolServer([string] $DbgRegKey , 
                               [string] $CacheDirectory )
{
    CreateDirectoryIfNeeded $CacheDirectory
        
    # Turn off Just My Code.
    Set-ItemPropertyScript $dbgRegKey JustMyCode 0 DWORD
    
    # Turn on .NET Framework Source stepping.
    Set-ItemPropertyScript $dbgRegKey FrameworkSourceStepping 1 DWORD
    
    # Turn on Source Server Support.
    Set-ItemPropertyScript $dbgRegKey UseSourceServer 1 DWORD
    
    # Turn on Source Server Diagnostics as that's a good thing. :)
    Set-ItemPropertyScript $dbgRegKey ShowSourceServerDiagnostics 1 DWORD
    
    # It's very important to turn off requiring the source to match exactly.
    # With this flag on, .NET Reference Source Stepping doesn't work.
    Set-ItemPropertyScript $dbgRegKey UseDocumentChecksum 0 DWORD
    
    # Turn on using the Microsoft symbol servers. 
    Set-ItemPropertyScript $dbgRegKey SymbolUseMSSymbolServers 1 DWORD
    
    # Set the VS SymbolPath setting.
    Set-ItemPropertyScript $dbgRegKey SymbolPath ""
    
    # Tell VS that all paths are empty.
    Set-ItemPropertyScript $dbgRegKey SymbolPathState ""
    
    # Set the symbol cache dir to the same value as used in the environment
    # variable.
    Set-ItemPropertyScript $dbgRegKey SymbolCacheDir $CacheDirectory
}

###############################################################################
# Public Cmdlets
###############################################################################
function Get-SourceServer
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>
    GetCommonSettings SourceServerExtractToDirectory _NT_SOURCE_PATH
}

Export-ModuleMember  Get-SourceServer
###############################################################################

function Set-SourceServer
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>
    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the source server directory")]
        [string] $Directory
    ) 
    
    $sourceServExtractTo = "SourceServerExtractToDirectory"
    
    CreateDirectoryIfNeeded $Directory
    
    if (Test-Path $devTenDebuggerRegKey)
    {
        Set-ItemProperty -path $devTenDebuggerRegKey -Name $sourceServExtractTo -Value $Directory 
    }
    
    if (Test-Path $devElevenDebuggerRegKey)
    {
        Set-ItemProperty -path $devElevenDebuggerRegKey -Name $sourceServExtractTo -Value $Directory 
    }
    
    # Always set the _NT_SOURCE_PATH value for WinDBG.
    Set-ItemProperty -Path HKCU:\Environment -Name _NT_SOURCE_PATH -Value "SRV*$Directory"
    
    ""
    "Please log out to activate the new source server settings"
    ""        
}

Export-ModuleMember Set-SourceServer
###############################################################################

function Get-SymbolServer
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>
    GetCommonSettings SymbolCacheDir _NT_SYMBOL_PATH
}

Export-ModuleMember Get-SymbolServer
###############################################################################

function Get-SourceServerFiles
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>
    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the source server directory")]
        [string] $CacheDirectory ,
        [Parameter(HelpMessage="The optional full path to SCRTOOL.EXE")]
        [string] $SrcTool = ""
    ) 
    
    if ($SrcTool -eq "")
    {
        # Go with the default of looking up WinDBG in the path.
        $windbg = Get-Command windbg.exe -ErrorAction SilentlyContinue
        if ($windbg -eq $null)
        {
            throw "Please use the -SrcTool parameter or have WinDBG in the path"
        }
        
        $windbgPath = Split-Path ($windbg.Definition)
        $SrcTool = $windbgPath + "\SRCSRV\SRCTOOL.EXE"
    }
    
    if ((Get-Command $SrcTool -ErrorAction SilentlyContinue) -eq $null)
    {
        throw "SRCTOOL.EXE does not exist."
    }
    
    if ((Test-Path $CacheDirectory) -eq $false)
    {
        throw "The specified cache directory does not exist."
    }
    
    $cmd = "$SrcTool -d:$CacheDirectory -x $_.FullName"
    
    # Get all the PDB files, execute SRCTOOL.EXE on each one.
    Get-ChildItem -Recurse -Include *.pdb -Path $cacheDirectory | `
        ForEach-Object { &$SrcTool -d:$CacheDirectory -x $_.FullName }

}

Export-ModuleMember  Get-SourceServerFiles
###############################################################################

function Set-SymbolServer
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param ( [switch]   $Internal ,
    		[switch]   $Public ,
    		[string]   $CacheDirectory ,
    		[string[]] $SymbolServers = @()  )
            
    # Do the parameter checking.
    if ( $Internal -eq $Public )
    {
        throw "You must specify either -Internal or -Public"
    }

    # Check if VS is running. 
    if (Get-Process 'devenv' -ErrorAction SilentlyContinue)
    {
        throw "Visual Studio is running. Please close all instances before running this script"
    }
    
    if ($Internal)
    {
    	if ( $CacheDirectory.Length -eq 0 )
    	{
        	$CacheDirectory = "C:\SYMBOLS\INTERNAL" 
    	}
        
        $symPath = "SRV*$CacheDirectory*http://SYMWEB"

        for ( $i = 0 ; $i -lt $SymbolServers.Length ; $i++ )
        {
            $symPath += "*"
            $symPath += $SymbolServers[$i]

    	}
        $symPath += ";"
        
        Set-ItemPropertyScript HKCU:\Environment _NT_SYMBOL_PATH $symPath

        if (Test-Path $devTenDebuggerRegKey)
        {
        
            SetInternalSymbolServer $devTenDebuggerRegKey $CacheDirectory $symPath
        }

        if (Test-Path $devElevenDebuggerRegKey)
        {
        
            SetInternalSymbolServer $devElevenDebuggerRegKey $CacheDirectory $symPath
        }
    }
    else
    {
    
        if ( $CacheDirectory.Length -eq 0 )
    	{
        	$CacheDirectory = "C:\SYMBOLS\PUBLIC" 
    	}

        # It's public so we have a little different processing to do. I have to 
        # add the MicrosoftPublicSymbols as VS hardcodes that onto the path.
        # This way both WinDBG and VS are using the same paths for public
        # symbols.
        $refSrcPath = "$CacheDirectory\PublicSymbols*http://referencesource.microsoft.com/symbols"
        $msdlPath = "$CacheDirectory*http://msdl.microsoft.com/download/symbols"
        $extraPaths = ""
        $enabledPDBLocations ="11"
        
        # Poke on any additional symbol servers. I've keeping everything the
        # same between VS as WinDBG.
    	for ( $i = 0 ; $i -lt $SymbolServers.Length ; $i++ )
    	{
            $extraPaths += ";"
            $extraPaths += $SymbolServers[$i]
            $enabledPDBLocations += "1"
    	}
        
        $envPath = "SRV*$refSrcPath;SRV*$msdlPath$extraPaths"
    
        Set-ItemPropertyScript HKCU:\Environment _NT_SYMBOL_PATH $envPath
    
        if (Test-Path $devTenDebuggerRegKey)
        {
            SetPublicSymbolServer $devTenDebuggerRegKey $CacheDirectory
        }
        
        if (Test-Path $devElevenDebuggerRegKey)
        {
            SetPublicSymbolServer $devElevenDebuggerRegKey $CacheDirectory
        }
    }
    
    ""
    "Please log out to activate the new symbol server settings"
    ""                
}

Export-ModuleMember Set-SymbolServer
###############################################################################

function Expand-ZipFile
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>

    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the zip file to expand")]
        [string] $ZipFile ,
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the directory to expand into")]
        [string] $Destination
    ) 
    # Basic idea found here 
    # http://ochoco.blogspot.com/2009/04/quick-bytes-unzipping-zip-file-using.html.
    # Tweaked to be more usable.
    
    if (! (Test-Path $ZipFile))
    {
        throw "The zip file must exist."
    }
    
    CreateDirectoryIfNeeded $Destination
    
    # It's important you get the full path at the shell application fails if 
    # you're using a relative path.
    $Destination = Resolve-Path $Destination
    
    $shellApplication = new-object -com shell.application 
    $zipPackage = $shellApplication.NameSpace($ZipFile) 
    $destinationFolder = $shellApplication.NameSpace($Destination) 
    # The first parameter to CopyHere are all the files, the second parameter
    # of 20 says to turn off the default UI of the progress dialog and say 
    # yes to all dialog boxes.
    # All the codes can be found here:
    # http://social.technet.microsoft.com/Forums/en-US/winserverpowershell/thread/b77840b8-459d-4509-8cc8-8fc7f6603e86
    $destinationFolder.CopyHere($zipPackage.Items(),20) 
}

Export-ModuleMember Expand-ZipFile
###############################################################################

function Get-SysinternalsSuite
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>
    param ( 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the extract directory")]
        [string] $Extract ,
        [Parameter(HelpMessage="Please specify the directory to expand into")]
        [string] $Save
    ) 
    
    CreateDirectoryIfNeeded $Extract
    
    [Boolean]$deleteZipFile = $TRUE
    [String]$downloadFile = ""
    if ( $Save.Length -gt 0 )
    { 
        CreateDirectoryIfNeeded ( $Save )
        $downloadFile = $Save
        $deleteZipFile = $FALSE
    }
    else
    { 
        # Use the %TEMP% path for the user.
        $downloadFile = $env:temp
    }
    
    # Build up the full location and filename.
    $downloadFile = $(Get-item $downloadFile).FullName
    $downloadFile = Join-Path -path $downloadFile -childpath "SysinternalsSuite.zip" 

    # Let the download begin!
    Write-Output "Starting download of the Sysinternals Suite"
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile("http://download.sysinternals.com/files/SysinternalsSuite.zip" ,
                            $downloadFile)
    Write-Output "Sysinternals suite downloaded to $downloadFile"

    Write-Output "Extracting files into $Extract"
    Expand-ZipFile $downloadFile $Extract
    
    if ($deleteZipFile -eq $true)
    {
        Remove-Item $downloadFile    
    }
}

Export-ModuleMember Get-SysinternalsSuite
###############################################################################

function Get-Uptime
{
<#
.EXTERNALHELP WintellectPowerShell.psm1-help.xml
#>
    param( [string] $computerName = ".")

    $wmi = Get-WmiObject -class Win32_OperatingSystem -computer $computerName
    $LBTime=$wmi.ConvertToDateTime($wmi.Lastbootuptime)
    New-TimeSpan $LBTime $(get-date)
}

Export-ModuleMember Get-Uptime
###############################################################################
# SIG # Begin signature block
# MIIO0QYJKoZIhvcNAQcCoIIOwjCCDr4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUx+fuE1dx8wPcMo5ZYcb5azj9
# xl+gggmnMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRw9L8RwhOPTp3u
# 474PNPm7lXLEqDANBgkqhkiG9w0BAQEFAASCAQALrwT6PYQJvJhcHrWIFYWp2aaF
# La2PfZVZC0hOBwYmWyUQQM6UpagYAxRjMVMmk3mcpzqYbd7eNeCA7TmYR8eLsLsj
# Za9kKkZXQDr5E5RKiudGk9Fw9uRsEKY7KTcBozMNc+2sCxcoggrBU85Z+nCc7gs9
# lDDk3WVCIMOaLSerERD+pnZru5WDJDn3mRJK6/mfTNT5X8FzqF1roI0Ic0bVuLeD
# Cbh2UNciBZqeD284K0c/327TI2XMfVaVxe71HiPVbTkbrqK/O5AbS7V4fByCKJ/K
# ZWpPqktYAN6W+04PgUjABaSJtCgMQqh8Czp0pBAwR+6k5tvfbQd4jyU3til/oYIC
# RDCCAkAGCSqGSIb3DQEJBjGCAjEwggItAgEAMIGqMIGVMQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRy
# dXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QCEEeKjvtZ4dg/
# DOFC0qKHB74wCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEyMDcwNjIzMTk0M1owIwYJKoZIhvcNAQkEMRYEFDTc
# lq30nAJz1Z/FpnDDbKhso/P+MA0GCSqGSIb3DQEBAQUABIIBADMIuzVOIuyeg2M/
# au8NSfITXW6fyESQoP6IoQ9mfD/s/XoetPsDOtlfkr3hREQKe+p7VBcey7P+5MNk
# 5RA3gB2smrWMS+vp/Ih0OIe7x/c2SGL/Xd/NT937YkfkiSoEfQBBDMGW3BETQ28I
# BJfSD09Skg994bZ7OIB7iEY6XeIdVjwKFpqc1dx9bfRCvdPijEhdBzyvZ0IIgiN3
# b8Fgi8x3kEWn21DnMnzUMQtw0GGYLB3MI9f+ocYtlkbvYHnJ57HtAcgRHVzbqry+
# c9ehJov2KHK+6IuVFelMcvPbjWTrPqjLBkrQhTnQo/Auyhqp3sA8u9m+sLzfTner
# 28eDOr8=
# SIG # End signature block
