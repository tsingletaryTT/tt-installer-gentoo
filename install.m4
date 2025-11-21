#!/bin/bash
# shellcheck disable=SC2317

# SPDX-FileCopyrightText: © 2025 Tenstorrent AI ULC
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# m4_ignore(
echo "This is just a script template, not the script (yet) - pass it to 'argbash' to fix this." >&2
exit 11 #)
# ARG_HELP([A one-stop-shop for installing the Tenstorrent stack])
# ARG_VERSION([echo "__INSTALLER_DEVELOPMENT_BUILD__"])
# ========================= Boolean Arguments =========================
# ARG_OPTIONAL_BOOLEAN([install-kmd],,[Kernel-Mode-Driver installation],[on])
# ARG_OPTIONAL_BOOLEAN([install-hugepages],,[Configure HugePages],[on])
# ARG_OPTIONAL_BOOLEAN([install-podman],,[Install Podman],[on])
# ARG_OPTIONAL_BOOLEAN([install-metalium-container],,[Download and install Metalium container],[on])
# ARG_OPTIONAL_BOOLEAN([install-tt-flash],,[Install tt-flash for updating device firmware],[on])
# ARG_OPTIONAL_BOOLEAN([install-tt-topology],,[Install tt-topology (Wormhole only)],[off])
# ARG_OPTIONAL_BOOLEAN([install-sfpi],,[Install SFPI],[on])
# ARG_OPTIONAL_BOOLEAN([install-inference-server],,[Install tt-inference-server],[on])

# =========================  Podman Metalium Arguments =========================
# ARG_OPTIONAL_SINGLE([metalium-image-url],,[Container image URL to pull/run],[ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-amd64])
# ARG_OPTIONAL_SINGLE([metalium-image-tag],,[Tag (version) of the Metalium image],[latest-rc])
# ARG_OPTIONAL_SINGLE([podman-metalium-script-dir],,[Directory where the helper wrapper will be written],["$HOME/.local/bin"])
# ARG_OPTIONAL_SINGLE([podman-metalium-script-name],,[Name of the helper wrapper script],["tt-metalium"])
# ARG_OPTIONAL_BOOLEAN([install-metalium-models-container],,[Install additional TT-Metalium container for running model demos],[off])

# ========================= String Arguments =========================
# ARG_OPTIONAL_SINGLE([python-choice],,[Python setup strategy: active-venv, new-venv, system-python, pipx],[new-venv])
# ARG_OPTIONAL_SINGLE([reboot-option],,[Reboot policy after install: ask, never, always],[ask])
# ARG_OPTIONAL_SINGLE([update-firmware],,[Update TT device firmware: on, off, force],[on])
# ARG_OPTIONAL_SINGLE([github-token],,[Optional GitHub API auth token],[])

# ========================= Version Arguments =========================
# ARG_OPTIONAL_SINGLE([kmd-version],,[Specific version of TT-KMD to install],[])
# ARG_OPTIONAL_SINGLE([fw-version],,[Specific version of firmware to install],[])
# ARG_OPTIONAL_SINGLE([systools-version],,[Specific version of system tools to install],[])
# ARG_OPTIONAL_SINGLE([smi-version],,[Specific version of tt-smi to install],[])
# ARG_OPTIONAL_SINGLE([flash-version],,[Specific version of tt-flash to install],[])
# ARG_OPTIONAL_SINGLE([topology-version],,[Specific version of tt-topology to install],[])
# ARG_OPTIONAL_SINGLE([sfpi-version],,[Specific version of SFPI to install],[])

# ========================= Path Arguments =========================
# ARG_OPTIONAL_SINGLE([new-venv-location],,[Path for new Python virtual environment],[$HOME/.tenstorrent-venv])

# ========================= Mode Arguments =========================
# ARG_OPTIONAL_BOOLEAN([mode-container],,[Enable container mode (skips KMD, HugePages, and SFPI, never reboots)],[off])
# ARG_OPTIONAL_BOOLEAN([mode-non-interactive],,[Enable non-interactive mode (no user prompts)],[off])
# ARG_OPTIONAL_BOOLEAN([verbose],,[Enable verbose output for debugging])
# ARG_OPTIONAL_BOOLEAN([mode-repository-beta],,[BETA: Use external repository for package installation.],[off])

# ARGBASH_GO

# [ <-- needed because of Argbash

# Logo
# Credit: figlet font slant by Glenn Chappell
LOGO=$(cat << "EOF"
   __                  __                             __
  / /____  ____  _____/ /_____  _____________  ____  / /_
 / __/ _ \/ __ \/ ___/ __/ __ \/ ___/ ___/ _ \/ __ \/ __/
/ /_/  __/ / / (__  ) /_/ /_/ / /  / /  /  __/ / / / /_
\__/\___/_/ /_/____/\__/\____/_/  /_/   \___/_/ /_/\__/
EOF
)

KERNEL_LISTING_DEBIAN=$( cat << EOF
	apt list --installed |
	grep linux-image |
	awk 'BEGIN { FS="/"; } { print \$1; }' |
	sed 's/^linux-image-//g' |
	grep -v "^generic$\|^generic-hwe-[0-9]\{2,\}\.[0-9]\{2,\}$\|virtual"
EOF
)

KERNEL_LISTING_UBUNTU=$( cat << EOF
	apt list --installed |
	grep linux-image |
	awk 'BEGIN { FS="/"; } { print \$1; }' |
	sed 's/^linux-image-//g' |
	grep -v "^generic$\|^generic-hwe-[0-9]\{2,\}\.[0-9]\{2,\}$\|virtual"
EOF
)
KERNEL_LISTING_FEDORA="rpm -qa | grep \"^kernel.*-devel\" | grep -v \"\-devel-matched\" | sed 's/^kernel-devel-//'"
KERNEL_LISTING_EL="rpm -qa | grep \"^kernel.*-devel\" | grep -v \"\-devel-matched\" | sed 's/^kernel-devel-//'"
# Gentoo: List installed kernel versions from /lib/modules
# Exclude .old backups and sort by version number
KERNEL_LISTING_GENTOO="ls /lib/modules | grep -v '.old$' | sort -V"

# ========================= GIT URLs =========================

# ========================= Repository Configuration =========================

# GitHub repository URLs
TT_KMD_GH_REPO="tenstorrent/tt-kmd"
TT_FW_GH_REPO="tenstorrent/tt-firmware"
TT_SYSTOOLS_GH_REPO="tenstorrent/tt-system-tools"
TT_SMI_GH_REPO="tenstorrent/tt-smi"
TT_FLASH_GH_REPO="tenstorrent/tt-flash"
TT_TOPOLOGY_GH_REPO="tenstorrent/tt-topology"
TT_SFPI_GH_REPO="tenstorrent/sfpi"

# ========================= Backward Compatibility Environment Variables =========================

# Support environment variables as fallbacks for backward compatibility
# If env var is set, use it; otherwise use argbash value with default

# Podman Metalium URLs and Settings
METALIUM_IMAGE_URL="${TT_METALIUM_IMAGE_URL:-${_arg_metalium_image_url}}"
METALIUM_IMAGE_TAG="${TT_METALIUM_IMAGE_TAG:-${_arg_metalium_image_tag}}"
PODMAN_METALIUM_SCRIPT_DIR="${TT_PODMAN_METALIUM_SCRIPT_DIR:-${_arg_podman_metalium_script_dir}}"
PODMAN_METALIUM_SCRIPT_NAME="${TT_PODMAN_METALIUM_SCRIPT_NAME:-${_arg_podman_metalium_script_name}}"

# String Parameters - use env var if set, otherwise argbash value
PYTHON_CHOICE="${TT_PYTHON_CHOICE:-${_arg_python_choice}}"
REBOOT_OPTION="${TT_REBOOT_OPTION:-${_arg_reboot_option}}"

# Path Parameters - use env var if set, otherwise argbash value
NEW_VENV_LOCATION="${TT_NEW_VENV_LOCATION:-${_arg_new_venv_location}}"

# Boolean Parameters - support legacy env vars for backward compatibility
# Convert env vars to argbash format if they exist
if [[ -n "${TT_INSTALL_KMD:-}" ]]; then
	if [[ "${TT_INSTALL_KMD}" == "true" || "${TT_INSTALL_KMD}" == "0" || "${TT_INSTALL_KMD}" == "on" ]]; then
		_arg_install_kmd="on"
	else
		_arg_install_kmd="off"
	fi
fi

if [[ -n "${TT_INSTALL_HUGEPAGES:-}" ]]; then
	if [[ "${TT_INSTALL_HUGEPAGES}" == "true" || "${TT_INSTALL_HUGEPAGES}" == "0" || "${TT_INSTALL_HUGEPAGES}" == "on" ]]; then
		_arg_install_hugepages="on"
	else
		_arg_install_hugepages="off"
	fi
fi

if [[ -n "${TT_INSTALL_PODMAN:-}" ]]; then
	if [[ "${TT_INSTALL_PODMAN}" == "true" || "${TT_INSTALL_PODMAN}" == "0" || "${TT_INSTALL_PODMAN}" == "on" ]]; then
		_arg_install_podman="on"
	else
		_arg_install_podman="off"
	fi
fi

if [[ -n "${TT_INSTALL_METALIUM_CONTAINER:-}" ]]; then
	if [[ "${TT_INSTALL_METALIUM_CONTAINER}" == "true" || "${TT_INSTALL_METALIUM_CONTAINER}" == "0" || "${TT_INSTALL_METALIUM_CONTAINER}" == "on" ]]; then
		_arg_install_metalium_container="on"
	else
		_arg_install_metalium_container="off"
	fi
