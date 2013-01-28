# Wintellect PowerShell Change Log #

## January, 27, 2013
Added the very cool Set-ProjectProperties cmdlet to make batch updating of Visual Studio projects much easier. Right now it only supports C# projects.

Changed the architecture of the whole module to break up a single .PSM1 file into different files for each cmdlet. This will make development much easier going forward.

Removed the external help XML file and put all help back into the source code. Editing the external file was a pain in the butt because the editor leaves lots to be desired and I was never going to support updatable help anyway.

## October 14, 2012 ##
Added the following cmdlets:
Compare-Directories - Can compare directories to see if they contain the same filenames as well as the same content.

Get-Hash - Gets the cryptographic hash for a file or string.

## September 29, 2012 ##
Added the following cmdlets:

Test-RegPath - Original author [Can Dedeoglu](http://blogs.msdn.com/candede "Can Dedeoglu")

Remove-IntelliTraceFiles - If saving your debugging IntelliTrace files, the directory can quickly fill with many large files. This cmdlet keeps your IntelliTrace file directory cleaned up.

## August 29, 2012 ##
Initial release to GitHub.