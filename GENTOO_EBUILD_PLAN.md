# Gentoo Ebuild Collection Plan for Tenstorrent Stack

## Overview

This document outlines a comprehensive plan to create a Gentoo overlay with ebuilds for the complete Tenstorrent software stack. This represents the proper Gentoo-native approach to packaging and distribution, providing advantages over the scripted installer including automatic dependency resolution, USE flag configuration, and integration with Gentoo's package management system.

## Benefits of Ebuild Approach

### Advantages over Script Installer
1. **Native Package Management**: Full integration with `emerge`, `equery`, `eix`
2. **Automatic Dependency Resolution**: Portage handles all dependencies
3. **USE Flags**: User-controllable feature toggles
4. **Version Management**: Easy upgrades, downgrades, and slotting
5. **Configuration Management**: `etc-update` for config file handling
6. **Binary Package Support**: Can create binpkgs for faster deployment
7. **Kernel Rebuild Integration**: Automatic module rebuilds with `@module-rebuild`
8. **Init System Integration**: Proper OpenRC/systemd service installation
9. **Uninstallation**: Clean removal with `emerge --depclean`
10. **Verification**: `equery check` for file integrity

### Disadvantages to Consider
1. **Maintenance Overhead**: Requires updating ebuilds for each new release
2. **Gentoo-Specific**: Won't help users on other distributions
3. **Initial Setup**: More complex than a simple bash script
4. **Review Process**: GURU or official tree submission requires review

## Recommended Approach: Dual Strategy

**Short-term (Current)**: Continue with script-based installer for quick deployment and multi-distro support

**Long-term (This Plan)**: Create and maintain Gentoo overlay for native integration, submit to GURU for community adoption

**Transition Path**: Script installer can detect ebuild availability and recommend it

---

## Overlay Structure

### Repository Layout

```
tenstorrent-overlay/
├── profiles/
│   ├── repo_name                          # Contains: tenstorrent
│   └── categories                         # List of package categories
├── metadata/
│   ├── layout.conf                        # Overlay configuration
│   └── pkg_desc_index                     # Generated index
├── licenses/
│   └── Tenstorrent-EULA                   # If needed for proprietary components
├── sys-kernel/
│   └── tt-kmd/
│       ├── tt-kmd-1.34.ebuild
│       ├── tt-kmd-1.35.ebuild
│       ├── tt-kmd-9999.ebuild             # Live git version
│       ├── Manifest                        # Checksums
│       └── metadata.xml                    # Package metadata
├── sys-apps/
│   └── tt-system-tools/
│       ├── tt-system-tools-1.0.0.ebuild
│       ├── tt-system-tools-9999.ebuild
│       ├── Manifest
│       ├── metadata.xml
│       └── files/
│           ├── tt-hugepages.openrc        # OpenRC init script
│           └── tt-hugepages.confd         # OpenRC config
├── dev-python/
│   ├── tt-smi/
│   │   ├── tt-smi-1.0.0.ebuild
│   │   ├── tt-smi-9999.ebuild
│   │   ├── Manifest
│   │   └── metadata.xml
│   ├── tt-flash/
│   │   ├── tt-flash-1.0.0.ebuild
│   │   ├── tt-flash-9999.ebuild
│   │   ├── Manifest
│   │   └── metadata.xml
│   ├── tt-topology/
│   │   ├── tt-topology-1.0.0.ebuild
│   │   ├── tt-topology-9999.ebuild
│   │   ├── Manifest
│   │   └── metadata.xml
│   └── tt-inference-server/
│       ├── tt-inference-server-1.0.0.ebuild
│       ├── tt-inference-server-9999.ebuild
│       ├── Manifest
│       └── metadata.xml
├── dev-util/
│   └── sfpi/
│       ├── sfpi-1.0.0.ebuild
│       ├── sfpi-9999.ebuild
│       ├── Manifest
│       └── metadata.xml
├── app-containers/
│   └── tt-metalium/
│       ├── tt-metalium-1.0.0.ebuild       # Wrapper script + podman pull
│       ├── Manifest
│       └── metadata.xml
└── virtual/
    └── tenstorrent/
        ├── tenstorrent-1.0.ebuild          # Meta-package for full stack
        ├── Manifest
        └── metadata.xml
```

### Repository Configuration Files

#### profiles/repo_name
```
tenstorrent
```

#### profiles/categories
```
sys-kernel
sys-apps
dev-python
dev-util
app-containers
virtual
```

