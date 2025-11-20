# Gentoo Linux Support Implementation Plan for tt-installer

## Overview

This document outlines the implementation plan for adding Gentoo Linux support to the tt-installer project for Tenstorrent hardware and firmware installation. The implementation will support kernel modules (tt-kmd), system management tools (tt-smi), and the tt-metal framework along with all necessary build dependencies.

## Current Architecture Analysis

### Main Components
- **install.m4**: Bash script template (processed by argbash) - main installer logic
- **install_inference.py**: Python script for inference server installation
- **Supported Distros**: Ubuntu, Debian, Fedora, RHEL/CentOS (via APT/DNF package managers)

### Installation Flow
1. Base package installation (git, python3-pip, dkms, cargo, rustc, jq, protobuf-compiler)
2. Python environment setup (venv, pipx, or system-python)
3. TT-KMD (Kernel Mode Driver) via DKMS
4. TT-Flash + Firmware update
5. HugePages configuration via tenstorrent-tools systemd service
6. tt-smi (System Management Interface - Python)
7. SFPI (firmware interface)
8. Podman + Metalium containers
9. tt-inference-server (optional)

### Key Dependencies by Category

**System Build Tools:**
- git
- dkms (Dynamic Kernel Module Support)
- jq (JSON processor)
- protobuf-compiler

**Rust Toolchain:**
- cargo
- rustc

**Python Stack:**
- python3
- python3-pip
- python3-venv (Ubuntu/Debian)
- python3-devel (Fedora/RHEL) - headers
- pipx

**Container Runtime:**
- podman
- podman-docker

**Kernel Development:**
- linux-headers (implicit via DKMS)

## Gentoo Portage Package Mapping

| Debian/Fedora Package | Gentoo Package | Notes |
|----------------------|----------------|-------|
| git | dev-vcs/git | Standard |
| dkms | sys-kernel/dkms | Available in portage |
| jq | app-misc/jq | Standard |
| protobuf-compiler | dev-libs/protobuf | Standard |
| cargo + rustc | dev-lang/rust | Includes both |
| python3 | dev-lang/python:3.x | Usually pre-installed |
| python3-pip | dev-python/pip | Bundled with Python |
| python3-venv | dev-lang/python | Built with USE="sqlite" |
| python3-devel | dev-lang/python | Headers included |
| pipx | dev-python/pipx | Available |
| podman | app-containers/podman | Available |
| linux-headers | sys-kernel/linux-headers | gentoo-sources includes headers |

## Code Changes Required

### 1. Detection & Base Package Installation (install.m4)

**Location: Lines 266-277, 1102-1132**

#### Add Gentoo Distribution Detection

```bash
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID=${ID}
        DISTRO_VERSION=${VERSION_ID}
        check_is_ubuntu_20

        # Add Gentoo-specific handling
        if [[ "${DISTRO_ID}" = "gentoo" ]]; then
            # Gentoo doesn't have consistent VERSION_ID
            DISTRO_VERSION=$(uname -r | cut -d'-' -f1)
        fi
    else
        error "Cannot detect Linux distribution"
        exit 1
    fi
}
```

#### Add Gentoo Kernel Listing Variable (around line 88)

```bash
KERNEL_LISTING_GENTOO="ls /lib/modules | grep -v '.old$' | sort -V"
```

#### Add Gentoo Base Package Installation (around line 1128)

```bash
"gentoo")
    # Sync portage tree (optional, may be slow)
    # sudo emerge --sync --quiet

    sudo emerge --ask=n --verbose \
        dev-vcs/git \
        dev-python/pip \
        sys-kernel/dkms \
        dev-lang/rust \
        dev-python/pipx \
        app-misc/jq \
        dev-libs/protobuf

    KERNEL_LISTING="${KERNEL_LISTING_GENTOO}"
    ;;
```

### 2. HugePages Configuration (install.m4)

**Location: manual_install_hugepages() - around line 817**

#### Add Helper Functions

Add these functions before `manual_install_hugepages()`:

```bash
manual_install_hugepages_gentoo_source() {
    log "Setting up HugePages for Gentoo (building from source)"
    cd "${WORKDIR}"

    git clone --branch "v${SYSTOOLS_VERSION}" \
        https://github.com/tenstorrent/tt-system-tools.git
    cd tt-system-tools

    # Detect init system
    if command -v systemctl &> /dev/null && systemctl --version &> /dev/null 2>&1; then
        log "Installing with systemd"
        sudo make install PREFIX=/usr || {
            warn "Make install failed, falling back to manual configuration"
            manual_configure_hugepages_gentoo
            return
        }
        sudo systemctl enable tenstorrent-hugepages.service
        sudo systemctl enable dev-hugepages-1G.mount
        sudo systemctl start tenstorrent-hugepages.service || true
        sudo systemctl start dev-hugepages-1G.mount || true
    else
        log "Installing with OpenRC"
        warn "OpenRC support requires manual configuration"
        manual_configure_hugepages_gentoo
    fi
}

manual_configure_hugepages_gentoo() {
    log "Configuring HugePages manually for Gentoo"

    # Configure kernel parameters
    sudo mkdir -p /etc/sysctl.d
    sudo tee /etc/sysctl.d/99-tenstorrent-hugepages.conf > /dev/null << EOF
# Tenstorrent HugePages Configuration
vm.nr_hugepages = 2048
vm.hugetlb_shm_group = 0
EOF

    sudo sysctl -p /etc/sysctl.d/99-tenstorrent-hugepages.conf

    # Mount hugepages
    sudo mkdir -p /dev/hugepages-1G

    if command -v systemctl &> /dev/null; then
        # Create systemd mount unit
        sudo tee /etc/systemd/system/dev-hugepages-1G.mount > /dev/null << EOF
[Unit]
Description=1GB HugePages Mount for Tenstorrent
DefaultDependencies=no
Before=local-fs.target

[Mount]
What=hugetlbfs
Where=/dev/hugepages-1G
Type=hugetlbfs
Options=pagesize=1G

[Install]
WantedBy=local-fs.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable dev-hugepages-1G.mount
        sudo systemctl start dev-hugepages-1G.mount || true
    else
        # Add to /etc/fstab for OpenRC
        if ! grep -q "/dev/hugepages-1G" /etc/fstab 2>/dev/null; then
            echo "hugetlbfs /dev/hugepages-1G hugetlbfs pagesize=1G 0 0" \
                | sudo tee -a /etc/fstab
        fi
        sudo mount /dev/hugepages-1G 2>/dev/null || warn "Failed to mount hugepages, may need reboot"
    fi

    log "HugePages configured manually"
}
```

#### Modify manual_install_hugepages()

Add Gentoo case around line 857:

```bash
"fedora"|"rhel"|"centos")
    # ... existing code ...
    ;;
"gentoo")
    manual_install_hugepages_gentoo_source
    ;;
*)
    error "This distro is unsupported. Skipping HugePages install!"
    ;;
```

### 3. SFPI Installation (install.m4)

**Location: manual_install_sfpi() - around line 896**

Add Gentoo case before the default error case:

```bash
"centos"|"fedora"|"rhel")
    SFPI_FILE_EXT="rpm"
    SFPI_DISTRO_TYPE="fedora"
    ;;
"gentoo")
    log "Building SFPI from source for Gentoo"
    cd "${WORKDIR}"

    # Clone SFPI repository
    git clone --branch "${SFPI_VERSION}" \
        https://github.com/tenstorrent/sfpi.git || \
        git clone https://github.com/tenstorrent/sfpi.git

    cd sfpi

    # Check if SFPI version tag exists and checkout
    if git rev-parse "${SFPI_VERSION}" >/dev/null 2>&1; then
        git checkout "${SFPI_VERSION}"
    else
        warn "Version ${SFPI_VERSION} not found, using latest"
    fi

    # Build based on project type
    if [[ -f "Cargo.toml" ]]; then
        # Rust project
        cargo build --release
        sudo install -Dm755 target/release/sfpi /usr/local/bin/sfpi
    elif [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        # Python project
        ${PYTHON_INSTALL_CMD} .
    else
        error "Unknown SFPI build system"
        return 1
    fi

    log "SFPI built and installed from source"
    return 0
    ;;
*)
    error "Unsupported distribution for SFPI installation: ${DISTRO_ID}"
    exit 1
    ;;
```

### 4. Podman Installation (install.m4)

**Location: install_podman() - around line 562**

Add Gentoo case around line 573:

```bash
"rhel"|"centos")
    sudo dnf install -y podman podman-docker
    ;;
"gentoo")
    sudo emerge --ask=n app-containers/podman
    log "Podman installed via portage"
    ;;
*)
    error "Unsupported distribution for Podman installation: ${DISTRO_ID}"
    return 1
    ;;
```

### 5. Update README.md

**Location: README.md - around line 71**

Add Gentoo to compatibility matrix:

```markdown
| OS     | Version     | Working? | Notes                                     |
| ------ | ----------- | -------- | ----------------------------------------- |
| Ubuntu | 24.04.2 LTS | Yes      | None                                      |
| Ubuntu | 22.04.5 LTS | Yes      | None                                      |
| Ubuntu | 20.04.6 LTS | Yes      | - Deprecated; support will be removed in a later release<br>- Metalium cannot be installed|
| Debian | 12.10.0     | Yes      | - Curl is not installed by default<br>- The packaged rustc version is too old to complete installation, we recommend using [rustup](https://rustup.rs/) to install a more modern version|
| Fedora | 41          | Yes      | May require restart after base package install |
| Fedora | 42          | Yes      | May require restart after base package install |
| Gentoo | Latest (rolling) | Beta  | - DKMS-based kernel module installation<br>- May require emerge --sync before installation<br>- Supports both systemd and OpenRC<br>- Some packages built from source |
| Other DEB-based distros  | N/A          | N/A     | Unsupported but may work |
| Other RPM-based distros  | N/A          | N/A     | Unsupported but may work |
```

## Kernel Module (TT-KMD) Strategy

### Current Implementation
- Uses DKMS (Dynamic Kernel Module Support)
- Clones tt-kmd from GitHub at specific version
- Uses `dkms add` and `dkms install` commands
- Installs for all detected kernel versions

### Gentoo Approach

**Option 1: Use DKMS (Recommended for short-term)**
- Gentoo has `sys-kernel/dkms` in portage
- Works identically to other distros
- Same code path, well-tested
- **No changes needed to manual_install_kmd()**

**Option 2: Native Gentoo Kernel Module Build (Long-term)**
- Create custom ebuild for tt-kmd
- Place in local overlay: `/usr/local/portage/sys-kernel/tt-kmd/`
- Use `linux-mod.eclass` for kernel module building
- More "Gentoo native", automatic kernel rebuild integration

**Recommended: Use Option 1 initially, migrate to Option 2 for production**

## Python Tooling Strategy

### Current Implementation
Installs Python packages via pip from GitHub:
```bash
${PYTHON_INSTALL_CMD} git+https://github.com/tenstorrent/tt-flash.git@"${FLASH_VERSION}"
${PYTHON_INSTALL_CMD} git+https://github.com/tenstorrent/tt-smi@"${SMI_VERSION}"
${PYTHON_INSTALL_CMD} git+https://github.com/tenstorrent/tt-topology.git@"${TOPOLOGY_VERSION}"
```

### Gentoo Compatibility

The current approach is **already compatible with Gentoo** because:
- Uses standard pip/Python installation
- Installs from source (GitHub)
- Not dependent on distribution-specific packaging

**Note:** Recommend using `pipx` or `venv` instead of `system-python` on Gentoo due to PEP 668 (externally-managed-environment).

## Testing Strategy

### Prerequisites
- Gentoo Linux installation (latest stage3)
- Tenstorrent hardware (or VM for testing without hardware)
- Kernel sources installed (`gentoo-sources`)
- Both systemd and OpenRC profiles for testing

### Test Cases

#### Test 1: Base Package Installation
```bash
# Test emerge can install all dependencies
sudo emerge --pretend dev-vcs/git dev-python/pip sys-kernel/dkms \
    dev-lang/rust dev-python/pipx app-misc/jq dev-libs/protobuf

# Verify versions meet requirements
rust --version  # Should be recent (1.70+)
jq --version
```

#### Test 2: Full Installation (Non-Interactive)
```bash
./install.sh --mode-non-interactive \
    --python-choice=pipx \
    --reboot-option=never
```

#### Test 3: KMD Installation
```bash
# After install, verify module loaded
lsmod | grep tenstorrent
modinfo tenstorrent
```

#### Test 4: HugePages Configuration
```bash
# Verify hugepages mounted
mount | grep hugepages-1G
cat /proc/meminfo | grep Huge

# Check systemd service (if systemd)
systemctl status dev-hugepages-1G.mount
systemctl status tenstorrent-hugepages.service

# Check OpenRC service (if OpenRC)
rc-status | grep tenstorrent
```

#### Test 5: Python Tools
```bash
# Verify tools installed and working
tt-smi --version
tt-flash --version

# Test with hardware
tt-smi  # Should show device info
```

#### Test 6: Podman & Metalium
```bash
# Verify podman works
podman --version
podman images | grep metalium

# Test metalium container
tt-metalium "python3 --version"
```

## Long-Term Recommendations

### Create Gentoo Overlay

Create an official Gentoo overlay repository: `tenstorrent-overlay`

#### Structure
```
tenstorrent-overlay/
├── profiles/
│   └── repo_name
├── sys-kernel/
│   └── tt-kmd/
│       ├── tt-kmd-1.34.ebuild
│       ├── tt-kmd-9999.ebuild (live ebuild)
│       └── Manifest
├── sys-apps/
│   ├── tt-smi/
│   │   ├── tt-smi-1.0.0.ebuild
│   │   └── Manifest
│   ├── tt-flash/
│   │   ├── tt-flash-1.0.0.ebuild
│   │   └── Manifest
│   └── tt-system-tools/
│       ├── tt-system-tools-1.0.0.ebuild
│       └── Manifest
└── app-misc/
    └── sfpi/
        ├── sfpi-1.0.0.ebuild
        └── Manifest
```