fi

if [[ -n "${TT_UPDATE_FIRMWARE:-}" ]]; then
	if [[ "${TT_UPDATE_FIRMWARE}" == "true" || "${TT_UPDATE_FIRMWARE}" == "0" || "${TT_UPDATE_FIRMWARE}" == "on" ]]; then
		_arg_update_firmware="on"
	else
		_arg_update_firmware="off"
	fi
fi

if [[ -n "${TT_MODE_NON_INTERACTIVE:-}" ]]; then
	if [[ "${TT_MODE_NON_INTERACTIVE}" == "true" || "${TT_MODE_NON_INTERACTIVE}" == "0" || "${TT_MODE_NON_INTERACTIVE}" == "on" ]]; then
		_arg_mode_non_interactive="on"
	else
		_arg_mode_non_interactive="off"
	fi
fi

# If container mode is enabled, disable KMD, HugePages, and SFPI
# shellcheck disable=SC2154
if [[ "${_arg_mode_container}" = "on" ]]; then
	_arg_install_kmd="off"
	_arg_install_hugepages="off" # Both KMD and HugePages must live on the host kernel
	_arg_install_podman="off" # No podman in podman
	_arg_install_sfpi="off"
	REBOOT_OPTION="never" # Do not reboot
fi

# In non-interactive mode, set reboot default if not specified
if [[ "${_arg_mode_non_interactive}" = "on" ]]; then
	# In non-interactive mode, we can't ask the user for anything
	# So if they don't provide a reboot choice we will pick a default
	if [[ "${REBOOT_OPTION}" = "ask" ]]; then
		REBOOT_OPTION="never" # Do not reboot
	fi
fi

# For the repository mode beta, we will disable the existing install functions
# and call a new function which installs the dependencies using the APT repo.
# shellcheck disable=SC2154
if [[ "${_arg_mode_repository_beta}" = "on" ]]; then
	_arg_install_hugepages="off"
	_arg_install_sfpi="off"
	_arg_install_kmd="off"
	export INSTALL_TT_REPOS="on"
	export INSTALL_SW_FROM_REPOS="on"
fi

SYSTEMD_NOW="${TT_SYSTEMD_NOW:---now}"
SYSTEMD_NO="${TT_SYSTEMD_NO:-1}"
PIPX_ENSUREPATH_EXTRAS="${TT_PIPX_ENSUREPATH_EXTRAS:- }"
PIPX_INSTALL_EXTRAS="${TT_PIPX_INSTALL_EXTRAS:- }"

# ========================= Main Script =========================

# Create working directory
TMP_DIR_TEMPLATE="tenstorrent_install_XXXXXX"
# Use mktemp to get a temporary directory
WORKDIR=$(mktemp -d -p /tmp "${TMP_DIR_TEMPLATE}")

# Initialize logging
LOG_FILE="${WORKDIR}/install.log"
# Redirect stdout to the logfile.
# Removes color codes and prepends the date
exec > >( \
		tee >( \
				stdbuf -o0 \
						sed 's/\x1B\[[0-9;]*[A-Za-z]//g' | \
						xargs -d '\n' -I {} date '+[%F %T] {}' \
				> "${LOG_FILE}" \
				) \
		)
exec 2>&1

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# argbash workaround: close square brackets ]]]]]

# log messages to terminal (with color)
log() {
	local msg="[INFO] $1"
	echo -e "${GREEN}${msg}${NC}"  # Color output to terminal
}

# log errors
error() {
	local msg="[ERROR] $1"
	echo -e "${RED}${msg}${NC}"
}

# log an error and then exit
error_exit() {
    error "$1"
    exit 1
}

# log warnings
warn() {
	local msg="[WARNING] $1"
	echo -e "${YELLOW}${msg}${NC}"
}

check_has_sudo_perms() {
	if ! sudo true; then
		error "Cannot use sudo, exiting..."
		exit 1
	fi
}

detect_distro() {
	# shellcheck disable=SC1091 # Always present
	if [[ -f /etc/os-release ]]; then
		. /etc/os-release
		DISTRO_ID=${ID}
		DISTRO_VERSION=${VERSION_ID}
		check_is_ubuntu_20

		# Gentoo-specific handling:
		# Gentoo doesn't provide a consistent VERSION_ID in /etc/os-release
		# Instead, we use the kernel version as a proxy for the system version
		# This is acceptable since Gentoo is a rolling release distribution
		if [[ "${DISTRO_ID}" = "gentoo" ]]; then
			DISTRO_VERSION=$(uname -r | cut -d'-' -f1)
			log "Detected Gentoo Linux (kernel version: ${DISTRO_VERSION})"
		fi
	else
		error "Cannot detect Linux distribution"
		exit 1
	fi
}

check_is_ubuntu_20() {
	# Check if it's Ubuntu and version starts with 20
	if [[ "${DISTRO_ID}" = "ubuntu" ]] && [[ "${DISTRO_VERSION}" == 20* ]]; then
		IS_UBUNTU_20=0 # Ubuntu 20.xx
	else
		IS_UBUNTU_20=1 # Not that
	fi
}

# Function to verify download
verify_download() {
	local file=$1
	if [[ ! -f "${file}" ]]; then
		error "Download failed: ${file} not found"
		exit 1
	fi
}

# Function to prompt for yes/no
confirm() {
	# In non-interactive mode, always return true
	if [[ "${_arg_mode_non_interactive}" = "on" ]]; then
		return 0
	fi

	while true; do
		read -rp "$1 [Y/n] " yn
		case ${yn} in
			[Nn]* ) echo && return 1;;
			[Yy]* | "" ) echo && return 0;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}

# Get Python installation choice interactively or use default
get_python_choice() {
	# In non-interactive mode, use the provided argument
	if [[ "${_arg_mode_non_interactive}" = "on" ]]; then
		log "Non-interactive mode, using Python installation method: ${_arg_python_choice}"
		return
	fi

	log "How would you like to install Python packages?"
	# Interactive mode - show current choice and allow override
	while true; do
		echo "1) active-venv: Use the active virtual environment"
		echo "2) new-venv: [DEFAULT] Create a new Python virtual environment (venv) at ${NEW_VENV_LOCATION}"
		echo "3) system-python: Use the system pathing, available for multiple users. *** NOT RECOMMENDED UNLESS YOU ARE SURE ***"
		if [[ "${IS_UBUNTU_20}" != "0" ]]; then
			echo "4) pipx: Use pipx for isolated package installation"
		fi
		read -rp "Enter your choice (1-4) or press enter for default (${_arg_python_choice}): " user_choice
		echo # newline

		# If user provided no value, use default and exit
		if [[ -z "${user_choice}" ]]; then
			break
		fi

		# Process user choice
		case "${user_choice}" in
			1|active-venv)
				PYTHON_CHOICE="active-venv"
				break
				;;
			2|new-venv)
				PYTHON_CHOICE="new-venv"
				break
				;;
			3|system-python)
				PYTHON_CHOICE="system-python"
				break
				;;
			4|pipx)
				PYTHON_CHOICE="pipx"
				break
				;;
			*)
				warn "Invalid choice '${user_choice}'. Please try again."
				;;
		esac
	done
}

# Generic function to fetch latest version from any GitHub repository
# Usage: fetch_latest_version <repo> <prefix_to_remove>
# Returns: version string with prefix removed, or exits with error code
fetch_latest_version() {
	local repo="$1"
	local prefix_to_remove="${2:-}"

	if ! command -v jq &> /dev/null; then
		return 1  # jq not installed
	fi

	local response
	local response_headers
	local response_body
	local latest_version

	# Curl options
	# We always suppress connect headers (fixes issues with systems using proxies)
	# -D - dumps the headers to stdout
	curl_opts=(--suppress-connect-headers -D -)

	# SC is worried this might not exist, but argbash guarantees it will
    # shellcheck disable=SC2154
	if [[ "${_arg_verbose}" = "on" ]]; then
		curl_opts+=(-v)
	else
		curl_opts+=(-s -S)
	fi

	if [[ -n "${_arg_github_token}" ]]; then
		curl_opts+=(-H "Authorization: token ${_arg_github_token}")
	fi

	response=$(curl "${curl_opts[@]}" \
		https://api.github.com/repos/"${repo}"/releases/latest)

	# Split at the first blank line
	response_headers=$(echo "${response}" | sed '/^\r*$/,$d')
	response_body=$(echo "${response}" | sed '1,/^\r*$/d')

	if [[ "${_arg_verbose}" = "on" ]]; then
		echo "=== GitHub API Response Headers ===" >&2
		echo "${response_headers}" >&2
		echo "=== GitHub API Response Body ===" >&2
		echo "${response_body}" >&2
		echo "===================================" >&2
	fi

	# Check for GitHub API rate limit
	if echo "${response_headers}" | grep -qi "x-ratelimit-remaining: 0"; then
		return 2  # GitHub API rate limit exceeded
	fi

	# Check if response body is valid JSON
	if ! echo "${response_body}" | jq . >/dev/null 2>&1; then
		return 3  # Invalid JSON response
	fi

	latest_version=$(echo "${response_body}" | jq -r '.tag_name' 2>/dev/null)

	# Check if we got a valid tag_name
	if [[ -z "${latest_version}" || "${latest_version}" == "null" ]]; then
		return 4  # No tag_name found
	fi

	# Remove prefix if specified
	if [[ -n "${prefix_to_remove}" ]]; then
		echo "${latest_version#"${prefix_to_remove}"}"
	else
		echo "${latest_version}"
	fi

	return 0
}

# Helper function to handle version fetch errors
handle_version_fetch_error() {
	local component="$1"
	local error_code="$2"
	local repo="$3"

	case ${error_code} in
		1)
			error "jq command not found!"
			error "Please ensure jq is installed: sudo apt install jq (or equivalent for your distro)"
			error "Failed to fetch ${component} version."
			;;
		2)
			error "GitHub API rate limit exceeded"
			error "You have exceeded the GitHub API rate limit (60 requests per hour for unauthenticated requests)"
			error "Repository: ${repo}"
			error "Failed to fetch ${component} version."
			;;
		3)
			error "GitHub API returned invalid JSON"
			error "This may be a network issue or other API issue"
			error "Repository: ${repo}"
			error "Failed to fetch ${component} version."
			;;
		4)
			error "No valid tag_name found in API response"
			error "The repository may not have any releases or the API response is malformed"
			error "Repository: ${repo}"
			error "Failed to fetch ${component} version."
			;;
		*)
			error "Unknown error (code ${error_code})"
			error "Repository: ${repo}"
			error "Failed to fetch ${component} version."
			;;
	esac
}

