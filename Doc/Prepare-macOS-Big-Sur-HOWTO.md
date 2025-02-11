# How to set up a macOS Monterey machine for the daily builds

Note: A Mac can be configured for the BBS with
https://github.com/Bioconductor/bioconductor_salt.

## 0. General information and tips


- For how to uninstall Mac packages (`.pkg` files) using native `pkgutil`:
  https://wincent.com/wiki/Uninstalling_packages_(.pkg_files)_on_Mac_OS_X
- Watch https://mac.r-project.org/ for changes in requirements. Binaries can be
  found at https://mac.r-project.org/bin/. These binaries should be preferred
  over others.
- As of April 2023, the minimum supported OS is MacOSX11.
- This document describes how to prepare both x86_64 and arm64 machines for
  the BBS.
- Since Ventura, the terminal needs Full Disk Access to access the contents of
  a user's Downloads directory. Even if the Downloads directory is created
  manually, working with files in the Downloads directory may result in
  unexpected behavior:

      # User is created via GUI
      kjohnson3:Downloads auser$ ls -la
      Operation not permitted

      # User created via terminal; Downloads created manually
      kjohnson3:Downloads biocbuild$ sudo installer -verbose -pkg XQuartz-2.8.5.pkg -target /

      installer: Package name is
      installer: Upgrading at base path /
      installer: Preparing for installation….....
      installer: Preparing the disk….....
      installer: Preparing ….....
      installer: Waiting for other installations to complete….....
      installer: Configuring the installation….....
      installer:
       
      installer: The upgrade failed. (The Installer encountered an error that
      caused the installation to fail. Contact the software manufacturer for
      assistance. An error occurred while extracting files from the package
      “XQuartz-2.8.5.pkg”.)

  You also won't be able to create cronjobs, so your user must have full disk
  access.



## 1. Initial setup (from the administrator account)


This section describes the very first steps that need to be performed on
a pristine macOS Monterey installation (e.g. after creating a Mac instance on
MacStadium). Skip them and go directly to the next section if the biocbuild
account was created by someone else and if the core team member public keys
were already installed.

Everything in this section must be done **from the administrator account**
(the only account that should exist on the machine at this point).


### 1.1 Set the hostnames

    sudo scutil --set ComputerName merida1
    sudo scutil --set LocalHostName merida1
    sudo scutil --set HostName merida1

TESTING:

    scutil --get ComputerName
    scutil --get LocalHostName
    scutil --get HostName
    networksetup -getcomputername


### 1.2 Set DNS servers

    sudo networksetup -setdnsservers 'Ethernet 1' 216.126.35.8 216.24.175.3 8.8.8.8

TESTING:

    networksetup -getdnsservers 'Ethernet 1'
    ping www.bioconductor.org


### 1.3 Apply all software updates

    softwareupdate -l                  # to list all software updates
    sudo softwareupdate -ia --verbose  # install them all
    sudo reboot                        # reboot

TESTING: After reboot, check that the machine is running the latest release
of macOS Monterey i.e. 12.6.4. Check this with:

    system_profiler SPSoftwareDataType
    uname -a  # should show xnu-8020.240.18.700.8~1/RELEASE_X86_64 (or higher)

IMPORTANT: The OS versions present on the build machines are listed
in the `BBS/nodes/nodespecs.py` file and the OS versions displayed on
the build reports are extracted from this file. So it's important to
keep this file in sync with the actual versions present on the builders.


### 1.4 Create the biocbuild account

    sudo dscl . -create /Users/biocbuild
    sudo dscl . -create /Users/biocbuild UserShell /bin/bash
    sudo dscl . -create /Users/biocbuild UniqueID "505"
    sudo dscl . -create /Users/biocbuild PrimaryGroupID 20
    sudo dscl . -create /Users/biocbuild NFSHomeDirectory /Users/biocbuild
    sudo dscl . -passwd /Users/biocbuild <password_for_biocbuild>
    sudo dscl . -append /Groups/admin GroupMembership biocbuild
    sudo cp -R /System/Library/User\ Template/English.lproj /Users/biocbuild
    sudo chown -R biocbuild:staff /Users/biocbuild

    From now on we assume that the machine has a biocbuild account with admin
privileges (i.e. who belongs to the admin group). Note that on the Linux and
Windows builders the biocbuild user is just a regular user with no admin
privileges (not even a sudoer on Linux). However, on a Mac builder, during
STAGE5 of the builds (i.e. BUILD BIN step), the biocbuild user needs to be
able to set ownership and group of the files in the binary packages to
root:admin (this is done calling the chown-rootadmin executable, see below
in this document for the details), and then remove all these files at the
beginning of the next run. It needs to belong to the admin group in order
to be able to do this. Check this with:

    groups biocbuild

Because biocbuild belongs to the admin group, it automatically is a sudoer.
So all the configuration and management of the builds can and should be done
from the biocbuild account.


### 1.5 Add biocbuild authorized_keys

Add authorized_keys to /Users/biocbuild/.ssh.



## 2. Check hardware, OS, and connectivity with central build node


Except for 2.1, everything in this section must be done **from the
biocbuild account**.


### 2.1 Check that biocbuild belongs to the admin group

Check with:

    groups biocbuild

If biocbuild doesn't belong to the admin group, then you can add with the
following command from the administrator account:

    sudo dseditgroup -o edit -a biocbuild -t user admin

From now on everything must be done **from the biocbuild account**.


### 2.2 Check hardware requirements

These are the requirements for running the BioC software builds:

                          strict minimum  recommended
    Nb of logical cores:              16           24
    Memory:                         32GB         64GB

Hard drive: 512GB if the plan is to run BBS only on the machine. More (e.g.
768GB) if the plan is to also run the Single Package Builder.

Check nb of cores with:

    sysctl -n hw.logicalcpu   # logical cores
    sysctl -n hw.ncpu         # should be the same as 'sysctl -n hw.logicalcpu'
    sysctl -n hw.activecpu    # should be the same as 'sysctl -n hw.logicalcpu'
    sysctl -n hw.physicalcpu  # physical cores

Check amount of RAM with:

    system_profiler SPHardwareDataType  # will also report nb of physical cores

Check hard drive with:

    system_profiler SPStorageDataType


### 2.3 Apply any pending system updates and reboot

Make sure the machine is running the latest release of macOS Monterey:

    system_profiler SPSoftwareDataType

If not, use your your personal account or the administrator account to
update to the latest with:

    sudo softwareupdate -ia --verbose

and reboot the machine.

Check the kernel version (should be Darwin 21 for macOS Monterey):

    uname -sr


### 2.4 Install XQuartz

Download it from https://xquartz.macosforge.org/

    cd /Users/biocbuild/Downloads
    curl -LO https://github.com/XQuartz/XQuartz/releases/download/XQuartz-2.8.5/XQuartz-2.8.5.pkg

Install with:

    sudo installer -pkg XQuartz-2.8.5.pkg -target /
    cd /usr/local/include/
    ln -s /opt/X11/include/X11 X11

