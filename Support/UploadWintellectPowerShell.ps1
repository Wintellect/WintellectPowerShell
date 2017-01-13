param
(
        [Parameter(Mandatory=$true,
                   HelpMessage="Please specify the api key")]
        [string] $apiKey
)

Publish-Module -NuGetApiKey $apiKey -Path ..\ -Verbose 