fetch_tt_sw_versions() {
	local fetch_errors=0

	# Component configuration: env_var:arg_var:version_var:display_name:repo:prefix
	local components=(
		"TT_KMD_VERSION:_arg_kmd_version:KMD_VERSION:TT-KMD:${TT_KMD_GH_REPO}:ttkmd-"
		"TT_FW_VERSION:_arg_fw_version:FW_VERSION:Firmware:${TT_FW_GH_REPO}:v"
		"TT_SYSTOOLS_VERSION:_arg_systools_version:SYSTOOLS_VERSION:System Tools:${TT_SYSTOOLS_GH_REPO}:v"
		"TT_SMI_VERSION:_arg_smi_version:SMI_VERSION:tt-smi:${TT_SMI_GH_REPO}:"
		"TT_FLASH_VERSION:_arg_flash_version:FLASH_VERSION:tt-flash:${TT_FLASH_GH_REPO}:"
		"TT_SFPI_VERSION:_arg_sfpi_version:SFPI_VERSION:SFPI:${TT_SFPI_GH_REPO}:v"
	)

	# Process each component
	for component_config in "${components[@]}"; do
		IFS=':' read -r env_var arg_var version_var display_name repo prefix <<< "${component_config}"

		# Use environment variable if set, then argbash version if present, otherwise latest
		if [[ -n "${!env_var:-}" ]]; then
			declare -g "${version_var}=${!env_var}"
		elif [[ -n "${!arg_var}" ]]; then
			declare -g "${version_var}=${!arg_var}"
		else
			local version_result
			if version_result=$(fetch_latest_version "${repo}" "${prefix}"); then
				declare -g "${version_var}=${version_result}"
			else
				local exit_code=$?
				handle_version_fetch_error "${display_name}" "${exit_code}" "${repo}"
				fetch_errors=1
			fi
		fi
	done

	# If there were fetch errors, exit early
	if [[ ${fetch_errors} -eq 1 ]]; then
		HAVE_SET_TT_SW_VERSIONS=1
		error "*** Failed to fetch software versions due to the errors above!"
		error_exit "Visit https://github.com/tenstorrent/tt-installer/wiki/Common-Problems#software-versions-are-empty-or-null for troubleshooting help."
	fi

	# Validate all version variables are properly set (not empty or "null")
	if [[ -n "${KMD_VERSION}" && "${KMD_VERSION}" != "null" && \
	      -n "${FW_VERSION}" && "${FW_VERSION}" != "null" && \
	      -n "${SYSTOOLS_VERSION}" && "${SYSTOOLS_VERSION}" != "null" && \
	      -n "${SMI_VERSION}" && "${SMI_VERSION}" != "null" && \
	      -n "${FLASH_VERSION}" && "${FLASH_VERSION}" != "null" && \
	      -n "${SFPI_VERSION}" && "${SFPI_VERSION}" != "null" ]]; then
		HAVE_SET_TT_SW_VERSIONS=0
		log "Using software versions:"
		log "  TT-KMD: ${KMD_VERSION}"
		log "  Firmware: ${FW_VERSION}"
		log "  System Tools: ${SYSTOOLS_VERSION}"
		log "  tt-smi: ${SMI_VERSION#v}"
		log "  tt-flash: ${FLASH_VERSION#v}"
		log "  SFPI: ${SFPI_VERSION#v}"
	else
		HAVE_SET_TT_SW_VERSIONS=1
		error "*** Software versions are empty or null after successful fetch!"
		error "  TT-KMD: '${KMD_VERSION}'"
		error "  Firmware: '${FW_VERSION}'"
		error "  System Tools: '${SYSTOOLS_VERSION}'"
		error "  tt-smi: '${SMI_VERSION}'"
		error "  tt-flash: '${FLASH_VERSION}'"
		error "  SFPI: '${SFPI_VERSION}'"
		error "This may indicate an issue with the GitHub API responses."
		error_exit "Visit https://github.com/tenstorrent/tt-installer/wiki/Common-Problems#software-versions-are-empty-or-null for a fix."
	fi
}

# Function to check if Podman is installed
check_podman_installed() {
	command -v podman &> /dev/null
}

# Function to install Podman
install_podman() {
	log "Installing Podman"
	cd "${WORKDIR}"

	# Add GUIDs/UIDs for rootless Podman
	# See https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
	sudo usermod --add-subgids 10000-75535 "$(whoami)"
	sudo usermod --add-subuids 10000-75535 "$(whoami)"

	# Install Podman using package manager
	case "${DISTRO_ID}" in
		"ubuntu"|"debian")
			sudo apt install -y podman podman-docker
			;;
		"fedora")
			sudo dnf install -y podman podman-docker
			;;
		"rhel"|"centos")
			sudo dnf install -y podman podman-docker
			;;
		"gentoo")
			# Gentoo: Install Podman via emerge (portage)
			# app-containers/podman includes all necessary dependencies
			# Note: Gentoo's podman package handles Docker compatibility automatically
			log "Installing Podman for Gentoo via emerge"

			# Gentoo Package Masking Issue:
			# Podman and many of its dependencies are often keyword-masked (~amd64)
			# on Gentoo, meaning they're marked as testing/unstable packages.
			# This is common for rapidly-evolving container technologies.
			#
			# We need to unmask these packages before installation by adding them
			# to /etc/portage/package.accept_keywords/
			#
			# Common podman dependencies that need unmasking:
			# - app-containers/podman (the main package)
			# - app-containers/netavark (network stack)
			# - app-containers/aardvark-dns (DNS for containers)
			# - app-containers/catatonit (init for containers)
			# - net-firewall/iptables (if masked)
			# - sys-apps/fuse-overlayfs (overlay filesystem support)

			log "Configuring package keywords for Podman and dependencies"

			# Create package.accept_keywords directory if it doesn't exist
			# This directory holds per-package keyword overrides
			sudo mkdir -p /etc/portage/package.accept_keywords

			# Create a dedicated file for Tenstorrent-related package keywords
			# Using a separate file makes it easy to track what we've changed
			# and allows for easy removal later if needed
			sudo tee /etc/portage/package.accept_keywords/tenstorrent-podman > /dev/null << 'EOF'
# Tenstorrent installer: Podman and dependencies
# These packages are required for tt-metalium container support
# Keyword acceptance (~amd64) allows installation of testing packages

# Main podman package
app-containers/podman ~amd64

# Container networking stack
app-containers/netavark ~amd64
app-containers/aardvark-dns ~amd64

# Container init system
app-containers/catatonit ~amd64

# Overlay filesystem support for container storage
sys-apps/fuse-overlayfs ~amd64

# Container runtime dependencies
app-containers/containers-common ~amd64
app-containers/containers-image ~amd64
app-containers/containers-storage ~amd64

# Networking dependencies
net-firewall/iptables ~amd64
sys-apps/iproute2 ~amd64

# Common Go dependencies that podman needs
dev-go/go-md2man ~amd64
EOF

			log "Package keywords configured, proceeding with installation"
			log "Note: This may take a while as Gentoo builds from source"

			# Now install podman with all dependencies unmasked
			# --ask=n suppresses interactive prompts
			# --verbose shows what's being installed
			# --autounmask-continue automatically handles any additional unmasking needed
			sudo emerge --ask=n --verbose --autounmask-continue app-containers/podman || {
				error "Podman installation failed"
				error "You may need to manually unmask additional packages"
				error "Check: emerge -pv app-containers/podman"
				return 1
			}

			# Gentoo's podman package may require additional post-install configuration
			# The package should handle most configuration automatically, but we log
			# a message in case users need to perform additional setup
			log "Podman installed successfully via portage"
			log "Note: If you encounter issues with rootless podman, check /etc/subuid and /etc/subgid"
			;;
		*)
			error "Unsupported distribution for Podman installation: ${DISTRO_ID}"
			return 1
			;;
	esac

	# Verify Podman installation
	if podman --version; then
		log "Podman installed successfully"
	else
		error "Podman installation failed"
		return 1
	fi

	return 0
}

