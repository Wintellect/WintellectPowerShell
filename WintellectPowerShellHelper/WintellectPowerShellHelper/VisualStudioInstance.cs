using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace WintellectPowerShellHelper
{
    /// <summary>
    /// Maps to the Microsoft.VisualStudio.Setup.Configuration.InstanceState enum so it does not have to be exported.
    /// </summary>
    public enum InstanceStatus : Int32
    {
        /// <summary>
        /// The instance state is not determined.
        /// </summary>
        None = 0,

        /// <summary>
        /// The instance installation path exists
        /// </summary>
        Local = 1,

        /// <summary>
        /// A product is regisistered to teh instance
        /// </summary>
        Registered = 2,

        /// <summary>
        /// No reboot is required for the insance.
        /// </summary>
        NoRebootRequired = 4,

        /// <summary>
        /// The instance represents a complete installation.
        /// </summary>
        Complete = Int32.MaxValue

    }

    /// <summary>
    /// Represents an installation package that is part of a Visual Studio 2017 installation.
    /// </summary>
    public class PackageReference
    {
        /// <summary>
        /// Gets the build branch of the package.
        /// </summary>
        public String Branch { internal set; get; }

        /// <summary>
        ///  Gets the target process architecture of the package
        /// </summary>
        public String Chip { internal set; get; }

        /// <summary>
        /// Gets the general package identifier.
        /// </summary>
        public String Id { internal set; get; }

        /// <summary>
        /// A value indicating whether the package refers to an external extension.
        /// </summary>
        public Boolean IsExtension { internal set; get; }

        /// <summary>
        /// Gets the language and optional region identifier.
        /// </summary>
        public String Language { internal set; get; }

        /// <summary>
        /// Gets the unique identifier consisting of all defined tokens.
        /// </summary>
        public String UniqueId { internal set; get; }

        /// <summary>
        /// Gets the version of the package.
        /// </summary>
        public String Version { internal set; get; }

    }

    /// <summary>
    /// Represents all the information about an individual Visual Studio 2017, or higher, installtion.
    /// </summary>
    public class VisualStudioInstance
    {
        /// <summary>
        /// The instance ID for the installation.
        /// </summary>
        public String InstanceId { internal set; get; }

        /// <summary>
        /// The state of this installation.
        /// </summary>
        public InstanceStatus Status { internal set; get; }

        /// <summary>
        /// The converted version string.
        /// </summary>
        public String InstalledVersionNumber { internal set; get; }

        /// <summary>
        /// The path to the installation root.
        /// </summary>
        public String InstallationPath { internal set; get; }

        /// <summary>
        /// The product name.
        /// </summary>
        public String ProductName { internal set; get; }

        /// <summary>
        ///  Returns the description of the product.
        /// </summary>
        public String Description { internal set; get; }

        /// <summary>
        /// Returns the display name of the product.
        /// </summary>
        public String DisplayName { internal set; get; }

        /// <summary>
        /// Returns the list of products for this installation.
        /// </summary>
        public IList<PackageReference> Products { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of workloads for this installation.
        /// </summary>
        public IList<PackageReference> Workloads { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of components for this installation.
        /// </summary>
        public IList<PackageReference> Components { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of Vsix for this installation.
        /// </summary>
        public IList<PackageReference> Visx { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns teh list of Exe for this installation.
        /// </summary>
        public IList<PackageReference> Exe { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of Msi for this installation.
        /// </summary>
        public IList<PackageReference> Msi { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of Msu for this installation.
        /// </summary>
        public IList<PackageReference> Msu { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of Group for this installation.
        /// </summary>
        public IList<PackageReference> Group { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of Windows Features for this installation.
        /// </summary>
        public IList<PackageReference> WindowsFeature { get; } = new List<PackageReference>();

        /// <summary>
        /// Returns the list of other package types.
        /// </summary>
        public IList<PackageReference> OtherPackages { get; } = new List<PackageReference>();
    }
}
