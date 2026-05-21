# EURLC-WGS

EURLC-WGS is a bacterial whole genome sequencing (WGS) analysis pipeline focused on foodborne pathogens and microbial genomics.

The pipeline performs automated quality control, species determination, assembly, typing, contamination analysis, AMR detection, clustering analysis, and report generation from Illumina sequencing data.

The project is developed at the Swedish Veterinary Agency (SVA), Uppsala, Sweden.

---

## Features

- Fastp quality trimming
- Kraken2 + Bracken species determination
- Mash screening
- Assembly using SPAdes / Shovill / SKESA
- MLST and cgMLST analysis
- AMR analysis using AMRFinderPlus and ResFinder
- Interactive clustering reports
- HTML and PDF reporting
- MultiQC summarization
- Conda-based installation
- Optional automatic environment installation

---

## Installation

Clone the repository:

```bash
git clone https://github.com/BoSegerman/eurlc-wgs.git
cd eurlc-wgs
```

Run the installer:

```bash
bash install.sh
```

---

## Database directory

The pipeline expects databases to be installed in:

```text
~/eurlc-wgs_db
```

This directory may contain databases and schemas for:

- Kraken2
- Mash
- chewBBACA
- ResFinder
- Bakta
- CheckM

Some databases can be automatically installed by the pipeline.

---

## Usage

Basic example:

```bash
conda activate eurlc-wgs
cd ~/mydatadir
eurlc-wgs 
```

Show help:

```bash
eurlc-wgs --help
```

---

## Configuration

The pipeline can use:

- built-in default configuration
- user-supplied configuration files
- configuration files located in the database directory

---

## Conda environments

Conda environments are defined using YAML files in:

```text
envs/core/
envs/optional/
```

Optional tools include:

- Bakta
- Unicycler
- CheckM

---

## Project status

The pipeline is currently under active development and early external testing.

Interfaces, configuration structure, and output formats may still change between versions.

---

## Author

Bo Segerman  
Swedish Veterinary Agency (SVA)  
Uppsala, Sweden

GitHub:
https://github.com/BoSegerman
