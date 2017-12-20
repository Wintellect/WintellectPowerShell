# Wintellect PowerShell Change Log #

## Version Current
- Added support for the new Source Linking in VS 2017.
- Removed forcing "set" as an alias because it made the installation of the module ugly and confusing. Add the following to your $profile to bring it back: Set-Alias -Name set -Value Set-Environment -Scope Global -Option AllScope
- Fixed some formatting in the read me and a spelling error in the help.

## 4.0.0.3
- Many thanks to [Sebastian Solnica](https://github.com/lowleveldesign) for fixing an internationalization bug in Import-VisualStudioEnvironment: [Pull request](https://github.com/Wintellect/WintellectPowerShell/pull/9).
- Fixed some formatting in this file.

## 4.0.0.2
- Fixed a bug with Get-SysInternalsSuite where I needed to add the -Force option when expanding the zip file to force extract into a directory with the existing tools files.
- Thanks to [bojanrajkovic](https://github.com/bojanrajkovic) as he fixed an issue it Test-Path: [Pull Request](https://github.com/Wintellect/WintellectPowerShell/pull/8).

## 4.0.0.1
- PowerShell 5.0 is now the minimum supported version. It's time to upgrade people. 
- Dropped support for any versions prior to VS 2013. Continue to use WintellectPowerShell 3.3.2.0 for older versions of Visual Studio.
- Completely rewrote everything in SymbolsSource.ps1. With VS 2017 no longer using the global registry to save settings, I had to make the changes in the CurrentSettings.vssettings file. This change works for VS2013-VS2017. The only difference you will notice is that after running WintellectPowerShell cmdlets is that you will see Visual Studio show the quick dialog that it is loading settings.
- Added the Set-SymbolAndSourceServer cmdlet. This combines both Set-SymbolServer and Set-SourceServer (which both still exist) because you really should set both at once.
- Updated Import-VisualStudioEnvironment to work with VS 2017 as Microsoft changed how the environment batch files worked.
- Updated Remove-IntelliTrace files to support VS 2017. That was a lot of work because Visual Studio 2017's installation is now complex enough that it requires an API to determine what's installed. Also, VS 2017 moved to private registry hives for performance reasons. I introduced a support DLL written in C# to isolate this complexity.
- Updated Add-NgenPdbs to work with VS 2017.
- Fixed all warnings reported by Invoke-ScriptAnalysis (version 1.9.0).

## November 16, 2015
- Fixed issue in Import-VisualStudioEnvironment that if the C++ tools were not installed, falls back to using VSDEVCMD.BAT to set the environment. Because VSDEVCMD.BAT does not support command line arguments, you only get the 32-bit tools. Use the -Verbose switch to see if VSDEVCMD.BAT is used.

## October 21, 2015
- Fixed an issue in Remove-IntelliTraceFiles where it did not work on VS 2015.

## July 9, 2015
- Fixed most of the errors reported by Invoke-ScriptAnalysis. Once RTM hits for PowerShell 5.0 I will fix the rest or suppress as appropriate.
- Add-NgenPDBs now supports VS 2015
- Fixed an issue in Compare-Directories where I removed stripping of the original and new directory paths when it was really needed. Sorry.

## June 25, 2015
- Set-SymbolServer now uses the new https://msdl.microsoft.com/download/symbols for more security.

## May 4, 2015
- Added Get-DumpAnalysis to automate minidump analysis easier.
- Fixed a bug in Get-SourceServer and Get-SymbolServer.

## December 27, 2014
Small updates

- Added Set-Signatures to make signing scripts easier mainly for me and others who sign but also have Azure certificates on the computer.
- Removed unneeded array conversion in Compare-Directories
- Removed the -Quiet switch to Add-NgenPdbs and removed Write-Host calls in the function. Use the standard -Verbose to see the output.

## November 11, 2014
A huge refactor! 

- Full support for the spanking new Visual Studio 2015.
- Now dot sourcing the individual files so I can start sharing some code.
- Fixed many of the warnings reported by Script Analyer 1.4.
- Now requiring PowerShell 4.0.
- Removed my Get-Hash and now using Get-FileHash.
- Remove-IntelliTraceFiles now supports -Latest like Import-VisualStudioEnvironment
- Get-SysInternalsSuite uses Invoke-WebRequest and additionally called Unblock-File to unlock all the extracted files.
- Fixed the issue where I was not exporting the set alias correctly.


## July 7, 2014
- Fixed an issue in Add-NgenPdbs where I wasn't handling the case where the VS cache directory could be blank.

## June 18, 2014
- Fixed an issue reported by [Chris Fraire/idodeclare](https://github.com/idodeclare) is Set-ProjectProperties where the assembly name for XML document comments was not set correctly in all cases.
- Ensured Set-ProjectProperties.ps1 is clean as reported by Microsoft's Script Analyzer plug in.

## June 13, 2014
- Fixed an issue with relative paths in Expand-ZipFile
- Added the -CurrentEnvironmentOnly  switch to both Set-SymbolServer and Set-SourceServer that changes on the environment variables for the current PowerShell window. This is only useful when using WinDBG because Visual Studio requires registry settings instead of environment variables.
- For the two files I touched, ensured they are clean as reported by Microsoft's Script Analyzer plug in.

## March 11, 2014
- Fixed a bug in Compare-Directories.

## November 18, 2013
- Fixed a copy pasta bug in Get-SourceServerFiles
- Add-NgenPdbs now properly supports VS 2013
- Re-digitally signed everything with my new code signing certificate as the old one was expiring. I didn't have to do that but was signing the changed file so went ahead and did all of them.

## July 17, 2013
- Updated Set-SymbolServer, Set-SourceServer, Get-SourceServer, and Remove-IntelliTraceFiles to support VS 2013.

## June 24, 2013
- Fixed a bug in Import-VisualStudioEnvironment where I should be looking at the Wow6432Node on x64 dev boxes reported by [RaHe67](https://github.com/RaHe67). Also updated the cmdlet with the official version and name of VS 2013.

## May 20, 2013
- Updated the Set-SymbolServer -public switch to use the same cache on both the reference source and msdl download items. With VS 2012 this works better and helps avoid multiple downloads of various PDB files. Since I no longer use VS 2010, I'm not sure what affect this will have on that version. Also, I turn off using the Microsoft symbol servers as I'm putting them all in the _NT_SYMBOL_PATH environment variable anyway.
- Additionally, Set-SymbolServer now puts any specified symbol servers with the -SymbolServers switch at the front of the _NT_SYMBOL_PATH environment variable. This will make symbol downloading faster for those with your own symbol server set up.

## May 9, 2013
- Added the Set-Environment, Invoke-CmdScript, and Import-VisualStudioEnvironment cmdlets.
- The Invoke-CmdScript cmdlet is based off [Lee Holmes'](http://www.leeholmes.com/blog/2006/05/11/nothing-solves-everything-%e2%80%93-powershell-and-other-technologies/) version.
- The Set-Environment cmdlet is from [Wes Haggard](http://weblogs.asp.net/whaggard/archive/2007/02/08/powershell-version-of-cmd-set.aspx). To replace the default set alias with the one provided by WintellectPowerShell, execute the following command before importing the module:

`Import-Module WintellectPowerShell
Remove-Item alias:set -Force -ErrorAction SilentlyContinue
`

## February 25, 2013
- Added the Add-NgenPdb cmdlet.

## January, 27, 2013
- Added the very cool Set-ProjectProperties cmdlet to make batch updating of Visual Studio projects much easier. Right now it only supports C# projects.
- Changed the architecture of the whole module to break up a single .PSM1 file into different files for each cmdlet. This will make development much easier going forward.
- Removed the external help XML file and put all help back into the source code. Editing the external file was a pain in the butt because the editor leaves lots to be desired and I was never going to support updatable help anyway.

## October 14, 2012 ##
- Added the following cmdlets: 
    - Compare-Directories - Can compare directories to see if they contain the same filenames as well as the same content.
    - Get-Hash - Gets the cryptographic hash for a file or string.

## September 29, 2012 ##
- Added the following cmdlets: 
    - Test-RegPath - Original author [Can Dedeoglu](http://blogs.msdn.com/candede "Can Dedeoglu")
    - Remove-IntelliTraceFiles - If saving your debugging IntelliTrace files, the directory can quickly fill with many large files. This cmdlet keeps your IntelliTrace file directory cleaned up.

## August 29, 2012 ##
- Initial release to GitHub.