# Install Podman Metalium container
install_podman_metalium() {
	log "Installing Metalium via Podman"

	# Create wrapper script directory
	mkdir -p "${PODMAN_METALIUM_SCRIPT_DIR}" || error_exit "Failed to create script directory"

	# Create wrapper script
	log "Creating wrapper script..."
	cat > "${PODMAN_METALIUM_SCRIPT_DIR}/${PODMAN_METALIUM_SCRIPT_NAME}" << EOF
#!/bin/bash
# Wrapper script for tt-metalium using Podman

# Image configuration
METALIUM_IMAGE="${METALIUM_IMAGE_URL}:${METALIUM_IMAGE_TAG}"

# Run the command using Podman

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

	# Make the script executable
	chmod +x "${PODMAN_METALIUM_SCRIPT_DIR}/${PODMAN_METALIUM_SCRIPT_NAME}" || error_exit "Failed to make script executable"

	# Check if the directory is in PATH
	if [[ ":${PATH}:" != *":${PODMAN_METALIUM_SCRIPT_DIR}:"* ]]; then
		warn "${PODMAN_METALIUM_SCRIPT_DIR} is not in your PATH."
		warn "A restart may fix this, or you may need to update your shell RC"
	fi

	# Pull the image
	log "Pulling the tt-metalium image (this may take a while)..."
	podman pull "${METALIUM_IMAGE_URL}:${METALIUM_IMAGE_TAG}" || error "Failed to pull image"

	log "Metalium installation completed"
	return 0
}

# Install Podman Metalium "models" container
install_podman_metalium_models() {
	log "Installing Metalium Models Container via Podman"
	local PODMAN_METALIUM_MODELS_SCRIPT_DIR="${HOME}/.local/bin"
	local PODMAN_METALIUM_MODELS_SCRIPT_NAME="tt-metalium-models"
	local METALIUM_MODELS_IMAGE_TAG="latest-rc"
	local METALIUM_MODELS_IMAGE_URL="ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-models-amd64"

	# Create wrapper script directory
	mkdir -p "${PODMAN_METALIUM_MODELS_SCRIPT_DIR}" || error_exit "Failed to create script directory"

	# Create wrapper script
	log "Creating wrapper script..."
	cat > "${PODMAN_METALIUM_MODELS_SCRIPT_DIR}/${PODMAN_METALIUM_MODELS_SCRIPT_NAME}" << EOF
#!/bin/bash
# Wrapper script for tt-metalium-models using Podman

echo "================================================================================"
echo "NOTE: This container tool for tt-metalium is meant to enable users to try out"
echo "      demos, and is not meant for production use. This container is liable to"
echo "      to change at anytime."
echo ""
echo "      For more information see https://github.com/tenstorrent/tt-metal/issues/25602"
echo "================================================================================"

# Image configuration
METALIUM_IMAGE="${METALIUM_MODELS_IMAGE_URL}:${METALIUM_MODELS_IMAGE_TAG}"

# Run the command using Podman
#
# Explaining some changes:
#  removal of --volume=\${HOME}:/home/user \\: the user in the upstream monster
#  container is user, and we put the source code in that user's directory, so
#  this would override it
#
#  removal of --workdir=/home/user \\: not super needed, but it's nice for
#  people to just be in the source code, ready to go
#
#  addition of --entrypoint /bin/bash: The current upstream container needs to
#  override the entrypoint. Why not just corral users into /bin/bash?
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

	# Make the script executable
	chmod +x "${PODMAN_METALIUM_MODELS_SCRIPT_DIR}/${PODMAN_METALIUM_MODELS_SCRIPT_NAME}" || error_exit "Failed to make script executable"

	# Check if the directory is in PATH
	if [[ ":${PATH}:" != *":${PODMAN_METALIUM_MODELS_SCRIPT_DIR}:"* ]]; then
		warn "${PODMAN_METALIUM_MODELS_SCRIPT_DIR} is not in your PATH."
		warn "A restart may fix this, or you may need to update your shell RC"
	fi

	# Pull the image
	log "Pulling the tt-metalium-models image (this may take a while)..."
	podman pull "${METALIUM_MODELS_IMAGE_URL}:${METALIUM_MODELS_IMAGE_TAG}" || error "Failed to pull image"

	log "Metalium Models installation completed"
	return 0
}

get_podman_metalium_choice() {
	# If we're on Ubuntu 20, Podman is not available - force disable
	if [[ "${IS_UBUNTU_20}" = "0" ]]; then
		_arg_install_metalium_container="off"
		_arg_install_metalium_models_container="off"
		_arg_install_podman="off"
		return
	fi
	# In non-interactive mode, use the provided arguments
	if [[ "${_arg_mode_non_interactive}" = "on" ]]; then
		log "Non-interactive mode, using Podman Metalium installation preference: ${_arg_install_metalium_container}"
		log "Non-interactive mode, using Metalium Models installation preference: ${_arg_install_metalium_models_container}"
		return
	fi
	# Only ask if Podman is installed or will be installed
	if [[ "${_arg_install_podman}" = "on" ]] || check_podman_installed; then
		# Interactive mode - allow override
		log "Would you like to install the TT-Metalium slim container?"
		log "This container is appropriate if you only need to use TT-NN"
		if confirm "Install Metalium"; then
			_arg_install_metalium_container="on"
		else
			_arg_install_metalium_container="off"
		fi
	else
		# Podman won't be installed, so don't install Metalium
		_arg_install_metalium_container="off"
		warn "Podman is not and will not be installed, skipping Podman Metalium installation"
	fi
	# Only ask if Podman is installed or will be installed
	if [[ "${_arg_install_podman}" = "on" ]] || check_podman_installed; then
		# Interactive mode - allow override
		log "Would you like to install the TT-Metalium Model Demos container?"
		log "This container is best for users who need more TT-Metalium functionality, such as running prebuilt models, but it's large (8GB)"
		if confirm "Install Metalium Models"; then
			_arg_install_metalium_models_container="on"
		else
			_arg_install_metalium_models_container="off"
		fi
	else
		# Podman won't be installed, so don't install Metalium
		_arg_install_metalium_models_container="off"
		warn "Podman is not and will not be installed, skipping Podman Metalium Models installation"
	fi

	# Disable Podman if both Metalium containers are disabled
	if [[ "${_arg_install_metalium_container}" = "off" ]] && [[ "${_arg_install_metalium_models_container}" = "off" ]]; then
		_arg_install_podman="off"
	fi
}

get_inference_server_choice() {
	# In non-interactive mode, use the provided argument
	if [[ "${_arg_mode_non_interactive}" = "on" ]]; then
		log "Non-interactive mode, using tt-inference-server installation preference: ${_arg_install_inference_server}"
		return
	fi

	# Interactive mode - allow override
	log "Would you like to install tt-inference-server?"
	log "This will clone the inference server repository to ~/.local/lib and create a wrapper script"
	if confirm "Install tt-inference-server"; then
		_arg_install_inference_server="on"
	else
		_arg_install_inference_server="off"
	fi
}

manual_install_kmd() {
log "Installing Kernel-Mode Driver"
	cd "${WORKDIR}"
	# Get the KMD version, if installed, while silencing errors
	if KMD_INSTALLED_VERSION=$(modinfo -F version tenstorrent 2>/dev/null); then
		warn "Found active KMD module, version ${KMD_INSTALLED_VERSION}."
		if confirm "Force KMD reinstall?"; then
			sudo dkms remove "tenstorrent/${KMD_INSTALLED_VERSION}" --all
			git clone --branch "ttkmd-${KMD_VERSION}" https://github.com/tenstorrent/tt-kmd.git
			sudo dkms add tt-kmd
			sudo dkms install "tenstorrent/${KMD_VERSION}"
			sudo modprobe tenstorrent
		else
			warn "Skipping KMD installation"
		fi
	else
		# Only install KMD if it's not already installed
		git clone --branch "ttkmd-${KMD_VERSION}" https://github.com/tenstorrent/tt-kmd.git
		sudo dkms add tt-kmd
		# Ok so this gets exciting fast, so hang on for a second while I explain
		# During the offline installer we need to figure out what kernels are actually installed
		# because the kernel running on the system is not what we just installed and it's going
		# to complain up a storm if we don't have the headers for the running kernel, which we don't
		# so lets start by figuring out what kernels we do have (packaging, we can do this by doing a
		# ls on /lib/modules too but right now I'm doing it this way, deal.
		# Then we wander through and do dkms for the installed kernels only.  After that instead of
		# trying to modprobe the module on a system we might not have built for, we check if we match
		# and only then try modprobe
		for x in $( eval "${KERNEL_LISTING}" )
		do
			sudo dkms install "tenstorrent/${KMD_VERSION}" -k "${x}"
			if [[ "$( uname -r )" == "${x}" ]]
			then
				sudo modprobe tenstorrent
			fi
		done
	fi
}

