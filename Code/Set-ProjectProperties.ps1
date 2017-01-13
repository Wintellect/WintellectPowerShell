#requires -version 5.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2017 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -Version Latest 

###############################################################################
# Script Global Variables
###############################################################################
# The namespace for everything in a VS project file.
$script:BuildNamespace = "http://schemas.microsoft.com/developer/msbuild/2003"

# These are the settings used as the defaults for the general property group.
$script:DefaultDotNetGeneralProperties = @{
}

# The default properties for both debug and release builds.
$script:DefaultDotNetConfigProperties = @{
# Stop the build on any compilation warnings.
"TreatWarningsAsErrors" = "true";
# Always check for numeric wrapping. Does not cause perf issues.
"CheckForOverflowUnderflow" = "true";
# Always run code analysis. This will set the Microsoft minimum rules if the CodeAnalysisRuleSet
# property is not specified.
"RunCodeAnalysis" = "true";
# Always produce an XML document file. This script block gets the binary output directory and
# puts the doc comment file there as well.
"DocumentationFile" = 
        {
            # The configuration to add the DocumentationFile element into.
            param($config)

            # Go find the main property group to get the name of the assembly.
            $assemblyName = $config.ParentNode.GetElementsByTagName("AssemblyName")[0].InnerText

            # Set the output name to be the path. This works in both C# and VB.
            $valueName = Join-Path -Path $config.OutputPath -ChildPath "$assemblyName.XML"

            ReplaceNode -document $config.ParentNode.ParentNode `
                        -topElement $config `
                        -elementName "DocumentationFile" `
                        -elementValue $valueName
        }
}

# The array of default rulesets when setting the <CodeAnalysisRulesSet>
# property so I don't try to do relative paths when setting it.
$script:BuiltInRulesets = 
"AllRules.ruleset",
"BasicCorrectnessRules.ruleset",
"BasicDesignGuidelineRules.ruleset",
"ExtendedCorrectnessRules.ruleset",
"ExtendedDesignGuidelineRules.ruleset",               
"GlobalizationRules.ruleset",
"ManagedMinimumRules.ruleset",
"MinimumRecommendedRules.ruleset",
"MixedMinimumRules.ruleset",
"MixedRecommendedRules.ruleset",
"NativeMinimumRules.ruleset",
"NativeRecommendedRules.ruleset",
"SecurityRules.ruleset"                              

###############################################################################
# Public Cmdlets
###############################################################################
function Set-ProjectProperties
{
<#
.SYNOPSIS
A script to make Visual Studio 2013 and higher project management easier for 
.NET Standard/Full projects.

.DESCRIPTION
When you need to make a simple change to a number of Visual Studio projects, 
it can be a large pain to manually go through and do those changes, especially 
since it's so easy to forget a project or mess up. This script's job is to 
automate the process so it's repeatable and consistent.

If you do not specify any custom options, the script will automatically update
projects with the following settings. 

[Note that at this time only C# projects are supported.]

C# Debug and Release configurations
---------------
-    Treat warnings as errors
-    Check for arithmetic overflow and underflow
-    Enable code analysis with the default Code Analysis settings file.
-    Turn on creation of XML doc comment files.

This script is flexible and you can control down to setting/changing an 
individual property if necessary. There are many examples in the Examples 
section.

.PARAMETER  Path
This script can take pipeline input so you can easily handle deeply nested
project trees. 

.PARAMETER OverrideDefaultProperties
If set, will not apply the default settings built into the script and only
take the properties to change with the CustomGeneralProperties and 
CustomConfigurationProperties parameters.

.PARAMETER Configurations
The array of configurations you want to change in the project file these are
matching strings so if you specify something like 'Debug|AnyCPU' you are 
narrowing down the configuration to search. The default is 'Debug' and 
'Release'.

.PARAMETER CustomGeneralProperties
The hash table for the general properties such as TargetFrameworkVersion, 
FileAlignment and other properties on the Application or Signing tab when
looking at the project properties. The key is the property name and the 
value is either the string, or a script block that will be called to do 
custom processing. The script block will be passed the XML for all the 
global project properties so it can do additional processing.

.PARAMETER CustomConfigurationProperties
The hash table for the properties such as TreatWarningsAsErrors and 
RunCodeAnalysis which are per build configuration(s). Like the 
CustomGeneralProperties, the hash table key is the property to set and the
value is the string to set or a script block for advanced processing. The 
script block will be passed the current configuration. See the examples
for how this can be used.

.EXAMPLE
dir -recurse *.csproj | Set-ProjectProperties

Recursively updates all the C# project files in the current directory with 
all the default settings.

.EXAMPLE

dir A.csproj | `
    Set-ProjectProperties `
        -CustomGeneralProperties @{"AssemblyOriginatorKeyFile" = "c:\dev\ConsoleApplication1.snk"} 

Updates A.CSPROJ to the default settings and adds the strong name key to the 
general properties. When specifying the AssemblyOriginatorKeyFile this script 
will treat file correctly and make it a relative path from the .CSPROJ folder 
location. When specifying a file, use the full path to the file so everything 
works correctly.

.EXAMPLE

dir B.csproj | `
    Set-ProjectProperties `
        -CustomConfigurationProperties @{ "CodeAnalysisRuleSet" = "c:\dev\WintellectRuleSet.ruleset"}

Updates B.CSPROJ to the default settings and sets all configurations to 
enable Code Analysis with the custom rules file specified. Always specify the 
full path to the custom ruleset file as the script will handle making all 
references to it relative references in the configurations.

If you specify one of the default Code Analysis rules files that shipped with 
Visual Studio, the script properly handles those as well. You can find all the 
default ruleset files by looking in the 
"<VS Install Dir>\Team Tools\Static Analysis Tools\Rule Sets" folder.

.EXAMPLE

dir C.csproj | Set-ProjectProperties `
        -OverrideDefaultProperties `
        -Configurations "Release" `
        -CustomConfigurationProperties @{ "DefineConstants" = 
                {
                    param($config)
                    $defines = $config.GetElementsByTagName("DefineConstants")
                    $defines[0].InnerText = $defines[0].InnerText + ";FOOBAR"
                } 
            }

Updates C.CSPROJ by only adding a new define to only the Release configuration, 
keeping any existing define and not using the default changes.

.INPUTS
The Visual Studio project files to change.

.NOTES
Obviously, to maximize your usage you should be familiar with all the 
properties in Visual Studio project files and the properties in them. 
See http://msdn.microsoft.com/en-us/library/0k6kkbsd.aspx for more information.

.LINK
http://www.wintellect.com/devcenter/author/jrobbins
https://github.com/Wintellect/WintellectPowerShell
#>
    # I hate suppressing this warning, but I created this cmdlet long before the 
    # script analyzer came out. If someone has this in a script, changing the
    # cmdlet name will break them.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Scope="Function")]
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(ValueFromPipeline, Mandatory=$true)]
        [System.IO.FileInfo[]] $Path,
        [switch]    $OverrideDefaultProperties,
        [string[]]  $Configurations = @("Debug", "Release"),
        [HashTable] $CustomGeneralProperties = @{},
        [HashTable] $CustomConfigurationProperties = @{}
    )

    begin
    {
        function ReplaceNode(         $document=$null,
                                      $topElement=$null,
                             [string] $elementName="",
                             [string] $elementValue="")
        {
            Write-Debug -Message "Replacing $elementName=$elementValue"

            $origNode = $topElement[$elementName]
            if ($null -eq $origNode)
            {
                $node = $document.CreateElement($elementName,$script:BuildNamespace)
                $node.InnerText = $elementValue

                [void]$topElement.AppendChild($node)
            }
            else
            {
                $origNode.InnerText = $elementValue
            }
        }

        function ReplaceRelativePathNode([string] $fileLocation="",
                                                  $document=$null,
                                                  $topElement=$null,
                                         [string] $elementName="",
                                         [String] $fullUseFilePath="")
        {
            try
            {
                Push-Location -Path (Split-Path -Path $fileLocation)

                $relLocation = Resolve-Path -Path $fullUseFilePath -Relative

                Write-Debug -Message "Setting relative path $elementName=$relLocation"

                ReplaceNode -document $document `
                            -topElement $topElement `
                            -elementName $elementName `
                            -elementValue $relLocation
            }
            finally
            {
                Pop-Location
            }
        }

        function HandleCSharpMainProperties([string]    $file, 
                                            [xml]       $fileXML=$null, 
                                            [hashtable] $newMainProps=@{})
        {
            # Go find the main property group which is the one with the ProjectGuid in it.
            $mainProps = $fileXML.Project.PropertyGroup | Where-Object { $null -ne $_["ProjectGuid"] }

            if (($null -eq $mainProps) -or ($mainProps -is [Array]))
            {
                throw "$file does not have the correct property group with the ProjectGuid or has multiple"
            }

            # Enumerate through the property keys.
            foreach ($item in $newMainProps.GetEnumerator())
            {
                if ($item.Key -eq "AssemblyOriginatorKeyFile")
                {
                    # Get the full path to the .SNK file specified.
                    $snkFile = Resolve-Path -Path $item.Value -ErrorAction SilentlyContinue

                    if ($null -eq $snkFile)
                    {
                        [string]$inputFile = $item.Value
                        throw "Unable to find $inputFile, Please specify the full path to the file."
                    }

                    ReplaceRelativePathNode -fileLocation $file `
                                            -document $fileXML `
                                            -topElement $mainProps `
                                            -elementName "AssemblyOriginatorKeyFile" `
                                            -fullUseFilePath $snkFile

                    # In case the user forgot, set the option to use the SNK file also.
                    ReplaceNode -document $fileXML `
                                -topElement $mainProps `
                                -elementName "SignAssembly" `
                                -elementValue "true"
                }
                elseif ($item.Value -is [scriptblock])
                {
                    & $item.Value $mainProps
                }
                else
                {
                    ReplaceNode -document $fileXML `
                                -topElement $mainProps `
                                -elementName $item.Key `
                                -elementValue $item.Value
                }
            }
        }

        function HandleCSharpConfigProperties([string]    $file,
                                              [xml]       $allFileXML=$null,
                                              [string]    $configString="",
                                              [HashTable] $newProps=@{})
        {
            # Get the configuration propery group.
            $configGroup = $allFileXML.GetElementsByTagName("PropertyGroup") | Where-Object { ($_.GetAttribute("Condition") -ne "") -and ($_.Condition -match $configString) }

            if (($null -eq $configGroup) -or ($configGroup -is [Array]))
            {
                throw "$file does not have the $configString property group or has multiple."
            }


            foreach($item in $newProps.GetEnumerator())
            {
                # Have to treat the CodeAnalysisRuleSet property special so we get the 
                # relative path set.
                if ($item.Key -eq "CodeAnalysisRuleSet")
                {
                    # Is the ruleset file one of the default files?
                    if ($script:BuiltInRulesets -contains $item.Value)
                    {
                        # Simple enough, plop in the default name and go on.
                        ReplaceNode -document $allFileXML `
                                    -topElement $configGroup `
                                    -elementName $item.Key `
                                    -elementValue $item.Value
                    }
                    else
                    {
                        # Get the full path to the .RuleSet file specified.
                        $ruleFile = Resolve-Path -Path $item.Value -ErrorAction SilentlyContinue

                        if ($null -eq $ruleFile)
                        {
                            [string]$inputFile = $item.Value
                            throw "Unable to find $inputFile, Please specify the full path to the file."
                        }

                        ReplaceRelativePathNode -fileLocation $file `
                                                -document $allFileXML `
                                                -topElement $configGroup `
                                                -elementName $item.Key `
                                                -fullUseFilePath $ruleFile

                    }

                    # In case the user forgot, set the option to turn on using the code analysis file.
                    ReplaceNode -document $allFileXML `
                                -topElement $configGroup `
                                -elementName "RunCodeAnalysis" `
                                -elementValue "true"

                }
                elseif ($item.Value -is [scriptblock])
                {
                    & $item.Value $configGroup
                }
                else
                {
                    ReplaceNode -document $allFileXML `
                                -topElement $configGroup `
                                -elementName $item.Key `
                                -elementValue $item.Value
                }
            }
        }

        function ProcessCSharpProjectFile([string] $file)
        {

            # Try and read the file as XML. Let the errors go if it's not.
            [xml]$fileXML = Get-Content -Path $file

            # Check to see if this is a .NET Core project.
            if ($null -ne $fileXML.Project.Attributes["Sdk"])
            {
                Write-Verbose ".NET Core project types not supported by this cmdlet!"
                return
            }


            # Build up the property hash values.
            [HashTable]$mainPropertiesHash = @{}
            [HashTable]$configPropertiesHash = @{}

            # Does the user just want to apply their properties?
            if ($OverrideDefaultProperties)
            {
                $mainPropertiesHash = $CustomGeneralProperties
                $configPropertiesHash = $CustomConfigurationProperties
            }
            else
            {
                $mainPropertiesHash = $script:DefaultDotNetGeneralProperties.Clone()
                if ($CustomGeneralProperties.Count -gt 0)
                {
                    $mainPropertiesHash = Merge-HashTables -htold $mainPropertiesHash -htnew $CustomGeneralProperties
                }

                $configPropertiesHash = $script:DefaultDotNetConfigProperties.Clone()
                if ($CustomConfigurationProperties.Count -gt 0)
                {
                    $configPropertiesHash = Merge-HashTables -htold $configPropertiesHash -htnew $CustomConfigurationProperties
                }
            }

            # Are there any main properties to change?
            if ($mainPropertiesHash.Count -gt 0)
            {
               HandleCSharpMainProperties -file $file -fileXML $fileXML -newMainProps $mainPropertiesHash
            }

            # Any configuration properties to change?
            if ($configPropertiesHash.Count -gt 0)
            {
                # Loop through the configuration array.
                foreach($config in $Configurations)
                {
                    HandleCSharpConfigProperties -file $file -allFileXML $fileXML -configString $config -newProps $configPropertiesHash
                }
            }

            $fileXML.Save($file)
        }

        function ProcessProjectFile([string] $file)
        {
            # Is the file read only?
            if ((Get-ChildItem -Path $file).IsReadOnly)
            {
                throw "$file is readonly so it cannot be changed"
            }

            $ext = [System.IO.Path]::GetExtension($file)

            switch -Wildcard ($ext)
            {
                "*.csproj"
                {
                    ProcessCSharpProjectFile -file $file
                }

                default
                {
                    throw "Sorry, $file is an unsupported project type at this time."
                }
            }


        }
    }
    process
    {
        if ($PSCmdlet.ShouldProcess($path, "Updating settings"))
        {
            Write-Verbose "Processing : $path"
            ProcessProjectFile $path
        }
    }
    end
    {
    }
}

