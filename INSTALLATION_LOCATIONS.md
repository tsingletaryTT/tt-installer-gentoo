# Tenstorrent Installation Locations

This document describes where all Tenstorrent software components are installed by the tt-installer script.

## Quick Reference Table

| Component | Location | Type | Notes |
|-----------|----------|------|-------|
| **tt-metal source** | `~/tt-metal/` | Git clone | **Main development directory** |
| **tt-kmd** | `/lib/modules/$(uname -r)/updates/dkms/` | Kernel module | Via DKMS |
| **tt-smi** | Python site-packages or `~/.local/bin/` | Python CLI tool | Depends on python choice |
| **tt-flash** | Python site-packages or `~/.local/bin/` | Python CLI tool | Depends on python choice |
| **tt-topology** | Python site-packages or `~/.local/bin/` | Python CLI tool | Optional, Depends on python choice |
| **SFPI** | `/usr/local/bin/sfpi` | Binary | Gentoo: built from source |
| **HugePages config** | `/etc/sysctl.d/99-tenstorrent-hugepages.conf` | Config file | Kernel parameters |
| **HugePages mount** | `/dev/hugepages-1G/` | Mount point | 1GB hugepages |
| **tt-metalium wrapper** | `~/.local/bin/tt-metalium` | Shell script | Container wrapper |
| **tt-metalium container** | `~/.local/share/containers/storage/` | Container image | Podman storage |
| **tt-inference-server** | `~/.local/lib/tt-inference-server/` | Git clone | Source code |
| **tt-inference-server wrapper** | `~/.local/bin/tt-inference-server` | Shell script | Convenience wrapper |
| **Installation log** | `/tmp/tenstorrent_install_*/install.log` | Log file | Temporary |

---

## Detailed Component Locations

### 1. TT-Metal Source Code (~/tt-metal)

**Installation Method**: Git clone to user's home directory

**Location**:
```
~/tt-metal/                            # Main development directory
~/tt-metal/.git/                       # Git repository
~/tt-metal/tt_metal/                   # Core framework code
~/tt-metal/models/                     # Model implementations
~/tt-metal/tests/                      # Test suites
~/tt-metal/build/                      # Build artifacts (after building)
```

**What is tt-metal?**

tt-metal (TT-Metalium) is Tenstorrent's complete AI framework. This is the **primary development directory** for working with Tenstorrent hardware. It contains:
- TT-NN (TensorT Neural Network) framework
- Low-level hardware APIs
- Model implementations
- Examples and tutorials
- Build system and tooling

**Ownership**:
- **Critical**: Installed as the actual user (not root), even when using sudo
- This ensures proper permissions for development work
- Automatically updates if already exists (git pull)

**How to verify**:
```bash
# Check if installed
ls -la ~/tt-metal/

# Check ownership (should be your user, not root)
ls -ld ~/tt-metal/

# Check git status
cd ~/tt-metal
git status
git log -1  # See latest commit

# Check which branch
git branch
```

**Working with tt-metal**:
```bash
# Navigate to tt-metal
cd ~/tt-metal

# Pull latest changes
git pull

# Build tt-metal (see README.md for full instructions)
# Build process depends on your hardware and configuration

# Run examples
cd ~/tt-metal/models/demos/
# Follow specific model README instructions
```

**Why ~/tt-metal?**

This location is standard across Tenstorrent development:
- Standard TT devXP (developer experience)
- Matches internal and external documentation
- Easy to find and navigate
- Proper ownership for development
- Not buried in system directories

### 2. Kernel Module (tt-kmd)

**Installation Method**: DKMS (Dynamic Kernel Module Support)

**Locations**:
```
/usr/src/tenstorrent-<version>/        # Source code for DKMS
/lib/modules/$(uname -r)/updates/dkms/ # Compiled kernel module
/dev/tenstorrent/                      # Device nodes (created automatically)
```

**How to verify**:
```bash
# Check if module is loaded
lsmod | grep tenstorrent

# Check module info
modinfo tenstorrent

# Check device nodes
ls -la /dev/tenstorrent/

# Check DKMS status
dkms status | grep tenstorrent
```

