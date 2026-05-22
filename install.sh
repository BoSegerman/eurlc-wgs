
#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install.sh
# Installs EURLC-WGS conda environments, executable scripts, templates and assets.
#
# Usage:
#   ./install.sh              install core environments
#   ./install.sh --optional   install core + optional environments
#
# Expected project layout:
#
#   install.sh
#   bin/eurlc-wgs
#   scripts/hash_results_alleles.py
#   docs/help.txt
#   envs/core/*.yml
#   envs/optional/*.yml
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
INSTALL_OPTIONAL=0
RESOURCES_ONLY=0

# -----------------------------------------------------------------------------
# Parse installer options
# -----------------------------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --optional|--with-optional)
            INSTALL_OPTIONAL=1
            ;;
        --resources-only|--dev)
            RESOURCES_ONLY=1
            ;;
        -h|--help)
            echo "Usage:"
            echo "  ./install.sh                    install core environments + resources"
            echo "  ./install.sh --optional         install core + optional environments + resources"
            echo "  ./install.sh --resources-only   install scripts/templates/assets/help only"
            echo "  ./install.sh --dev              same as --resources-only"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown installer option: $arg"
            echo "Usage: ./install.sh [--optional] [--resources-only]"
            exit 1
            ;;
    esac
done

echo ">>> EURLC-WGS installer"
echo ">>> Source directory: ${SRC_DIR}"

# -----------------------------------------------------------------------------
# Locate conda/mamba
# -----------------------------------------------------------------------------


if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: conda not found in PATH. Please install Miniconda/Mambaforge first."
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

if [[ "${RESOURCES_ONLY}" -eq 0 ]]; then

if [[ ! -d "${CORE_ENV_DIR}" ]]; then
    echo "ERROR: Missing core env directory: ${CORE_ENV_DIR}"
    exit 1
fi

export PYTHONWARNINGS="ignore::FutureWarning"

# Keep this local to this installer run.
export CONDA_CHANNEL_PRIORITY=flexible

# -----------------------------------------------------------------------------
# Collect environment YAML files
# -----------------------------------------------------------------------------