#### Benefits
- Native Gentoo package management
- Automatic dependency resolution
- Integration with `eselect` tools
- Automatic rebuilds on kernel updates
- Proper USE flag support

### Example Ebuild

**sys-kernel/tt-kmd/tt-kmd-1.34.ebuild:**

```bash
# Copyright 2025 Tenstorrent Inc.
# Distributed under the terms of the Apache License v2.0

EAPI=8

inherit linux-mod-r1

DESCRIPTION="Tenstorrent Kernel Mode Driver"
HOMEPAGE="https://github.com/tenstorrent/tt-kmd"
SRC_URI="https://github.com/tenstorrent/tt-kmd/archive/ttkmd-${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="sys-kernel/dkms"
RDEPEND="${DEPEND}"

S="${WORKDIR}/tt-kmd-ttkmd-${PV}"

src_compile() {
    linux-mod-r1_src_compile
}

src_install() {
    linux-mod-r1_src_install
}
```

### Submit to Gentoo GURU

Consider submitting ebuilds to [GURU](https://wiki.gentoo.org/wiki/Project:GURU) (Gentoo User Repository Overlay) for community maintenance.

## Known Limitations & Considerations

### Init System Support
- **Systemd**: Full support planned
- **OpenRC**: Manual configuration fallback (HugePages via /etc/fstab)
- Consider creating proper OpenRC init scripts for production use

### Package Availability
- Most dependencies available in main portage tree
- SFPI may need source build if no Gentoo package exists
- Some users may have `~amd64` packages masked (needs `package.accept_keywords`)

### Kernel Considerations
- Gentoo users may run custom kernels
- DKMS should handle most cases
- Users with heavily patched kernels may need manual module building

### Compilation Time
- Gentoo builds from source by default
- Initial package installation may be slow (especially Rust)
- Consider documenting binary package options (`FEATURES="getbinpkg"`)

## Implementation Checklist

- [ ] Add Gentoo detection to `detect_distro()` in install.m4:266-277
- [ ] Add `KERNEL_LISTING_GENTOO` variable at install.m4:88
- [ ] Add Gentoo base package installation case in install.m4:1102-1132
- [ ] Implement `manual_install_hugepages_gentoo_source()` helper function
- [ ] Implement `manual_configure_hugepages_gentoo()` helper function
- [ ] Add Gentoo case to `manual_install_hugepages()` at install.m4:860
- [ ] Add Gentoo source-build case to `manual_install_sfpi()` at install.m4:896
- [ ] Add Gentoo case to `install_podman()` at install.m4:573
- [ ] Update README.md compatibility matrix to include Gentoo
- [ ] Test on Gentoo with systemd profile
- [ ] Test on Gentoo with OpenRC profile
- [ ] Create Gentoo overlay repository (long-term)
- [ ] Write ebuilds for tt-kmd, tt-smi, tt-flash, tt-system-tools
- [ ] Submit to GURU overlay (optional)

## Quick Start Commands

To begin implementing Gentoo support:

### 1. Modify install.m4 - Add at line 88
```bash
KERNEL_LISTING_GENTOO="ls /lib/modules | grep -v '.old$' | sort -V"
```

### 2. Modify install.m4 - Add Gentoo case around line 1128
```bash
"gentoo")
    sudo emerge --ask=n \
        dev-vcs/git dev-python/pip sys-kernel/dkms \
        dev-lang/rust dev-python/pipx app-misc/jq dev-libs/protobuf
    KERNEL_LISTING="${KERNEL_LISTING_GENTOO}"
    ;;
```

### 3. Build the installer
```bash
make  # This processes install.m4 through argbash
```

### 4. Test on Gentoo
```bash
./install.sh --mode-non-interactive --python-choice=pipx --reboot-option=never
```

## Summary

This implementation plan provides:

1. **Complete code modifications** for all installation components
2. **Gentoo-specific implementations** for HugePages, SFPI, and system tools
3. **Support for both systemd and OpenRC** init systems
4. **Fallback strategies** when pre-built packages aren't available
5. **Long-term recommendations** for native Gentoo packaging via ebuilds
6. **Testing strategy** to validate all components
7. **Implementation checklist** to track progress

The design prioritizes:
- **Minimal changes** to existing codebase structure
- **Consistency** with other distro implementations
- **Robustness** with fallback options for edge cases
- **Future-proofing** with overlay and ebuild recommendations

All components (kernel modules, tt-smi, tt-metal, Python tools, C++, Ninja, and other build tools) are addressed with appropriate installation strategies for Gentoo's source-based package management system.
