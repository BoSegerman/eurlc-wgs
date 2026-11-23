# EURLC-WGS

**Whole-genome sequencing analysis of bacterial isolates — from Illumina
reads to a QC-checked, typed and clustered report in one command.**

EURLC-WGS takes a folder of Illumina reads (or finished assemblies) and
runs the complete analysis a public-health or food-safety laboratory needs
for routine isolate typing: read QC, species identification, contamination
check, assembly, MLST, cgMLST, AMR genes, serotyping and virulence genes,
and cgMLST clustering. The result is one HTML report per run, with a QC
verdict for every sample, a detailed report and PDF per sample, and
tables for download.

It is built first for ***Campylobacter***, with specific support for
***Salmonella***, ***E. coli*** and ***Listeria monocytogenes***. Isolates
of other species are analysed with everything that is not
species-specific.

EURLC-WGS is developed at the Swedish Veterinary Agency (SVA), Uppsala,
Sweden, which is the **European Union Reference Laboratory for
*Campylobacter*** (EURL-Campylobacter) — hence the name, and the focus on
the methods and cgMLST schemas used by the EU network of national
reference laboratories.

> **Status: release candidate (1.0.0-rc3).** Feature-frozen and under test
> before version 1.0.0; only corrections are made. Feedback is very welcome.
> What has changed is in [CHANGELOG.md](CHANGELOG.md).

---

## What it does

For each sample:

| Stage | Tools |
|---|---|
| Read QC and trimming | built-in prescan, fastp |
| Species and contamination | Kraken2 + Bracken, Mash screen |
| Downsampling of very deep samples | BBMap |
| Assembly, best result chosen automatically | SPAdes, SKESA (optional: Shovill) |
| Assembly QC | QUAST, Bowtie2 remapping |
| MLST | FastMLST, mlst |
| AMR genes and point mutations | AMRFinderPlus, ResFinder |
| Serotyping and virulence (by species) | SISTR, SeqSero2, ECTyper, LisSero, VirulenceFinder |
| cgMLST | chewBBACA (EFSA-compatible schemas) |

Then, for the whole run: cgMLST distance matrices and clusters per species,
a MultiQC summary, QC evaluation against species-specific thresholds
(PASS / WARNING / CRITICAL / FAIL), and the reports.

Also included:

- **QC screen** (`--qc-screen`): a quick traffic-light check of a
  sequencing run's raw reads, for the sequencing lab to see which samples
  need a closer look — no assembly, minutes rather than hours.
- **Resume and re-run**: an interrupted run continues where it stopped;
  single steps can be re-run with new settings while everything else is
  reused.
- **Parallel mode**: several samples and steps at once, within the limits
  you set for threads and memory.
- **Reproducibility for accredited work**: databases can be frozen to
  checksummed versions, and the whole configuration — settings, database
  versions, tool environments and the pipeline version — sealed under a
  name. Every report shows whether the run matches the seal.
- **Sensible input handling**: Illumina sample numbers and lanes are
  removed from sample names, and one sample sequenced on several lanes is
  merged automatically.

---

## Requirements