TESTING: Logout and login again so that the changes made by the installer
to the `PATH` take effect. Then:

    which Xvfb        # should be /opt/X11/bin/Xvfb
    ls -l /usr/X11    # should be a symlink to /opt/X11


### 2.5 Run Xvfb as service

`Xvfb` is run as global daemon controlled by launchd. We run this as a daemon
instead of an agent because agents are run on behalf of the logged in user
while a daemon runs in the background on behalf of the root user (or any user
you specify with the 'UserName' key).

    man launchd
    man launchctl

#### Create plist file

The plist files in `/Library/LaunchDaemons` specify how applications are
called and when they are started. We'll call our plist `local.xvfb.plist`.

    sudo vim /Library/LaunchDaemons/local.xvfb.plist

Paste these contents into `local.xvfb.plist`:

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
          <true/>
        <key>Label</key>
          <string>local.xvfb</string>
        <key>ProgramArguments</key>
          <array>
            <string>/opt/X11/bin/Xvfb</string>
            <string>:1</string>
            <string>-screen</string>
            <string>0</string>
            <string>800x600x16</string>
          </array>
        <key>RunAtLoad</key>
          <true/>
        <key>ServiceDescription</key>
          <string>Xvfb Virtual X Server</string>
        <key>StandardOutPath</key>
          <string>/var/log/xvfb/xvfb.stdout.log</string>
        <key>StandardErrorPath</key>
          <string>/var/log/xvfb/xvfb.stderror.log</string>
      </dict>
    </plist>

NOTE: The `KeepAlive` key means the system will try to restart the service if
it is killed.  When testing the set up, you should set `KeepAlive` to `false`
so you can manually start/stop the service. Once you are done testing, set
`KeepAlive` back to `true`.

#### Logs

stdout and stderror logs are output to `/var/log/xvfb` as indicated in
`/Library/LaunchDaemons/local.xvfb.plist`. Logs are rotated with `newsyslog`
and the config is in `/etc/newsyslog.d/`.

Create `xvfb.conf`:

    sudo vim /etc/newsyslog.d/xvfb.conf

Add these contents:

    # logfilename          [owner:group]    mode count size when  flags [/pid_file] [sig_num]
    /var/log/xvfb/xvfb.stderror.log         644  5     5120 *     JN
    /var/log/xvfb/xvfb.stdout.log           644  5     5120 *     JN

These instructions rotate logs when they reached a file size of 5MB. Once
the `xvfb.conf` file is in place, simulate a rotation:

    sudo newsyslog -nvv

#### Export global variable `DISPLAY`

    sudo vim /etc/profile

Add this line to `/etc/profile`:

    export DISPLAY=:1.0

Log out and log back in as biocbuild to confirm $DISPLAY is defined:

    echo $DISPLAY

#### Load the service

    sudo launchctl load /Library/LaunchDaemons/local.xvfb.plist

`xvfb` should appear in the list of loaded services:

    sudo launchctl list | grep xvfb

If a PID is assigned that means the daemon is running. The service is
scheduled to start on boot so at this point there probably is no PID
assigned (service is loaded but not started).

#### Test starting/stopping the service

NOTE: For testing, set `KeepAlive` to `false` in
`/Library/LaunchDaemons/local.xvfb.plist`. Once testing is done,
reset the key to `true`.

The `RunAtLoad` directive in `/Library/LaunchDaemons/local.xvfb.plist`
says to start the service at boot. To test the service without a re-boot
use the `start` and `stop` commands with the service label.

    sudo launchctl start local.xvfb

Check the service has started with either of these commands:

    sudo launchctl list | grep xvfb
    ps aux | grep -v grep | grep Xvfb

Stop the service:

    sudo launchctl stop local.xvfb

If you have problems starting the service set the log level to debug
and check (or tail) the log file:

    sudo launchctl log level debug
    sudo tail -f /var/log/xvfb/xvfb.stderror.log &

Try to start the job again:

    sudo launchctl start local.xvfb

#### Reboot

Reboot the server and confirm the service came up:

    ps aux | grep -v grep | grep Xvfb

#### Kill the process

When `KeepAlive` is set to 'true' in `/Library/LaunchDaemons/local.xvfb.plist`,
the service will be restarted if killed with:

    sudo kill -9 <PID>

If you really need to kill the service, change `KeepAlive` to `false`
in the plist file, then kill the process.

#### Test

    sudo launchctl list | grep xvfb                     # should be running
    echo $DISPLAY                                       # :1.0
    /path/to/Rscript -e 'png(tempfile(), type="Xlib")'  # no more error!


### 2.6 Install Apple's Command Line Tools

You only need this for the `ld`, `make`, and `clang` commands. Check whether
you already have them or not with:

    which ld       # /usr/bin/ld
    ld -v          # BUILD 20:07:01 Nov 7 2022
    which make     # /usr/bin/make
    make -v        # GNU Make 3.81
    which clang    # /usr/bin/clang
    clang -v       # Apple clang version 14.0.0 (clang-1400.0.29.202)
    which git      # /usr/bin/git
    git --version  # git version 2.37.1 (Apple Git-137.1)

If you do, skip this section.

--------------------------------------------------------------------------
The Command Line Tools for Xcode is a subset of Xcode that includes Apple
LLVM compiler (with Clang front-end), linker, Make, and other developer
tools that enable Unix-style development at the command line. It's all
that is needed to install/compile R packages with native code in them (note
that it even includes the `svn` and `git` clients, and the most recent
versions include `python3`).

The full Xcode IDE is much bigger (e.g. 10.8 GB for Xcode 12.3 vs 431MB
for the Command Line Tools for Xcode 12.3) and is not needed.

Go on https://developer.apple.com/ and pick up the last version for
macOS Monterey (`Command_Line_Tools_for_Xcode_14.dmg` as of April 12, 2023).
More recent versions of Xcode and the Command Line Tools are provided
as `xip` files.

If you got a `dmg` file, install with:

    sudo hdiutil attach Command_Line_Tools_for_Xcode_14.dmg
    sudo installer -pkg "/Volumes/Command Line Developer Tools/Command Line Tools.pkg" -target /
    sudo hdiutil detach "/Volumes/Command Line Developer Tools"

If you got an `xip` file, install with:

    ## Check the file first:
    pkgutil --verbose --check-signature path/to/xip

    ## Install in /Applications
    cd /Applications
    xip --expand path/to/xip

    ## Agree to the license:
    sudo xcodebuild -license

TESTING:

    which make   # /usr/bin/make
    which clang  # /usr/bin/clang
    clang -v     # Apple clang version 14.0.0 (clang-1400.0.29.202)
--------------------------------------------------------------------------


### 2.7 Install Minimum Supported SDK

As of April 2023, MacOSX11 is the minimum supported OS by CRAN, so Bioconductor
should also build packages for this operating system. If the latest SDK for
MacOSX11 is not in `/Library/Developer/CommandLineTools/SDKs`, download and
install:

    cd ~/Download
    curl -LO https://mac.r-project.org/sdk/MacOSX11.3.sdk.tar.xz
    sudo tar -zf MacOSX11.3.sdk.tar.xz -C /Library/Developer/CommandLineTools/SDKs