# Gentoo HugePages Installation - Source Build Approach
# This function attempts to build and install tt-system-tools from source
# for Gentoo systems. It detects whether systemd or OpenRC is in use and
# configures accordingly. Falls back to manual configuration if build fails.
manual_install_hugepages_gentoo_source() {
	log "Setting up HugePages for Gentoo (building from source)"
	cd "${WORKDIR}"

	# Clone the tt-system-tools repository at the specified version
	# This contains the HugePages configuration scripts and systemd/OpenRC units
	git clone --branch "v${SYSTOOLS_VERSION}" \
		https://github.com/tenstorrent/tt-system-tools.git
	cd tt-system-tools

	# Detect which init system is in use (systemd or OpenRC)
	# Gentoo supports both, so we need to handle each appropriately
	if command -v systemctl &> /dev/null && systemctl --version &> /dev/null 2>&1; then
		# Systemd is present and working
		log "Detected systemd, installing HugePages configuration for systemd"

		# Attempt to install using the project's Makefile
		# PREFIX=/usr ensures files are installed to standard system locations
		sudo make install PREFIX=/usr || {
			warn "Make install failed, falling back to manual configuration"
			manual_configure_hugepages_gentoo
			return
		}

		# Enable and start the tenstorrent-hugepages service
		# This service configures kernel parameters for HugePages at boot
		sudo systemctl enable tenstorrent-hugepages.service

		# Enable and start the hugepages mount unit
		# This mounts the 1GB hugepages filesystem at /dev/hugepages-1G
		sudo systemctl enable dev-hugepages-1G.mount

		# Try to start services immediately (|| true prevents script exit on failure)
		# Services may fail if hugepages aren't available yet, which is okay
		sudo systemctl start tenstorrent-hugepages.service || true
		sudo systemctl start dev-hugepages-1G.mount || true

		log "HugePages configuration installed via systemd"
	else
		# OpenRC is in use (Gentoo's traditional init system)
		log "Detected OpenRC, using manual HugePages configuration"
		warn "OpenRC support requires manual configuration (no packaged OpenRC service yet)"

		# Fall back to manual configuration for OpenRC systems
		# We don't have native OpenRC service scripts in tt-system-tools yet
		manual_configure_hugepages_gentoo
	fi
}

# Gentoo HugePages Manual Configuration
# This function manually configures HugePages when the source build approach
# doesn't work or when OpenRC is in use. It sets up kernel parameters,
# creates mount points, and configures either systemd or OpenRC appropriately.
manual_configure_hugepages_gentoo() {
	log "Configuring HugePages manually for Gentoo"

	# Configure kernel parameters for HugePages
	# These settings persist across reboots via /etc/sysctl.d/
	sudo mkdir -p /etc/sysctl.d

	# Create sysctl configuration file for HugePages
	# vm.nr_hugepages: Number of 2MB hugepages to reserve (2048 = 4GB)
	# vm.hugetlb_shm_group: Group ID that can use hugepages (0 = root)
	sudo tee /etc/sysctl.d/99-tenstorrent-hugepages.conf > /dev/null << EOF
# Tenstorrent HugePages Configuration
# Reserve 2048 hugepages (2MB each = 4GB total)
vm.nr_hugepages = 2048
# Allow root group to use hugepages
vm.hugetlb_shm_group = 0
EOF

	# Apply the sysctl settings immediately (without reboot)
	sudo sysctl -p /etc/sysctl.d/99-tenstorrent-hugepages.conf

	# Create mount point for 1GB hugepages
	# Tenstorrent hardware requires 1GB hugepages for optimal performance
	sudo mkdir -p /dev/hugepages-1G

	# Configure mounting based on init system
	if command -v systemctl &> /dev/null; then
		# Systemd: Create a systemd mount unit
		log "Creating systemd mount unit for 1GB hugepages"

		# Create systemd mount unit file
		# Unit files for mount points must be named after their mount path
		# with slashes replaced by hyphens
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

		# Reload systemd to recognize the new unit file
		sudo systemctl daemon-reload

		# Enable the mount unit to start at boot
		sudo systemctl enable dev-hugepages-1G.mount

		# Try to mount immediately (|| true prevents script exit on failure)
		# May fail if 1GB hugepages aren't supported by the hardware
		sudo systemctl start dev-hugepages-1G.mount || true

		log "Systemd mount unit created for 1GB hugepages"
	else
		# OpenRC: Add to /etc/fstab for automatic mounting at boot
		log "Adding hugepages to /etc/fstab for OpenRC"

		# Check if entry already exists to avoid duplicates
		if ! grep -q "/dev/hugepages-1G" /etc/fstab 2>/dev/null; then
			# Add hugepages mount to fstab
			# Format: filesystem mountpoint type options dump pass
			echo "hugetlbfs /dev/hugepages-1G hugetlbfs pagesize=1G 0 0" \
				| sudo tee -a /etc/fstab
		fi

		# Try to mount immediately
		# || warn ensures we inform the user if it fails but don't exit
		sudo mount /dev/hugepages-1G 2>/dev/null || \
			warn "Failed to mount hugepages, may need reboot or kernel with 1GB hugepage support"

		log "HugePages added to /etc/fstab for OpenRC"
	fi

	log "HugePages configured manually"
}

manual_install_hugepages() {
	log "Setting up HugePages"
	BASE_TOOLS_URL="https://github.com/tenstorrent/tt-system-tools/releases/download"
	case "${DISTRO_ID}" in
		"ubuntu"|"debian")
			TOOLS_FILENAME="tenstorrent-tools_${SYSTOOLS_VERSION}_all.deb"
			TOOLS_URL="${BASE_TOOLS_URL}/v${SYSTOOLS_VERSION}/${TOOLS_FILENAME}"
			curl -fsSLO "${TOOLS_URL}"
			verify_download "${TOOLS_FILENAME}"
			sudo dpkg -i "${TOOLS_FILENAME}"
			if [[ "${SYSTEMD_NO}" != 0 ]]
			then
				# adding quotes around SYSTEMD_NOW means they won't be
				# interpretted, which is exactly what we want them to be
				# shellcheck disable=2086
				sudo systemctl enable ${SYSTEMD_NOW} tenstorrent-hugepages.service
				# adding quotes around SYSTEMD_NOW means they won't be
				# interpretted, which is exactly what we want them to be
				# shellcheck disable=2086
				sudo systemctl enable ${SYSTEMD_NOW} 'dev-hugepages\x2d1G.mount'
			fi
			;;
		"fedora"|"rhel"|"centos")
			TOOLS_FILENAME="tenstorrent-tools-${SYSTOOLS_VERSION}-1.noarch.rpm"
			TOOLS_URL="${BASE_TOOLS_URL}/v${SYSTOOLS_VERSION}/${TOOLS_FILENAME}"
			curl -fsSLO "${TOOLS_URL}"
			verify_download "${TOOLS_FILENAME}"
			sudo dnf install -y "${TOOLS_FILENAME}"
			if [[ "${SYSTEMD_NO}" != 0 ]]
			then
				# adding quotes around SYSTEMD_NOW means they won't be
				# interpretted, which is exactly what we want them to be
				# shellcheck disable=2086
				sudo systemctl enable ${SYSTEMD_NOW} tenstorrent-hugepages.service
				# adding quotes around SYSTEMD_NOW means they won't be
				# interpretted, which is exactly what we want them to be
				# shellcheck disable=2086
				sudo systemctl enable ${SYSTEMD_NOW} 'dev-hugepages\x2d1G.mount'
			fi
			;;
		"gentoo")
			# Gentoo: Build and install from source
			# Gentoo doesn't have pre-built .deb or .rpm packages, so we build from source
			# This calls our helper function which handles both systemd and OpenRC
			log "Installing HugePages for Gentoo (source build)"
			manual_install_hugepages_gentoo_source
			;;
		*)
			error "This distro is unsupported. Skipping HugePages install!"
			;;
	esac
}

