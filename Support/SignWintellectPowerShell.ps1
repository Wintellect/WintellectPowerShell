Set-StrictMode -version Latest

$cert = @(Get-ChildItem cert:\CurrentUser\My -codesigning)[0]
$timeServer = "http://timestamp.comodoca.com/authenticode"
# Build my list of files to sign.
$files = Get-ChildItem -Path ..\Code\*.* -Include *.ps*,*.dll
$files += Get-ChildItem -Path ..\* -Include *.ps*

Set-AuthenticodeSignature -FilePath $files -Certificate $cert -TimestampServer $timeServer
