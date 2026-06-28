EURLC-WGS

EURLC-WGS is a Perl-based whole genome sequencing analysis pipeline for bacterial isolate analysis, mainly focused on foodborne pathogens such as Campylobacter, Salmonella, Listeria, and E. coli/VTEC.

The pipeline is intended to run from a directory containing input FASTQ or FASTA files. It creates a pipeline output directory, normally named eurlc-wgs, containing results, logs, reports, quality-control outputs, clustering outputs, and downloadable tables.

## Main purpose

The pipeline performs automated bacterial WGS analysis including:

* raw read quality control
* adapter/FASTQ prescan
* trimming with fastp
* optional downsampling with BBMap
* species identification and contamination assessment
* assembly with SPAdes, Shovill, SKESA, and optionally Unicycler
* selection of a main assembly
* assembly QC using QUAST and remapping
* MLST and FastMLST
* cg/wgMLST using chewBBACA
* AMR detection using AMRFinderPlus and ResFinder
* clustering and distance matrix generation
* interactive HTML reports
* PDF reports
* TSV exports

## Implementation

The main pipeline is a large Perl script installed as:

text
bin/eurlc-wgs


The project structure is:

text
assets/
bin/
docs/
envs/
scripts/
templates/
install.sh
README.md
LICENSE
.gitignore


The pipeline uses many separate Conda environments to avoid dependency conflicts. Environment YAML files are divided into:

text
envs/core/
envs/optional/


Core tools are installed by default. Optional tools such as Bakta, CheckM, and Unicycler are supported but not installed unless requested.

## Installation model

The installer creates or updates Conda environments and installs scripts/resources into:

text
$CONDA_BASE/envs/eurlc-wgs/bin/
$CONDA_BASE/share/eurlc-wgs/


Installed shared resources include:

text
share/eurlc-wgs/templates/
share/eurlc-wgs/assets/
share/eurlc-wgs/envs/
share/eurlc-wgs/help.txt


There is also a --resources-only / --dev install mode that only updates the main script, helper scripts, templates, assets, environment YAMLs, and help file without reinstalling all Conda environments.

## Databases

The pipeline expects a database directory, normally:

text
~/eurlc-wgs_db


This may contain databases for Kraken2, Mash, chewBBACA schemas, ResFinder, Bakta, CheckM, and other resources.

The database directory may also contain user-overridden environment YAML files, for example:

text
~/eurlc-wgs_db/envs/


The intended lookup order for environment YAMLs is:

1. explicit path in config
2. user/database override in ~/eurlc-wgs_db/envs/
3. installed defaults in $CONDA_BASE/share/eurlc-wgs/envs/
4. fallback package-based installation logic

## Configuration

The pipeline has built-in default configuration stored in the Perl script. A config file can also be specified explicitly or placed in the database directory.

Tool configuration typically includes:

perl
env
yml
package_name
install_version
program_name
db_path
db_test
install_db
enabled
arguments


Some tools use a single package_name; others use a packages array containing several packages.

## Reporting

The reporting structure is being reorganized so user-facing reports are under:

text
report/


Important report outputs include:

text
report/EURLC-WGS-report.html
report/index.html
report/samples/html/
report/samples/pdf/
report/clustering/
report/amr/
report/assets/
report/tsv/


The main report links to per-sample short and detailed reports, clustering reports, AMR viewer, TSV exports, and PDF outputs.

Templates are stored in:

text
templates/main_report.html.tt
templates/short_report.html.tt
templates/detailed_report.html.tt


Assets include CSS, logo, and favicon.

## Interactive clustering report

The pipeline generates an interactive clustering HTML report from distance and comparison-success matrices.

Features include:

* selectable distance or comparison-success matrix
* distance threshold slider
* comparison-success warning threshold slider
* filtering samples by QC status
* default visibility of PASS and WARNING samples
* colored sample name cells by QC status
* highlighting close distances
* highlighting low comparison success values
* cluster summary based on threshold

Default clustering thresholds can be read from schema configuration:

perl
$R_cfg_schemas->{$schemaname}{threshold}


with fallback to a default value such as 10.

## QC status handling

Samples may have QC status values such as:

text
PASS
WARNING
CRITICAL
FAIL
UNKNOWN


These statuses are used in reports, matrix filtering, sample table coloring, and filtered clustering exports.

## AMR viewer

The pipeline includes an AMR profile viewer as an HTML report. It combines normalized AMRFinderPlus and ResFinder hits into a searchable/filterable table.

The viewer supports:

* filtering by sample QC status
* filtering by tool
* minimum identity
* minimum coverage
* search across sample/gene/class/phenotype/accession
* summary of visible hits

AMRFinderPlus results are usually stored under:

perl
$sample->{results}{amrfinderplus}{amr_hits}


ResFinder results are usually stored under:

perl
$sample->{results}{resfinder_fasta}{resfinder_hits}


## Important Perl data structures

The pipeline uses global structures such as:

perl
%rundata
$R_samples
$R_cfg
$R_cfg_schemas
%runstep


Each sample stores runstep results under:

perl
$R_samples->[$i]{results}{$runstep_name}


High-level summarized values are stored under:

perl
$R_samples->[$i]{main_results}


Report issues and QC status are stored under:

perl
$R_samples->[$i]{report_issues}
$R_samples->[$i]{qc}


## Logging

The pipeline uses a central log_message() function. It writes timestamped messages to log files and selected messages to screen.

ANSI colors are controlled by a global variable:

perl
$USE_COLOR


The pipeline should support:

text
--no-color


and preferably automatically disable colors when stdout is not a terminal.

A GUI wrapper should use non-colored, non-interactive mode.

## GUI launcher project

A separate project is being prototyped as a simple graphical launcher for Windows/WSL users. It should remain separate from the main pipeline.

The launcher should:

* let the user select an input directory
* run the pipeline through WSL or directly in Linux mode
* show live pipeline output in a text window
* avoid terminal interaction
* run the pipeline in non-interactive mode

The pipeline should eventually support:

text
--no-color
--non-interactive
--yes / --assume-yes


to make GUI launching safe.

## Development workflow

The project is now managed with Git/GitHub.

Suggested branch model:

text
main = stable/test-user releases
dev  = active development


Typical workflow:

bash
git switch dev
git pull
# edit and test
git add .
git commit -m "message"
git push


Stable versions are merged to main and tagged, for example:

text
v0.1.0-beta1


The pipeline is licensed under GPL-3.0.

## Coding style considerations

When modifying the pipeline:

* prefer central helper functions over repeated path logic
* avoid hard-coded paths where possible
* keep user-facing reports under report/
* keep raw/intermediate software outputs outside report/
* keep databases outside Git
* keep Conda environment definitions versioned in Git
* keep optional tools disabled by default
* avoid interactive prompts in GUI/non-interactive mode
* make all generated links relative to the report file location
* preserve existing backward compatibility where practical