shopt -s nullglob
YML_FILES=("${CORE_ENV_DIR}"/*.yml)

if [[ "${INSTALL_OPTIONAL}" -eq 1 ]]; then
    if [[ -d "${OPTIONAL_ENV_DIR}" ]]; then
        YML_FILES+=("${OPTIONAL_ENV_DIR}"/*.yml)
    else
        echo "WARNING: Optional env directory missing: ${OPTIONAL_ENV_DIR}"
    fi
fi
shopt -u nullglob

if [[ ${#YML_FILES[@]} -eq 0 ]]; then
    echo "ERROR: No yml files found in ${CORE_ENV_DIR}"
    exit 1
fi

echo ">>> Environments selected: ${#YML_FILES[@]}"
if [[ "${INSTALL_OPTIONAL}" -eq 1 ]]; then
    echo ">>> Optional environments: included"
else
    echo ">>> Optional environments: not included"
fi

# -----------------------------------------------------------------------------
# Create/update conda environments
# -----------------------------------------------------------------------------

for yml in "${YML_FILES[@]}"; do

    env_name="$(awk '
        $1 == "name:" {
            print $2;
            exit;
        }
    ' "${yml}")"

    if [[ -z "${env_name}" ]]; then
        echo "ERROR: Could not determine environment name from ${yml}"
        exit 1
    fi

    echo
    echo ">>> Installing/updating environment: ${env_name}"
    echo ">>> YAML: ${yml}"

    if conda env list | awk 'NF > 1 {print $1}' | grep -qx "${env_name}"; then
        echo ">>> Environment exists, updating..."
        "${CONDA_BIN}" env update -n "${env_name}" -f "${yml}" --prune
    else
        echo ">>> Creating environment..."
        "${CONDA_BIN}" env create -f "${yml}"
    fi
done

echo
echo ">>> All selected conda environments processed."

else
    echo ">>> Resource-only mode: skipping conda environment creation/update"
fi
# -----------------------------------------------------------------------------
# Locate main eurlc-wgs environment
# -----------------------------------------------------------------------------

EURLC_ENV_PATH="$("${CONDA_BIN}" env list | awk -v env="${MAIN_ENV}" '$1 == env {print $NF; exit}')"

if [[ -z "${EURLC_ENV_PATH}" ]]; then
    echo "ERROR: Could not find ${MAIN_ENV} environment."
    echo "       Check that envs/core/eurlc-wgs.yml exists and contains: name: eurlc-wgs"
    exit 1
fi

TARGET_BIN="${EURLC_ENV_PATH}/bin"
TARGET_SHARE="${CONDA_BASE}/share/eurlc-wgs"
TARGET_TEMPLATES="${TARGET_SHARE}/templates"
TARGET_ASSETS="${TARGET_SHARE}/assets"

echo
echo ">>> Main environment: ${EURLC_ENV_PATH}"
echo ">>> Shared resources: ${TARGET_SHARE}"

mkdir -p "${TARGET_BIN}"
mkdir -p "${TARGET_TEMPLATES}"
mkdir -p "${TARGET_ASSETS}"

# -----------------------------------------------------------------------------
# Install executable scripts
# -----------------------------------------------------------------------------

echo
echo ">>> Installing executable scripts into ${TARGET_BIN}"

if [[ -f "${SRC_DIR}/bin/eurlc-wgs" ]]; then
    cp -p "${SRC_DIR}/bin/eurlc-wgs" "${TARGET_BIN}/eurlc-wgs"
    chmod +x "${TARGET_BIN}/eurlc-wgs"
    echo ">>> Installed bin/eurlc-wgs"
elif [[ -f "${SRC_DIR}/eurlc-wgs" ]]; then
    cp -p "${SRC_DIR}/eurlc-wgs" "${TARGET_BIN}/eurlc-wgs"
    chmod +x "${TARGET_BIN}/eurlc-wgs"
    echo ">>> Installed eurlc-wgs"
elif [[ -f "${SRC_DIR}/run.perl" ]]; then
    cp -p "${SRC_DIR}/run.perl" "${TARGET_BIN}/eurlc-wgs"
    chmod +x "${TARGET_BIN}/eurlc-wgs"
    echo ">>> Installed run.perl as eurlc-wgs"
else
    echo "ERROR: Could not find main script: bin/eurlc-wgs, eurlc-wgs or run.perl"
    exit 1
fi

if [[ -f "${SRC_DIR}/scripts/hash_results_alleles.py" ]]; then
    cp -p "${SRC_DIR}/scripts/hash_results_alleles.py" "${TARGET_BIN}/hash_results_alleles.py"
    chmod +x "${TARGET_BIN}/hash_results_alleles.py"
    echo ">>> Installed scripts/hash_results_alleles.py"
else
    echo "WARNING: Missing scripts/hash_results_alleles.py"
fi

# -----------------------------------------------------------------------------
# Install templates
# -----------------------------------------------------------------------------

echo
echo ">>> Installing templates into ${TARGET_TEMPLATES}"

if [[ -d "${TEMPLATE_DIR}" ]]; then
    cp -pr "${TEMPLATE_DIR}/." "${TARGET_TEMPLATES}/"
    echo ">>> Templates installed"
else
    echo "WARNING: Missing templates directory: ${TEMPLATE_DIR}"
fi

# -----------------------------------------------------------------------------
# Install assets
# -----------------------------------------------------------------------------

echo
echo ">>> Installing assets into ${TARGET_ASSETS}"

if [[ -d "${ASSET_DIR}" ]]; then
    cp -pr "${ASSET_DIR}/." "${TARGET_ASSETS}/"
    echo ">>> Assets installed"
else
    echo "WARNING: Missing assets directory: ${ASSET_DIR}"
fi

# -----------------------------------------------------------------------------
# Install help file
# -----------------------------------------------------------------------------

echo
echo ">>> Installing help file into ${TARGET_SHARE}"

if [[ -f "${HELP_FILE}" ]]; then
    cp -p "${HELP_FILE}" "${TARGET_SHARE}/help.txt"
    echo ">>> Installed docs/help.txt"
else
    echo "WARNING: Missing help file: ${HELP_FILE}"
fi

# -----------------------------------------------------------------------------
# Install yml files
# -----------------------------------------------------------------------------

TARGET_ENVS="${TARGET_SHARE}/envs"

mkdir -p "${TARGET_ENVS}"

cp -pr "${ENV_DIR}/core" "${TARGET_ENVS}/"
cp -pr "${ENV_DIR}/optional" "${TARGET_ENVS}/"

# -----------------------------------------------------------------------------
# Basic sanity checks
# -----------------------------------------------------------------------------

echo
echo ">>> Running basic sanity checks"

if "${EURLC_ENV_PATH}/bin/perl" -c "${TARGET_BIN}/eurlc-wgs" >/dev/null; then
    echo ">>> Perl syntax check OK"
else
    echo "WARNING: Perl syntax check failed for ${TARGET_BIN}/eurlc-wgs"
fi

if [[ ! -f "${TARGET_ASSETS}/style.css" ]]; then
    echo "WARNING: Missing installed asset: style.css"
fi

if [[ ! -f "${TARGET_ASSETS}/mainreport.css" ]]; then
    echo "WARNING: Missing installed asset: mainreport.css"
fi

if [[ ! -f "${TARGET_ASSETS}/eurlc-wgs-logo.png" ]]; then
    echo "WARNING: Missing installed asset: eurlc-wgs-logo.png"
fi

if [[ ! -f "${TARGET_ASSETS}/favicon.png" ]]; then
    echo "WARNING: Missing installed asset: favicon.png"
fi

if [[ ! -f "${TARGET_TEMPLATES}/main_report.html.tt" ]]; then
    echo "WARNING: Missing installed template: main_report.html.tt"
fi

if [[ ! -f "${TARGET_TEMPLATES}/short_report.html.tt" ]]; then
    echo "WARNING: Missing installed template: short_report.html.tt"
fi

if [[ ! -f "${TARGET_TEMPLATES}/detailed_report.html.tt" ]]; then
    echo "WARNING: Missing installed template: detailed_report.html.tt"
fi

if [[ ! -f "${TARGET_SHARE}/help.txt" ]]; then
    echo "WARNING: Missing installed help file: help.txt"
fi

echo
echo ">>> Installation complete."
echo
echo "Activate with:"
echo "    conda activate ${MAIN_ENV}"
echo
echo "Run with:"
echo "    eurlc-wgs --help"
echo
echo "To install optional environments later:"
echo "    ./install.sh --optional"
