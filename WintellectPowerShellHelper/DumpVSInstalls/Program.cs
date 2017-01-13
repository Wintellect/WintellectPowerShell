using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using WintellectPowerShellHelper;

namespace DumpVSInstalls
{
    class Program
    {
        static void Main(string[] args)
        {
            IList<VisualStudioInstance> instances = VisualStudioSetup.GetInstalledInstances(includeAllPackages: true);

            foreach (var instance in instances)
            {
                Console.WriteLine("--------------------");
                Console.WriteLine($"Product Name     : {instance.ProductName}");
                Console.WriteLine($"Display Name     : {instance.DisplayName}");
                Console.WriteLine($"Description      : {instance.Description}");
                Console.WriteLine($"Instance ID      : {instance.InstanceId}");
                Console.WriteLine($"Status           : {instance.Status}");
                Console.WriteLine($"Install Path     : {instance.InstallationPath}");
                Console.WriteLine($"Version          : {instance.InstalledVersionNumber}");

                Console.WriteLine($"Product Count    : {instance.Products.Count}");
                DumpPackageReferences(instance.Products);

                Console.WriteLine($"Workload Count   : {instance.Workloads.Count}");
                DumpPackageReferences(instance.Workloads);

                Console.WriteLine($"Component Count  : {instance.Components.Count}");
                DumpPackageReferences(instance.Components);

                Console.WriteLine($"Vsix Count       : {instance.Visx.Count}");
                DumpPackageReferences(instance.Visx);

                Console.WriteLine($"Exe Count        : {instance.Exe.Count}");
                DumpPackageReferences(instance.Exe);

                Console.WriteLine($"Msi Count        : {instance.Msi.Count}");
                DumpPackageReferences(instance.Msi);

                Console.WriteLine($"Msu Count        : {instance.Msu.Count}");
                DumpPackageReferences(instance.Msu);

                Console.WriteLine($"Group Count      : {instance.Group.Count}");
                DumpPackageReferences(instance.Group);

                Console.WriteLine($"WinFeature Count : {instance.WindowsFeature.Count}");
                DumpPackageReferences(instance.WindowsFeature);
            }

        }

        static void DumpPackageReferences(IList<PackageReference> itemList)
        {
            foreach (var item in itemList)
            {
                Console.WriteLine($"   Id            : {item.Id}");

                if (!String.IsNullOrEmpty(item.Branch))
                {
                    Console.WriteLine($"     Branch      : {item.Branch}");
                }

                if (!String.IsNullOrEmpty(item.Chip))
                {
                    Console.WriteLine($"     Chip        : {item.Chip}");
                }

                if (item.IsExtension)
                {
                    Console.WriteLine($"     Extension   : {item.IsExtension}");
                }

                if (!String.IsNullOrEmpty(item.Language))
                {
                    Console.WriteLine($"     Language    : {item.Language}");
                }

                if (!String.IsNullOrEmpty(item.UniqueId))
                {
                    Console.WriteLine($"     UniqueId    : {item.UniqueId}");
                }

                if (!String.IsNullOrEmpty(item.Version))
                {
                    Console.WriteLine($"     Version     : {item.Version}");
                }
            }
        }
    }
}