# Function to install SFPI
manual_install_sfpi() {
	log "Installing SFPI"
	local arch
	local SFPI_RELEASE_URL="https://github.com/tenstorrent/sfpi/releases/download"
	local SFPI_FILE_ARCH
	local SFPI_DISTRO_TYPE
	local SFPI_FILE_EXT
	local SFPI_FILE

	arch=$(uname -m)

	case "${arch}" in
		"aarch64"|"arm64")
			SFPI_FILE_ARCH="aarch64"
			;;
		"amd64"|"x86_64")
			SFPI_FILE_ARCH="x86_64"
			;;
		*)
			error "Unsupported architecture for SFPI installation: ${arch}"
			exit 1
			;;
	esac

	case "${DISTRO_ID}" in
		"debian"|"ubuntu")
			SFPI_FILE_EXT="deb"
			SFPI_DISTRO_TYPE="debian"
			;;
		"centos"|"fedora"|"rhel")
			SFPI_FILE_EXT="rpm"
			SFPI_DISTRO_TYPE="fedora"
			;;
		"gentoo")
			# Gentoo: Build SFPI from source
			# No pre-built packages are available for Gentoo, so we clone and build
			# SFPI (SFP Interface) is used for managing SFP modules on Tenstorrent hardware
			log "Building SFPI from source for Gentoo"
			cd "${WORKDIR}"

			# Clone the SFPI repository
			# First try to clone at the specified version tag
			# If that fails (version tag doesn't exist), clone the main branch
			log "Cloning SFPI repository (version ${SFPI_VERSION})..."
			if ! git clone --branch "${SFPI_VERSION}" \
				https://github.com/tenstorrent/sfpi.git 2>/dev/null; then
				warn "Failed to clone at version ${SFPI_VERSION}, trying main branch..."
				if ! git clone https://github.com/tenstorrent/sfpi.git 2>/dev/null; then
					error "Failed to clone SFPI repository from GitHub"
					error "Network issue or repository unavailable?"
					warn "Skipping SFPI installation - you can install it manually later"
					warn "Visit: https://github.com/tenstorrent/sfpi"
					return 0  # Don't fail the entire installation
				fi
			fi

			if [[ ! -d "sfpi" ]]; then
				error "SFPI directory not found after clone"
				warn "Skipping SFPI installation"
				return 0
			fi

			cd sfpi

			# Check if the specified SFPI version tag exists
			# If it does, checkout that version; otherwise use latest
			if git rev-parse "${SFPI_VERSION}" >/dev/null 2>&1; then
				git checkout "${SFPI_VERSION}"
				log "Checked out SFPI version ${SFPI_VERSION}"
			else
				warn "Version ${SFPI_VERSION} not found in repository, using latest commit"
			fi

			# Detect build system and build accordingly
			# SFPI could be either a Rust or Python project
			if [[ -f "Cargo.toml" ]]; then
				# Rust project: Build with cargo
				log "Detected Rust project (Cargo.toml), building with cargo"
				log "This may take a few minutes on first build..."

				if ! cargo build --release; then
					error "Cargo build failed for SFPI"
					warn "Skipping SFPI installation - you can build it manually later"
					warn "Directory: ${WORKDIR}/sfpi"
					return 0
				fi

				# Check if binary was actually built
				if [[ ! -f "target/release/sfpi" ]]; then
					error "SFPI binary not found after build"
					warn "Skipping SFPI installation"
					return 0
				fi

				# Install the compiled binary to /usr/local/bin
				# This location is typically in PATH and appropriate for local software
				sudo install -Dm755 target/release/sfpi /usr/local/bin/sfpi
				log "SFPI binary installed to /usr/local/bin/sfpi"

			elif [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
				# Python project: Install with pip/pipx
				log "Detected Python project, installing with pip"

				if ! ${PYTHON_INSTALL_CMD} . ; then
					error "Python package installation failed for SFPI"
					warn "Skipping SFPI installation - you can install it manually later"
					warn "Directory: ${WORKDIR}/sfpi"
					return 0
				fi

				log "SFPI Python package installed"

			else
				# Unknown build system
				error "Unknown SFPI build system (no Cargo.toml, setup.py, or pyproject.toml found)"
				warn "Contents of directory:"
				ls -la
				warn "Skipping SFPI installation - manual installation may be needed"
				return 0  # Don't fail entire installation
			fi

			log "SFPI built and installed from source successfully"
			return 0
			;;
		*)
			error "Unsupported distribution for SFPI installation: ${DISTRO_ID}"
			exit 1
			;;
	esac

	# The following code only runs for non-Gentoo distros (deb/rpm packages)
	# Gentoo returns early in the case above

	SFPI_FILE="sfpi_${SFPI_VERSION}_${SFPI_FILE_ARCH}_${SFPI_DISTRO_TYPE}.${SFPI_FILE_EXT}"
	log "Downloading ${SFPI_FILE}"

    # shellcheck disable=SC2154
	if [[ "${_arg_verbose}" = "on" ]]; then
		curl -fvSLO "${SFPI_RELEASE_URL}/${SFPI_VERSION}/${SFPI_FILE}"
	else
		curl -fsSLO "${SFPI_RELEASE_URL}/${SFPI_VERSION}/${SFPI_FILE}"
	fi

	verify_download "${SFPI_FILE}"

	case "${SFPI_FILE_EXT}" in
		"deb")
			sudo apt install -y "./${SFPI_FILE}"
			;;
		"rpm")
			sudo dnf install -y "./${SFPI_FILE}"
			;;
		*)
			error "Unexpected SFPI package file extension: '${SFPI_FILE_EXT}'"
			exit 1
			;;
	esac
}

# Install tt-metal (TT-Metalium source code) to ~/tt-metal
# This is the core TT-Metalium framework for development
# Standard TT devXP requires this in the user's home directory
install_tt_metal() {
	log "Installing tt-metal source code to ~/tt-metal"

	# Determine the actual user (not root) even when using sudo
	# This is critical because we want ~/tt-metal owned by the user, not root
	# SUDO_USER is set when using sudo, otherwise use current USER
	ACTUAL_USER="${SUDO_USER:-$USER}"
	ACTUAL_HOME=$(eval echo "~${ACTUAL_USER}")

	log "Installing for user: ${ACTUAL_USER}"
	log "Home directory: ${ACTUAL_HOME}"

	TT_METAL_DIR="${ACTUAL_HOME}/tt-metal"

	# Check if tt-metal already exists
	if [[ -d "${TT_METAL_DIR}" ]]; then
		warn "tt-metal directory already exists at ${TT_METAL_DIR}"

		# Check if it's a git repository
		if [[ -d "${TT_METAL_DIR}/.git" ]]; then
			log "Existing git repository found, updating..."
			# Run git operations as the actual user, not root
			if [[ -n "${SUDO_USER}" ]]; then
				sudo -u "${ACTUAL_USER}" bash -c "cd ${TT_METAL_DIR} && git fetch --all"
				sudo -u "${ACTUAL_USER}" bash -c "cd ${TT_METAL_DIR} && git pull"
			else
				cd "${TT_METAL_DIR}"
				git fetch --all
				git pull
			fi
			log "tt-metal updated from git"
		else
			warn "Existing tt-metal directory is not a git repository"
			warn "Skipping tt-metal installation to avoid overwriting"
			warn "Remove ${TT_METAL_DIR} manually if you want to reinstall"
			return 0
		fi
	else
		# Clone tt-metal as the actual user, not root
		log "Cloning tt-metal from GitHub (this may take a few minutes)..."

		# Run git clone as the actual user to ensure correct ownership
		if [[ -n "${SUDO_USER}" ]]; then
			# Using sudo, run as the actual user
			sudo -u "${ACTUAL_USER}" git clone https://github.com/tenstorrent/tt-metal.git "${TT_METAL_DIR}" || {
				error "Failed to clone tt-metal repository"
				warn "Skipping tt-metal installation"
				warn "You can manually clone it later with:"
				warn "  git clone https://github.com/tenstorrent/tt-metal.git ~/tt-metal"
				return 0
			}
		else
			# Not using sudo, just clone normally
			git clone https://github.com/tenstorrent/tt-metal.git "${TT_METAL_DIR}" || {
				error "Failed to clone tt-metal repository"
				warn "Skipping tt-metal installation"
				return 0
			}
		fi

		log "tt-metal cloned successfully to ${TT_METAL_DIR}"
	fi

	# Verify ownership is correct (should be owned by actual user, not root)
	OWNER=$(stat -c '%U' "${TT_METAL_DIR}" 2>/dev/null || stat -f '%Su' "${TT_METAL_DIR}" 2>/dev/null)
	if [[ "${OWNER}" != "${ACTUAL_USER}" ]]; then
		warn "tt-metal directory owner is ${OWNER}, expected ${ACTUAL_USER}"
		warn "Fixing ownership..."
		sudo chown -R "${ACTUAL_USER}:${ACTUAL_USER}" "${TT_METAL_DIR}"
	fi

	log "tt-metal is ready at ${TT_METAL_DIR}"
	log "To build tt-metal, see: ${TT_METAL_DIR}/README.md"
	log "Standard TT development workflow uses this directory"
	log ""
	log "Quick start:"
	log "  cd ~/tt-metal"
	log "  # Follow build instructions in README.md"

	return 0
}

install_tt_repos () {
	log "Installing TT repositories to your distribution package manager"
	case "${DISTRO_ID}" in
		"ubuntu"|"debian")
			# Add the apt listing
			# shellcheck disable=2002
			echo "deb [signed-by=/etc/apt/keyrings/tt-pkg-key.asc] https://ppa.tenstorrent.com/ubuntu/ $( cat /etc/os-release | grep "^VERSION_CODENAME=" | sed 's/^VERSION_CODENAME=//' ) main" | sudo tee /etc/apt/sources.list.d/tenstorrent.list > /dev/null

			# Setup the keyring
			sudo mkdir -p /etc/apt/keyrings; sudo chmod 755 /etc/apt/keyrings

			# Download the key
			sudo wget -O /etc/apt/keyrings/tt-pkg-key.asc https://ppa.tenstorrent.com/ubuntu/tt-pkg-key.asc
			;;
		"fedora")
			sudo bash -c 'cat > /etc/yum.repos.d/tenstorrent.repo << EOF
[Tenstorrent]
name=Tenstorrent
baseurl=https://ppa.tenstorrent.com/fedora
enabled=1
gpgcheck=1
gpgkey=http://ppa.tenstorrent.com/tt-pkg-key.asc
EOF'
			;;
		"rhel"|"centos")
			warn "RHEL and CentOS are not officially supported. Using Fedora repos."
			sudo bash -c 'cat > /etc/yum.repos.d/tenstorrent.repo << EOF
[Tenstorrent]
name=Tenstorrent
baseurl=https://ppa.tenstorrent.com/fedora
enabled=1
gpgcheck=1
gpgkey=http://ppa.tenstorrent.com/tt-pkg-key.asc
EOF'
			;;
		*)
			error_exit "Unsupported distro: ${DISTRO_ID}"
			;;
	esac
}

install_sw_from_repos () {
	log "Installing software from TT repositories"
	case "${DISTRO_ID}" in
		"ubuntu"|"debian")
			# For now, install the big three
			sudo apt update
			sudo apt install -y tenstorrent-dkms tenstorrent-tools sfpi
			;;
		"fedora")
			sudo dnf install -y tenstorrent-dkms tenstorrent-tools sfpi
			;;
		"rhel"|"centos")
			warn "RHEL and CentOS are not officially supported. Using Fedora repos."
			sudo dnf install -y tenstorrent-dkms tenstorrent-tools sfpi
			;;
		*)
			error_exit "Unsupported distro: ${DISTRO_ID}"
			;;
	esac
}

