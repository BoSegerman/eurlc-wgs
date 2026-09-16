#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install.sh
# Installs the eurlc-wgs pipeline: creates the main conda environment,
# copies scripts/templates/assets/resources, then hands off to
# 'eurlc-wgs --setup' which installs tool environments and databases.
#
# Usage:
#   ./install.sh                    install eurlc-wgs + run setup
#   ./install.sh --no-setup         install eurlc-wgs only, skip setup
#   ./install.sh --optional         include optional tool environments in setup
#   ./install.sh --assume-yes       non-interactive (for scripts/CI)
#   ./install.sh --resources-only   reinstall scripts/templates/assets only
#
# Expected project layout:
#   install.sh
#   bin/eurlc-wgs
#   scripts/hash_results_alleles.py
#   docs/help.txt
#   envs/core/eurlc-wgs.yml          <- main environment (the only one installed here)
#   envs/core/*.yml                   <- tool environments (installed by eurlc-wgs --setup)
#   envs/optional/*.yml               <- optional tools  (installed by eurlc-wgs --setup)
#   templates/*
#   assets/*
# -----------------------------------------------------------------------------

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_DIR="${SRC_DIR}/envs"
CORE_ENV_DIR="${ENV_DIR}/core"
OPTIONAL_ENV_DIR="${ENV_DIR}/optional"
TEMPLATE_DIR="${SRC_DIR}/templates"
ASSET_DIR="${SRC_DIR}/assets"
HELP_FILE="${SRC_DIR}/docs/help.txt"

MAIN_ENV="eurlc-wgs"
MAIN_YML="${CORE_ENV_DIR}/eurlc-wgs.yml"

RUN_SETUP=1
INSTALL_OPTIONAL=0
ASSUME_YES=0
RESOURCES_ONLY=0
UNINSTALL=0

# -----------------------------------------------------------------------------
# Parse options
# -----------------------------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --optional|--with-optional)
            INSTALL_OPTIONAL=1 ;;
        --no-setup)
            RUN_SETUP=0 ;;
        --assume-yes|-y)
            ASSUME_YES=1 ;;
        --resources-only|--dev)
            RESOURCES_ONLY=1
            RUN_SETUP=0 ;;
        --uninstall)
            UNINSTALL=1 ;;
        -h|--help)
            echo "Usage:"
            echo "  ./install.sh                   install eurlc-wgs + run setup"
            echo "  ./install.sh --no-setup        install eurlc-wgs only, skip setup"
            echo "  ./install.sh --optional        include optional tools in setup"
            echo "  ./install.sh --assume-yes      non-interactive"
            echo "  ./install.sh --resources-only  reinstall scripts/templates/assets only"
            echo "  ./install.sh --uninstall       remove all eurlc-wgs environments and resources"
            exit 0 ;;
        *)
            echo "ERROR: Unknown option: $arg"
            echo "Run ./install.sh --help for usage."
            exit 1 ;;
    esac
done

echo ">>> EURLC-WGS installer"
echo ">>> Source directory: ${SRC_DIR}"

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------

if [[ "${UNINSTALL}" -eq 1 ]]; then
    echo ">>> Uninstalling eurlc-wgs..."

    if ! command -v conda >/dev/null 2>&1; then
        echo "ERROR: conda not found in PATH."
        exit 1
    fi

    CONDA_BASE_U="$(conda info --base)"

    # Remove all eurlc-wgs* environments
    echo ">>> Removing conda environments..."
    conda env list | awk '$1 ~ /^eurlc-wgs/ {print $1}' | while read -r env; do
        echo ">>> Removing: ${env}"
        conda env remove -n "${env}" -y
    done

    # Remove shared resources
    SHARE_DIR="${CONDA_BASE_U}/share/eurlc-wgs"
    if [[ -d "${SHARE_DIR}" ]]; then
        echo ">>> Removing shared resources: ${SHARE_DIR}"
        rm -rf "${SHARE_DIR}"
    else
        echo ">>> Shared resources not found: ${SHARE_DIR} (already removed?)"
    fi

    echo ">>> Uninstall complete."
    echo ">>> Note: eurlc-wgs_db/ (databases and config) was NOT removed."
    echo ">>>       Remove it manually if no longer needed."
    exit 0
fi

# -----------------------------------------------------------------------------
# Locate conda
# -----------------------------------------------------------------------------

if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: conda not found in PATH. Please install Miniconda first."
    exit 1
