#requires -version 2.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2014 - John Robbins/Wintellect
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
http://www.wintellect.com/blogs/jrobbins
http://code.wintellect.com
#>
    param
    (
        [string[]]  $paths,
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
                switch ($item.Key)
                {
                    "AssemblyOriginatorKeyFile" 
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
                $resolvedPaths = Resolve-Path -Path $path
                foreach ($file in $resolvedPaths)
                {
                    ProcessProjectFile $file
                }
            }
        }
    }
}

# SIG # Begin signature block
# MIIYTQYJKoZIhvcNAQcCoIIYPjCCGDoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUCR6dHPthJ7jcWe/CfK+OHsjs
# esugghM9MIIEhDCCA2ygAwIBAgIQQhrylAmEGR9SCkvGJCanSzANBgkqhkiG9w0B
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
# MCMGCSqGSIb3DQEJBDEWBBTpaWlnvaOH1mgap34jWltrRLb+XTANBgkqhkiG9w0B
# AQEFAASCAQC075iRa2YH4VPJdOb+HJPhZvFw2FwvHanG96jwRvT28hcSVMLNwfgQ
# dDGu8Bo5MpTw3bFq1Ms+IEEOAruX38ec77k7HxVD4eZlTaJlQlNh8BJNtTw2cZse
# 1yeRfrjyfkFsOshRAiiATf8xXwkxqB3ojwAllUJRSBSQwojQOR85BOOhzltzJf28
# 3IEO8zjOLO8f2ZxbNUuM0IdCM8D9/jgiaADC3RW7q3HIPqAzaNgdgB2HNczSxXGs
# E+5q0GdscV4MJrrW86/WbpUpQD7qCXGskQJr9XesC+8x0uzdbu0qR4gQS/mu5isl
# 7TwnVYe54yEKvQ1nkvhCZvFB23KOlxlpoYICRTCCAkEGCSqGSIb3DQEJBjGCAjIw
# ggIuAgEAMIGrMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNVBAcT
# DlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# ITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMUVVRO
# LVVTRVJGaXJzdC1PYmplY3QCEQCf6sgRsPFiR6X8INgFI6zmMAkGBSsOAwIaBQCg
# XTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xNTA3
# MDkxNzIwMTVaMCMGCSqGSIb3DQEJBDEWBBQ3NtJCV6IZSENyh1j/6jMSupeTSzAN
# BgkqhkiG9w0BAQEFAASCAQAVbYw6thNHBqWFmobsEX7KByA0J2v9pAzQWPrvGZpH
# DscwjKWcWQ40STbJfh+P1A37Fu/C+W1E5r4uZCswvBZ+Y8zqgtD9nJbAtIz/Y8J8
# fHWb0m+8eQTxYxUIcaH7oGaBPo4qHExfS076D/fuwN8CsPOli5k8l18Le/ogv3xV
# VlhFsnMd8J4+U6poiBeesM99RZpJSiOIyKeen9li4omIqp3T/q/rF+vwXBqS+mtR
# FAYNIH3BYDYY3vZkTe9KTG1M9hHBRC4gz8i+uAJLS/t89N4cH9315j7W9dFa5OvH
# 6/pxLTOJ5PMNebalQKNZcwvLPgVWZgBL7xAAPWbPJBHH
# SIG # End signature block