install_inference_server () {
	log "Installing tt-inference-server"
	local INFERENCE_SERVER_LIB_DIR="${HOME}/.local/lib"
	local INFERENCE_SERVER_BIN_DIR="${HOME}/.local/bin"
	local INFERENCE_SERVER_SCRIPT_NAME="tt-inference-server"
	local INFERENCE_SERVER_REPO_URL="https://github.com/tenstorrent/tt-inference-server.git"

	# Create directories
	mkdir -p "${INFERENCE_SERVER_LIB_DIR}" || error_exit "Failed to create library directory"
	mkdir -p "${INFERENCE_SERVER_BIN_DIR}" || error_exit "Failed to create bin directory"

	# Clone the repository
	log "Cloning tt-inference-server repository..."
	if [[ -d "${INFERENCE_SERVER_LIB_DIR}/tt-inference-server" ]]; then
		warn "tt-inference-server directory already exists at ${INFERENCE_SERVER_LIB_DIR}/tt-inference-server"
		if confirm "Remove existing directory and re-clone?"; then
			rm -rf "${INFERENCE_SERVER_LIB_DIR}/tt-inference-server"
			git clone "${INFERENCE_SERVER_REPO_URL}" "${INFERENCE_SERVER_LIB_DIR}/tt-inference-server" || error_exit "Failed to clone tt-inference-server"
		else
			warn "Skipping clone, will create wrapper script only"
		fi
	else
		git clone "${INFERENCE_SERVER_REPO_URL}" "${INFERENCE_SERVER_LIB_DIR}/tt-inference-server" || error_exit "Failed to clone tt-inference-server"
	fi

	# Create wrapper script
	log "Creating wrapper script..."
	cat > "${INFERENCE_SERVER_BIN_DIR}/${INFERENCE_SERVER_SCRIPT_NAME}" << 'EOF'
#!/bin/bash

cd ${HOME}/.local/lib/tt-inference-server
python ${HOME}/.local/lib/tt-inference-server/run.py "$@"
EOF

	# Make the script executable
	chmod +x "${INFERENCE_SERVER_BIN_DIR}/${INFERENCE_SERVER_SCRIPT_NAME}" || error_exit "Failed to make script executable"

	# Check if the directory is in PATH
	if [[ ":${PATH}:" != *":${INFERENCE_SERVER_BIN_DIR}:"* ]]; then
		warn "${INFERENCE_SERVER_BIN_DIR} is not in your PATH."
		warn "A restart may fix this, or you may need to update your shell RC"
	fi

	log "tt-inference-server installation completed"
	return 0
}