#### metadata/layout.conf
```ini
# Tenstorrent Overlay Configuration
repo-name = tenstorrent
masters = gentoo
# Use thin manifests (only distfile checksums)
thin-manifests = true
# Use EAPI 8
eapis-banned = 0 1 2 3 4 5 6 7
# Sign commits
sign-commits = true
sign-manifests = false
# Cache format
cache-formats = md5-dict
```

---

## Component Analysis & Ebuild Planning

### 1. Kernel Module: sys-kernel/tt-kmd

**Source**: https://github.com/tenstorrent/tt-kmd
**Type**: Linux kernel module (DKMS-style)
**Eclass**: `linux-mod-r1` (modern kernel module eclass)
**License**: Apache-2.0

#### Key Requirements
- Kernel headers (linux-headers)
- Build-time: kernel sources matching running kernel
- Runtime: Automatic rebuild on kernel updates
- Device node creation (/dev/tenstorrent)

#### Ebuild Template: tt-kmd-1.34.ebuild

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

inherit linux-mod-r1

DESCRIPTION="Tenstorrent Kernel Mode Driver for AI accelerators"
HOMEPAGE="https://github.com/tenstorrent/tt-kmd"
SRC_URI="https://github.com/tenstorrent/tt-kmd/archive/refs/tags/ttkmd-${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="debug"

# Kernel configuration requirements
CONFIG_CHECK="MODULES HUGETLBFS"
MODULE_NAMES="tenstorrent(misc:${S})"

S="${WORKDIR}/tt-kmd-ttkmd-${PV}"

src_compile() {
	local modargs=(
		# Pass debug flag if USE flag is set
		$(usex debug 'DEBUG=1' '')
	)
	linux-mod-r1_src_compile "${modargs[@]}"
}

src_install() {
	linux-mod-r1_src_install

	# Install udev rules for device node creation
	insinto /lib/udev/rules.d
	doins debian/tenstorrent.udev || die

	# Documentation
	dodoc README.md
}

pkg_postinst() {
	linux-mod-r1_pkg_postinst

	elog "Tenstorrent kernel module installed."
	elog "The module should be automatically loaded at boot."
	elog "To load manually: modprobe tenstorrent"
	elog ""
	elog "Check device status with: ls -la /dev/tenstorrent"
}
```

#### Ebuild Template: tt-kmd-9999.ebuild (Live Git)

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

inherit git-r3 linux-mod-r1

DESCRIPTION="Tenstorrent Kernel Mode Driver for AI accelerators (live version)"
HOMEPAGE="https://github.com/tenstorrent/tt-kmd"
EGIT_REPO_URI="https://github.com/tenstorrent/tt-kmd.git"

LICENSE="Apache-2.0"
SLOT="0"
IUSE="debug"

CONFIG_CHECK="MODULES HUGETLBFS"
MODULE_NAMES="tenstorrent(misc:${S})"

src_compile() {
	local modargs=(
		$(usex debug 'DEBUG=1' '')
	)
	linux-mod-r1_src_compile "${modargs[@]}"
}

src_install() {
	linux-mod-r1_src_install
	insinto /lib/udev/rules.d
	doins debian/tenstorrent.udev || die
	dodoc README.md
}

pkg_postinst() {
	linux-mod-r1_pkg_postinst
	ewarn "You are using a live git version of tt-kmd."
	ewarn "This may be unstable. Consider using a tagged release."
}
```

#### metadata.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE pkgmetadata SYSTEM "https://www.gentoo.org/dtd/metadata.dtd">
<pkgmetadata>
	<maintainer type="person">
		<email>tsingletary@tenstorrent.com</email>
		<name>Tenstorrent Inc.</name>
	</maintainer>
	<longdescription>
		Kernel mode driver for Tenstorrent AI accelerator hardware.
		Provides /dev/tenstorrent device interface and manages hardware
		resources including PCIe communication and memory management.
	</longdescription>
	<use>
		<flag name="debug">Enable debug logging and symbols</flag>
	</use>
	<upstream>
		<remote-id type="github">tenstorrent/tt-kmd</remote-id>
		<bugs-to>https://github.com/tenstorrent/tt-kmd/issues</bugs-to>
	</upstream>
