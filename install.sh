#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install.sh
# Installs the eurlc-wgs pipeline: creates the main conda environment,
# copies scripts/templates/assets/help, then hands off to
# 'eurlc-wgs --setup' which installs tool environments and databases.
#
# Usage:
#   ./install.sh                    install eurlc-wgs + run setup (asks which species)
#   ./install.sh --species=LIST     the species to set the installation up for, e.g.
#                                   --species=campylobacter,salmonella  (or: all)
#   ./install.sh --no-setup         install eurlc-wgs only, skip setup
#   ./install.sh --optional         include optional tool environments in setup
#   ./install.sh --assume-yes       non-interactive (for scripts/CI)
#   ./install.sh --resources-only   reinstall scripts/templates/assets only
#   ./install.sh --database=DIR     the database folder (default ~/eurlc-wgs_db)
#
# A database folder from a sealed installation holds the exact package list
# of every conda environment (DIR/conda_envs/<env>.explicit, written by
# eurlc-wgs --generate-seal). When the list for the main environment is
# there, the environment is made from it instead of from the YML file, so
# that it is the same as on the computer where the seal was made; the tool
# environments are then made from their lists by eurlc-wgs --setup.
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
DB_DIR="${HOME}/eurlc-wgs_db"
SPECIES=""
SPECIES_KEYS="campylobacter salmonella ecoli listeria"

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
        --database=*)
            DB_DIR="${arg#--database=}" ;;
        --species=*)
            SPECIES="${arg#--species=}" ;;
        -h|--help)
            echo "Usage:"
            echo "  ./install.sh                   install eurlc-wgs + run setup; asks which species"
            echo "                                 to set the installation up for"
            echo "  ./install.sh --species=LIST    the species, without asking: campylobacter, salmonella,"
            echo "                                 ecoli, listeria (comma-separated), or all"
            echo "  ./install.sh --no-setup        install eurlc-wgs only, skip setup"
            echo "  ./install.sh --optional        include optional tools in setup"
            echo "  ./install.sh --assume-yes      non-interactive"
            echo "  ./install.sh --resources-only  reinstall scripts/templates/assets only"
            echo "  ./install.sh --uninstall       remove all eurlc-wgs environments and resources"
            echo "  ./install.sh --database=DIR    the database folder (default ~/eurlc-wgs_db); with the"
            echo "                                 package lists of a sealed installation in DIR/conda_envs,"
            echo "                                 the environments are made from them"
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
# Which species? Asked first, so that the rest runs without anyone watching.
# The database folder decides (the same rule as in eurlc-wgs --setup):
#   config_seal.ini     a sealed installation: used as it is, no choice
#   eurlc-wgs.config    an existing installation: keeps its species
#                       (--species adds to them)
#   neither             a new installation: --species, or the question below,
#                       or all species when there is no terminal to ask in
# -----------------------------------------------------------------------------

# "1, Salmonella,ecoli" -> "campylobacter,salmonella,ecoli"; fails on anything else
species_list() {
    local out="" tok key n
    local -a keys=(${SPECIES_KEYS})
    local -a toks=()
    IFS=',' read -r -a toks <<< "$1"
    for tok in ${toks[@]+"${toks[@]}"}; do
        tok="$(echo "${tok}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
        [[ -z "${tok}" ]] && continue
        key=""
        case "${tok}" in
            all)                               echo "all"; return 0 ;;
            [1-9])                             n=$((tok - 1)); key="${keys[$n]:-}" ;;
            campylobacter|campy)               key="campylobacter" ;;
            salmonella)                        key="salmonella" ;;
            ecoli|e.coli|e_coli|escherichia|escherichiacoli) key="ecoli" ;;
            listeria)                          key="listeria" ;;
        esac
        [[ -z "${key}" ]] && return 1
        [[ ",${out}," == *",${key},"* ]] || out="${out:+${out},}${key}"
    done
    [[ -z "${out}" ]] && return 1
    echo "${out}"
}