Make a symlink to the major version:

    cd https://mac.r-project.org/sdk/MacOSX11.3.sdk.tar.xz
    sudo ln -s /Library/Developer/CommandLineTools/SDKs/MacOSX11.3.sdk MacOSX11.sdk

To build for the minimum version, add the following to `/etc/profile`:

    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX11.sdk
    export MACOSX_DEPLOYMENT_TARGET=11.0


### 2.8 Install gfortran

Simon uses the universal binary available at
https://github.com/R-macos/gcc-12-branch/releases/tag/12.2-darwin-r0.

Download with:

    cd /Users/biocbuild/Downloads
    curl -LO https://github.com/R-macos/gcc-12-branch/releases/download/12.2-darwin-r0/gfortran-12.2-darwin20-r0-universal.tar.xz

Install with:

    sudo tar -xf gfortran-12.2-darwin20-r0-universal.tar.xz -C /

Make sure /opt/gfortran/SDK points to the minimum required SDKROOT. By default,
it will point to `/Library/Developer/CommandLineTools/SDKs/MacOS11.sdk`:

    ln -sfn /Library/Developer/CommandLineTools/SDKs/MacOSX11.sdk /opt/gfortran/SDK

TESTING:

    gfortran --version  # GNU Fortran (GCC) 12.2.0

Finally check that the gfortran libraries got installed in
`/Library/Frameworks/R.framework/Resources/lib` and make sure that
`LOCAL_FORTRAN_DYLIB_DIR` in `BBS/utils/macosx-inst-pkg.sh` points to this
location.  Otherwise  we will produce broken binaries again (see
https://support.bioconductor.org/p/95587/#95631).


### 2.9 Install Simon's Binaries

We use binaries available at https://mac.r-project.org/bin, which are referred
to as "Simon's Binaries." They should be preferred over installing via Homebrew.
See IMPORTANT NOTE in the _Install Homebrew_ section above. Also make sure to
fix `/usr/local/` permissions as described in the _Install Homebrew_ section if
Simon's binary gets extracted there (normally the case for the
`darwin20/x86_64` binaries).

You will need to `sudo R` to allow the binaries to be installed.

Following instructions at https://mac.r-project.org/bin

    source("https://mac.R-project.org/bin/install.R")

Install necessary packages:

    pkgs <- c("fftw",                               # CRAN ffw, ffwtools, PoissonBinomial, qqconf
              "fribidi",                            # CRAN ragg, textshaping
              "gsl",                                # BioC GLAD
              "glpk",                               # BioC MMUPHin
              "hdf5",                               # CRAN ncdf4 for Bioc mzR
              "harfbuzz",                           # CRAN ragg, textshaping
              "netcdf",                             # CRAN ncdf4 for Bioc mzR
              "openssl",
              "pkgconfig",
              "pcre2",                              # CRAN rJava
              "proj",                               # CRAN proj4
              "protobuf",                           # CRAN protolib
              "udunits",                            # CRAN lwgeom, sf, units
              "xz")
    install.libs(pkgs)

For openssl, in `/etc/profile` if x86_64:

- Append `/opt/R/x86_64/bin` to `PATH`.

- Add `/opt/R/x86_64/lib/pkgconfig` to `PKG_CONFIG_PATH`.

- Add the following line
    ```
    export OPENSSL_LIBS="/opt/R/x86_64/lib/libssl.a /opt/R/x86_64/lib/libcrypto.a"
    ```
For arm64:

- Append `/opt/R/arm64/bin` to `PATH`.

- Add `/opt/R/arm64/lib/pkgconfig` to `PKG_CONFIG_PATH`.

- Add the following line
    ```
    export OPENSSL_LIBS="/opt/R/arm64/lib/libssl.a /opt/R/arm64/lib/libcrypto.a"
    ```

This will trigger statically linking of the **rtracklayer** package against
the openssl libraries.