</pkgmetadata>
```

---

### 2. System Tools: sys-apps/tt-system-tools

**Source**: https://github.com/tenstorrent/tt-system-tools
**Type**: System configuration tools (HugePages)
**Eclass**: `systemd`, `openrc`
**License**: Apache-2.0

#### Key Requirements
- HugePages kernel support
- systemd unit files OR OpenRC init scripts
- sysctl configuration files
- Mount point creation

#### Ebuild Template: tt-system-tools-1.0.0.ebuild

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

inherit systemd

DESCRIPTION="Tenstorrent system configuration tools (HugePages, device setup)"
HOMEPAGE="https://github.com/tenstorrent/tt-system-tools"
SRC_URI="https://github.com/tenstorrent/tt-system-tools/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="systemd openrc"
REQUIRED_USE="|| ( systemd openrc )"

RDEPEND="
	sys-kernel/tt-kmd
	systemd? ( sys-apps/systemd )
	openrc? ( sys-apps/openrc )
"

src_install() {
	# Install sysctl configuration for HugePages
	insinto /etc/sysctl.d
	newins sysctl/hugepages.conf 99-tenstorrent-hugepages.conf

	if use systemd; then
		# Install systemd service for HugePages configuration
		systemd_dounit systemd/tenstorrent-hugepages.service

		# Install systemd mount unit for 1GB hugepages
		systemd_dounit systemd/dev-hugepages-1G.mount

		# Enable by default
		systemd_enable_service multi-user.target tenstorrent-hugepages.service
		systemd_enable_service local-fs.target dev-hugepages-1G.mount
	fi

	if use openrc; then
		# Install OpenRC init script
		# Note: We'll need to create this ourselves
		newinitd "${FILESDIR}"/tt-hugepages.openrc tt-hugepages
		newconfd "${FILESDIR}"/tt-hugepages.confd tt-hugepages
	fi

	# Scripts and tools
	dobin bin/tt-setup-hugepages || die

	# Documentation
	dodoc README.md
}

pkg_postinst() {
	elog "Tenstorrent system tools installed."
	elog ""
	elog "HugePages configuration:"
	if use systemd; then
		elog "  systemctl enable --now tenstorrent-hugepages.service"
		elog "  systemctl enable --now dev-hugepages-1G.mount"
	fi
	if use openrc; then
		elog "  rc-update add tt-hugepages default"
		elog "  rc-service tt-hugepages start"
	fi
	elog ""
	elog "Verify HugePages: cat /proc/meminfo | grep Huge"
	elog "Check mount: mount | grep hugepages-1G"
}
```

#### OpenRC Init Script: files/tt-hugepages.openrc

```bash
#!/sbin/openrc-run
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

description="Configure HugePages for Tenstorrent hardware"

depend() {
	need localmount
	after modules
}

start() {
	ebegin "Configuring HugePages for Tenstorrent"

	# Apply sysctl settings
	/sbin/sysctl -p /etc/sysctl.d/99-tenstorrent-hugepages.conf

	# Create mount point
	if [ ! -d /dev/hugepages-1G ]; then
		mkdir -p /dev/hugepages-1G
	fi

	# Mount 1GB hugepages if not already mounted
	if ! mountinfo -q /dev/hugepages-1G; then
		mount -t hugetlbfs -o pagesize=1G hugetlbfs /dev/hugepages-1G
	fi

	eend $?
}

stop() {
	ebegin "Unmounting HugePages"
	if mountinfo -q /dev/hugepages-1G; then
		umount /dev/hugepages-1G
	fi
	eend $?
}
```

#### OpenRC Config: files/tt-hugepages.confd

```bash
# Configuration for Tenstorrent HugePages service
# Number of 2MB hugepages to reserve
HUGEPAGES_2MB=2048

# Group ID allowed to use hugepages (0 = root)
HUGEPAGES_GROUP=0
```

---

### 3. Python Packages: dev-python/tt-smi

**Source**: https://github.com/tenstorrent/tt-smi
**Type**: Python package
**Eclass**: `distutils-r1` or `pypi`
**License**: Apache-2.0

#### Ebuild Template: tt-smi-1.0.0.ebuild

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..12} )

inherit distutils-r1 pypi

DESCRIPTION="Tenstorrent System Management Interface"
HOMEPAGE="https://github.com/tenstorrent/tt-smi"

# If using PyPI
# inherit pypi and it will auto-generate SRC_URI

