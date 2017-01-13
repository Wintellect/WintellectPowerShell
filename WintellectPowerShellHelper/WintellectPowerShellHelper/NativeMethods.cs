using System;
using System.Runtime.InteropServices;
using Microsoft.VisualStudio.Setup.Configuration;

namespace WintellectPowerShellHelper
{
    internal static class NativeMethods
    {
        [Flags]
        internal enum RegSAM
        {
            AllAccess = 0x000f003f,
            Read = 0x20019,
            Write = 0x20006,
        }

        [DllImport("Microsoft.VisualStudio.Setup.Configuration.Native.dll", ExactSpelling = true, PreserveSig = true)]
        internal static extern int GetSetupConfiguration([MarshalAs(UnmanagedType.Interface), Out] out ISetupConfiguration configuration, 
                                                         IntPtr reserved);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        internal static extern int RegLoadAppKey(String hiveFile, out int hKey, RegSAM samDesired, int options, int reserved);

    }
}