**How to manually load/unload**:
```bash
# Load module
sudo modprobe tenstorrent

# Unload module
sudo modprobe -r tenstorrent

# Check kernel logs
dmesg | grep -i tenstorrent
```

**Automatic loading**: The module is automatically loaded at boot via DKMS.

**Rebuild on kernel update**: DKMS automatically rebuilds the module when you install a new kernel.

---

### 2. HugePages Configuration

**Installation Method**: System configuration files + systemd/OpenRC services

**Files Created**:

#### Gentoo (systemd):
```
/etc/sysctl.d/99-tenstorrent-hugepages.conf           # Kernel parameters
/etc/systemd/system/dev-hugepages-1G.mount            # systemd mount unit
/dev/hugepages-1G/                                     # Mount point
```

#### Gentoo (OpenRC):
```
/etc/sysctl.d/99-tenstorrent-hugepages.conf           # Kernel parameters
/etc/fstab                                             # Mount entry added
/dev/hugepages-1G/                                     # Mount point
```

#### Ubuntu/Debian/Fedora:
```
/etc/systemd/system/tenstorrent-hugepages.service     # systemd service
/etc/systemd/system/dev-hugepages-1G.mount            # systemd mount unit
/dev/hugepages-1G/                                     # Mount point
```

**How to verify**:
```bash
# Check if hugepages are configured
cat /proc/meminfo | grep Huge

# Check if 1GB hugepages are mounted
mount | grep hugepages-1G

# Check sysctl settings
sysctl vm.nr_hugepages
sysctl vm.hugetlb_shm_group

# Check systemd services (if using systemd)
systemctl status tenstorrent-hugepages.service
systemctl status dev-hugepages-1G.mount
```

**Configuration values**:
- `vm.nr_hugepages = 2048` (2048 x 2MB = 4GB of hugepages)
- `vm.hugetlb_shm_group = 0` (allows root group to use hugepages)

---

### 3. Python Tools (tt-smi, tt-flash, tt-topology)

**Installation Method**: pip (direct install or via pipx/venv)

The location depends on which Python installation method was chosen:

#### Option 1: pipx (Recommended for Gentoo)
```
~/.local/bin/tt-smi                    # Executable wrapper
~/.local/bin/tt-flash                  # Executable wrapper
~/.local/bin/tt-topology               # Executable wrapper (optional)
~/.local/pipx/venvs/tt-smi/            # Isolated venv for tt-smi
~/.local/pipx/venvs/tt-flash/          # Isolated venv for tt-flash
~/.local/pipx/venvs/tt-topology/       # Isolated venv for tt-topology
```

#### Option 2: new-venv (Default)
```
~/.tenstorrent-venv/                   # Python virtual environment
~/.tenstorrent-venv/bin/tt-smi         # Executables in venv
~/.tenstorrent-venv/bin/tt-flash
~/.tenstorrent-venv/bin/tt-topology
~/.tenstorrent-venv/lib/python3.*/site-packages/  # Python packages
```

#### Option 3: active-venv (User-managed)
```
$VIRTUAL_ENV/bin/tt-smi                # In your active venv
$VIRTUAL_ENV/bin/tt-flash
$VIRTUAL_ENV/bin/tt-topology
```

#### Option 4: system-python (Not recommended)
```
/usr/local/bin/tt-smi                  # System-wide executables
/usr/local/bin/tt-flash
/usr/local/bin/tt-topology
/usr/local/lib/python3.*/site-packages/  # System Python packages
```

**How to verify**:
```bash
# Check if tools are in PATH
which tt-smi
which tt-flash

# Check versions
tt-smi --version
tt-flash --version

# For pipx, list installed packages
pipx list

# For venv, check the venv
source ~/.tenstorrent-venv/bin/activate
pip list | grep tt-
```

**Running the tools**:
```bash
# If using pipx or system-python, just run directly:
tt-smi

# If using new-venv, you need to activate first:
source ~/.tenstorrent-venv/bin/activate
tt-smi

# Or use full path:
~/.tenstorrent-venv/bin/tt-smi
```

---

