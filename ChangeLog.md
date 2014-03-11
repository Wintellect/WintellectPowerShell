# Wintellect PowerShell Change Log #

## March 11, 2014
Fixed a bug in Compare-Directories.

## November 18, 2013
Fixed a copy pasta bug in Get-SourceServerFiles

Add-NgenPdbs now properly supports VS 2013

Re-digitally signed everything with my new code signing certificate as the old one was expiring. I didn't have to do that but was signing the changed file so went ahead and did all of them.

## July 17, 2013
Updated Set-SymbolServer, Set-SourceServer, Get-SourceServer, and Remove-IntelliTraceFiles to support VS 2013.

## June 24, 2013
Fixed a bug in Import-VisuaStudioEnvironment where I should be looking at the Wow6432Node on x64 dev boxes reported by [RaHe67](https://github.com/RaHe67). Also updated the cmdlet with the official version and name of VS 2013.

## May 20, 2013
Updated the Set-SymbolServer -public switch to use the same cache on both the reference source and msdl download items. With VS 2012 this works better and helps avoid multiple downloads of various PDB files. Since I no longer use VS 2010, I'm not sure what affect this will have on that version. Also, I turn off using the Microsoft symbol servers as I'm putting them all in the _NT_SYMBOL_PATH environment variable anyway.

Additionally, Set-SymbolServer now puts any specified symbol servers with the -SymbolServers switch at the front of the _NT_SYMBOL_PATH environment variable. This will make symbol downloading faster for those with your own symbol server set up.

## May 9, 2013
Added the Set-Environment, Invoke-CmdScript, and Import-VisuaStudioEnvironment cmdlets.

The Invoke-CmdScript cmdlet is based off [Lee Holmes'](http://www.leeholmes.com/blog/2006/05/11/nothing-solves-everything-%e2%80%93-powershell-and-other-technologies/) version.

The Set-Environment cmdlet is from [Wes Haggard](http://weblogs.asp.net/whaggard/archive/2007/02/08/powershell-version-of-cmd-set.aspx). To replace the default set alias with the one provided by WintellectPowerShell, execute the following command before importing the module:

`Import-Module WintellectPowerShell
Remove-Item alias:set -Force -ErrorAction SilentlyContinue
`

## February 25, 2013
Added the Add-NgenPdb cmdlet.

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