fi

if command -v mamba >/dev/null 2>&1; then
    CONDA_BIN="mamba"
else
    CONDA_BIN="conda"
fi

CONDA_BASE="$(conda info --base)"

echo ">>> Using: ${CONDA_BIN}"
echo ">>> Conda base: ${CONDA_BASE}"

# -----------------------------------------------------------------------------
# Install main eurlc-wgs environment
# -----------------------------------------------------------------------------

if [[ "${RESOURCES_ONLY}" -eq 0 ]]; then

    if [[ ! -f "${MAIN_YML}" ]]; then
        echo "ERROR: Missing main environment YML: ${MAIN_YML}"
        exit 1
    fi

    export PYTHONWARNINGS="ignore::FutureWarning"
    export CONDA_CHANNEL_PRIORITY=flexible

    echo
    echo ">>> Installing main environment: ${MAIN_ENV}"
    echo ">>> YML: ${MAIN_YML}"

    if conda env list | awk 'NF > 1 {print $1}' | grep -qx "${MAIN_ENV}"; then
        echo ">>> Environment exists, updating..."
        "${CONDA_BIN}" env update -n "${MAIN_ENV}" -f "${MAIN_YML}" --prune
    else
        echo ">>> Creating environment..."
        "${CONDA_BIN}" env create -f "${MAIN_YML}"
    fi

    echo ">>> Main environment installed."
    echo
    echo ">>> Tool environments (fastp, kraken2, spades, ...) will be installed"
    echo ">>> by 'eurlc-wgs --setup' in a later step."

else
    echo ">>> Resource-only mode: skipping conda environment creation."
fi

# -----------------------------------------------------------------------------
# Locate installed eurlc-wgs environment
# -----------------------------------------------------------------------------

EURLC_ENV_PATH="$("${CONDA_BIN}" env list | awk -v env="${MAIN_ENV}" '$1 == env {print $NF; exit}')"

if [[ -z "${EURLC_ENV_PATH}" ]]; then
    echo "ERROR: Could not find '${MAIN_ENV}' environment."
    echo "       Ensure envs/core/eurlc-wgs.yml contains: name: eurlc-wgs"
    exit 1
fi

CONDA_BASE_ACTUAL="$(conda info --base)"
TARGET_BIN="${EURLC_ENV_PATH}/bin"
TARGET_SHARE="${CONDA_BASE_ACTUAL}/share/eurlc-wgs"
TARGET_TEMPLATES="${TARGET_SHARE}/templates"
TARGET_ASSETS="${TARGET_SHARE}/assets"
TARGET_ENVS="${TARGET_SHARE}/envs"

echo
echo ">>> Main environment: ${EURLC_ENV_PATH}"
echo ">>> Shared resources: ${TARGET_SHARE}"

mkdir -p "${TARGET_BIN}"
mkdir -p "${TARGET_TEMPLATES}"
mkdir -p "${TARGET_ASSETS}"
mkdir -p "${TARGET_ENVS}"

# -----------------------------------------------------------------------------
# Install executable scripts
# -----------------------------------------------------------------------------

echo
echo ">>> Installing scripts into ${TARGET_BIN}"

MAIN_SCRIPT=""
for candidate in "${SRC_DIR}/bin/eurlc-wgs" "${SRC_DIR}/eurlc-wgs" "${SRC_DIR}/run.perl"; do
    if [[ -f "$candidate" ]]; then
        MAIN_SCRIPT="$candidate"
        break
    fi
done

if [[ -z "${MAIN_SCRIPT}" ]]; then
    echo "ERROR: Could not find main script (bin/eurlc-wgs, eurlc-wgs or run.perl)"
    exit 1
fi

cp -p "${MAIN_SCRIPT}" "${TARGET_BIN}/eurlc-wgs"
chmod +x "${TARGET_BIN}/eurlc-wgs"
echo ">>> Installed: $(basename "${MAIN_SCRIPT}") → eurlc-wgs"

if [[ -f "${SRC_DIR}/scripts/hash_results_alleles.py" ]]; then
    cp -p "${SRC_DIR}/scripts/hash_results_alleles.py" "${TARGET_BIN}/hash_results_alleles.py"
    chmod +x "${TARGET_BIN}/hash_results_alleles.py"
    echo ">>> Installed: hash_results_alleles.py"
else
    echo "WARNING: Missing scripts/hash_results_alleles.py"
fi