# If using GitHub releases:
SRC_URI="https://github.com/tenstorrent/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/click-8.0[${PYTHON_USEDEP}]
	>=dev-python/rich-13.0[${PYTHON_USEDEP}]
	>=dev-python/psutil-5.9[${PYTHON_USEDEP}]
	sys-kernel/tt-kmd
"

BDEPEND="
	dev-python/setuptools[${PYTHON_USEDEP}]
	dev-python/wheel[${PYTHON_USEDEP}]
"

distutils_enable_tests pytest

python_install_all() {
	distutils-r1_python_install_all

	# Install shell completions if available
	if [[ -f completions/tt-smi.bash ]]; then
		dobashcomp completions/tt-smi.bash
	fi
}

pkg_postinst() {
	elog "Tenstorrent SMI installed."
	elog "Run 'tt-smi' to view device status."
	elog ""
	elog "Make sure tt-kmd kernel module is loaded:"
	elog "  modprobe tenstorrent"
}
```

#### Alternative: Using pypi Eclass

```bash
# If tt-smi is available on PyPI, use pypi eclass for auto SRC_URI
EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..12} )

inherit distutils-r1 pypi

# pypi.eclass will automatically generate:
# SRC_URI="https://files.pythonhosted.org/packages/.../tt_smi-${PV}.tar.gz"
```

---

### 4. Python Package: dev-python/tt-flash

**Similar structure to tt-smi**

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..12} )

inherit distutils-r1

DESCRIPTION="Tenstorrent firmware flashing utility"
HOMEPAGE="https://github.com/tenstorrent/tt-flash"
SRC_URI="https://github.com/tenstorrent/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/click-8.0[${PYTHON_USEDEP}]
	>=dev-python/requests-2.28[${PYTHON_USEDEP}]
	sys-kernel/tt-kmd
"

distutils_enable_tests pytest
```

---

### 5. SFPI: dev-util/sfpi

**Source**: https://github.com/tenstorrent/sfpi
**Type**: Either Rust or Python (needs detection)
**Eclass**: `cargo` OR `distutils-r1`

#### Option A: If Rust Project

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

CRATES="
	# Generated by: cargo ebuild --manifest-path path/to/Cargo.toml
	# List all dependency crates here
"

inherit cargo

DESCRIPTION="Tenstorrent SFPI (SFP Interface) utility"
HOMEPAGE="https://github.com/tenstorrent/sfpi"
SRC_URI="
	https://github.com/tenstorrent/sfpi/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${CARGO_CRATE_URIS}
"

LICENSE="Apache-2.0"
# Add licenses for all Rust dependencies
LICENSE+=" MIT Unicode-DFS-2016"
SLOT="0"
KEYWORDS="~amd64"

QA_FLAGS_IGNORED="usr/bin/sfpi"

src_install() {
	cargo_src_install
	dodoc README.md
}
```

#### Option B: If Python Project

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..12} )

inherit distutils-r1

DESCRIPTION="Tenstorrent SFPI (SFP Interface) utility"
HOMEPAGE="https://github.com/tenstorrent/sfpi"
SRC_URI="https://github.com/tenstorrent/sfpi/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"

# Add Python dependencies as needed
```

---

### 6. Container Wrapper: app-containers/tt-metalium

**Source**: N/A (wrapper script)
**Type**: Podman container wrapper
**Eclass**: Standard ebuild

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

DESCRIPTION="Tenstorrent Metalium container wrapper for TT-NN development"
HOMEPAGE="https://github.com/tenstorrent/tt-metal"

# No source tarball needed - we create the wrapper script
LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+models"

RDEPEND="
	app-containers/podman
	sys-kernel/tt-kmd
	sys-apps/tt-system-tools
"

# Container image details
METALIUM_IMAGE_URL="ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-amd64"
METALIUM_IMAGE_TAG="latest-rc"
METALIUM_MODELS_IMAGE_URL="ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-models-amd64"