### 4. SFPI (SFP Interface)

**Installation Method**: Varies by distribution

#### Gentoo (Built from source):
```
/usr/local/bin/sfpi                    # Compiled binary (Rust) or Python package
```

#### Ubuntu/Debian/Fedora (Pre-built package):
```
/usr/bin/sfpi                          # Installed via package manager
```

**How to verify**:
```bash
# Check if installed
which sfpi

# Check version
sfpi --version

# Test run
sfpi --help
```

**Source code** (Gentoo only):
- Cloned to: `/tmp/tenstorrent_install_*/sfpi/`
- Only present during installation, not kept after

---

### 5. Podman Container Runtime

**Installation Method**: System package manager

**Locations**:
```
/usr/bin/podman                        # Podman binary
/etc/containers/                       # Podman configuration
~/.config/containers/                  # User-specific config
~/.local/share/containers/storage/     # Container storage (rootless)
/etc/subuid                            # User ID mappings for rootless
/etc/subgid                            # Group ID mappings for rootless
```

**How to verify**:
```bash
# Check if installed
which podman
podman --version

# List containers
podman ps -a

# List images
podman images

# Check storage location
podman info | grep -A 10 graphRoot
```

---

### 6. tt-metalium Container

**What is tt-metalium?**
tt-metalium is the Tenstorrent ML framework (TT-NN) packaged as a Podman container. It provides a complete development environment for running neural networks on Tenstorrent hardware.

**Container Image**:
- **Image URL**: `ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-amd64`
- **Tag**: `latest-rc` (by default)
- **Size**: ~1GB (slim) or ~10GB (models variant)

**Storage Locations**:

#### Container Image Storage (rootless Podman):
```
~/.local/share/containers/storage/overlay/          # Image layers
~/.local/share/containers/storage/overlay-images/   # Image metadata
~/.local/share/containers/storage/overlay-layers/   # Layer data
```

#### Wrapper Script:
```
~/.local/bin/tt-metalium                # Shell script wrapper
~/.local/bin/tt-metalium-models         # Models container wrapper (optional)
```

**How the wrapper works**:

The `tt-metalium` script is a convenience wrapper that:
1. Mounts your home directory at `/home/user` inside the container
2. Mounts `/dev/tenstorrent` and `/dev/hugepages-1G` for hardware access
3. Forwards your display for GUI apps
4. Runs in privileged mode for hardware access

**How to verify**:
```bash
# Check if wrapper exists
which tt-metalium
cat ~/.local/bin/tt-metalium

# List pulled images
podman images | grep metalium

# Check image details
podman image inspect ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-amd64:latest-rc

# Check image size
podman image ls --format "{{.Repository}}:{{.Tag}} {{.Size}}" | grep metalium
```

**Where does the container run?**

When you run `tt-metalium`, it:
- **Does NOT** copy files to your system permanently
- **Mounts** your `$HOME` directory at `/home/user` inside container
- **Working directory**: Whatever directory you're in when you run it (mounted as `/home/user/<path>`)
- **Temporary files**: Stored in container, deleted when container exits
- **Persistent files**: Only files you save to your mounted `$HOME` persist

**Example usage**:
```bash
# Start interactive shell in container
tt-metalium

# Run a command in container
tt-metalium python3 my_script.py

# Run with your files (they're automatically mounted)
cd ~/my-project/
tt-metalium python3 train_model.py
# ^ This sees /home/user/my-project/ inside the container
```

**Container storage usage**:
```bash
# Check total storage used by Podman
du -sh ~/.local/share/containers/storage/

# Check specific container size
podman system df

# Clean up unused containers/images
podman system prune -a
```

---

### 7. tt-inference-server

**Installation Method**: Git clone + wrapper script

**Locations**:
```
~/.local/lib/tt-inference-server/       # Git repository clone
~/.local/bin/tt-inference-server        # Wrapper script
```

**Wrapper script contents**:
```bash
#!/bin/bash
cd ${HOME}/.local/lib/tt-inference-server
python ${HOME}/.local/lib/tt-inference-server/run.py "$@"
```

