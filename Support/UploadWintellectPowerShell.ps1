param
(
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the api key")]
        [string] $apiKey, 
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the release notes for this version")]
        [string] $ReleaseNotes 
)

Publish-Module -NuGetApiKey $apiKey `
               -IconUri "https://avatars0.githubusercontent.com/u/2118457?v=3&amp;s=200" `
               -LicenseUri "https://raw.githubusercontent.com/Wintellect/WintellectPowerShell/master/License.txt" `
               -Path ..\ `
               -ProjectUri https://github.com/Wintellect/WintellectPowerShell `
               -ReleaseNotes $ReleaseNotes `
               -Tags "Wintellect","Debugging", "Symbol Servers", "Visual Studio" `
               -Verbose 