src_install() {
	# Create wrapper script for base metalium
	newbin - tt-metalium <<-EOF
		#!/bin/bash
		# Tenstorrent Metalium container wrapper (Gentoo package)

		METALIUM_IMAGE="${METALIUM_IMAGE_URL}:${METALIUM_IMAGE_TAG}"

		podman run --rm -it \\
			--privileged \\
			--volume=/dev/hugepages-1G:/dev/hugepages-1G \\
			--volume=\${HOME}:/home/user \\
			--device=/dev/tenstorrent:/dev/tenstorrent \\
			--workdir=/home/user \\
			--env=DISPLAY=\${DISPLAY} \\
			--env=HOME=/home/user \\
			--env=TERM=\${TERM:-xterm-256color} \\
			--network=host \\
			--security-opt label=disable \\
			--entrypoint /bin/bash \\
			\${METALIUM_IMAGE} "\$@"
	EOF

	if use models; then
		# Create wrapper for models container
		newbin - tt-metalium-models <<-EOF
			#!/bin/bash
			# Tenstorrent Metalium Models container wrapper

			METALIUM_IMAGE="${METALIUM_MODELS_IMAGE_URL}:${METALIUM_IMAGE_TAG}"

			echo "===================================================================="
			echo "NOTE: This container tool for tt-metalium is meant to enable"
			echo "      users to try out demos, not for production use."
			echo "===================================================================="

			podman run --rm -it \\
				--privileged \\
				--volume=/dev/hugepages-1G:/dev/hugepages-1G \\
				--device=/dev/tenstorrent:/dev/tenstorrent \\
				--env=DISPLAY=\${DISPLAY} \\
				--env=HOME=/home/user \\
				--env=TERM=\${TERM:-xterm-256color} \\
				--network=host \\
				--security-opt label=disable \\
				--entrypoint /bin/bash \\
				\${METALIUM_IMAGE} "\$@"
		EOF
	fi
}

pkg_postinst() {
	elog "Tenstorrent Metalium container wrapper installed."
	elog ""
	elog "Pulling container image on first run..."
	podman pull "${METALIUM_IMAGE_URL}:${METALIUM_IMAGE_TAG}" || \
		ewarn "Failed to pull container. It will be pulled on first use."

	if use models; then
		elog "Pulling models container image..."
		podman pull "${METALIUM_MODELS_IMAGE_URL}:${METALIUM_IMAGE_TAG}" || \
			ewarn "Failed to pull models container. It will be pulled on first use."
	fi

	elog ""
	elog "Usage:"
	elog "  tt-metalium              # Start interactive shell"
	elog "  tt-metalium python3      # Run Python"
	elog "  tt-metalium 'ls -la'     # Run command"

	if use models; then
		elog "  tt-metalium-models       # Models container"
	fi
}
```

---

### 7. Meta Package: virtual/tenstorrent

**Purpose**: Pull in the complete Tenstorrent stack with one command

```bash
# Copyright 2025 Gentoo Authors
# Distributed under the terms of the Apache License v2.0

EAPI=8

DESCRIPTION="Virtual package for the complete Tenstorrent software stack"
HOMEPAGE="https://www.tenstorrent.com/"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+flash +smi +topology +metalium +inference-server openrc systemd"
REQUIRED_USE="|| ( openrc systemd )"

RDEPEND="
	sys-kernel/tt-kmd
	sys-apps/tt-system-tools[openrc?,systemd?]
	dev-util/sfpi

	flash? ( dev-python/tt-flash )
	smi? ( dev-python/tt-smi )
	topology? ( dev-python/tt-topology )
	metalium? ( app-containers/tt-metalium )
	inference-server? ( dev-python/tt-inference-server )
"
```

#### Usage

```bash
# Install complete stack with defaults
emerge virtual/tenstorrent

# Install with custom USE flags
USE="openrc -systemd -metalium" emerge virtual/tenstorrent

# Install just SMI tools (minimal)
emerge sys-kernel/tt-kmd sys-apps/tt-system-tools dev-python/tt-smi
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (Weeks 1-2)
1. ✅ Create overlay directory structure
2. ✅ Set up repository metadata (layout.conf, repo_name, etc.)
3. ✅ Create sys-kernel/tt-kmd ebuild
4. ✅ Test kernel module installation and loading
5. ✅ Submit kernel module ebuild to GURU (optional)

### Phase 2: System Services (Weeks 3-4)
1. ✅ Create sys-apps/tt-system-tools ebuild
2. ✅ Write OpenRC init scripts
3. ✅ Test systemd unit files
4. ✅ Test HugePages configuration on both init systems
5. ✅ Verify automatic service startup

### Phase 3: Python Packages (Weeks 5-6)
1. ✅ Create dev-python/tt-smi ebuild
2. ✅ Create dev-python/tt-flash ebuild
3. ✅ Create dev-python/tt-topology ebuild (optional)
4. ✅ Test Python package installations
5. ✅ Verify command-line tools work