**How to verify**:
```bash
# Check if cloned
ls -la ~/.local/lib/tt-inference-server/

# Check wrapper
cat ~/.local/bin/tt-inference-server

# Test run
tt-inference-server --help
```

**Update inference server**:
```bash
cd ~/.local/lib/tt-inference-server
git pull
```

---

### 8. Gentoo-Specific: Package Keywords

**Installation Method**: Configuration file

**Location**:
```
/etc/portage/package.accept_keywords/tenstorrent-podman
```

**What it does**: Unmasks ~amd64 packages so Podman and dependencies can be installed.

**Contents**:
```
app-containers/podman ~amd64
app-containers/netavark ~amd64
app-containers/aardvark-dns ~amd64
# ... etc
```

**How to verify**:
```bash
# Check if file exists
cat /etc/portage/package.accept_keywords/tenstorrent-podman

# Check what packages are keyworded
grep tenstorrent /etc/portage/package.accept_keywords/* 2>/dev/null
```

**Remove if needed** (after installation):
```bash
sudo rm /etc/portage/package.accept_keywords/tenstorrent-podman
```

---

## Installation Log

**Location**: `/tmp/tenstorrent_install_XXXXXX/install.log`

Where `XXXXXX` is a random string generated by mktemp.

**Lifetime**: Temporary directory, usually deleted on reboot.

**How to find recent logs**:
```bash
# Find recent install logs
find /tmp -name "tenstorrent_install_*" -type d 2>/dev/null

# View most recent log
cat $(find /tmp -name "install.log" -path "*/tenstorrent_install_*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2)
```

**Save log for later**:
```bash
# Copy to your home directory
cp /tmp/tenstorrent_install_*/install.log ~/tenstorrent-install-$(date +%Y%m%d).log
```

---

## Complete File Tree Summary

```
System-wide:
├── /lib/modules/$(uname -r)/updates/dkms/tenstorrent.ko   # Kernel module
├── /usr/src/tenstorrent-<version>/                         # DKMS source
├── /dev/tenstorrent/                                        # Device nodes
├── /dev/hugepages-1G/                                       # HugePages mount
├── /etc/sysctl.d/99-tenstorrent-hugepages.conf            # Kernel params
├── /etc/systemd/system/tenstorrent-hugepages.service      # systemd service
├── /etc/systemd/system/dev-hugepages-1G.mount             # systemd mount
├── /etc/portage/package.accept_keywords/tenstorrent-*     # Gentoo keywords
├── /usr/local/bin/sfpi                                     # SFPI binary (Gentoo)
└── /usr/bin/podman                                         # Podman binary

User home directory:
~/.local/
├── bin/
│   ├── tt-metalium                    # Container wrapper
│   ├── tt-metalium-models             # Models container wrapper
│   ├── tt-inference-server            # Inference server wrapper
│   ├── tt-smi                         # SMI tool (if using pipx)
│   └── tt-flash                       # Flash tool (if using pipx)
├── lib/
│   └── tt-inference-server/           # Inference server git clone
├── share/
│   └── containers/
│       └── storage/                    # Podman container storage
│           ├── overlay/                # Container layers
│           ├── overlay-images/         # Image metadata
│           └── overlay-layers/         # Layer data
├── pipx/
│   └── venvs/                         # pipx virtual environments
│       ├── tt-smi/
│       ├── tt-flash/
│       └── tt-topology/
└── config/
    └── containers/                     # Podman user config

~/.tenstorrent-venv/                   # Virtual environment (if new-venv)
├── bin/
│   ├── tt-smi
│   ├── tt-flash
│   └── tt-topology
└── lib/python3.*/site-packages/

Temporary:
/tmp/tenstorrent_install_XXXXXX/       # Installation workspace
└── install.log                         # Installation log
```

---

## Disk Space Usage Estimates

