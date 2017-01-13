using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WintellectPowerShellHelper
{
    /// <summary>
    /// Helps make reading and writing the VS 2017+ private registry files easier.
    /// </summary>
    public static class PrivateRegistry
    {
        /// <summary>
        /// Reads a the specified value out of the specified privateregistry.bin file.
        /// </summary>
        /// <param name="fileName">
        /// The Visual Studio 2017+ privateregistry.bin file. This must be the full 
        /// path to the file including the instance id.
        /// </param>
        /// <param name="keyName">
        /// The registry key to read.
        /// </param>
        /// <param name="value">
        /// The value to read.
        /// </param>
        /// <returns>
        /// Null if the value does not exist or is not set. Otherwise, the registry value.
        /// </returns>
        /// <exception cref="ArgumentException">
        /// Thrown if any paramaters are null or empty.
        /// </exception>
        public static String ReadValue(String fileName, String keyName, String value)
        {
            if (String.IsNullOrEmpty(fileName))
            {
                throw new ArgumentException("fileName cannot be null");
            }

            if (String.IsNullOrEmpty(keyName))
            {
                throw new ArgumentException("key cannot be null");
            }

            if (String.IsNullOrEmpty(value))
            {
                throw new ArgumentException("value cannot be null");
            }

            Int32 regHandle = OpenPrivateRegistry(fileName);

            String result = null;

            // Now this, my friends, is the beauty of a using statement!
            using (var safeRegistryHandle = new SafeRegistryHandle(new IntPtr(regHandle), true))
            using (var appKey = RegistryKey.FromHandle(safeRegistryHandle))
            using (var openedKey = appKey.OpenSubKey(keyName, true))
            {
                if (openedKey != null)
                {
                    Object val = openedKey.GetValue(value);
                    result = val.ToString();
                }
            }

            return result;
        }

        private static Int32 OpenPrivateRegistry(String regFileName)
        {
            Int32 returnCode = NativeMethods.RegLoadAppKey(regFileName,
                                                           out var result,
                                                           NativeMethods.RegSAM.Read,
                                                           0,
                                                           0);
            if (returnCode != 0)
            {
                throw new Win32Exception(returnCode, "RegLoadAppKey failed opening " + regFileName);
            }
            return result;
        }
    }
}