if [[ "${UNINSTALL}" -eq 0 && "${RUN_SETUP}" -eq 1 ]]; then
    if [[ -n "${SPECIES}" ]]; then
        if ! SPECIES="$(species_list "${SPECIES}")"; then
            echo "ERROR: --species: choose from campylobacter, salmonella, ecoli, listeria (comma-separated), or all."
            exit 1
        fi
    fi
    if [[ -f "${DB_DIR}/config_seal.ini" ]]; then
        echo ">>> Sealed installation found in ${DB_DIR}: it is used as it is."
        if [[ -n "${SPECIES}" ]]; then
            echo "ERROR: --species cannot be used with a sealed installation: its species are part of what"
            echo "       the seal covers. Leave --species out, or give another folder with --database=DIR."
            exit 1
        fi
    elif [[ -f "${DB_DIR}/eurlc-wgs.config" ]]; then
        echo ">>> Existing installation found in ${DB_DIR}: it keeps its species; what is missing is installed."
        if [[ -n "${SPECIES}" ]]; then echo ">>> Species to add: ${SPECIES}"; fi
    elif [[ -z "${SPECIES}" ]]; then
        if [[ "${ASSUME_YES}" -eq 0 && -t 0 && -t 1 ]]; then
            echo
            echo "Which species should this installation be set up for?"
            echo "(The tools and the cgMLST schema of each chosen species are installed."
            echo " More can be added later with: eurlc-wgs --setup species=<name>)"
            n=1
            for key in ${SPECIES_KEYS}; do
                case "${key}" in
                    campylobacter) label="Campylobacter" ;;
                    salmonella)    label="Salmonella" ;;
                    ecoli)         label="Escherichia coli" ;;
                    listeria)      label="Listeria" ;;
                esac
                echo "  ${n}) ${label}"
                n=$((n + 1))
            done
            while true; do
                read -r -p "Numbers or names separated by commas, e.g. 1,2 [Enter = all]: " answer
                [[ -z "${answer}" ]] && answer="all"
                if SPECIES="$(species_list "${answer}")"; then break; fi
                echo "Not recognised: ${answer}"
            done
        else
            SPECIES="all"
            echo ">>> No --species given and no terminal to ask in: all species are installed."
        fi
        echo ">>> Species: ${SPECIES}"
    fi
fi

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

    # Shared resources live inside the eurlc-wgs environment and went with
    # it; remove the copy that versions before 0.1.0 put in the conda base.
    SHARE_DIR="${CONDA_BASE_U}/share/eurlc-wgs"
    if [[ -d "${SHARE_DIR}" ]]; then
        echo ">>> Removing old shared resources: ${SHARE_DIR}"
        rm -rf "${SHARE_DIR}"
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
    # Strict channel priority, as bioconda recommends: with conda-forge listed
    # first, a package is never mixed in from a lower channel. All tool
    # environments are solved this way too (eurlc-wgs --setup below inherits
    # it).
    export CONDA_CHANNEL_PRIORITY=strict

    echo
    echo ">>> Installing main environment: ${MAIN_ENV}"
    echo ">>> YML: ${MAIN_YML}"

    # The fingerprint eurlc-wgs gives an environment or a package list:
    # MD5 of the sorted package lines (conda_env_fingerprint in bin/eurlc-wgs).
    env_fingerprint()  { conda list --explicit -n "$1" 2>/dev/null | grep -E '^@EXPLICIT$|^https?:' | LC_ALL=C sort | md5sum | cut -d' ' -f1; }
    list_fingerprint() { sed -E 's/#[0-9a-fA-F]+[[:space:]]*$//' "$1" | tr -d '\r' | grep -E '^@EXPLICIT$|^https?:' | LC_ALL=C sort | md5sum | cut -d' ' -f1; }

    MAIN_LIST="${DB_DIR}/conda_envs/${MAIN_ENV}.explicit"
    MAIN_EXISTS=0
    conda env list | awk 'NF > 1 {print $1}' | grep -qx "${MAIN_ENV}" && MAIN_EXISTS=1

    if [[ -s "${MAIN_LIST}" ]]; then
        echo ">>> Package list of a sealed installation found: ${MAIN_LIST}"
        if [[ "${MAIN_EXISTS}" -eq 1 && "$(env_fingerprint "${MAIN_ENV}")" == "$(list_fingerprint "${MAIN_LIST}")" ]]; then
            echo ">>> Environment exists and is as in the package list."
        else
            if [[ "${MAIN_EXISTS}" -eq 1 ]]; then
                echo ">>> Environment exists but differs from the package list: removing it..."
                conda env remove -n "${MAIN_ENV}" -y
            fi
            echo ">>> Creating environment from the package list..."
            conda create -y -n "${MAIN_ENV}" --file "${MAIN_LIST}"
        fi
    elif [[ "${MAIN_EXISTS}" -eq 1 ]]; then
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
# Inside the environment, as a bioconda package installs it (B17). The
# pipeline also still finds the old location in the conda base.
TARGET_SHARE="${EURLC_ENV_PATH}/share/eurlc-wgs"
OLD_SHARE="${CONDA_BASE_ACTUAL}/share/eurlc-wgs"
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