| Component | Approximate Size | Notes |
|-----------|-----------------|-------|
| **tt-kmd** | ~5-10 MB | Kernel module + source |
| **HugePages config** | <1 KB | Config files only |
| **Python tools (venv)** | ~50-100 MB | Depends on dependencies |
| **Python tools (pipx)** | ~100-200 MB | Multiple isolated venvs |
| **SFPI** | ~10-50 MB | Depends on implementation |
| **Podman** | ~50 MB | Binary and dependencies |
| **tt-metalium container** | ~1 GB | Slim container |
| **tt-metalium-models** | ~10 GB | Includes model demos |
| **tt-inference-server** | ~50-100 MB | Git repository |
| **Rust (if installed)** | ~1-2 GB | Compiler and toolchain |

**Total (minimal)**: ~1.5 GB (without models container)
**Total (with models)**: ~11.5 GB

---

## Uninstallation

To completely remove Tenstorrent software:

```bash
# 1. Remove kernel module
sudo dkms remove tenstorrent/<version> --all
sudo rm -rf /usr/src/tenstorrent-*

# 2. Remove Python tools (pipx)
pipx uninstall tt-smi
pipx uninstall tt-flash
pipx uninstall tt-topology

# 3. Remove Python tools (venv)
rm -rf ~/.tenstorrent-venv

# 4. Remove SFPI
sudo rm /usr/local/bin/sfpi

# 5. Remove containers and images
podman rm -a                           # Remove all containers
podman rmi -a                          # Remove all images
rm -rf ~/.local/share/containers/      # Remove storage

# 6. Remove wrapper scripts
rm ~/.local/bin/tt-metalium
rm ~/.local/bin/tt-metalium-models
rm ~/.local/bin/tt-inference-server

# 7. Remove inference server
rm -rf ~/.local/lib/tt-inference-server

# 8. Remove HugePages configuration
sudo rm /etc/sysctl.d/99-tenstorrent-hugepages.conf
sudo systemctl disable tenstorrent-hugepages.service
sudo systemctl disable dev-hugepages-1G.mount
sudo rm /etc/systemd/system/tenstorrent-hugepages.service
sudo rm /etc/systemd/system/dev-hugepages-1G.mount
# (For OpenRC, remove fstab entry manually)

# 9. Remove Gentoo package keywords
sudo rm /etc/portage/package.accept_keywords/tenstorrent-*

# 10. Reboot to unload kernel module
sudo reboot
```

---

## Questions & Troubleshooting

### Where is tt-metal itself installed?

**tt-metal IS installed directly at `~/tt-metal/`** by the installer!

- The **source code** is cloned to `~/tt-metal/` during installation
- This is the **primary development directory** for working with Tenstorrent hardware
- Owned by your user (not root) for proper development permissions
- Automatically updated (git pull) if you run the installer again

Additionally, there's also:
- The **tt-metalium container** which contains a complete pre-built tt-metal
- When you run `tt-metalium`, you're running inside a container
- The container lives in `~/.local/share/containers/storage/`
- Useful for quick testing without building from source

### How do I access tt-metal source code?

**It's already installed!**

```bash
# Navigate to tt-metal
cd ~/tt-metal

# Check status
git status
git log -1

# Pull latest changes
git pull

# Build tt-metal (see README.md for instructions)
# Follow the build process for your hardware
```

### Should I use ~/tt-metal or the container?

**Use both, depending on your needs:**

**~/tt-metal (source installation)** - For development:
- Modify source code
- Build custom versions
- Develop new features
- Debug issues
- Follow latest development

**tt-metalium container** - For quick usage:
- Pre-built, ready to use
- No build time required
- Isolated environment
- Quick testing and demos

**Typical workflow:**
```bash
# Develop in ~/tt-metal
cd ~/tt-metal
# Make changes, build, test

# Or use pre-built container for quick tests
tt-metalium python3 my_script.py
```

### How much disk space do containers use?

```bash
# Check Podman storage usage
podman system df

# Check directory size
du -sh ~/.local/share/containers/storage/

# See breakdown by image
podman images --format "{{.Repository}}:{{.Tag}} {{.Size}}"
```

### Can I move the container storage location?

Yes, but requires Podman reconfiguration:

```bash
# Edit ~/.config/containers/storage.conf
# Change graphroot to your desired location
```

---

**Last Updated**: 2025-01-20
**Installer Version**: Development (gentoo-support branch)