Fix `/usr/local/` permissions if Simon's binary gets extracted there (normally
the case for the `darwin17/x86_64` binaries).

    # Fix /usr/local/ permissions:
    sudo chown -R biocbuild:admin /usr/local/*
    sudo chown -R root:wheel /usr/local/texlive

TESTING: Check pkg-config (possibly needed for open-babel)

    which pkg-config # /opt/R/x86_64/bin/pkg-config or /opt/R/arm64/bin/pkg-config
    pkg-config --list-all


TESTING: Try to install the **GLAD** package *from source* for GSL

    library(BiocManager)
    BiocManager::install("GLAD", type="source")

TESTING: Try to install **MMUPHin** package *from source* for BioC GLPK

Note: You may need to reinstall `igraph`.

TESTING: The **MMUPHin** package uses `igraph::cluster_optimal()` internally
which requires GLPK:

    library(igraph)
    cluster_optimal(make_graph("Zachary"))

If GLPK is not available, one gets:

    Error in cluster_optimal(make_graph("Zachary")) :
      At optimal_modularity.c:84 : GLPK is not available, Unimplemented function call

TESTING: Try to install the **ncdf4** package *from source*:

    install.packages("ncdf4", type="source", repos="https://cran.r-project.org")

If you have time, you can also try to install the **mzR** package but be aware
that this takes much longer:

    library(BiocManager)
    BiocManager::install("mzR", type="source")  # takes between 7-10 min


### 2.10 Install Homebrew

IMPORTANT NOTE: We use Homebrew to install some of the libraries and other
tools required by the Bioconductor daily builds. However, if those libraries
or tools are available as precompiled binaries in the `darwin20/x86_64`
or `darwin20/arm64` folders at https://mac.r-project.org/bin/, then they
should be preferred over an installation via Homebrew. We refer to those
binaries as Simon's binaries. They are used on the CRAN build machines.
They've been well-tested and are very stable. They're safer than installing
via Homebrew, which is known to sometimes cause problems. For all these
reasons, **Simon's binaries are preferred over Homebrew installs or any other
installs**.

First make sure `/usr/local` is writable by the `biocbuild` user and other
members of the `admin` group:

    # Fix /usr/local/ permissions:
    sudo chown -R biocbuild:admin /usr/local/*
    sudo chown -R root:wheel /usr/local/texlive

Then install with:

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

TESTING:

    brew doctor


### 2.11 Set `RETICULATE_PYTHON` and install Python 3 modules

#### Set `RETICULATE_PYTHON` in `/etc/profile`

We need to make sure that, by default, the **reticulate** package will
use the system-wide Python interpreter that is in the `PATH`.

In the terminal, execute

    which python3

This is the reticulate path that must be set in `/etc/profile`. For example, if
the output of `which python3` is `/usr/bin/python3` then in `/etc/profile`
add

    export RETICULATE_PYTHON="/usr/bin/python3"  # same as 'which python3'

Logout and login again for the changes to `/etc/profile` to take effect.

Note: If `brew` is used to install Bioconductor package dependencies, some
brew formulas install another version of Python as a dependency, which can take
precedence over the default system-wide Python interpreter. If the brewed
Python must be kept, it can be `unlink`ed to prevent it from taking precedence
with `brew unlink <formula>`. Otherwise, the brewed Python can be removed with
`brew uninstall --ignore-dependencies <formula>` and its dependencies can be
cleaned up with `brew autoremove`.

TESTING: If R is already installed on the machine, start it, and do:

    if (!require(reticulate))
        install.packages("reticulate", repos="https://cran.r-project.org")
    ## py_config() should display the path to the system-wide Python
    ## interpreter returned by the 'which python3' command above.
    ## It should also display this note:
    ##   NOTE: Python version was forced by RETICULATE_PYTHON
    py_config()

#### Install Python 3 modules needed by BBS

`BBS_UBUNTU_PATH` must be the path to `BBS/Ubuntu-files/22.04`.

    sudo -H pip3 install -r $BBS_UBUNTU_PATH/pip_bbs.txt

#### Install Python modules required by Single Package Builder

    sudo -H pip3 install -r $BBS_UBUNTU_PATH/pip_spb.txt

#### Install Python modules required by CRAN/Bioconductor packages

    sudo -H pip3 install -r $BBS_UBUNTU_PATH/pip_pkgs.txt

Optionally, install all of the above with

    python3 -m pip install $(cat $BBS_UBUNTU_PATH/pip_*.txt | awk '/^[^#]/ {print $1}')

Note: it's ok if jupyter lab is not installed but everything else should be.

TESTING:

- `jupyter --version` should display something like this:
    ```
    merida1:~ biocbuild$ jupyter --version
    jupyter core     : 4.6.3
    jupyter-notebook : 6.1.4
    qtconsole        : 4.7.7
    ipython          : 7.19.0
    ipykernel        : 5.3.4
    jupyter client   : 6.1.7
    jupyter lab      : not installed
    nbconvert        : 6.0.7
    ipywidgets       : 7.5.1
    nbformat         : 5.0.8
    traitlets        : 5.0.5
    ```

- Start python3 and try to import the above modules. Quit.

- Try to build the **BiocSklearn** package (takes < 1 min):
    ```
    cd ~/bbs-3.19-bioc/meat/
    R CMD build BiocSklearn
    ```
    and the destiny package:
    ```
    R CMD build destiny
    ```


### 2.12 Install MacTeX

Home page: https://www.tug.org/mactex/

Download:

    https://mirror.ctan.org/systems/mac/mactex/MacTeX.pkg

As of October 2023 the above page is displaying "Downloading MacTeX 2023".

    cd /Users/biocbuild/Downloads
    curl -LO https://mirror.ctan.org/systems/mac/mactex/MacTeX.pkg

Install with:

    sudo installer -pkg MacTeX.pkg -target /
    
    # Fix /usr/local/ permissions:
    sudo chown -R biocbuild:admin /usr/local/*
    sudo chown -R root:wheel /usr/local/texlive

TESTING: Logout and login again so that the changes made by the installer
to the `PATH` take effect. Then:

    which tex


### 2.13 Install Pandoc

#### x86_64

Install Pandoc 2.7.3 instead of the latest Pandoc (2.9.2.1 as of April 2020).
The latter breaks `R CMD build` for 8 Bioconductor software packages
(**FELLA**, **flowPloidy**, **MACPET**, **profileScoreDist**, **projectR**,
**swfdr**, and **TVTB**) with the following error:

    ! LaTeX Error: Environment cslreferences undefined.

Download with:

    curl -LO https://github.com/jgm/pandoc/releases/download/2.7.3/pandoc-2.7.3-macOS.pkg > /Users/biocbuild/Downloads/pandoc.pkg

#### arm64

Earlier releases are not available for arm64, so the latest version of pandoc
should be installed.

Download

    curl -LO https://github.com/jgm/pandoc/releases/download/3.1.8/pandoc-3.1.8-arm64-macOS.pkg > /Users/biocbuild/Downloads/pandoc.pkg

#### For all macs

Install with:

    sudo installer -pkg pandoc.pkg -target /
    
    # Fix /usr/local/ permissions:
    sudo chown -R biocbuild:admin /usr/local/*
    sudo chown -R root:wheel /usr/local/texlive


### 2.14 Install pstree

These are just convenient to have when working interactively on a build
machine but are not required by the daily builds or propagation pipe.

Install with:

    brew install pstree


### 2.15 Replace `/etc/ssl/cert.pm` with CA bundle if necessary

#### curl: (60) SSL certificate problem: certificate has expired

To test for the issue, curl a URL. The output should state that the
certificate has expired. For example

    merida1:~ biocbuild$ curl https://stat.ethz.ch/
    curl: (60) SSL certificate problem: certificate has expired
    More details here: https://curl.haxx.se/docs/sslcerts.html
    
    curl performs SSL certificate verification by default, using a "bundle"
     of Certificate Authority (CA) public keys (CA certs). If the default
     bundle file isn't adequate, you can specify an alternate file
     using the --cacert option.
    If this HTTPS server uses a certificate signed by a CA represented in
     the bundle, the certificate verification probably failed due to a
     problem with the certificate (it might be expired, or the name might
     not match the domain name in the URL).
    If you'd like to turn off curl's verification of the certificate, use
     the -k (or --insecure) option.
    HTTPS-proxy has similar options --proxy-cacert and --proxy-insecure.

#### Install a new CA bundle

First move and rename the old cert.pem. For example

    mv  /etc/ssl/cert.pem /etc/ssl/certs/cert.pem.org

Then go to https://curl.haxx.se/docs/sslcerts.html and find the link to the
CA bundle generated by Mozilla. You can

    sudo curl --insecure https://curl.se/ca/cacert.pem -o /etc/ssl/cert.pem

TESTING

    merida1:~ biocbuild$ curl https://stat.ethz.ch/

It should not produce any output that the certificate has expired.



## 3. Set up the Bioconductor software builds

Everything in this section must be done **from the biocbuild account**.


### 3.1 Check connectivity with central builder

#### Check that you can ping the central builder

Depending on whether the node you're ping'ing from is within RPCI's DMZ
or not, use the central builder's short or long (i.e. hostname+domain)
hostname. For example:

    ping nebbiolo1                                  # from within RPCI's DMZ
    ping nebbiolo1.bioconductor.org                 # from anywhere else

#### Install biocbuild RSA private key

Add `~/.BBS/id_rsa` to the biocbuild home (copy `id_rsa` from another build
machine). Then `chmod 400 ~/.BBS/id_rsa` so permissions look like this:

    merida1:~ biocbuild$ ls -l .BBS/id_rsa
    -r--------  1 biocbuild  staff  884 Jan 12 12:19 .BBS/id_rsa

#### Check that you can ssh to the central build node

    ssh -i ~/.BBS/id_rsa nebbiolo1                   # from within DFCI's DMZ

#### Check that you can send HTTPS requests to the central node

    curl http://nebbiolo1                           # from within DFCI's DMZ

More details on https implementation in `BBS/README.md`.


### 3.2 Clone BBS git tree and create bbs-x.y-bioc directory structure

Must be done from the biocbuild account.

#### Clone BBS git tree

    cd
    git clone https://github.com/bioconductor/BBS

#### Compile `chown-rootadmin.c`

    cd ~/BBS/utils/
    gcc chown-rootadmin.c -o chown-rootadmin
    sudo chown root:admin chown-rootadmin
    sudo chmod 4750 chown-rootadmin

TESTING: Check that the permissions on the `chown-rootadmin` executable
look like this:

    merida1:utils biocbuild$ ls -al chown-rootadmin
    -rwsr-x---  1 root  admin  8596 Jan 13 12:55 chown-rootadmin

#### Create bbs-x.y-bioc directory structure

    mkdir -p bbs-3.19-bioc/log


### 3.3 Install R

Must be done from the `biocbuild` account.

#### Choose latest R binary for macOS

If installing R devel: download R from https://mac.r-project.org/ (e.g.
pick up `R-4.0-branch.pkg`). Unlike the installer image (`.pkg` file),
the tarball (`.tar.gz` file) does NOT include Tcl/Tk (which is needed
by R base package **tcltk**) so make sure to grab the former.

If installing R release: download R from CRAN (e.g. from
https://cloud.r-project.org/bin/macosx/). Make sure to pick the installer, not
the source tarball, as the former contains Tcl/Tk libraries that will install
in `/usr/local`.

#### Download and install

Remove the previous R installation:

    cd /Library/Frameworks/
    sudo rm -rf R.framework

For example, if installing for x86_64 mac, download and install with:

    cd /Users/biocbuild/Downloads
    curl -O https://mac.r-project.org/big-sur-x86_64/R-devel/R-devel-x86_64.pkg
    sudo installer -pkg R-4.4-x86_64.pkg -target /

Note that, unlike what we do on the Linux and Windows builders, this is a
*system-wide* installation of R i.e. it's in the `PATH` for all users on the
machine so can be started with `R` from anywhere.

#### Basic testing

Start R, check the version displayed by the startup message, then:

    # --- check capabilities ---

    capabilities()  # all should be TRUE
    X11()           # nothing visible should happen
    dev.off()

    # --- install rgl and try to load it ---
    install.packages("rgl", repos="https://cran.r-project.org")
    library(rgl)

If `library(rgl)` fails with an error like:

    Error: package or namespace load failed for ‘rgl’:
     .onLoad failed in loadNamespace() for 'rgl', details:
      call: grDevices::quartz()
      error: unable to create quartz() device target, given type may not be supported
    In addition: Warning message:
    In grDevices::quartz() : No displays are available

then add `export RGL_USE_NULL=TRUE` to `/etc/profile`, logout and login
again (so that the change takes effect), and try `library(rgl)` again.

    # --- install a few CRAN packages *from source* ---

    # Contains C++ code:
    install.packages("Rcpp", type="source", repos="https://cran.r-project.org")
    # Contains Fortran code:
    install.packages("minqa", type="source", repos="https://cran.r-project.org")
    # Only if CRAN doesn't provide the binary for macOS yet:
    install.packages("Cairo", type="source", repos="https://cran.r-project.org")

#### Install BiocManager + BiocCheck

From R:

    install.packages("BiocManager", repos="https://cran.r-project.org")

    library(BiocManager)  # This displays the version of Bioconductor
                          # that BiocManager is pointing at.

    ## IMPORTANT: Switch to "devel" **ONLY** if you are installing R for
    ## the devel builds and if BioC devel uses the same version of R as
    ## BioC release!
    BiocManager::install(version="devel")

    BiocManager::install("BiocCheck")  # required by SPB

If some CRAN packages failed to compile, see _What if CRAN doesn't provide
package binaries for macOS yet?_ subsection below.

#### [OPTIONAL] More testing

From R:

    # Always good to have; try this even if CRAN binaries are not available:
    install.packages("devtools", repos="https://cran.r-project.org")
    BiocManager::install("BiocStyle")

    BiocManager::install("rtracklayer")
    BiocManager::install("VariantAnnotation")
    BiocManager::install("rhdf5")

Quit R and check that rtracklayer got statically linked against the openssl
libraries with:

    otool -L /Library/Frameworks/R.framework/Resources/library/rtracklayer/libs/rtracklayer.so

#### Configure R to use the Java installed on the machine

    sudo R CMD javareconf

TESTING: See "Install Java" below in this file for how to test Java/rJava.

#### Flush the data caches

When R is updated, it's a good time to flush the cache for AnnotationHub,
ExperimentHub, and BiocFileCache. This is done by removing the corresponding
folders present in `~/Library/Caches/`. For example, basilisk's cache is at
`~/Library/Caches/org.R-project.R/R/basilisk`.

Removing these folders means all packages using these resources will have
to re-download the files. This ensures that resources are still available.
However it also contributes to an increased runtime for the builds.

Should we also remove package specific caches?

#### What if CRAN doesn't provide package binaries for macOS yet?

If the builds are using R-devel and CRAN doesn't provide package binaries
for Mac yet, install the following package binaries (these are the
Bioconductor deps that are "difficult" to compile from source on Mac,
as of Oct 2023):

    difficult_pkgs <- c("archive", "arrangements", "av", "fftw", "fftwtools",
          "gdtools", "gert", "ggiraph", "git2r", "glpkAPI", "gmp", "gsl",
          "hdf5r", "igraph", "jpeg", "lwgeom", "magick", "ncdf4", "pbdZMQ",
          "pdftools", "PoissonBinomial", "proj4", "protolite", "qqconf",
          "ragg", "RcppAlgos", "redux", "rJava", "RMariaDB", "Rmpfr", "RMySQL",
          "RPostgres", "rsvg", "sf", "showtext", "svglite", "sysfonts",
          "terra", "textshaping", "tiff", "units", "vdiffr", "V8", "XML",
          "xml2")

First try to install with:

    install.packages(setdiff(difficult_pkgs, rownames(installed.packages())), repos="https://cran.r-project.org")

It should fail for most (if not all) packages. However, it's still worth
doing it as it will be able to install many dependencies from source.
Then try to install the binaries built with the current R release:

    ## Replace 'x86_64' with 'arm64' if on arm64 Mac:
    contriburl <- "https://cran.r-project.org/bin/macosx/big-sur-x86_64/contrib/4.3"
    install.packages(setdiff(difficult_pkgs, rownames(installed.packages())), contriburl=contriburl)

NOTES:

- The binaries built for a previous version of R are not guaranteed to work
  with R-devel but if they can be loaded then it's **very** likely that they
  will. So make sure they can be loaded:
    ```
    for (pkg in difficult_pkgs) library(pkg, character.only=TRUE)
    ```

- Most binary packages in `difficult_pkgs` (e.g. **XML**, **rJava**, etc)
  contain a shared object (e.g. `libs/XML.so`) that is linked to `libR.dylib`
  via an absolute path that is specific to the version of R that was used
  when the object was compiled/linked e.g.
    ```
    /Library/Frameworks/R.framework/Versions/4.3/Resources/lib/libR.dylib
    ```
  So loading them in a different version of R (e.g. R 4.4) will fail with
  an error like this:
    ```
    > library(XML)
    Error: package or namespace load failed for ‘XML’:
     .onLoad failed in loadNamespace() for 'XML', details:
      call: dyn.load(file, DLLpath = DLLpath, ...)
      error: unable to load shared object '/Library/Frameworks/R.framework/Versions/4.4/Resources/library/XML/libs/XML.so':
      dlopen(/Library/Frameworks/R.framework/Versions/4.4/Resources/library/XML/libs/XML.so, 6): Library not loaded: /Library/Frameworks/R.framework/Versions/4.4/Resources/lib/libR.dylib
      Referenced from: /Library/Frameworks/R.framework/Versions/4.4/Resources/library/XML/libs/XML.so
      Reason: image not found
    ```
  However, they can easily be tricked by creating a symlink. Note that in R 4.3,
  paths became suffixed with `-x86_64`:
    ```
    cd /Library/Frameworks/R.framework/Versions
    ln -s 4.3-x86_64 4.3
    ```

- Do NOT install the Cairo binary built for a previous version of R (hopefully
  you'll manage to install it from source). Even though it can be loaded,
  it's most likely to not work properly e.g. it might produce errors like
  this:
    ```
    library(Cairo)
    Cairo(600, 600, file="plot.png", type="png", bg="white")
    # Error in Cairo(600, 600, file = "plot.png", type = "png", bg = "white") : 
    #   Graphics API version mismatch
    ```

- Try:
    ```
    library(ragg)
    agg_capture()

    library(ggplot2)
    ggsave("test.png")
    ```
  If these fail with a "Graphics API version mismatch" error, then it
  means that the **ragg** binary package (which was built with a previous
  version of R) is incompatible with this new version of R (current R
  devel in our case). In this case ragg needs to be installed from source:
    ```
    install.packages("ragg", type="source", repos="https://cran.r-project.org")
    ```
  Note that installing ragg from source requires the libwebp, JPEG, and TIFF
  system libraries. See "Additional stuff not needed in normal times" above in
  this file for how to do this.

- Test GLPK available:

    ```
    library(igraph)
    cluster_optimal(make_graph("Zachary"))
    ```
  Produces
    ```
    Error in cluster_optimal(make_graph("Zachary")) :
      At optimal_modularity.c:84 : GLPK is not available, Unimplemented function call
    ```


### 3.4 Add software builds to biocbuild's crontab

Must be done from the biocbuild account.

Add the following entry to biocbuild crontab:

    00 15 * * 0-5 /bin/bash --login -c 'cd /Users/biocbuild/BBS/3.19/bioc/`hostname -s` && ./run.sh >>/Users/biocbuild/bbs-3.19-bioc/log/`hostname -s`-`date +\%Y\%m\%d`-run.log 2>&1'

Now you can proceed to the next section or wait for a complete build run
before doing so.


### 3.5 Alternatively run builds with Python3

If the build on an Apple Silicon runs slow when being kicked off by a cronjob,
it may be due to a low effective Quality of Service (QoS) clamp, which is the
lower bound of QoS. If the QoS is "utility", efficiency processers will be used.
We can get around this by kicking a script manually, which will give us an
"unspecified" QoS clamp, which is slightly higher so that performance cores
will be engaged.

Use `utils/build.py` to run the build with Python3 in a `screen`. It will
produce a log at `LOG_PATH`.

    python3 -m venv env
    source env/bin/active
    pip3 install schedule pytz
    python3 BBS/utils/build.py

See https://github.com/Bioconductor/BBS/issues/387 for details troubleshooting
on kjohnson3.


## 4. Install additional stuff for Bioconductor packages with special needs


Everything in this section must be done **from the biocbuild account**.


### 4.1 Install Java

Go to https://jdk.java.net/ and follow the link to the latest JDK. Then
download the tarball for your specific mac (e.g. `openjdk-21_macos-x64_bin.tar.gz`
for x86_64 or `openjdk-21_macos-aarch64_bin.tar.gz` for arm64) to `/Users/biocbuild/Downloads`.

Install with:

    cd /usr/local/
    sudo tar zxvf /Users/biocbuild/Downloads/openjdk-21_macos-x64_bin.tar.gz
    
    # Fix /usr/local/ permissions:
    sudo chown -R biocbuild:admin /usr/local/*
    sudo chown -R root:wheel /usr/local/texlive

Then:

    cd /usr/local/bin/
    ln -s ../jdk-21.jdk/Contents/Home/bin/java
    ln -s ../jdk-21.jdk/Contents/Home/bin/javac
    ln -s ../jdk-21.jdk/Contents/Home/bin/jar

In `/etc/profile` add the following line:

    export JAVA_HOME=/usr/local/jdk-21.jdk/Contents/Home

TESTING: Logout and login again so that the changes to `/etc/profile` take
effect. Then:

    java --version
    # openjdk 21 2023-09-19
    # OpenJDK Runtime Environment (build 21+35-2513)
    # OpenJDK 64-Bit Server VM (build 21+35-2513, mixed mode, sharing)

    javac --version
    # javac 21

Finally reconfigure R to use this new Java installation:

    sudo R CMD javareconf

TESTING: Try to install the **rJava** package:

    # install the CRAN binary
    install.packages("rJava", repos="https://cran.r-project.org")
    library(rJava)
    .jinit()
    .jcall("java/lang/System", "S", "getProperty", "java.runtime.version")
    # [1] "21+35-2513"


### 4.2 Install JAGS

Download with:

    cd /Users/biocbuild/Downloads
    curl -LO https://sourceforge.net/projects/mcmc-jags/files/JAGS/4.x/Mac%20OS%20X/JAGS-4.3.0.dmg

Install with:

    sudo hdiutil attach JAGS-4.3.0.dmg
    sudo installer -pkg /Volumes/JAGS-4.3.0/JAGS-4.3.0.mpkg -target /
    sudo hdiutil detach /Volumes/JAGS-4.3.0
    
    # Fix /usr/local/ permissions:
    sudo chown -R biocbuild:admin /usr/local/*
    sudo chown -R root:wheel /usr/local/texlive

TESTING: Try to install the **rjags** package *from source*:

    install.packages("rjags", type="source", repos="https://cran.r-project.org")


### 4.3 Install CMake

Needed for CRAN package **nloptr**, which is used by a few Bioconductor
packages.

Home page: https://cmake.org/

Let's make sure it's not already installed:

    which cmake

Note that installing CMake via Homebrew (`brew install cmake`) should be
avoided. In our experience, even though it leads to a `cmake` command that
works at the beginning, it might break in the future (and it has in our case)
as we install more and more components to the machine. So, if for any reason
you already have a brewed CMake on the machine, make sure to remove it:

    brew uninstall cmake

Then:

    cd /Users/biocbuild/Downloads
    curl -LO https://github.com/Kitware/CMake/releases/download/v3.23.0/cmake-3.23.0-macos-universal.dmg
    sudo hdiutil attach cmake-3.23.0-macos-universal.dmg
    cp -ri /Volumes/cmake-3.23.0-macos-universal/CMake.app /Applications/
    sudo hdiutil detach /Volumes/cmake-3.23.0-macos-universal

Then in `/etc/profile` *prepend* `/Applications/CMake.app/Contents/bin`
to `PATH`, or, if the file as not line setting `PATH` already, add the
following line:

    export PATH="/Applications/CMake.app/Contents/bin:$PATH"

TESTING: Logout and login again so that the changes to `/etc/profile` take
effect. Then:

    which cmake
    cmake --version


### 4.4 Install Open Babel

TODO: Modify instructions for arm64

The **ChemmineOB** package requires Open Babel 3. Note that the Open Babel
website seems very outdated:

    http://openbabel.org/

The latest news reported in the News feed is from 2016-09-21 (as of
Oct 23rd, 2020) and it announces the release of Open Babel 2.4.0!
However, there seems to be a version 3.0. It's on GitHub:
https://github.com/openbabel/openbabel

Before anything else, do:

    python3 --version

and record the current version of Python 3. This is the version that
we installed earlier with all the modules required for the builds.
This is our primary Python 3 installation.

The brew formulae (`3.1.1_1` as of Oct 23rd, 2020) will install a bunch
of dependencies e.g. `python@3.9`, `glib`, `cairo`, `eigen`, and possibly
many more (e.g. `libpng`, `freetype`, `fontconfig`, `gettext`, `libffi`,
`pcre`, `lzo`, `sqlite`, `pixman`) depending on what's already installed:

    brew install eigen
    brew install open-babel

If another Python 3 was already installed via `brew` (e.g. `python@3.8`),
then `python@3.9` will get installed as keg-only because it's an alternate
version of another formulae. This means it doesn't get put on the `PATH`.
Check this with:

    python3 --version

Hopefully this will still display the version of our primary Python 3
installation.

IMPORTANT NOTE: The automatic installation of `libpng` triggered by
`brew install open-babel` can break `pkg-config` and some other things
like Python 3 module `h5pyd`:

    pkg-config
    # dyld: Symbol not found: __cg_png_create_info_struct
    #   Referenced from: /System/Library/Frameworks/ImageIO.framework/Versions/A/ImageIO
    #   Expected in: /usr/local/lib/libPng.dylib
    #  in /System/Library/Frameworks/ImageIO.framework/Versions/A/ImageIO
    # Abort trap: 6

    python3
    # Python 3.8.6 (default, Oct 27 2020, 08:56:44) 
    # [Clang 11.0.0 (clang-1100.0.33.17)] on darwin
    # Type "help", "copyright", "credits" or "license" for more information.
    >>> import h5pyd
    # Traceback (most recent call last):
    # ...
    # from _scproxy import _get_proxy_settings, _get_proxies
    # ImportError: dlopen(/usr/local/Cellar/python@3.8/3.8.6_1/Frameworks/Python.framework/Versions/3.8/lib/python3.8/lib-dynload/_scproxy.cpython-38-darwin.so, 2): Symbol not found: __cg_png_create_info_struct
    #   Referenced from: /System/Library/Frameworks/ImageIO.framework/Versions/A/ImageIO
    #   Expected in: /usr/local/lib/libPng.dylib
    #  in /System/Library/Frameworks/ImageIO.framework/Versions/A/ImageIO

This will happen if `DYLD_LIBRARY_PATH` is set to `/usr/local/lib` so make
sure that this is not the case. Note that we used to need this setting for
Bioconductor package **rsbml** but luckily not anymore (**rsbml** is no longer
supported on macOS).

Initial testing:

    which obabel  # /usr/local/bin/obabel
    obabel -V
    # dyld: Library not loaded: /usr/local/opt/boost/lib/libboost_iostreams-mt.dylib
    #   Referenced from: /usr/local/bin/obabel
    #   Reason: image not found
    # Abort trap: 6

This suggests that the current `3.1.1_1` formulae is buggy (it doesn't
properly specify its dependencies).

Install `boost` (this will install `icu4c` if not already installed):

    brew install boost

Find the Cellar:

    brew --Cellar # /opt/homebrew/Cellar for arm64, /usr/local/Cellar on x86_64

Create the following symlink to the Cellar:

    cd /usr/local/lib
    # x86_64
    ln -s ../Cellar/open-babel/3.1.1_1/lib openbabel3
    # arm64
    ln -s /opt/homebrew/Cellar/open-babel/3.1.1_1/lib openbabel3

Add the directory containing `openbabel.pc` to `PKG_CONFIG_PATH`:

    export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/openbabel3/pkgconfig

TESTING:

    obabel -V
    # Open Babel 3.1.0 -- Oct 21 2020 -- 21:57:42  # version looks wrong!
    
    pkg-config --cflags openbabel-3
    # -I/usr/local/Cellar/open-babel/3.1.1_1/include/openbabel3     # x86_64
    # -I/opt/homebrew/Cellar/open-babel/3.1.1_1/include/openbabel3  # arm64
    
    pkg-config --libs openbabel-3
    # -L/usr/local/Cellar/open-babel/3.1.1_1/lib -lopenbabel        # x86_64
    # -L/opt/homebrew/Cellar/open-babel/3.1.1_1/lib -lopenbabel     # arm64

Then try to install ChemmineOB from source. From R:

    library(BiocManager)
    BiocManager::install("ChemmineOB", type="source")


### 4.5 Install the MySQL client

Note that we only need this for the **ensemblVEP** package. **RMySQL**
doesn't need it as long as we can install the binary package.

Even though we only need the MySQL client, we used to install the MySQL
Community Server because it was an easy way to get the MySQL client.
Not anymore! Our attempt to use the recent binaries available at
https://dev.mysql.com/downloads/ for macOS Monterey gave us too much
headache when trying to install Perl module DBD::mysql or install RMySQL
from source. So we switched to installing the MySQL client only via brew:

    brew install mysql-client

Then in `/etc/profile` append `/usr/local/opt/mysql-client/bin` to `PATH`
and `/usr/local/opt/mysql-client/lib/pkgconfig` to `PKG_CONFIG_PATH`.

Finally, make sure that you have a brewed `openssl` (`brew install openssl`,
see above in this file) and create the following symlinks (without them
`sudo cpan install DBD::mysql` won't be able to find the `ssl` or `crypto`
libraries and will fail):

    cd /usr/local/opt/mysql-client/lib/
    ln -s /usr/local/opt/openssl/lib/libssl.dylib
    ln -s /usr/local/opt/openssl/lib/libcrypto.dylib

TESTING: Logout and login again so that the changes to `/etc/profile` take
effect. Then:

    which mysql_config  # /usr/local/opt/mysql-client/bin/mysql_config

Then try to install the **RMySQL** package *from source*:

    library(BiocManager)
    install("RMySQL", type="source")


### 4.6 Install Ensembl VEP script

TODO: Modify instructions for arm64

Required by Bioconductor packages **ensemblVEP** and **MMAPPR2**.

Complete installation instructions are at
https://www.ensembl.org/info/docs/tools/vep/script/vep_download.html

#### Install Perl modules

- Make sure the MySQL client is installed on the system (see "Install
  the MySQL client" above in this file).

- According to ensembl-vep README, the following Perl modules are required:
    ```
    ## Needed by both ensemblVEP and MMAPPR2:
    sudo cpan install Archive::Zip
    sudo cpan install File::Copy::Recursive
    sudo cpan install DBI
    sudo cpan install DBD::mysql  # MySQL client needed!
    
    ## Needed by MMAPPR2 only:
    sudo cpan install -f XML::DOM::XPath  # -f to force install despite tests failing
    sudo cpan install IO::String
    sudo cpan install Bio::SeqFeature::Lite
    brew install htslib
    sudo cpan install Bio::DB::HTS::Tabix
    ```

#### Install ensembl-vep

    cd /usr/local/
    sudo git clone https://github.com/Ensembl/ensembl-vep.git
    cd ensembl-vep/
    sudo chown -R biocbuild:admin .
    #git checkout release/100  # select desired branch

    # Avoid the hassle of getting HTSlib to compile because ensemblVEP and
    # MMAPPR2 pass 'R CMD build' and 'R CMD check' without that and that's
    # all we care about. No sudo!
    perl INSTALL.pl --NO_HTSLIB
    # When asked if you want to install any cache files - say no
    # When asked if you want to install any FASTA files - say no
    # When asked if you want to install any plugins - say no

#### Edit `/etc/profile`

In `/etc/profile` append `/usr/local/ensembl-vep` to `PATH`.
Note that the `/etc/profile` file has read-only permissions (factory
settings). To save changes you will need to force save, e.g., in the
`vi` editor this is `w!`.

Logout and login again so that the changes to `/etc/profile` take effect.

#### Testing

Try to build and check the **ensemblVEP** and **MMAPPR2** packages:

    cd ~/bbs-3.19-bioc/meat/

    R CMD build ensemblVEP
    R CMD check --no-vignettes ensemblVEP_X.Y.Z.tar.gz

    R CMD build MMAPPR2
    R CMD check --no-vignettes MMAPPR2_X.Y.Z.tar.gz


### 4.7 Install ViennaRNA

Required by Bioconductor package **GeneGA**.

Download with:

    cd /Users/biocbuild/Downloads
    curl -O https://www.tbi.univie.ac.at/RNA/download/osx/macosx/ViennaRNA-2.4.11-MacOSX.dmg

Install with:

    sudo hdiutil attach ViennaRNA-2.4.11-MacOSX.dmg
    sudo installer -pkg "/Volumes/ViennaRNA 2.4.11/ViennaRNA Package 2.4.11 Installer.pkg" -target /
    sudo hdiutil detach "/Volumes/ViennaRNA 2.4.11"
    
    # Fix /usr/local/ permissions:
    sudo chown -R biocbuild:admin /usr/local/*
    sudo chown -R root:wheel /usr/local/texlive

TESTING:

    which RNAfold  # /usr/local/bin/RNAfold

Then try to build the **GeneGA** package:

    cd ~/bbs-3.19-bioc/meat/
    R CMD build GeneGA


### 4.8 Set up ImmuneSpaceR package for connecting to ImmuneSpace

Required by Bioconductor package **ImmuneSpaceR**. Get credentials from
Bitwarden.

In `/etc/profile` add:

    export ISR_login=*****
    export ISR_pwd=*****

TESTING: Logout and login again so that the changes to `/etc/profile` take
effect. Then try to build the **ImmuneSpaceR** package:

    cd ~/bbs-3.19-bioc/meat/
    R CMD build ImmuneSpaceR

### 4.9 Install mono

Required by Bioconductor package **rawrr**.

Install with:

    brew install mono

TESTING

    which mono  # /usr/local/bin/mono

Then try to install/build/check the **rawrr** package:

    cd ~/bbs-3.19-bioc/meat/
    R CMD INSTALL rawrr
    R CMD build rawrr
    R CMD check --no-vignettes rawrr_X.Y.Z.tar.gz


### 4.10 Install .NET Runtime

Required by Bioconductor package **rmspc**.

#### Install the runtime

Visit https://docs.microsoft.com/en-us/dotnet/core/install/macos. Download and
install the 6.0 .NET runtime corresponding to the build system's macOS.

##### x86_64

    curl -O https://download.visualstudio.microsoft.com/download/pr/8583970d-ca62-4053-9b25-01c2d2742062/8a5c9a04863a80655f483d67c3725255/dotnet-runtime-6.0.29-osx-x64.pkg

##### arm64

    curl -O https://download.visualstudio.microsoft.com/download/pr/99a222a4-b8fb-4d19-a91a-a69aeaf9ba06/fdd439f0dc45cb1357b03a30e2bc8f98/dotnet-runtime-6.0.29-osx-arm64.pkg

##### For all macs

    shasum -a 512 dotnet.pkg
    sudo installer -pkg dotnet.pkg -target /

#### Testing

You might need to logout and login again before trying this:

    cd ~/bbs-3.19-bioc/meat/
    R CMD build rmspc
    R CMD check --no-vignettes rmspc_X.Y.Z.tar.gz



## 5. Set up other builds


### 5.1 Annotation builds

Not run on Mac at the moment.


### 5.2 Experimental data builds

Not run on Mac at the moment.


### 5.3 Worflows builds

From the biocbuild account:

    mkdir -p ~/bbs-3.19-workflows/log

Then add the following entry to biocbuild's crontab:

    # BIOC 3.19 WORKFLOWS BUILDS
    # --------------------------
    
    00 08 * * 2,5 /bin/bash --login -c 'cd /Users/biocbuild/BBS/3.19/workflows/`hostname -s` && ./run.sh >>/Users/biocbuild/bbs-3.19-workflows/log/`hostname -s`-`date +\%Y\%m\%d`-run.log 2>&1'


### 5.4 Books builds

Not run on Mac at the moment.


### 5.5 Long Tests builds

From the biocbuild account:

    mkdir -p ~/bbs-3.19-bioc-longtests/log

Then add the following entry to biocbuild's crontab:

    # BIOC 3.19 SOFTWARE LONGTESTS BUILDS
    # -----------------------------------
    
    00 08 * * 6 /bin/bash --login -c 'cd /Users/biocbuild/BBS/3.19/bioc-longtests/`hostname -s` && ./run.sh >>/Users/biocbuild/bbs-3.19-bioc-longtests/log/`hostname -s`-`date +\%Y\%m\%d`-run.log 2>&1'

