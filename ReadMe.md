# Wintellect PowerShell Module #

After posting many random PowerShell scripts in my [blog ](http://www.wintellect.com/cs/blogs/jrobbins/default.aspx), I packaged them up into a common module to make sharing and incorporating easier. Please fork and let me know if there's any bugs you find. I hope you find it useful.

Here's the about text showing all cmdlets. Of course, all cmdlets have detailed help for more information.

    TOPIC
        about_WintellectPowerShell
        
    SHORT DESCRIPTION
        Provides cmdlets for setting up symbol servers and other functionality related to debugging.
               
    LONG DESCRIPTION
        This module makes setting up symbol servers and source server debugging functionality easier to control
        for Visual Studio 2010, Visual Studio 2012 and WinDBG. Setting up a development machine for symbol server 
        access is more difficult than it needs to be but no more.
        
        You can have any combination of Visual Studio 2010, Visual Studio 2012, and WinDBG on the computer for 
        these cmdlets to work.
        
        These cmdlets had been originally developed as PowerShell scripts by John Robbins and released on his blog.
        This module combines all the seperate scripts to make everything easier to manage.
        
        If you have any questions, suggestions, or bug reports, please contact John at john@wintellect.com.
                     
        The following cmdlets are included.

            Cmdlet					    Description
            ------------------		    ----------------------------------------------
            Set-SymbolServer            Sets up a computer to use a symbol server.
            
            Get-SymbolServer            Returns a hashtable of the current symbol server settings.

            Set-SourceServer            Sets the source server directory.

            Get-SourceServer            Returns a hashtable of the current source server settings
            
            Get-SourceServerFiles       Prepopulate your symbol cache with all your Source Server extracted source 
                                        code.
                    
            Get-SysinternalsSuite       Gets all the wonderful Sysinternals tools
            
            Get-Uptime                  Returns how long a computer has been running.
            
            Expand-ZipFile              Expands a .ZIP file to the specified directory.

            Test-PathReg                Utility function to test is a registry key property exists in a key.

            Remove-IntelliTraceFiles    Removes no longer needed IntelliTrace files.
            
    SEE ALSO
        Online help and updates: http://www.wintellect.com/CS/blogs/jrobbins/default.aspx
        Set-SymbolServer
        Get-SymbolServer
        Set-SourceServer
        Get-SourceServer
        Get-SourceServerFiles
        Get-SysinternalsSuite
        Get-Uptime
        Expand-ZipFile
        Test-PathReg