- **Linux**, or **Windows with WSL** (native Windows is not supported).
- **Conda** — [Miniforge](https://github.com/conda-forge/miniforge) is
  recommended. All tools are installed by the pipeline in their own conda
  environments, from the conda-forge and bioconda channels.
- **Disk**: a few tens of GB for the databases (the default Kraken2
  database alone is 8 GB), plus room for the results.
- **Memory**: 16 GB is a reasonable minimum; more for parallel runs.
- Internet access during installation.

---

## Installation

```bash
git clone https://github.com/BoSegerman/eurlc-wgs.git
cd eurlc-wgs
bash install.sh
```

`install.sh` asks which species the installation is for (*Campylobacter*,
*Salmonella*, *E. coli*, *Listeria*; any combination), and then runs without
further questions: it creates the conda environment `eurlc-wgs` and runs
`eurlc-wgs --setup`, which installs one environment per tool, downloads the
databases to `~/eurlc-wgs_db`, and installs the species tools and the cgMLST
schema of each chosen species. This takes a while the first time. When it
ends with "Setup complete. This installation is ready for: ...", it is ready
to use.

To give the species without being asked:

```bash
bash install.sh --species=campylobacter,salmonella     # or --species=all
```

Add a species later:

```bash
conda activate eurlc-wgs
eurlc-wgs --setup species=listeria
```

`eurlc-wgs --setup` can be run at any time to check the installation: it
lists every tool, database and cgMLST schema and installs what is missing.
Locking the tool and database versions of an installation for validated use
(freezing and sealing) is described in section 12 of the user manual.

**New versions.** The pipeline does not look for updates itself. To get an
e-mail for each release, choose *Watch → Custom → Releases* on the GitHub
page. Changes are listed in `CHANGELOG.md`; how to update is in section 12
of the user manual.

---

## Quick start

```bash
conda activate eurlc-wgs
cd /data/MiSeq_192          # the folder with your FASTQ files
eurlc-wgs
```

That is all: without arguments the pipeline analyses the folder you are
standing in. From anywhere else, name the folder:
`eurlc-wgs datadir=/data/MiSeq_192`.

The pipeline finds the FASTQ/FASTA files in the folder, shows the samples
it found, checks that every tool and database is in place, and runs the
analysis. When it is done, it prints a summary and the path to the report:

```
/data/MiSeq_192/eurlc-wgs/report/main_report.html
```

(In WSL: `explorer.exe .` in the report folder opens it in Windows.)

### A few common variations

```bash
# results somewhere else (e.g. when the data folder is read-only)
eurlc-wgs datadir=/data/MiSeq_192 outdir=/analysis/MiSeq_192

# use more of the computer
eurlc-wgs datadir=/data/MiSeq_192 parallel_mode=on max_threads=16 max_ram_gb=48

# quick QC screen of a sequencing run
eurlc-wgs datadir=/data/MiSeq_192 --qc-screen

# continue an interrupted run
eurlc-wgs outdir=/analysis/MiSeq_192 --resume

# re-run one step with another setting, keep everything else
eurlc-wgs outdir=/analysis/MiSeq_192 rerun=spades spades.timeout=4h

# all options
eurlc-wgs --help
```

### What you get

```
eurlc-wgs/
├── report/main_report.html   start here: all samples, QC, species, ST, serotype, AMR
├── report/samples_html/      detailed report per sample (and samples_pdf/)
├── report/clustering/        cgMLST distance matrices and clusters
├── report/tables/            tables for download
├── results/                  assemblies and the raw output of every tool
└── log/                      full log, run summary, versions used
```

---

## Documentation

- **[User manual](docs/eurlc-wgs-user-manual.md)** — installation, running,
  reading the results, settings, schemas, keeping an installation under
  control, troubleshooting.
- `eurlc-wgs --help` — every command-line option.
- `eurlc-wgs configfile=write` — writes every setting, with its current
  value, to `~/eurlc-wgs_db/eurlc-wgs.config` for you to read and edit.

---

## Getting help and reporting problems

**Bugs and suggestions:** please open an
[issue](https://github.com/BoSegerman/eurlc-wgs/issues). For a problem with
a run, include the command you used and the files `log/run_summary.txt`
and `log/log.txt` from the output folder.

**Questions and feedback**, or if you do not have a GitHub account: email
bo.segerman@sva.se. Logs with sample names or paths you cannot share
publicly should be sent by email rather than posted as an issue.

Feedback from routine use — what is unclear, what is missing, what you
had to work around — is especially welcome.

---

## Citing

There is no publication yet. If you use EURLC-WGS in your work, please
cite this repository and the version you used (`eurlc-wgs --version`), and
the tools it runs — their versions are listed in every report and in
`log/versioning_explicit/`.

---

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

The tools and databases the pipeline installs have their own licences.

---

## Author

Bo Segerman, Swedish Veterinary Agency (SVA), Uppsala, Sweden —
[github.com/BoSegerman](https://github.com/BoSegerman)
