using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.VisualStudio.Setup.Configuration;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Globalization;

namespace WintellectPowerShellHelper
{
    /// <summary>
    /// Helper class for getting all Visual Studio Instances.
    /// </summary>
    public static class VisualStudioSetup
    {
        private const int REGDB_E_CLASSNOTREG = unchecked((int)0x80040154);

        /// <summary>
        /// Returns the list of <seealso cref="VisualStudioInstance"/> representing the installed 
        /// Visual Studio instances on the machine.
        /// </summary>
        /// <param name="lcid">
        /// The local id to use for returning internationalized strings.
        /// </param>
        /// <param name="includeIncompleteInstances">
        /// If true, does all instances, even those that are incomplete. If false, the default,
        /// does just completed instances.
        /// </param>
        /// <param name="includeAllPackages">
        /// If true, includes all packages with the returned results. The default is to only 
        /// return the main installation data.
        /// </param>
        /// <returns>
        /// The list of installed instances. An empty list if none are installed.
        /// </returns>
        public static IList<VisualStudioInstance> GetInstalledInstances(int lcid = 0,
                                                                        Boolean includeIncompleteInstances = false,
                                                                        Boolean includeAllPackages = false)
        {
            List<VisualStudioInstance> resultList = new List<VisualStudioInstance>();

            // Grab the config interface and enumerate the instances.
            var setupConfig = GetSetupConfig();

            if (setupConfig != null)
            {

                IEnumSetupInstances instanceList = null;
                if (includeIncompleteInstances == false)
                {
                    instanceList = setupConfig.EnumInstances();
                }
                else
                {
                    instanceList = setupConfig.EnumAllInstances();
                }

                // Now it is time to loop!
                int fetched;
                ISetupInstance2[] instance = new ISetupInstance2[1];
                do
                {
                    instanceList.Next(1, instance, out fetched);
                    if (fetched > 0)
                    {
                        var filledInstance = FillInInstanceData(instance[0],
                                                                lcid,
                                                                includeAllPackages);
                        resultList.Add(filledInstance);
                    }

                } while (fetched > 0);
            }

            return resultList;
        }

        private static VisualStudioInstance FillInInstanceData(ISetupInstance2 instance,
                                                               int lcid,
                                                               Boolean includePackages)
        {
            VisualStudioInstance result = new VisualStudioInstance()
            {
                InstanceId = instance.GetInstanceId(),
                InstalledVersionNumber = instance.GetInstallationVersion(),
                Description = instance.GetDescription(lcid),
                DisplayName = instance.GetDisplayName(lcid)
            };

            // Hides the non-CLS clompliant uint.
            var tempState = instance.GetState();
            if (tempState == InstanceState.Complete)
            {
                result.Status = InstanceStatus.Complete;
            }
            else
            {
                result.Status = (InstanceStatus)tempState;
            }

            result.InstallationPath = instance.GetInstallationPath();

            ISetupPackageReference prod = instance.GetProduct();
            if (prod != null)
            {
                result.ProductName = prod.GetId();
            }

            if ((result.Status & InstanceStatus.Local) == InstanceStatus.Local)
            {
                result.InstallationPath = instance.GetInstallationPath();
            }


            if (includePackages)
            {
                ProcessPackages(instance, result);
            }

            return result;
        }

        private static void ProcessPackages(ISetupInstance2 instance, VisualStudioInstance result)
        {
            ISetupPackageReference[] packages = instance.GetPackages();

            foreach (var package in packages)
            {
                String packageType = package.GetType();

                PackageReference refPackage = CreatePackageReference(package);

                switch (packageType.ToUpper(CultureInfo.InvariantCulture))
                {
                    case "PRODUCT":
                        result.Products.Add(refPackage);
                        break;
                    case "WORKLOAD":
                        result.Workloads.Add(refPackage);
                        break;
                    case "COMPONENT":
                        result.Components.Add(refPackage);
                        break;
                    case "VSIX":
                        result.Visx.Add(refPackage);
                        break;
                    case "EXE":
                        result.Exe.Add(refPackage);
                        break;
                    case "MSI":
                        result.Msi.Add(refPackage);
                        break;
                    case "MSU":
                        result.Msu.Add(refPackage);
                        break;
                    case "GROUP":
                        result.Group.Add(refPackage);
                        break;
                    case "WINDOWSFEATURE":
                        result.WindowsFeature.Add(refPackage);
                        break;
                    default:
                        Trace.WriteLine(packageType);
                        result.OtherPackages.Add(refPackage);
                        break;

                }

            }
        }

        private static PackageReference CreatePackageReference(ISetupPackageReference package)
        {
            PackageReference refPackage = new PackageReference()
            {
                Branch = package.GetBranch(),
                Chip = package.GetChip(),
                Id = package.GetId(),
                IsExtension = package.GetIsExtension(),
                Language = package.GetLanguage(),
                UniqueId = package.GetUniqueId(),
                Version = package.GetVersion()
            };

            return refPackage;
        }

        private static ISetupConfiguration2 GetSetupConfig()
        {
            try
            {
                // Do the CoCreate dance first.
                return (ISetupConfiguration2)(new SetupConfiguration());
            }
            catch (COMException ex) when (ex.HResult == REGDB_E_CLASSNOTREG)
            {
                // Try it with the app-local call.
                var result = NativeMethods.GetSetupConfiguration(out var query, IntPtr.Zero);
                if (result < 0)
                {
                    // This means VS 2017+ is not installed.
                    return null;
                }

                return (ISetupConfiguration2)query;
            }
        }
    }

}