### Phase 4: Additional Tools (Week 7)
1. ✅ Determine SFPI build system (Rust vs Python)
2. ✅ Create dev-util/sfpi ebuild
3. ✅ Test SFPI installation
4. ✅ Create dev-python/tt-inference-server ebuild

### Phase 5: Containers & Meta-Package (Week 8)
1. ✅ Create app-containers/tt-metalium wrapper ebuild
2. ✅ Test container pull and execution
3. ✅ Create virtual/tenstorrent meta-package
4. ✅ Test full stack installation

### Phase 6: Documentation & Release (Week 9)
1. ✅ Write README for overlay
2. ✅ Document USE flags and configuration
3. ✅ Create installation guide
4. ✅ Test on clean Gentoo installation
5. ✅ Submit to GURU repository

---

## Testing Strategy

### Test Matrix

| Component | systemd | OpenRC | Stage3 | Hardened |
|-----------|---------|--------|--------|----------|
| tt-kmd    | ✓       | ✓      | ✓      | ?        |
| tt-system-tools | ✓ | ✓      | ✓      | ?        |
| tt-smi    | ✓       | ✓      | ✓      | ✓        |
| tt-flash  | ✓       | ✓      | ✓      | ✓        |
| sfpi      | ✓       | ✓      | ✓      | ?        |
| tt-metalium | ✓     | ✓      | ✓      | ?        |

### Test Procedures

#### Basic Installation Test
```bash
# Add overlay
eselect repository add tenstorrent git https://github.com/tsingletaryTT/tenstorrent-overlay.git
emaint sync -r tenstorrent

# Install full stack
emerge -av virtual/tenstorrent

# Verify
lsmod | grep tenstorrent
tt-smi
mount | grep hugepages
```

#### Kernel Rebuild Test
```bash
# Upgrade kernel
emerge -u gentoo-sources
eselect kernel set <new-kernel>

# Module should auto-rebuild
emerge @module-rebuild

# Verify
modinfo tenstorrent
```

#### USE Flag Test
```bash
# Test different configurations
USE="openrc -systemd" emerge virtual/tenstorrent
USE="systemd -openrc metalium models" emerge virtual/tenstorrent
USE="-flash -topology" emerge virtual/tenstorrent
```

---

## Maintenance & Versioning Strategy

### Version Bumping Process

1. **Monitor Upstream Releases**
   - Watch GitHub repositories for new tags
   - Subscribe to release notifications

2. **Create New Ebuild**
   ```bash
   cd tenstorrent-overlay/sys-kernel/tt-kmd
   cp tt-kmd-1.34.ebuild tt-kmd-1.35.ebuild
   # Edit version-specific details
   ebuild tt-kmd-1.35.ebuild manifest
   ```

3. **Test New Version**
   ```bash
   emerge -av =sys-kernel/tt-kmd-1.35
   ```

4. **Commit & Push**
   ```bash
   git add sys-kernel/tt-kmd/
   git commit -m "sys-kernel/tt-kmd: version bump to 1.35"
   git push
   ```

### Dependency Management

#### Tracking Python Dependencies

For Python packages, use `pyproject2setuptools` or manual inspection:

```bash
# Clone repository
git clone https://github.com/tenstorrent/tt-smi.git
cd tt-smi

# Check dependencies in pyproject.toml or setup.py
cat pyproject.toml | grep dependencies

# Add to ebuild RDEPEND
```

#### Tracking Rust Dependencies

For Rust packages, use `cargo ebuild`:

```bash
# Install cargo-ebuild tool
cargo install cargo-ebuild

# Generate ebuild with crate list
cargo ebuild --manifest-path sfpi/Cargo.toml

# Copy CRATES section to ebuild
```

---

## Overlay Publishing & Distribution

### GitHub Repository Setup

```bash
# Create overlay repository
mkdir tenstorrent-overlay
cd tenstorrent-overlay
git init

# Add all ebuilds and metadata
git add profiles/ metadata/ sys-kernel/ sys-apps/ dev-python/ dev-util/ app-containers/ virtual/

# Initial commit
git commit -m "Initial commit: Tenstorrent overlay for Gentoo"

# Push to GitHub
git remote add origin https://github.com/tsingletaryTT/tenstorrent-overlay.git
git push -u origin main
```

### User Installation Instructions

Create `README.md` for overlay:

