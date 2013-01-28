#requires -version 2.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2013 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode  –version Latest 

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
            $assemblyName = $config.ParentNode.GetElementsByTagName("AssemblyName")

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
function Set-ProjectProperties([string[]]  $paths,
                               [switch]    $OverrideDefaultProperties,
                               [string[]]  $Configurations = @("Debug", "Release"),
                               [HashTable] $CustomGeneralProperties = @{},
                               [HashTable] $CustomConfigurationProperties = @{})
{
<#
.SYNOPSIS
A script to make Visual Studio 2010 and higher project management easier.

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
-	Treat warnings as errors
-	Check for arithmetic overflow and underflow
-	Enable code analysis with the default Code Analysis settings file.
-	Turn on creation of XML doc comment files.

This script is flexible and you can control down to setting/changing an 
individual property if necessary. There are many examples in the Examples 
section.

.PARAMETER  paths
This script can take pipeline input so you can easily handle deeply nested
project trees. Alternatively, you can put wildcards in this, but recursive
directories will not be searched.

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
http://www.wintellect.com/cs/blogs/jrobbins/default.aspx
http://code.wintellect.com
#>
    begin
    {
        function ReplaceNode(         $document,
                                    $topElement,
                            [string] $elementName,
                            [string] $elementValue )
        {
            Write-Debug "Replacing $elementName=$elementValue"

            $origNode = $topElement[$elementName]
            if ($origNode -eq $null)
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

        function ReplaceRelativePathNode([string] $fileLocation,
                                                $document,
                                                $topElement,
                                        [string] $elementName,
                                        [String] $fullUseFilePath)
        {
            try
            {
                Push-Location (Split-Path $fileLocation)

                $relLocation = Resolve-Path $fullUseFilePath -Relative

                Write-Debug "Setting relative path $elementName=$relLocation"

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
                                            [xml]       $fileXML, 
                                            [hashtable] $newMainProps )
        {
            # Go find the main property group which is the one with the ProjectGuid in it.
            $mainProps = $fileXML.Project.PropertyGroup | Where-Object { $_["ProjectGuid"] -ne $null }

            if (($mainProps -eq $null) -or ($mainProps -is [Array]))
            {
                throw "$file does not have the correct property group with the ProjectGuid or has multiple"
            }

            # Enumerate through the property keys.
            foreach ($item in $newMainProps.GetEnumerator())
            {
                switch ($item.Key)
                {
                    "AssemblyOriginatorKeyFile" 
                    {
                        # Get the full path to the .SNK file specified.
                        $snkFile = Resolve-Path $item.Value -ErrorAction SilentlyContinue

                        if ($snkFile -eq $null)
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

                    default
                    {
                        ReplaceNode -document $fileXML `
                                    -topElement $mainProps `
                                    -elementName $item.Key `
                                    -elementValue $item.Value
                    }
                }
            }
        }

        function HandleCSharpConfigProperties([string]    $file,
                                              [xml]       $allFileXML,
                                              [string]    $configString,
                                              [HashTable] $newProps)
        {
            # Get the configuration propery group.
            $configGroup = $allFileXML.GetElementsByTagName("PropertyGroup") | Where-Object { ($_.GetAttribute("Condition") -ne "") -and ($_.Condition -match $configString) }

            if (($configGroup -eq $null) -or ($configGroup -is [Array]))
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
                        $ruleFile = Resolve-Path $item.Value -ErrorAction SilentlyContinue

                        if ($ruleFile -eq $null)
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
                    ReplaceNode -document $fileXML `
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
            [xml]$fileXML = Get-Content $file 


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
                    $mainPropertiesHash = MergeHashTables -htold $mainPropertiesHash -htnew $CustomGeneralProperties
                }

                $configPropertiesHash = $script:DefaultDotNetConfigProperties.Clone()
                if ($CustomConfigurationProperties.Count -gt 0)
                {
                    $configPropertiesHash = MergeHashTables -htold $configPropertiesHash -htnew $CustomConfigurationProperties
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
            if ((Get-ChildItem $file).IsReadOnly)
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
        if ($_)
        {
            ProcessProjectFile $_
        }
    }
    end
    {
        if ($paths)
        {
            # Loop through each item on the command line.
            foreach ($path in $paths)
            {
                # There might be a wildcard here so resolve it to an array.
                $resolvedPaths = Resolve-Path $path
                foreach ($file in $resolvedPaths)
                {
                    ProcessProjectFile $file
                }
            }
        }
    }
}

# SIG # Begin signature block
# MIIO0QYJKoZIhvcNAQcCoIIOwjCCDr4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmt3SgoQ++VMXiv95hQP3v0if
# 7+KgggmnMIIEkzCCA3ugAwIBAgIQR4qO+1nh2D8M4ULSoocHvjANBgkqhkiG9w0B
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTNhrGDF5T9yswk
# k88nhIqZDns5FzANBgkqhkiG9w0BAQEFAASCAQCG0LWMv0Jrg2Zva9IPXOm4Hpqa
# Tqw3YcbEmb17xoOnimqN2qd2dWP0zx2IZPHYI/2y4AkR4OHIDKcbdfHl7/Si1jXz
# dEO0DXeX8f5kvMQpCZQmqlTfxnpMlN4vU70aRa+D8Lt6IVZia4bV4JTHcNELfGzf
# iqmCZXhOUf/Kf+A6uPgtBzbeL3cYhXfvtU45G3OifO+asKIB1e3T5Jht3HfXlNe1
# q/Y1p51mnkJ4ORZRwREbPlNEWZhL4y9cuHlFTR7Tk55OHPWLsUWfTFUH868/NhBO
# 622C32mBisKINQmCUaqzJ8BXz5qOxMxAMIZschXAInWVxw427j9dC7C3djkKoYIC
# RDCCAkAGCSqGSIb3DQEJBjGCAjEwggItAgEAMIGqMIGVMQswCQYDVQQGEwJVUzEL
# MAkGA1UECBMCVVQxFzAVBgNVBAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRy
# dXN0LmNvbTEdMBsGA1UEAxMUVVROLVVTRVJGaXJzdC1PYmplY3QCEEeKjvtZ4dg/
# DOFC0qKHB74wCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTEzMDEyNzA4MDEzM1owIwYJKoZIhvcNAQkEMRYEFC3o
# 9HhNId7+OE/8JLEb3hyWGGHIMA0GCSqGSIb3DQEBAQUABIIBADzmB+AB4r6nE+Hw
# IwPwRGP0dp3D29+qFnrr5N3LJ4xSJ0cs7p1oP7AuseKifN8LLLyLq4GN4z0gpS97
# KrHzYZB/qitjJ89VWB90c4usk9dofCPBb2ytLK2f6R1l0HhlckxFJ36XIzlSpk6l
# GoKoqrHMrP5f+UW3HVX8K7UNeJeY+3dGHfw5KlXCsJdlvwPWevnE8DNvZdo15Nxx
# baDSZSRkG/8Ajw0RIqZ7v64ADM6D4R1UQL9jkZOthAQ458mWXkOXuVX0qKOA3Hxl
# AuLABuk6bwD2R08lbTwFKN8lX5BGLKScTeGBLcfTSYyzHy+FO68qD8IQt4p97OvZ
# Z+We8q4=
# SIG # End signature block