# -----------------------------------------------------------------------------
# Install templates, assets, help
# -----------------------------------------------------------------------------

echo
echo ">>> Installing templates into ${TARGET_TEMPLATES}"
if [[ -d "${TEMPLATE_DIR}" ]]; then
    cp -pr "${TEMPLATE_DIR}/." "${TARGET_TEMPLATES}/"
    echo ">>> Templates installed."
else
    echo "WARNING: Missing templates directory: ${TEMPLATE_DIR}"
fi

echo
echo ">>> Installing assets into ${TARGET_ASSETS}"
if [[ -d "${ASSET_DIR}" ]]; then
    cp -pr "${ASSET_DIR}/." "${TARGET_ASSETS}/"
    echo ">>> Assets installed."
else
    echo "WARNING: Missing assets directory: ${ASSET_DIR}"
fi

echo
echo ">>> Installing help file"
if [[ -f "${HELP_FILE}" ]]; then
    cp -p "${HELP_FILE}" "${TARGET_SHARE}/help.txt"
    echo ">>> Installed: help.txt"
else
    echo "WARNING: Missing help file: ${HELP_FILE}"
fi

# -----------------------------------------------------------------------------
# Install YML files into share (fallback for eurlc-wgs --setup)
# Tool environments in db_dir/yml/ take priority over these (see find_env_yml).
# -----------------------------------------------------------------------------

echo
echo ">>> Installing YML files into ${TARGET_ENVS}"

if [[ -d "${CORE_ENV_DIR}" ]]; then
    cp -pr "${CORE_ENV_DIR}" "${TARGET_ENVS}/"
    echo ">>> Installed core YML files."
fi

if [[ -d "${OPTIONAL_ENV_DIR}" ]]; then
    cp -pr "${OPTIONAL_ENV_DIR}" "${TARGET_ENVS}/"
    echo ">>> Installed optional YML files."
fi

# -----------------------------------------------------------------------------
# Sanity checks
# -----------------------------------------------------------------------------

echo
echo ">>> Running sanity checks"

if "${EURLC_ENV_PATH}/bin/perl" -c "${TARGET_BIN}/eurlc-wgs" >/dev/null 2>&1; then
    echo ">>> Perl syntax: OK"
else
    echo "WARNING: Perl syntax check failed for ${TARGET_BIN}/eurlc-wgs"
fi

for check_file in \
    "${TARGET_ASSETS}/style.css" \
    "${TARGET_ASSETS}/mainreport.css" \
    "${TARGET_ASSETS}/eurlc-wgs-logo.png" \
    "${TARGET_ASSETS}/favicon.png" \
    "${TARGET_TEMPLATES}/main_report.html.tt" \
    "${TARGET_TEMPLATES}/short_report.html.tt" \
    "${TARGET_TEMPLATES}/detailed_report.html.tt" \
    "${TARGET_SHARE}/help.txt"
do
    if [[ ! -f "$check_file" ]]; then
        echo "WARNING: Missing installed file: $check_file"
    fi
done

# -----------------------------------------------------------------------------
# Run eurlc-wgs --setup to install tool environments
# -----------------------------------------------------------------------------

if [[ "${RUN_SETUP}" -eq 1 ]]; then
    echo
    echo ">>> Running eurlc-wgs --setup to install tool environments..."
    echo ">>> (Tool environments are managed by the pipeline, not this script.)"
    echo

    SETUP_ARGS="--setup"
    [[ "${ASSUME_YES}" -eq 1 ]]       && SETUP_ARGS="${SETUP_ARGS} --assume-yes"
    [[ "${INSTALL_OPTIONAL}" -eq 1 ]] && SETUP_ARGS="${SETUP_ARGS} --optional"

    conda run -n "${MAIN_ENV}" eurlc-wgs ${SETUP_ARGS}
else
    echo
    echo ">>> Skipping eurlc-wgs --setup (--no-setup specified)."
    echo ">>> Run the following to complete installation:"
    echo ">>>   conda activate ${MAIN_ENV}"
    echo ">>>   eurlc-wgs --setup"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

echo
echo ">>> Installation complete."
echo
echo "Activate with:"
echo "    conda activate ${MAIN_ENV}"
echo
echo "Run with:"
echo "    eurlc-wgs --help"
echo
if [[ "${RUN_SETUP}" -eq 0 ]]; then
    echo "Tool environments not yet installed. Complete setup with:"
    echo "    eurlc-wgs --setup"
    echo
fi