# SIG # Begin signature block
# MIIUywYJKoZIhvcNAQcCoIIUvDCCFLgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrpc1cZmX+lWfXhfh//uoWS4M
# AbOggg+6MIIEmTCCA4GgAwIBAgIPFojwOSVeY45pFDkH5jMLMA0GCSqGSIb3DQEB
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
# MQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU3mG3cI3kmrGey7xQ6oWO
# FOiW8HgwDQYJKoZIhvcNAQEBBQAEggEAeQ/hLNX6dIker7UeSpzH2TXUS0sAmArc
# 2Cpdedt4oTmUBHOSwhYbpBYNlqh7G56r5JwRKUGnRQEdEWrBraGdzDuSQrQ44vWH
# P5wmNaIGFR6+ZPC6qb5LbWi8ltgzGus3JeAH59SDT18cuTuCqrhvWESMRLyXQbAU
# 6/aduO9rBEkibwiP2z9DZhZC5R/k8rNP5ZnVZRkjKpXsP3LUjYyeYSFV6CCCxb/V
# +BZZiQQpAr8E1ycnZXg6kMxcUrPNBlk1X1d1JdWAx5rScsrde9oeDijaJhfMBclB
# qAk1P/BVECOOPBdTRPAiTxWqifWuD9nqfkLazNWwoG124E7ctl4Dp6GCAkMwggI/
# BgkqhkiG9w0BCQYxggIwMIICLAIBADCBqTCBlTELMAkGA1UEBhMCVVMxCzAJBgNV
# BAgTAlVUMRcwFQYDVQQHEw5TYWx0IExha2UgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMSEwHwYDVQQLExhodHRwOi8vd3d3LnVzZXJ0cnVzdC5j
# b20xHTAbBgNVBAMTFFVUTi1VU0VSRmlyc3QtT2JqZWN0Ag8WiPA5JV5jjmkUOQfm
# MwswCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZI
# hvcNAQkFMQ8XDTE3MDExMjIzMDcyOFowIwYJKoZIhvcNAQkEMRYEFPJh0qEHYknV
# GO2syeop9kfsuIHIMA0GCSqGSIb3DQEBAQUABIIBAIjXM8Q1TPjM5z1StgNmdj2A
# TJlTNaYw9w36F2p7CzJJ7tz90m2tgGmLuocM+iSiRAnGCd5V7Nn3BYN5bGUXRWyq
# ItutqiFDw9lwTvg2WtojsNI21Vl5LOXC0p7dg+wnuSdq8NsRdcOvAU2oJq43gs+E
# RNhpur06oCTw7hI8nefmC1VgeMuOipq5Xzl7C0CFUh9amgQjxVecPqJkLciusP3S
# +8Q03F4QVc8Z+ZxY99QXWk4ClH3IVY1eAnBzul3B7ucam7ax5nnQX7/xNGlJ3yRt
# ABxHtUurN6QFOeCoglnLJw88DDsGjYXZZDFQXM0YmrgY+SDNBzk6XkY0P6CDkwQ=
# SIG # End signature block