```markdown
# Tenstorrent Overlay for Gentoo Linux

Official Gentoo overlay for Tenstorrent AI accelerator software stack.

## Installation

### Using eselect repository (recommended)

\`\`\`bash
# Add repository
eselect repository add tenstorrent git https://github.com/tsingletaryTT/tenstorrent-overlay.git

# Sync
emaint sync -r tenstorrent
\`\`\`

### Manual installation

\`\`\`bash
# Create repos.conf entry
mkdir -p /etc/portage/repos.conf/

cat > /etc/portage/repos.conf/tenstorrent.conf << EOF
[tenstorrent]
location = /var/db/repos/tenstorrent
sync-type = git
sync-uri = https://github.com/tsingletaryTT/tenstorrent-overlay.git
auto-sync = yes
EOF

# Sync
emaint sync -r tenstorrent
\`\`\`

## Usage

### Install complete stack

\`\`\`bash
emerge -av virtual/tenstorrent
\`\`\`

### Install specific components

\`\`\`bash
# Kernel module only
emerge sys-kernel/tt-kmd

# SMI tools
emerge dev-python/tt-smi

# Metalium container
emerge app-containers/tt-metalium
\`\`\`

### USE Flags

- `systemd` - Install systemd service files
- `openrc` - Install OpenRC init scripts
- `flash` - Include tt-flash firmware utility
- `smi` - Include system management interface
- `topology` - Include topology tools (Wormhole)
- `metalium` - Include Metalium container wrapper
- `models` - Include model demos container (large)

## Requirements

- Kernel with CONFIG_MODULES and CONFIG_HUGETLBFS
- Tenstorrent AI accelerator hardware
- ~amd64 architecture

## Support

- Issues: https://github.com/tsingletaryTT/tenstorrent-overlay/issues
- Upstream: https://github.com/tenstorrent/
\`\`\`

---

## GURU Submission Process

### Why Submit to GURU?

[GURU](https://wiki.gentoo.org/wiki/Project:GURU) (Gentoo User Repository) is the official community-maintained overlay. Benefits:

1. **Official Recognition**: Listed on Gentoo's repository list
2. **Community Review**: Other developers review your ebuilds
3. **Increased Visibility**: More users discover your packages
4. **CI/CD**: Automatic testing via Gentoo's infrastructure
5. **Credibility**: Association with official Gentoo project

### Prerequisites for GURU Submission

1. ✅ All ebuilds pass `pkgcheck scan`
2. ✅ Follow Gentoo ebuild standards (EAPI 8, proper licenses, etc.)
3. ✅ metadata.xml for all packages
4. ✅ Manifests generated (`ebuild <package>.ebuild manifest`)
5. ✅ Tested on at least one system
6. ✅ Proper commit messages (see Gentoo's commit policy)

### Submission Steps

1. **Fork GURU Repository**
   ```bash
   # Clone GURU
   git clone https://anongit.gentoo.org/git/repo/proj/guru.git
   cd guru
   ```

2. **Add Your Packages**
   ```bash
   # Copy your ebuilds to GURU structure
   cp -r ~/tenstorrent-overlay/sys-kernel/tt-kmd sys-kernel/
   cp -r ~/tenstorrent-overlay/dev-python/tt-smi dev-python/
   # etc.
   ```

3. **Validate with pkgcheck**
   ```bash
   pkgcheck scan sys-kernel/tt-kmd
   pkgcheck scan dev-python/tt-smi
   ```

4. **Commit with Proper Format**
   ```bash
   git add sys-kernel/tt-kmd
   git commit -s -m "sys-kernel/tt-kmd: new package, add 1.34"
   ```

5. **Submit Pull Request**
   - Push to your GitHub fork
   - Create PR on GURU repository
   - Wait for maintainer review

### Commit Message Format

```
category/package: action, version information

Optional longer description explaining the package,
why it's useful, any special considerations.

Bug: https://bugs.gentoo.org/123456 (if applicable)
Signed-off-by: Your Name <your.email@example.com>
```

Example:
```
sys-kernel/tt-kmd: new package, add 1.34

Tenstorrent Kernel Mode Driver for AI accelerator hardware.
Provides device interface via /dev/tenstorrent and manages
PCIe communication and memory resources.

Signed-off-by: Tenstorrent Developer <dev@tenstorrent.com>
```

---

## Advanced Topics

### Binary Package Generation

For faster deployment across multiple machines:

```bash
# On build host
FEATURES="buildpkg" emerge virtual/tenstorrent

