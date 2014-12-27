#requires -version 4.0
###############################################################################
# WintellectPowerShell Module
# Copyright (c) 2010-2014 - John Robbins/Wintellect
# 
# Do whatever you want with this module, but please do give credit.
###############################################################################

# Always make sure all variables are defined and all best practices are 
# followed.
Set-StrictMode -version Latest

###############################################################################
# Public Cmdlets
###############################################################################

function Compare-Directories
{
<#
.SYNOPSIS
Compare two directories to see if they are identical

.DESCRIPTION
This cmdlet will compare two directories and report if the files are identical 
by name, and optionally on content.
    
Symbol explanation:
=> - The file is in the -NewDir directory, not the -OriginalDir.
<= - The file is in the -OriginalDir directory and not the -NewDir.
!= - The file is in both directories, but the content is not identical.
    
If the directories are identical an empty hash table is returned.
    
Since sometimes filenames are long, you can pipe this output of this cmdlet 
into Format-Table -AutoSize to avoid truncating the filenames.

.PARAMETER OriginalDir
The original directory to use for the comparison.

.PARAMETER NewDir
The new directory to compare to.

.PARAMETER Excludes
 The array of exclusions, including wildcards, so you can filter out some of 
 the extraneous files.

.PARAMETER Recurse
Recurse the directory tree. The default is to just look at the directory.

.PARAMETER Force
Allows the cmdlet to get items that cannot otherwise not be accessed by the 
user, such as hidden or system files.

.PARAMETER Content
Check the content of matching filenames in both directories to see if they are 
equal. This is done through the Get-FileHash cmdlet from PowerShell 4.0.

.OUTPUTS 
HashTable
The name is the file, and the value is the difference indicator. If the 
directories are identical, an empty hash table is returned.

.EXAMPLE
C:\PS>Compare-Directories .\Original .\Copied -Content
    
    
Compares the original directory against a copied directory for both filenames 
and content.
    
This shows that both file a.pptx, and c.pptx are in both directories but the 
content is different. Files f.pptx and i.pptx are only in the .\Copied 
directory.    
    
Name                           Value
----                           -----
a.pptx                         !=
c.pptx                         !=
f.pptx                         =>
i.pptx                         =>

#>
    param (
        [Parameter(Mandatory=$true)]
        [string] $OriginalDir,
        [Parameter(Mandatory=$true)]
        [string] $NewDir,
        [string[]] $Excludes,
        [switch] $Recurse,
        [switch] $Force,
        [switch] $Content
        )

    if ((Test-Path -Path $OriginalDir) -eq $false)
    {
        throw "$OriginalDir does not exist"
    }

    if ((Test-Path -Path $NewDir) -eq $false)
    {
        throw "$NewDir does not exist"
    }
    
    # I need the real paths for the two input directories.
    $OriginalDir = (Resolve-Path -Path $OriginalDir).ToString().Trim("\")
    $NewDir = (Resolve-Path -Path $NewDir).ToString().Trim("\")
    # When you do a Resolve-Path on a network share you get the 
    # Microsoft.PowerShell.Core\FileSystem:: added to the name so 
    # yank it off if there.
    $OriginalDir = StripFileSystem -directory $OriginalDir
    $NewDir = StripFileSystem -directory $NewDir

    # Do the work to find all the files.
    $origFiles = Get-ChildItem -Path $OriginalDir -Recurse:$Recurse -Force:$Force -Exclude $Excludes
    $newFiles = Get-ChildItem -Path $NewDir -Recurse:$Recurse -Force:$Force -Exclude $Excludes

    # If either return is empty, create an empty array so I can return correct data.
    if ($origFiles -eq $null)
    {
        $origFiles = @()
    }
    if ($newFiles -eq $null)
    {
        $newFiles = @()
    }

    # Now do the comparisons on the names only.
    $nameComp = Compare-Object -ReferenceObject $origFiles -DifferenceObject $newFiles

    # The hash we are going to return.
    $resultHash = @{}
    
    # If there's no differences, $nameComp is null.
    if ($nameComp -ne $null)
    {
        # Push the PSCustomObject type into a resultHash table so content checking can put it's custom
        # results into the table.
        $nameComp | ForEach-Object { $resultHash[$_.InputObject] = $_.SideIndicator}
    }

    # if comparing the content
    if ($Content)
    {
        # Get just the matching values by calling Compare-Object -ExcludeDifferent -IncludeEqual.
        # Note that I'm using -PassThru here because I want result to be the identical filenames, not the
        # normal custom object returned by Compare-Object.
        $sameFiles = Compare-Object -ReferenceObject $origFiles -DifferenceObject $newFiles -IncludeEqual -ExcludeDifferent -PassThru

        foreach($file in $sameFiles)
        {
        
            # Build up the paths to the original file and the new file.
            $orig = $OriginalDir
            $orig += "\" + $file 

            # Am I about to check a directory that's in both places? If so, skip it because the
            # hash will be different because the strings are different.
            if ((Get-Item -Path $orig) -is [System.IO.DirectoryInfo])
            {
                continue 
            }

            $new = $NewDir 
            $new += "\" + $file

            $origHash = Get-FileHash -Path $orig
            $newHash = Get-FileHash -Path $new

            if ($origHash.Hash -ne $newHash.Hash)
            {
                $resultHash[$file] = "!="
            }
        }
    }

    # Nice trick to get the hash sorted by Name so it's easier to read.
    $resultHash.GetEnumerator()  | Sort-Object -Property Name
}

function StripFileSystem([string]$directory)
{
    $fsText = "Microsoft.PowerShell.Core\FileSystem::" 
    if ($directory.StartsWith($fsText))
    {
        $fsLen = $fsText.Length
        $dirLen = $directory.Length
        $directory = $directory.Substring($fsLen,$dirLen - $fsLen)
    }
    return $directory
}