if [[ -f "${SRC_DIR}/scripts/eurlc-validate" ]]; then
    cp -p "${SRC_DIR}/scripts/eurlc-validate" "${TARGET_BIN}/eurlc-validate"
    chmod +x "${TARGET_BIN}/eurlc-validate"
    echo ">>> Installed: eurlc-validate"
fi

if [[ -f "${SRC_DIR}/scripts/eurlc-efsa-export" ]]; then
    cp -p "${SRC_DIR}/scripts/eurlc-efsa-export" "${TARGET_BIN}/eurlc-efsa-export"
    chmod +x "${TARGET_BIN}/eurlc-efsa-export"
    echo ">>> Installed: eurlc-efsa-export"
fi
if [[ -f "${SRC_DIR}/scripts/eurlc-cgmlst-compare" ]]; then
    cp -p "${SRC_DIR}/scripts/eurlc-cgmlst-compare" "${TARGET_BIN}/eurlc-cgmlst-compare"
    chmod +x "${TARGET_BIN}/eurlc-cgmlst-compare"
    echo ">>> Installed: eurlc-cgmlst-compare"
fi

if [[ -f "${SRC_DIR}/scripts/eurlc-wgs-inspect" ]]; then
    cp -p "${SRC_DIR}/scripts/eurlc-wgs-inspect" "${TARGET_BIN}/eurlc-wgs-inspect"
    chmod +x "${TARGET_BIN}/eurlc-wgs-inspect"
    echo ">>> Installed: eurlc-wgs-inspect"
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
echo
echo ">>> Installing help file"
if [[ -f "${HELP_FILE}" ]]; then
    cp -p "${HELP_FILE}" "${TARGET_SHARE}/help.txt"
    echo ">>> Installed: help.txt"
else
    echo "WARNING: Missing help file: ${HELP_FILE}"
fi

# -----------------------------------------------------------------------------
# Install YML files into share. They are the only source of tool versions
# (B17); YML files in <db>/yml/ take priority over these (see find_env_yml).
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

# The copy an older install.sh put in the conda base would only be a stale
# second set of templates and YML files.
if [[ -d "${OLD_SHARE}" && "${OLD_SHARE}" != "${TARGET_SHARE}" ]]; then
    echo
    echo ">>> Removing old shared resources from the conda base: ${OLD_SHARE}"
    rm -rf "${OLD_SHARE}"
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
    "${TARGET_SHARE}/help.txt" \
    "${TARGET_ASSETS}/genome_sizes.tsv" \
    "${TARGET_ENVS}/core/eurlc-wgs-fastp.yml"
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

    # Always add --assume-yes when called from install.sh: conda run has no
    # terminal so interactive prompts would hang indefinitely.
    SETUP_ARGS="--setup --assume-yes"
    [[ "${DB_DIR}" != "${HOME}/eurlc-wgs_db" ]] && SETUP_ARGS="${SETUP_ARGS} database=${DB_DIR}"
    [[ "${INSTALL_OPTIONAL}" -eq 1 ]] && SETUP_ARGS="${SETUP_ARGS} --optional"
    [[ -n "${SPECIES}" ]] && SETUP_ARGS="${SETUP_ARGS} species=${SPECIES}"

    # Run setup from HOME to avoid the pipeline treating the source
    # directory as its input directory.
    # Use direct activation rather than conda run to avoid output buffering.
    cd "${HOME}"
    # shellcheck disable=SC1091
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${MAIN_ENV}"
    SETUP_RC=0
    eurlc-wgs ${SETUP_ARGS} || SETUP_RC=$?
    conda deactivate
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
if [[ "${RUN_SETUP}" -eq 1 && "${SETUP_RC:-0}" -ne 0 ]]; then
    # setup has said what is missing and what is ready (see above)
    echo ">>> Installation is NOT complete: setup reported problems (see above)."
    echo ">>> When they are solved, finish with:"
    echo "    conda activate ${MAIN_ENV}"
    echo "    eurlc-wgs --setup"
    echo
    exit 1
fi
echo ">>> Installation complete."
echo
echo "Start with:"
echo "    conda activate ${MAIN_ENV}"
if [[ "${RUN_SETUP}" -eq 1 ]]; then
    echo "    eurlc-wgs datadir=<folder with FASTQ files>"
    echo
    echo "Help:  eurlc-wgs --help   (user manual: docs/eurlc-wgs-user-manual.md)"
else
    echo
    echo "Tool environments, databases and cgMLST schemas are not yet installed. Complete with:"
    echo "    eurlc-wgs --setup species=<campylobacter,salmonella,ecoli,listeria or all>"
fi
echo