# Copy packages to other machines
rsync -av /var/cache/binpkgs/ other-machine:/var/cache/binpkgs/

# On other machines
emerge -avK virtual/tenstorrent  # -K = use binpkgs if available
```

### Crossdev Support

For cross-compilation to other architectures:

```bash
# Set up crossdev for aarch64
crossdev -t aarch64-unknown-linux-gnu

# Cross-compile tt-kmd for ARM64
aarch64-unknown-linux-gnu-emerge sys-kernel/tt-kmd
```

### Slotting & Co-Installation

If multiple versions need to coexist:

```ebuild
# In tt-kmd ebuild
SLOT="${PV%%.*}"  # Slot by major version: 1.x -> SLOT="1", 2.x -> SLOT="2"

# Users can install multiple versions:
# emerge =sys-kernel/tt-kmd-1.34:1
# emerge =sys-kernel/tt-kmd-2.0:2
```

---

## Summary & Next Steps

### What You Get with Ebuilds

1. **Native Integration**: Full Gentoo package management support
2. **Automatic Updates**: `emerge -u world` updates Tenstorrent packages
3. **Dependency Tracking**: Portage manages all dependencies
4. **Clean Removal**: `emerge --depclean` removes unused packages
5. **Configuration Management**: Protected config files with `etc-update`
6. **Init System Integration**: Proper systemd/OpenRC support
7. **Kernel Integration**: Automatic module rebuilds on kernel updates

### Effort Estimates

| Component | Complexity | Time | Priority |
|-----------|-----------|------|----------|
| tt-kmd | Medium | 8-16 hours | High |
| tt-system-tools | Medium | 8-16 hours | High |
| tt-smi | Low | 4-8 hours | High |
| tt-flash | Low | 4-8 hours | Medium |
| tt-topology | Low | 4-8 hours | Low |
| sfpi | Medium | 6-12 hours | Medium |
| tt-metalium | Low | 4-6 hours | Medium |
| tt-inference-server | Low | 4-8 hours | Low |
| Meta-package | Low | 2-4 hours | Medium |
| Documentation | Medium | 8-16 hours | High |
| Testing | High | 16-24 hours | High |
| GURU Submission | Medium | 8-16 hours | Medium |
| **TOTAL** | - | **80-160 hours** | - |

### Recommended Starting Point

1. **Start Simple**: Begin with tt-kmd ebuild only
2. **Test Thoroughly**: Ensure kernel module works on systemd and OpenRC
3. **Iterate**: Add one package at a time
4. **Get Feedback**: Share with Gentoo community early
5. **Document**: Write clear installation instructions

### Decision: Ebuild vs Script?

**Keep Both!**

- **Script Installer**: Quick, works across distros, good for new users
- **Ebuild Overlay**: Proper Gentoo integration, better for production

**Script can detect ebuilds**:
```bash
if emerge --pretend virtual/tenstorrent &>/dev/null; then
    log "Gentoo overlay detected! Recommend using: emerge virtual/tenstorrent"
    if confirm "Use native Gentoo packages instead of script?"; then
        exec emerge -av virtual/tenstorrent
    fi
fi
```

---

## Resources & References

### Gentoo Documentation
- [Ebuild Writing Guide](https://devmanual.gentoo.org/)
- [linux-mod-r1 eclass](https://devmanual.gentoo.org/eclass-reference/linux-mod-r1.eclass/index.html)
- [distutils-r1 eclass](https://dev.gentoo.org/~mgorny/python-guide/distutils.html)
- [systemd Integration](https://wiki.gentoo.org/wiki/Systemd)
- [OpenRC Service Scripts](https://wiki.gentoo.org/wiki/OpenRC)
- [GURU Project](https://wiki.gentoo.org/wiki/Project:GURU)

### Tools
- `pkgcheck` - Ebuild linting and validation
- `repoman` - Repository QA tool (deprecated, use pkgcheck)
- `ebuild` - Manual ebuild processing
- `cargo-ebuild` - Generate Rust ebuilds
- `pycargoebuild` - Generate Python+Rust ebuilds

### Example Overlays
- [GURU Repository](https://gitweb.gentoo.org/repo/proj/guru.git/)
- [Gentoo Science](https://github.com/gentoo/sci)
- [Gentoo NVIDIA](https://github.com/gentoo/nvidia)

---

**This plan provides a complete roadmap from concept to production-ready Gentoo ebuilds. Start with Phase 1 (tt-kmd) and iterate!**