# Main installation script
main() {
	echo -e "${LOGO}"
	echo # newline
	INSTALLER_VERSION="__INSTALLER_DEVELOPMENT_BUILD__" # Set to semver at release time by GitHub Actions
	log "Welcome to tenstorrent!"
	log "This is tt-installer version ${INSTALLER_VERSION}"
	log "Log is at ${LOG_FILE}"

	fetch_tt_sw_versions

	log "This script will install drivers and tooling and properly configure your tenstorrent hardware."

	if ! confirm "OK to continue?"; then
		error "Exiting."
		exit 1
	fi
	log "Starting installation"

	# Log special mode settings
	if [[ "${_arg_mode_non_interactive}" = "on" ]]; then
		warn "Running in non-interactive mode"
	fi
	if [[ "${_arg_mode_container}" = "on" ]]; then
		warn "Running in container mode"
	fi
	if [[ "${_arg_install_kmd}" = "off" ]]; then
		warn "KMD installation will be skipped"
	fi
	if [[ "${_arg_install_hugepages}" = "off" ]]; then
		warn "HugePages setup will be skipped"
	fi
	if [[ "${_arg_install_podman}" = "off" ]]; then
		warn "Podman installation will be skipped"
	fi
	if [[ "${_arg_install_metalium_container}" = "off" ]]; then
		warn "Metalium installation will be skipped"
	fi
	if [[ "${_arg_install_sfpi}" = "off" ]]; then
		warn "SFPI installation will be skipped"
	fi
	if [[ "${_arg_install_inference_server}" = "off" ]]; then
		warn "tt-inference-server installation will be skipped"
	fi
	# shellcheck disable=SC2154
	if [[ "${_arg_install_tt_flash}" = "off" ]]; then
		warn "TT-Flash installation will be skipped"
	fi
	if [[ "${_arg_update_firmware}" = "off" ]]; then
		warn "Firmware update will be skipped"
	fi
	if [[ "${_arg_update_firmware}" = "force" ]]; then
		warn "Firmware will be forcibly updated"
	fi
	if [[ "${_arg_install_metalium_models_container}" = "on" ]]; then
		log "Metalium Models container will be installed"
	fi

	log "Checking for sudo permissions... (may request password)"
	check_has_sudo_perms

	# Check distribution and install base packages
	detect_distro
	log "Installing base packages"
	case "${DISTRO_ID}" in
		"ubuntu")
			sudo apt update
			if [[ "${IS_UBUNTU_20}" = "0" ]]; then
				# On Ubuntu 20, install python3-venv and don't install pipx
				sudo apt install -y git python3-pip python3-venv dkms cargo rustc jq protobuf-compiler
			else
				sudo DEBIAN_FRONTEND=noninteractive apt install -y git python3-pip dkms cargo rustc pipx jq protobuf-compiler
			fi
			KERNEL_LISTING="${KERNEL_LISTING_UBUNTU}"
			;;
		"debian")
			# On Debian, packaged cargo and rustc are very old. Users must install them another way.
			sudo apt update
			sudo apt install -y git python3-pip dkms pipx jq protobuf-compiler
			KERNEL_LISTING="${KERNEL_LISTING_DEBIAN}"
			;;
		"fedora")
			sudo dnf install -y git python3-pip python3-devel dkms cargo rust pipx jq protobuf-compiler
			KERNEL_LISTING="${KERNEL_LISTING_FEDORA}"
			;;
		"rhel"|"centos")
			sudo dnf install -y epel-release
			sudo dnf install -y git python3-pip python3-devel dkms cargo rust pipx jq protobuf-compiler
			KERNEL_LISTING="${KERNEL_LISTING_EL}"
			;;
		"gentoo")
			# Gentoo Linux: Install packages via emerge (portage package manager)
			# Note: --ask=n suppresses interactive prompts for non-interactive mode
			# Note: We intentionally don't run 'emerge --sync' here as it can be very slow.
			#       Users should sync their portage tree before running this installer if needed.
			log "Installing base packages for Gentoo Linux via emerge (portage)"

			# Gentoo Package Masking Note:
			# Most of these base packages (git, jq, dkms, etc.) are typically stable
			# and don't require keyword unmasking. However, on some Gentoo profiles
			# or configurations, certain packages might be masked.
			#
			# The --autounmask-continue flag will automatically handle any masking
			# issues by writing appropriate entries to package.accept_keywords
			# and continuing with the installation.
			#
			# If you encounter masking issues, you can also manually unmask packages:
			#   echo "category/package ~amd64" | sudo tee -a /etc/portage/package.accept_keywords/tenstorrent

			# Install all required dependencies in one emerge command
			# --noreplace (-n): Don't reinstall packages that are already installed
			#   This prevents Rust and other large packages from being rebuilt unnecessarily
			#   on repeated installer runs. Saves significant time!
			# --autounmask-continue: automatically handle keyword masking if needed
			# --verbose: show detailed output of what's being installed
			# Note: Using --noreplace is safe here because we're installing core dependencies
			#       If they need updating, user can run 'emerge -uDN @world' separately.
			log "Checking and installing missing base packages (skipping already-installed packages)"
			sudo emerge --ask=n --noreplace --verbose --autounmask-continue \
				dev-vcs/git \
				dev-python/pip \
				sys-kernel/dkms \
				dev-lang/rust \
				dev-python/pipx \
				app-misc/jq \
				dev-libs/protobuf || {
				error "Failed to install base packages"
				error "Some packages may be masked. Try:"
				error "  emerge -pv <package-name>  # to see what's needed"
				error "Or manually accept keywords in /etc/portage/package.accept_keywords/"
				exit 1
			}

			# Set kernel listing command for Gentoo
			# Gentoo typically has kernel sources in /lib/modules
			KERNEL_LISTING="${KERNEL_LISTING_GENTOO}"

			log "Base packages ready on Gentoo"
			;;
		*)
			error "Unsupported distribution: ${DISTRO_ID}"
			exit 1
			;;
	esac

	if [[ "${IS_UBUNTU_20}" = "0" ]]; then
		warn "Ubuntu 20 is deprecated and support will be removed in a future release!"
		warn "Metalium installation will be unavailable. To install Metalium, upgrade to Ubuntu 22+"
		if [[ "${_arg_install_sfpi}" = "on" ]]; then
			warn "Pre-packaged SFPI is unavailable for Ubuntu 20; disabling"
			_arg_install_sfpi="off"
		fi
	fi

	if [[ "${DISTRO_ID}" = "debian" ]]; then
		warn "rustc and cargo cannot be automatically installed on Debian. Ensure the latest versions are installed before continuing."
		warn "If you are unsure how to do this, use rustup: https://rustup.rs/"
	fi

	# If jq wasn't installed before, we need to fetch these now that we have it installed
	if [[ "${HAVE_SET_TT_SW_VERSIONS}" = "1" ]]; then
		fetch_tt_sw_versions
	fi
	# If we still haven't successfully retrieved the versions, there is an error, so exit
	if [[ "${HAVE_SET_TT_SW_VERSIONS}" = "1" ]]; then
		echo "HAVE_SET_TT_SW_VERSIONS: ${HAVE_SET_TT_SW_VERSIONS}"

		which jq > /dev/null 2>&1
		res=$?
		if [[ "${res}" == "0" ]]
		then
			error_exit "Cannot fetch versions of TT software, likely a transient error in getting the versions - please try again"
		else
			error_exit "Cannot fetch versions of TT software. Is jq installed?"
		fi
	fi

	# Get Podman Metalium installation choice
	get_podman_metalium_choice

	# Get tt-inference-server installation choice
	get_inference_server_choice

	# Python package installation preference
	get_python_choice

	# Enforce restrictions on Ubuntu 20
	if [[ "${IS_UBUNTU_20}" = "0" ]] && [[ "${PYTHON_CHOICE}" = "pipx" ]]; then
		warn "pipx installation not supported on Ubuntu 20, defaulting to virtual environment"
		PYTHON_CHOICE="new-venv"
	fi

	# Set up Python environment based on choice
	case ${PYTHON_CHOICE} in
		"active-venv")
			if [[ -z "${VIRTUAL_ENV:-}" ]]; then
				error "No active virtual environment detected!"
				error "Please activate your virtual environment first and try again"
				exit 1
			fi
			log "Using active virtual environment: ${VIRTUAL_ENV}"
			INSTALLED_IN_VENV=0
			PYTHON_INSTALL_CMD="pip install"
			;;
		"system-python")
			log "Using system pathing"
			INSTALLED_IN_VENV=1
			# Check Python version to determine if --break-system-packages is needed (Python 3.11+)
			PYTHON_VERSION_MINOR=$(python3 -c "import sys; print(f'{sys.version_info.minor}')")
			if [[ ${PYTHON_VERSION_MINOR} -gt 10 ]]; then # Is version greater than 3.10?
				PYTHON_INSTALL_CMD="pip install --break-system-packages"
			else
				PYTHON_INSTALL_CMD="pip install"
			fi
			;;
		"pipx")
			log "Using pipx for isolated package installation"
			# adding quotes around PIPX_ENSUREPATH_EXTRAS means they won't be
			# interpretted, which is exactly what we want them to be
			# shellcheck disable=2086
			pipx ensurepath ${PIPX_ENSUREPATH_EXTRAS}
			# Enable the pipx path in this shell session
			export PATH="${PATH}:${HOME}/.local/bin/"
			INSTALLED_IN_VENV=1
			PYTHON_INSTALL_CMD="pipx install ${PIPX_INSTALL_EXTRAS}"
			;;
		"new-venv"|*)
			log "Setting up new Python virtual environment"
			python3 -m venv "${NEW_VENV_LOCATION}"
			# shellcheck disable=SC1091 # Must exist after previous command
			source "${NEW_VENV_LOCATION}/bin/activate"
			INSTALLED_IN_VENV=0
			PYTHON_INSTALL_CMD="pip install"
			;;
	esac

	# Install TT-KMD
	# Skip KMD installation if flag is set
	if [[ "${_arg_install_kmd}" = "off" ]]; then
		log "Skipping KMD installation"
	else
		manual_install_kmd
	fi

	# Install TT-Flash and Firmware
	# Skip tt-flash installation if flag is set
	if [[ "${_arg_install_tt_flash}" = "off" ]]; then
		log "Skipping TT-Flash installation"
	else
		log "Installing TT-Flash"
		cd "${WORKDIR}"
		${PYTHON_INSTALL_CMD} git+https://github.com/tenstorrent/tt-flash.git@"${FLASH_VERSION}"
	fi

	if [[ "${_arg_update_firmware}" = "off" ]]; then
		log "Skipping firmware update"
	else
		log "Updating firmware"
		# Create FW_FILE based on FW_VERSION
		FW_FILE="fw_pack-${FW_VERSION}.fwbundle"
		FW_RELEASE_URL="https://github.com/tenstorrent/tt-firmware/releases/download"
		BACKUP_FW_RELEASE_URL="https://github.com/tenstorrent/tt-zephyr-platforms/releases/download"

		# Download from GitHub releases
		if ! curl -fsSLO "${FW_RELEASE_URL}/v${FW_VERSION}/${FW_FILE}"; then
			warn "Could not find firmware bundle at main URL- trying backup URL"
			if ! curl -fsSLO "${BACKUP_FW_RELEASE_URL}/v${FW_VERSION}/${FW_FILE}"; then
				error_exit "Could not download firmware bundle. Ensure firmware version is valid."
			fi
		fi

		verify_download "${FW_FILE}"

		if [[ "${_arg_update_firmware}" = "force" ]]; then
			tt-flash --fw-tar "${FW_FILE}" --force
		else
			tt-flash --fw-tar "${FW_FILE}"
		fi
	fi

	# shellcheck disable=SC2154
	if [[ "${_arg_install_tt_topology}" = "on" ]]; then
		log "Installing tt-topology"

		if [[ -n "${TT_TOPOLOGY_VERSION:-}" ]]; then
			TOPOLOGY_VERSION="${TT_TOPOLOGY_VERSION}"
		elif [[ -n "${_arg_topology_version}" ]]; then
			TOPOLOGY_VERSION="${_arg_topology_version}"
		else
			if TOPOLOGY_VERSION=$(fetch_latest_version "${TT_TOPOLOGY_GH_REPO}"); then
				: # Success, TOPOLOGY_VERSION is set
			else
				local topology_exit_code=$?
				handle_version_fetch_error "tt-topology" "${topology_exit_code}" "${TT_TOPOLOGY_GH_REPO}"
				error_exit "Failed to fetch tt-topology version. Installation cannot continue."
			fi
		fi

		log "Topology Version: ${TOPOLOGY_VERSION}"

		${PYTHON_INSTALL_CMD} git+https://github.com/tenstorrent/tt-topology.git@"${TOPOLOGY_VERSION}"
	fi

	# Setup HugePages
	# Skip HugePages installation if flag is set
	if [[ "${_arg_install_hugepages}" = "off" ]]; then
		warn "Skipping HugePages setup"
	else
		manual_install_hugepages
	fi

	# Install TT-SMI
	log "Installing System Management Interface"
	${PYTHON_INSTALL_CMD} git+https://github.com/tenstorrent/tt-smi@"${SMI_VERSION}"

	# Install tt-metal source code to ~/tt-metal
	# This is standard TT devXP - provides the full source tree for development
	log "Installing tt-metal source code"
	install_tt_metal

	# Install Podman if requested
	if [[ "${_arg_install_podman}" = "off" ]]; then
		warn "Skipping Podman installation"
	else
		if ! check_podman_installed; then
			install_podman
		fi
	fi

	# Install Podman Metalium if requested
	if [[ "${_arg_install_metalium_container}" = "off" ]]; then
		warn "Skipping Podman Metalium installation"
	else
		if ! check_podman_installed; then
			warn "Podman is not installed. Cannot install Podman Metalium."
		else
			install_podman_metalium
		fi
	fi

	# Install Metalium Models container if requested
	if [[ "${_arg_install_metalium_models_container}" = "on" ]]; then
		if ! check_podman_installed; then
			warn "Podman is not installed. Cannot install Metalium Models."
		else
			install_podman_metalium_models
		fi
	fi

	if [[ ${INSTALL_TT_REPOS:-} = "on" ]]; then
		install_tt_repos
	fi

	if [[ ${INSTALL_SW_FROM_REPOS:-} = "on" ]]; then
		install_sw_from_repos
	fi

	if [[ "${_arg_install_sfpi}" = "on" ]]; then
		manual_install_sfpi
	fi

	if [[ "${_arg_install_inference_server}" = "on" ]]; then
		install_inference_server
	fi

	if [[ "${INSTALLED_IN_VENV}" = "0" ]]; then
		warn "You'll need to run \"source ${VIRTUAL_ENV}/bin/activate\" to use tenstorrent's Python tools."
	fi

	log "Please reboot your system to complete the setup."
	log "After rebooting, try running 'tt-smi' to see the status of your hardware."
	if [[ "${_arg_install_metalium_container}" = "on" ]]; then
		log "Use 'tt-metalium' to access the Metalium programming environment"
		log "Usage examples:"
		log "  tt-metalium                   # Start an interactive shell"
		log "  tt-metalium [command]         # Run a specific command"
		log "  tt-metalium python script.py  # Run a Python script"
	fi
	if [[ "${_arg_install_inference_server}" = "on" ]]; then
		log "Use 'tt-inference-server' to run the inference server"
		log "The inference server has been installed to ~/.local/lib/tt-inference-server"
		log "Usage: tt-inference-server [arguments]"
	fi

	# Log successful completion message
	log "✅ Installation completed successfully."
	log "Installation log saved to: ${LOG_FILE}"

	# Auto-reboot if specified
	if [[ "${REBOOT_OPTION}" = "always" ]]; then
		log "Auto-reboot enabled. Rebooting now..."
		sudo reboot
	# Otherwise, ask if specified
	elif [[ "${REBOOT_OPTION}" = "ask" ]]; then
		if confirm "Would you like to reboot now?"; then
			log "Rebooting..."
			sudo reboot
		fi
	fi
}

# Start installation
main

# ] <-- needed because of Argbash

# vim: noai:ts=4:sw=4:ft=bash
