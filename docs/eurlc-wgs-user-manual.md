# EURLC-WGS User Manual

Version 1.0.0-rc3 · November 2026

This manual is for the person who runs the pipeline: what it does, how to
start it, where the results are and how to read them, and what to do when
something goes wrong. It is installed with the pipeline as one HTML file
and as a PDF: `eurlc-wgs --manual` says where. `eurlc-wgs --help` lists the
options for running an analysis, `eurlc-wgs --help-admin` those for looking after an installation,
and every setting is listed, with its built-in value, in
`~/eurlc-wgs_db/eurlc-wgs.config` ([section 9](#9-settings)).

This is a release candidate. What does not work yet, or not as fully as it
should, is collected in [section 13](#13-known-limitations).

---

## Contents

1. [What the pipeline does](#1-what-the-pipeline-does)
2. [Installation](#2-installation)
3. [Your first run](#3-your-first-run)
4. [Input files](#4-input-files)
5. [The results folder](#5-the-results-folder)
6. [Reading the results](#6-reading-the-results)
7. [Everyday tasks](#7-everyday-tasks)
8. [QC screen for the sequencing lab](#8-qc-screen-for-the-sequencing-lab)
9. [Settings](#9-settings)
10. [Species and typing tools](#10-species-and-typing-tools)
11. [cgMLST schemas](#11-cgmlst-schemas)
12. [Keeping an installation under control](#12-keeping-an-installation-under-control)
13. [Known limitations](#13-known-limitations)
14. [Troubleshooting](#14-troubleshooting)
15. [Quick reference](#15-quick-reference)

---

## 1. What the pipeline does

EURLC-WGS analyses whole-genome sequencing data from bacterial isolates.
You give it a folder of Illumina reads (or finished assemblies) and get an
HTML report with quality control, species, assembly, sequence type,
serotype, resistance genes and cgMLST clustering.

It is built first for *Campylobacter*, with specific typing tools for
*Salmonella*, *E. coli* and *Listeria* as well. A sample of any other
species is analysed with everything that is not species-specific.

For each sample, in this order:

| Stage | What | Tools |
|---|---|---|
| Raw reads | Checksums, read-length and adapter scan | built in |
| Trimming | Adapter and quality trimming | fastp |
| Species | Species and genus from the reads | Kraken2 + Bracken |
| Downsampling | Reduce very deep samples to a target depth | BBMap |
| Contamination | Other species/genera in the reads | Kraken2, Mash screen |
| Assembly | One or more assemblies; the best becomes the main assembly | SPAdes, SKESA (optional: Shovill) |
| Assembly QC | Size, contigs, N50; reads mapped back | QUAST, Bowtie2 |
| MLST | Sequence type and clonal complex | FastMLST, mlst |
| AMR | Resistance genes and point mutations | AMRFinderPlus, ResFinder |
| Typing | Serotype, virulence genes (by species) | SISTR, SeqSero2, ECTyper, LisSero, VirulenceFinder |
| cgMLST | Allele profile | chewBBACA |

Then, for all samples together: assemblies sorted by species, cgMLST
profiles combined into distance matrices and a clustering report per
species, a MultiQC summary, QC evaluation against thresholds, and the
reports.

A sample that turns out to have too little data is **abandoned** early
(default: below 30× depth), so no time is spent assembling it. The other
samples continue.

---

## 2. Installation

### What you need

- Linux, or Windows with WSL. Native Windows is not supported.
- Conda (Miniconda or Miniforge). `mamba` is used if it is installed.
- Disk space for the databases (allow a few tens of GB; the default
  Kraken2 database alone is the 8 GB standard database) and memory to
  match: 16 GB is a reasonable minimum, more for parallel runs.
- Internet access during installation.

### Install

```bash
git clone https://github.com/BoSegerman/eurlc-wgs.git
cd eurlc-wgs
bash install.sh
```

`install.sh` first asks which species the installation is for:

```
Which species should this installation be set up for?
  1) Campylobacter
  2) Salmonella
  3) Escherichia coli
  4) Listeria
Numbers or names separated by commas, e.g. 1,2 [Enter = all]:
```

It then runs without further questions: it creates the conda environment
`eurlc-wgs`, installs the program into it, and runs `eurlc-wgs --setup`,
which creates one conda environment per tool, downloads the databases to
`~/eurlc-wgs_db`, and installs the species tools and the cgMLST schema of
each chosen species. This takes a while. When it ends with

```
Setup complete. This installation is ready for:
    Campylobacter      cgMLST schema CAMPISO-PubMLST-8
    Salmonella         cgMLST schema chewie_ns_salmonella
```

the installation is ready to use for those species
([section 3](#3-your-first-run)). If something could not be downloaded, it
says what is not ready; `eurlc-wgs --setup` then installs only what is
missing. Every setup writes a log to
`~/eurlc-wgs_db/setup_logs/<date-time>/log/log.txt`.

To give the species without being asked (in a script, or over a connection
without a terminal):

```bash
bash install.sh --species=campylobacter,salmonella
```

Without `--species` and without a terminal to ask in, all four species are
installed.

| `install.sh` option | Effect |
|---|---|
| `--species=LIST` | The species: `campylobacter`, `salmonella`, `ecoli`, `listeria` (comma-separated), or `all` |
| `--database=DIR` | The database folder, if not `~/eurlc-wgs_db` |
| `--no-setup` | Install the program only; run `eurlc-wgs --setup species=...` yourself later |
| `--assume-yes` | No questions (all species, unless `--species` is given) |
| `--resources-only` | Reinstall the program, templates and assets only (after `git pull`) |
| `--optional` | Also install the tools that are off by default (Bakta, CheckM, ...). CheckM is experimental, see [section 13](#13-known-limitations) |
| `--uninstall` | Remove all `eurlc-wgs*` environments and shared files (not the database folder) |

Tool versions come from the environment files in `envs/`; every
installation of one pipeline version gets the same tool versions.

### What is already in the database folder

`install.sh` and `eurlc-wgs --setup` look at the database folder first, and
say what they found:

| In the folder | Taken as | What happens |
|---|---|---|
| Nothing, or no `eurlc-wgs.config` | A new installation | Installed for the chosen species; `eurlc-wgs.config` is written |
| `eurlc-wgs.config` | An existing installation | Keeps its species. Every tool, database and schema is checked, and what is missing is installed. This also finishes an installation that was interrupted |
| `config_seal.ini` | A sealed installation ([section 12](#12-keeping-an-installation-under-control)) | Used as it is: no question, nothing downloaded, the environments made from the seal's package lists. Anything missing is reported as an error |

A database or schema counts as present when its files are, not when its
folder is: the folder of an interrupted download is not taken for a
database, and a half-installed schema folder is moved to
`chewbbaca/incomplete/` and the schema installed again.

### Add a species later

```bash
eurlc-wgs --setup species=listeria
```

installs the tools and the schema for it and adds it to `species_scope` in
`eurlc-wgs.config`. Species are only added this way, never removed; to stop
running the tools of a species, edit `species_scope` in the file. A sealed
installation cannot be changed.

### Check the installation

```bash
conda activate eurlc-wgs
eurlc-wgs --setup
```

`--setup` can be run as often as you like. It lists every tool, database
and cgMLST schema with `✓` or `✗` and offers to install what is missing. If
something could not be installed it ends with `ERROR: Setup finished with
problems: ...`, the species that are not ready, and exit code 1; otherwise
with "Setup complete" and the species the installation is ready for.

`--setup` shows that everything is in place. To see that the installation
also gives the results it should, run a small set of samples with known
results: `eurlc-wgs --installation-check`
([section 12](#12-keeping-an-installation-under-control)).

`eurlc-wgs --version` and `eurlc-wgs --help` work without the conda
environment. Anything else started outside it stops with
`Perl module(s) not found ... Activate it first (conda activate eurlc-wgs)`.

### The configuration file

A new installation gets `~/eurlc-wgs_db/eurlc-wgs.config`. It lists every
setting with its built-in value, commented out with `#`; only
`species_scope` is set. To change a setting, remove the `#` and edit the
value ([section 9](#9-settings)). Settings left commented follow the
pipeline's defaults, also after an update.

### Other cgMLST schemas

Each species gets its standard schema at installation. Other schemas, and
schemas of your own, are in [section 11](#11-cgmlst-schemas).

---

## 3. Your first run

```bash
conda activate eurlc-wgs
cd /data/MiSeq_192          # the folder with your FASTQ files
eurlc-wgs
```

That is all. The pipeline analyses the folder you are standing in and
writes everything to a new subfolder, `eurlc-wgs/`. From anywhere else:
`eurlc-wgs datadir=/data/MiSeq_192`.

What happens on screen:

1. **Where it will work.** `Input directory: /data/MiSeq_192` and
   `Press Ctrl+C now to cancel if this is not what you intended.`
2. **The samples it found**, one line each with type: `PE` (paired reads),
   `SE` (single reads) or `FASTA`. Check that the number and names are what
   you expect.
3. **Tool check** ("testing requirements"). A missing tool or database is
   offered for installation here, before the analysis starts.
4. **The analysis**, sample by sample, one line per step with a timer.
5. **The run summary**: samples, QC result, species, errors and warnings,
   and where the report is.

Open the report in a browser:

```
/data/MiSeq_192/eurlc-wgs/report/main_report.html
```

In WSL, type `explorer.exe .` in the report folder to open it in Windows.

### If the folder has been analysed before

```
Overwrite it (all earlier results are deleted), resume in it (reuse earlier results), or stop? [o=overwrite, r=resume, S=stop]:
```

Enter alone means stop. See [Continue an interrupted run](#continue-an-interrupted-run).
A folder that holds only the logs of a run that stopped before the
analysis (for example at a missing tool) is not asked about; it is simply
started again.

### If nothing was found

```
No FASTQ/FASTA files found in [/data/MiSeq_192].
If your files are in a subfolder, try recursive=yes.
```

Nothing is created and nothing is run.

---

## 4. Input files

### What is recognised

| Type | File names |
|---|---|
| Paired reads | `<name>_R1.fastq.gz` + `<name>_R2.fastq.gz`. Also `_1`/`_2`, `_R1_001`/`_R2_001`, with `-` instead of `_`, `.fq`, and uncompressed |
| Single reads | Any other `.fastq`, `.fq`, `.fastq.gz`, `.fq.gz` |
| Assemblies | `.fasta`, `.fa`, `.fna`, also `.gz` |

Upper and lower case do not matter. Reads and assemblies can be mixed in
one folder. Use `--fastq` or `--fasta` to analyse only one kind.

Files directly in the folder are used. Add `--recursive` to include
subfolders; output folders of the pipeline itself (this run's, or an
earlier run's inside the data folder) are not searched.

### Sample names

The sample name is the file name without the read suffix and extension.
`PT43-3_R1.fastq.gz` becomes `PT43-3`. Characters other than letters,
digits, `_` and `-` are replaced by `_` (the log says so). Two files that
end up with the same name get `_1`, `_2` added, with a warning.

Things to know:

- **Illumina's sample number and lane are removed.**
  `PT43_S12_L001_R1_001.fastq.gz` becomes sample `PT43`.
- **The same isolate on several lanes is merged.** `PT43_S12_L001_…` and
  `PT43_S12_L002_…` are joined into one file per read before the analysis
  and analysed as one sample, `PT43`. The original files are not changed;
  the sample report lists the lane files with their checksums.
- **Two different samples with the same name** (`PT43_S12_…` and
  `PT43_S13_…`: different sample numbers) are not merged. They keep their
  full names, `PT43_S12_L001` and `PT43_S13_L001`, with a warning.
- **An R1 without its R2** is analysed as single reads, with a warning
  naming the file that was expected.
- **A read set and an assembly with the same name** in one folder become
  two samples (`PT43` and `PT43_1`), with a warning.
- **A resumed run keeps the names** of its first run, also if that was made
  with an earlier version.

### Folder names

Spaces and quote characters are not allowed anywhere in the path of the
data folder, the output folder and the database folder: the analysis tools
cannot handle them. The run stops at the start and names the folder. In
WSL this typically means working under your Linux home or a
`/mnt/d/data/...` folder rather than `/mnt/c/Users/First Last/...`.

### Assemblies as input

A FASTA file skips trimming and assembly and goes straight to assembly QC,
MLST, AMR, typing and cgMLST. Read-based results (depth, Q30) are empty for
such a sample.

---

## 5. The results folder

```
eurlc-wgs/
├── EURLC-WGS-report.html      start page
├── report/
│   ├── main_report.html       all samples: QC, species, ST, serotype, AMR
│   ├── samples_html/          one detailed report per sample
│   ├── samples_pdf/           the same as PDF
│   ├── clustering/            cgMLST distance matrices and clusters
│   └── tables/                tables for download
├── results/
│   ├── assemblies/            <sample>.fasta = main assembly
│   │   ├── alternative_assemblies/   the other assemblers' results
│   │   └── by_species/        assemblies sorted by species
│   ├── qc/                    raw output of the QC tools, by stage
│   ├── typing/                MLST, serotyping, virulence
│   ├── amr/                   AMRFinderPlus, ResFinder
│   └── clustering/chewbbaca/  allele profiles
├── large_files/fastq/         trimmed, downsampled and lane-merged reads
├── data/rundata.json          everything in machine-readable form
├── log/                       log.txt, run_summary.txt, run_status.json,
│                              events.jsonl, tool output, versions
└── control/                   for pausing and stopping a run
```

What to keep: `report/`, `results/` and `log/` are the analysis.
`large_files/` holds the trimmed, downsampled and lane-merged reads, by far
the largest part. They are removed at the end of every run (settings
`cleanup.trimmed_fastq`, `cleanup.downsampled_fastq`, `cleanup.merged_fastq`;
`0` keeps them). A later `--resume` or `rerun=` that needs them makes them
again, only for the samples that need them.

The assemblers' working files (for SPAdes some 50 MB per sample: k-mer
folders, intermediate graphs, copies of the contigs) are removed as soon as
each assembly is done. The logs and the final assembly graph are kept, the
graph gzipped, for viewing in Bandage (`cleanup.assembly_graphs=keep`
keeps it uncompressed, `remove` drops it). SPAdes `scaffolds.fasta` is not
kept (`cleanup.spades_scaffolds=gzip` or `keep` keeps it when it differs
from `contigs.fasta`). `cleanup.assembler_workfiles=0` keeps everything.
The BLAST files ResFinder, VirulenceFinder and PlasmidFinder leave behind
are removed at the end of the run (`cleanup.blast_tmp=0` keeps them).

A config file written with `configfile=write` before November 2026 says
`bam = 0` (the default then): BAM files are then kept. Remove the line, or
set it to `1`, to get the current default.

The re-mapping keeps about 1 MB per sample: statistics, a depth summary
and allele counts, from which the mixture measure can be calculated again.
The BAM file is removed (`cleanup.bam=0` keeps it; `rerun=remap
cleanup.bam=0` makes it again). An output folder made before November 2026
also has the large `<sample>.depth.tsv` and `<sample>.pileup.gz`
(100-250 MB per sample); `eurlc-wgs --remap-check --convert <output folder>`
replaces them with the small files after checking that the results are
identical.

An analysis can be moved or copied: move the whole data folder, with
`eurlc-wgs/` in it, and run `eurlc-wgs --resume` there (or `eurlc-wgs
outdir=<new place>/eurlc-wgs --resume`). The raw files are found at the new
place and checked against the MD5 sums recorded when they were analysed; a
file that differs stops the run. The original paths stay in the logs as
the record of what was analysed, and the move is noted in the log and the
report. If the raw data is not there at all, the run continues with the
results it has; only a step that needs the reads again fails.

---

## 6. Reading the results

### The run summary

Printed last, and saved in `log/run_summary.txt`:

```
  Samples:     3  (FASTA 1, PE 2)
  QC:          1 PASS, 1 WARNING, 1 FAIL
               not PASS: S2 (WARNING), S3 (FAIL)
  Species:     Salmonella enterica (2), Listeria monocytogenes (1)
  Abandoned:   1 sample(s) could not be finished:
    S3 [spades]: SPAdes timed out after 30m
  Errors:      1
  Warnings:    4 (2 different)
  Report:      /data/run1/eurlc-wgs/report/main_report.html
  RESULT:  FINISHED WITH PROBLEMS -- check the errors / abandoned / FAIL samples above
```

| RESULT | Means |
|---|---|
| `FINISHED OK` | No warnings, all samples PASS |
| `FINISHED WITH WARNINGS` | Warnings, a sample with QC WARNING or CRITICAL, or tools that did not run |
| `FINISHED WITH PROBLEMS` | Errors, abandoned samples, or a sample with QC FAIL |

Each error and warning has the time since start (`[+00:31:00]`), which is
how you find it in `log/log.txt`. In parallel mode a line `Parallel:` shows
how much of the computer the run used.

The same information, for a script or a GUI, is in `log/run_status.json`.

### QC status of a sample

Every QC measure is compared with thresholds for the sample's species. The
sample's status is the worst one reached:

| Status | Meaning |
|---|---|
| PASS | All measures within limits |
| WARNING | Something to look at; results are normally usable |
| CRITICAL | Look carefully before using the results |
| FAIL | Results are probably not reliable |

What is checked by default:

| Measure | Default limits |
|---|---|
| Share of bases ≥ Q30 (raw reads) | warning < 80 %, critical < 70 %, fail < 50 % |
| Depth counting Q30 bases, after trimming | fail < 30× |
| Largest other species / other genus in the reads | fail > 5 % |
| The two species methods (Kraken2 and Mash screen) | warning when the species Kraken2 reports is not among those Mash screen finds (the reported species is Kraken2's). Mash screen finding a second species as well is contamination, judged by the measures above. To make it critical: `critical_taxonomy_species_disagree = >0` in the species' section |
| The analysis itself | critical when the sample was not analysed to the end: a step failed or hit its time limit, or the sample was abandoned ([below](#a-step-failed-or-hit-its-time-limit)). Not a threshold; cannot be switched off |
| Mean read length after trimming | warning < 50 bp |
| Assembly size (*C. jejuni*) | warning outside 1.56–1.98 Mb, critical outside 1.40–2.30 Mb, fail outside 1.37–2.60 Mb |
| Assembly size (*C. coli*) | warning outside 1.56–2.06 Mb, critical outside 1.40–2.30 Mb, fail outside 1.37–2.60 Mb |
| cgMLST loci called (*C. jejuni*, *C. coli*) | warning < 95 %, critical < 90 %, fail < 85 % |
| Assembly size (*S. enterica*) | warning outside 4.47–5.37 Mb, critical outside 4.4–5.8 Mb, fail outside 4.1–6.0 Mb |
| Assembly size (*E. coli*) | warning outside 4.42–5.81 Mb, fail outside 4.0–6.3 Mb |
| Assembly size (*L. monocytogenes*) | warning outside 2.82–3.2 Mb, critical outside 2.8–3.39 Mb, fail outside 2.5–3.6 Mb |
| Assembly N50 (*S. enterica*) | warning < 50 kb, critical < 30 kb, fail < 15 kb |
| Contigs ≥ 500 bp (*S. enterica*) | warning > 150, critical > 300, fail > 500 |
| Assembly GC (*S. enterica*) | warning outside 51.5–53 %, fail outside 50–54.5 % |
| cgMLST loci called (*S. enterica*) | warning < 98 %, critical < 95 %, fail < 90 % |

The assembly size limits come from an SVA survey of the GenBank
assemblies of each species: WARNING is the narrower and CRITICAL the wider
of the range that holds more than 99 % of the GenBank assemblies and the
EURL recommendation; FAIL is NCBI's limit. For *S. enterica* the other
CRITICAL limits are the EURL-Salmonella recommendations (N50 > 30 000, at
most 300 contigs, call rate ≥ 95 %). All are starting points that may
change in a later version.

For *E. coli* and *Listeria* there are no built-in limits for N50,
contigs or cgMLST call rate yet. Add your own ([section 9](#9-settings)) or
judge those values yourself.

Problems that happen during the run (a tool that failed, a time limit, a
missing input) are listed for the sample as well, separately from the
threshold checks. Such a sample is never shown as PASS: the results that
are there may look fine, but some are missing, so its status is CRITICAL
(or FAIL, when the data failed as well) and it is not reportable.

### Can the results be reported?

The sample table of the main report has a column **Reportable**, and each
sample's own report a line with the reason:

| Reportable | When |
|---|---|
| Yes | QC status PASS or WARNING |
| Assess | QC status CRITICAL: not reportable as it is, but a bioinformatician may approve it after looking at the details |
| No | QC status FAIL; or the analysis did not finish (an abandoned sample, or a step that failed). In the second case the QC status is CRITICAL, but there is nothing to assess: run the sample again ([below](#a-step-failed-or-hit-its-time-limit)) |
| Not validated | The species is not one of the configuration's validated species (below). Shown in grey: the sample is not bad, the method is not validated for it |

Hold the pointer over the value for the reason; it is also written out in
the sample's own report. The same verdict is in
`report/tables/eurlc_observed_results.tsv` (columns `reportable`,
`reportable_reason`, `validated_scope`) and in the results fingerprint.

**Validated species.** A lab that has validated the pipeline for certain
species declares them in the config file:

```ini
[general]
validated_species = Campylobacter jejuni, Campylobacter coli
```

A genus alone (`Campylobacter`) covers all its species. Samples of other
species are analysed as usual and all their results are in the report, but
they are marked and not reportable; the same goes for a sample without a
species call. A banner at the top of the main report names the validated
species and the samples outside them, and the run summary has a line
`Scope:`. With nothing declared (the default), nothing is marked. Because
the setting is in the config file, a config seal covers it
([section 12](#12-keeping-an-installation-under-control)).

### A step failed or hit its time limit

The run summary lists the samples and gives the command:

```
  Not finished: 1 sample(s) where a step failed or hit its time limit (QC CRITICAL, not reportable):
    D1_023: skesa (timeout)
    to run the failed steps again, keeping all other results:
      eurlc-wgs outdir=/data/run192/eurlc-wgs --resume skesa.timeout=<longer, e.g. 6h>
```

In the report the sample is CRITICAL and Reportable is No, with the failed
step as the reason. `--resume` runs only what is missing, for all samples
of the run, and rebuilds the reports; the finished results are kept.

- **Time limit** (`timeout`): give the tool more time in the same command
  (`skesa.timeout=6h`; assemblers have 2 hours by default).
- **Exit code**: look in `log/stderr.txt` for the tool's own message first.
  If the cause was temporary (a full disk, the computer was busy), the same
  `--resume` is enough.
- If the step fails again and the tool is not needed, it can be left out:
  `--resume disable=skesa`. Note that this changes what the result is based
  on (here: the main assembly is chosen among the remaining assemblers), so
  in a validated configuration it is a decision for whoever is responsible
  for the method.

The run ends with exit code 5 when a step failed.

### Abandoned samples

A sample below the minimum depth (`fatal_mindepth` and
`fatal_q30_mindepth`, default 30×) is stopped as soon as that is known. It
appears in the report with the reason, and the run ends with exit code 3.
The fix is normally more sequencing, not a setting.

A sample is also abandoned when a step that everything else depends on
fails (trimming, downsampling). It is then CRITICAL and not reportable,
with the step and the tool's message as the reason. When the cause is
solved, `--resume` analyses it again.

### Species and contamination

The species comes from Kraken2/Bracken on the trimmed reads. The
contamination check reports the largest *other* species and genus. Close
relatives that the method cannot separate are not counted (*C. jejuni* /
*C. coli*; *Shigella* for *E. coli*).

### Two strains of the same species in one sample

Kraken2 cannot see a second strain of the *same* species. For that, the
reads are mapped back to the sample's own assembly, and the pipeline counts
how many 1-kb stretches of the genome have positions where part of the
reads carry a different base. That number, *1-kb windows with mixed
positions*, is the measure to look at. It is in the sample's short report
(Contamination) and has its own section in the detailed sample report, right
after the remapping: the measure first (marked &#9733;, with its QC status
or a note that no threshold is set), then what it is built from (the mixed
positions, how many are isolated, their median minor allele fraction, which
is roughly the share of a second strain, the depth, why candidate positions
were set aside, the settings, and a link to every candidate position), and
last the values of the earlier method, for comparison only. With a
threshold set (below) it takes part in the sample's QC status like any
other measure.

How to read it (*C. jejuni*, about 100× depth):

| Windows | What it usually means |
|---|---|
| 0–10 | Normal for a clean isolate |
| 10–30 | Seen in a few clean isolates; no action on this alone |
| above 30 | Possible mixture: look at the sample (assembly size, number of contigs, cgMLST call rate) and consider re-isolating |
| hundreds | A second, clearly different strain at a few per cent or more |

What it cannot do: a second strain below about 5 % of the reads, or one
that is nearly identical to the main strain (same outbreak, a few cgMLST
alleles apart), does not show. A low number is therefore not proof of a
pure culture. Samples with single reads get no value.

No limit is built in yet. To get a QC warning, add
`warning_contamination_mixed_windows=>30` to the species section of your
config file ([section 9](#9-settings)). The value is provisional and was
set on *Campylobacter*; a species with a larger genome needs its own.

If the species could not be determined, the species-specific tools do not
run for that sample and the species thresholds fall back to the general
ones. The run summary lists such samples (`species unknown: S3 --
species-specific tools and thresholds not used`).

### Main assembly

When several assemblers ran, one result is chosen as the main assembly
(default: fewest contigs over 500 bp, after setting aside assemblies of
implausible size). The detailed sample report shows the candidates and why
one was chosen. The others are kept under `alternative_assemblies/`.

### Typing

- **ST**: from FastMLST, with mlst as second opinion. A disagreement is a
  warning.
- **Serotype**: *Salmonella* from SISTR (SeqSero2 if SISTR's own QC fails),
  *E. coli* from ECTyper, *Listeria* from LisSero. *Shigella* is run through
  ECTyper but gets no main serotype.
- **AMR**: AMRFinderPlus and ResFinder results are shown side by side; they
  are not merged into one verdict.

### cgMLST clustering

Per species and schema, under `report/clustering/`: allele distance matrix
and clusters for the samples of this run.

### Tools that did not run

If a sample is of a species whose tools are switched off, the summary says
so and gives the command to add them:

```
  Not run:     species-specific tools that are disabled in the configuration:
    [sistr] 2 Salmonella sample(s): S1, S2
    to run them now, keeping all other results:
      eurlc-wgs --resume enable=Salmonella
```

---

## 7. Everyday tasks

### Analyse another folder

```bash
eurlc-wgs datadir /data/MiSeq_193
```

Results go to `/data/MiSeq_193/eurlc-wgs/`.

### Put the results somewhere else

When the data folder is read-only, or results must be kept elsewhere:

```bash
eurlc-wgs datadir /data/MiSeq_193 outdir /analysis/MiSeq_193_wgs
```

The folder you give *is* the results folder, so name it after the run. An
existing folder with other content is refused.

### Use more of the computer

```bash
eurlc-wgs threads=8                       # threads per tool
eurlc-wgs parallel_mode=on                # several samples at the same time
eurlc-wgs parallel_mode=on max_threads=16 max_ram_gb=48
```

In parallel mode the screen shows a status board instead of a scrolling
log: progress, samples finished, and what is running. Without limits it
uses 85 % of the machine. On a shared or small computer, set
`max_threads` and `max_ram_gb`.

### Continue an interrupted run

```bash
cd /data/MiSeq_192
eurlc-wgs --resume
```

Finished steps are reused; what is missing is run. The samples are the
same as in the first run: new files in the folder are listed in a warning
and not analysed (start a new output folder for them). The report says
that the run was resumed and which results were reused.

With results in another place, the output folder is enough:

```bash
eurlc-wgs outdir /analysis/MiSeq_193_wgs --resume
```

A step that failed, hit its time limit or was interrupted is run again:
its unfinished result was set aside (`<file>.failed`, `.timeout`,
`.interrupted`) and is not reused.

### Run one step again

```bash
eurlc-wgs rerun=spades
eurlc-wgs rerun=lissero lissero.arguments="--min_id 98"
```

The step's results are removed and it is run again, together with every
step that builds on it; everything else is reused. The log lists exactly
which steps that is. `eurlc-wgs --list-steps` lists the step names (and
`--list-tools` the same list together with the tool names for `enable=`,
`disable=` and `<tool>.<setting>=`: a tool is a program with its settings,
a step one stage of the analysis, usually named after its tool). They are
also the names on the status board and in
the log; a misspelt name stops the run and prints the valid ones.

### Switch a tool on or off

```bash
eurlc-wgs disable=skesa
eurlc-wgs enable=plasmidfinder,bakta
eurlc-wgs --resume enable=Salmonella       # add the Salmonella tools to a finished run
```

A species name means all tools specific to that species. A newly enabled
tool is offered for installation at the start of the run.

### Change a tool's settings for one run

```bash
eurlc-wgs fastp.arguments="--detect_adapter_for_pe --cut_right --trim_poly_g --length_required 50"
eurlc-wgs spades.timeout=3h
```

`<tool>.<setting>=<value>`. A misspelt setting stops the run. Note that
`arguments` replaces the whole default argument string.

### Give a slow step more time

Every tool run has a time limit: 30 minutes, 2 hours for assemblers and
10 minutes for FastQC (which sometimes hangs).
A step that reaches it is stopped and reported; the run continues.

```bash
eurlc-wgs spades.timeout=4h        # one tool
eurlc-wgs timeout=1h               # the general limit
eurlc-wgs kraken2.timeout=0        # no limit
```

After a time limit, `--resume <tool>.timeout=4h` runs the step again with
the longer limit.

### Rebuild the report with new thresholds

Change the thresholds in the config file ([section 9](#9-settings)), then:

```bash
cd /data/MiSeq_192
eurlc-wgs summarize
```

Nothing is re-analysed; the stored results are evaluated again and the
reports rewritten.

### Run without anyone watching

```bash
eurlc-wgs datadir=/data/MiSeq_193 --assume-yes --resume > run.log 2>&1
```

`--assume-yes` answers installation questions. What happens to an existing
output folder is never guessed: say `--resume`, `overwrite=yes` or
`overwrite=no`. (`--resume` needs the output folder to exist; use
`overwrite=no` for a first run.)

Exit codes for a calling script:

| Code | Meaning |
|---|---|
| 0 | Finished, every step ran (QC warnings may still be there: read the RESULT line) |
| 1 | Stopped by an error |
| 2 | No input files found |
| 3 | Finished, but at least one sample was abandoned |
| 4 | Interrupted (Ctrl+C, kill) |
| 5 | Finished, but a step failed or hit its time limit |
| 6 | Stopped with `terminate` |

A script or GUI can also read `log/run_status.json`: state, result
(`ok`/`warnings`/`problems`), samples, failed steps and errors.

### Pause or stop a running pipeline

From another terminal:

```bash
echo pause     > /data/MiSeq_192/eurlc-wgs/control/cmd
echo resume    > /data/MiSeq_192/eurlc-wgs/control/cmd
echo terminate > /data/MiSeq_192/eurlc-wgs/control/cmd
```

Running steps are allowed to finish; `pause` starts no new ones until
`resume`, `terminate` then ends the run. Continue later with `--resume`.

Ctrl+C stops at once, the running tools too; their unfinished results are
set aside, and `--resume` runs those steps again.

### Validate against an EURL validation dataset

EURL-Campylobacter provides validation datasets (D1, D2, D3) with expected
results. Run the pipeline on a dataset's FASTQ files as usual:

```bash
cd EURLCAMPY_WGSVAL_D1_v1/fastq
eurlc-wgs
```

When the data folder, or the folder above it, holds a
`<ID>_validation_profile.yml`, the results are compared with the dataset's
expected results by themselves: species, MLST, QC status and QC problems,
cgMLST call rate, reportability, the expected clusters (at the configured
cluster threshold of the schema) and the MD5 of every FASTQ file against the
dataset's file manifest. The verdict is shown at the top of the main report
and in the run summary; the full report, one line per sample and check, is
in `report/validation/`.

`validate=<dataset folder>` uses a dataset elsewhere, `validate=off`
switches it off, and `eurlc-wgs summarize` validates a finished run again.

Every sample gets a *reportable* verdict
([section 6](#can-the-results-be-reported)): PASS and WARNING are reportable
(WARNING with a note), CRITICAL and FAIL are not, nor is an abandoned
sample or a sample outside the configuration's validated species. In a
validation, a sample of a species outside the dataset's target species is
not reportable either, whether or not validated species are declared.

The comparison is made by `eurlc-validate`, which works with any pipeline:
a lab with another pipeline writes its results as a simple table and runs
it. See `docs/eurlc-validate.md`.

### Check that an update did not change the results

Every run writes a *results fingerprint*,
`report/tables/eurlc_results_fingerprint.json.gz`: every result that
matters for a report, per sample (QC status and reportability, species and
contamination, each QC measure's value and status, the mixture measure,
MLST from each tool, serotype, AMR and virulence genes, cgMLST call rate
and the allele of every locus per schema, the selected and the candidate
assemblies with their MD5), and what the run was made with (tool and
database versions, every setting).

After an update of the pipeline, a tool or a database, run a fixed set of
samples again and compare with an earlier run:

```bash
eurlc-wgs-inspect compare /data/verification_2026-06/eurlc-wgs /data/verification_2026-11/eurlc-wgs
```

The comparison lists, per area, what is different, and what the two runs
were made with that differs (versions, settings). Exit code 0 when nothing
differs that was not expected. When a difference is expected (an AMR
database update, say), name it: `--expect amr` (an area),
`--expect qc.coverage` (measures starting with that),
`--expect "assembly.*.md5"` (a pattern). Expected differences are still
listed, but do not count. `--rel-tolerance 0.001` lets numbers that differ
by less than 0.1 % count as the same. `--out <folder>` writes
`comparison.html`, `comparison.tsv` and `comparison.json`.

**Automatically.** Keep the verification samples in one data folder, and
copy the fingerprint of a run you have checked into a `reference/` folder
in it (or next to it):

```bash
mkdir -p /data/verification/reference
cp /data/verification/eurlc-wgs/report/tables/eurlc_results_fingerprint.json.gz \
   /data/verification/reference/2026-11-16_0.1.0.json.gz
```

Every later run of that data folder is compared with the newest file in
`reference/`. The verdict is shown at the top of the main report and in
the run summary; the comparison is in `report/verification/`.
`verify_reference=<file or folder>` uses another reference,
`verify_reference=off` switches it off, `verify_expect=amr,qc.coverage`
names the expected differences. A validation dataset folder can have a
`reference/` folder too: then both run.

**Repeatability.** Give more than one run, and each is compared with the
reference; at the end the number of samples with the same results in every
run is shown per area:

```bash
eurlc-wgs-inspect compare run1/eurlc-wgs run2/eurlc-wgs run3/eurlc-wgs --out repeatability/
```

The same data run twice on the same computer with the same settings should
give the same results. Differences often start in the assembly (another
MD5) and carry over into the steps after it; a different number of threads
is a common cause, and the comparison points out when it differs.

Older output folders have no fingerprint; `eurlc-wgs summarize` in the
folder writes one without analysing anything again.

### Find out why two cgMLST analyses differ

When another pipeline gets a different call rate for the same isolate,
`eurlc-cgmlst-compare` compares the two chewBBACA results locus by locus and
looks up each differing allele in the other side's schema, so you can tell
a schema difference from an assembly or settings difference:

```bash
eurlc-cgmlst-compare explain <ours>/ <theirs>/ --schema-a <our schema> --schema-b <their schema>
```

See `docs/eurlc-cgmlst-compare.md`, which also describes a 2 × 2 run (both
assemblies against both schemas) that separates the causes.

### See what takes the space, or send results for a closer look

`scripts/eurlc-wgs-inspect` reads an output folder and never changes it.
It needs only Python 3.

```bash
# what is there, what takes the space, what could go, duplicate files
eurlc-wgs-inspect inventory /data/MiSeq_192/eurlc-wgs

# the same, with a checksum for every file, saved as a table
eurlc-wgs-inspect inventory /data/MiSeq_192/eurlc-wgs --md5 --manifest MiSeq_192.manifest.tsv

# a small package (usually a few MB) with the tools' own result files,
# logs and report tables for some samples: no reads, no BAM
eurlc-wgs-inspect extract /data/MiSeq_192/eurlc-wgs --samples S12,S17 -o MiSeq_192_review

# every sample of several runs in one table, the spread of each QC measure per
# species, and the issues that come back across runs
eurlc-wgs-inspect summarize /data/MiSeq_*/eurlc-wgs --tsv all_samples.tsv
eurlc-wgs-inspect summarize /data/MiSeq_*/eurlc-wgs --expected known.tsv --species Campylobacter

# a table of the samples to fill in what is known about them (for --expected)
eurlc-wgs-inspect known-template                           # the run you are in
eurlc-wgs-inspect known-template /data/MiSeq_201 --update known.tsv
eurlc-wgs-inspect known-template --all /data               # every run below /data

# the mixture measure of every sample in several runs, and its spread per species
eurlc-wgs-inspect mixture /data/MiSeq_*/eurlc-wgs --threshold 30 --tsv mixture.tsv
```

`inventory` lists the space per folder, step, file type and sample, the
largest files, and the kinds of files that are candidates for removal or
compression, with what each one is. These are suggestions to look at, not
a delete list. Files the report links to are never suggested.

`summarize` is for choosing thresholds and finding problems. For each
species it shows every QC measure's spread (minimum, 5th percentile,
median, 95th percentile, maximum) next to the thresholds in force, and how
many samples got WARNING, CRITICAL or FAIL on it. With `--expected`, a
tab-separated file `run`, `sample`, `expected`, `note` (for example
`MiSeq_192  PT43-10  contaminated  10 % C. coli`; `*` as run means any
run), the spread is taken over the samples listed as `clean`, and each
measure also shows, per label (for example `contaminated 3/4`), how many of
the known problem samples it flags, and their values. Samples not in the
table, or listed as `unknown`, are left out of both. Rows where `expected` is empty are ignored, and other columns are
allowed.

`known-template` writes that table for you (`known.tsv`, or `-o`). It has one
row per sample, with `expected` and `note` empty and, to go by, the
species, QC status, ST and QC issues. Without a run it takes the run you are
standing in: the folder with `eurlc-wgs/` in it, or anywhere inside
`eurlc-wgs/`. Every run below a folder is taken only when asked, with
`--all <folder>`. Open the table in Excel, fill in `expected` (`clean` for
samples whose values are normal) and `note`, and save it as tab-separated
text; files saved from Excel in Windows-1252 are read too. `--update
known.tsv` adds the samples of further runs to the same table and keeps
what you have filled in, and any columns of your own; the previous version
is kept as `known.tsv.bak`. The run is named by the folder above
`eurlc-wgs/`, so two runs with the same folder name get a warning.

A run folder can hold more than one output folder: a QC screen
(`eurlc-wgs_qcscreen`), or an earlier analysis kept under another name
(`eurlc_wgs_1`). When there is an `eurlc-wgs` folder, it is the run, and
`known-template --all` and `summarize` leave the others out (and say so).
`--all-outdirs` takes them too; they are then named by the run folder and
their own name, for example `MiSeq_192/eurlc_wgs_1`. An output folder
without an `eurlc-wgs` next to it is always taken.

At the end, the warnings and errors that occur in the runs are
grouped (numbers replaced by `#`) and counted, so a problem that comes back
in many samples stands out. `--tsv` writes one row per sample with every
measure and its status.

`mixture` lists, per sample, the windows with mixed positions
([section 6](#two-strains-of-the-same-species-in-one-sample)), what they
are built from, and the species and QC status, then the spread per species
(median, 90th and 95th percentile, maximum). Use it on runs of clean
isolates to choose a threshold. Samples analysed with an earlier version
are listed with the command that updates them.

`extract --anonymize` replaces the sample names with S01, S02, ... and the
folder paths with `<OUTDIR>` and `<DATADIR>` in both file names and
contents. The key is written next to the package (`.samplemap.tsv`); keep
it, and do not send it with the package. Look through the package before
you send it: free text, such as a lab name in a read header, is not
replaced.

---

## 8. QC screen for the sequencing lab

A quick check of the raw reads straight after a sequencing run, to decide
which samples are good enough to pass on and which need a
bioinformatician's look:

```bash
cd /data/MiSeq_192
eurlc-wgs --qc-screen
```

It trims the reads, identifies the species and evaluates the read-level QC
thresholds. No assembly or typing is done. Results go to
`eurlc-wgs_qcscreen/` (separate from a normal analysis of the same folder):

- `qcscreen_report.html` — one line per sample with a traffic light
- `qcscreen_status.json` — the same for a program to read

| Light | Meaning |
|---|---|
| Green | All values within thresholds |
| Yellow | A warning threshold is crossed, or the species could not be determined |
| Red | A critical or fail threshold is crossed, or the sample could not be processed |

The thresholds are the same as in the full analysis, so a green sample is
not later failed on its reads. A normal analysis can be started on the
same folder at any time.

Kraken2 needs its whole database in memory. On a small computer, run
without `parallel_mode` (the default), or set `max_ram_gb`.

---

## 9. Settings

### Where settings come from

1. Built-in defaults.
2. A config file. If you give none, `eurlc-wgs.config` in the database
   folder is used when it exists. That is the place for a lab's standard
   settings.
3. The command line, for this run only.

Later sources win. The log and the report list every setting that was
changed on the command line.

### Create and edit a config file

A new installation already has `~/eurlc-wgs_db/eurlc-wgs.config`, written
by `--setup`: every setting is there with its built-in value, as a line
starting with `#`. Remove the `#` and edit the value to change a setting.
Lines left with `#` keep the built-in value, also when a later version of
the pipeline changes it.

```bash
eurlc-wgs --write-configfile
eurlc-wgs --write-configfile=campy-test.config     # in the database folder
eurlc-wgs --write-configfile=/some/folder/my.config
```

writes a file where every setting is in use with its current value
(`configfile=write` is the older form of the same command). A file with
another name is used with `configfile=<name>`: a name without a folder is
looked for in the database folder. That
fixes all of them, also against later changes of the defaults -- for when
the file itself should show every value that applied. It does not overwrite
an existing file without asking.

With `database=<folder>` the file used is `eurlc-wgs.config` in that folder.

The format:

```ini
[general]
threads=16
parallel_mode=on
species_scope=Campylobacter

[fastp]
arguments=--detect_adapter_for_pe --cut_right --trim_poly_g --length_required 50

[spades]
timeout=3h
```

- One `name=value` per line, under a `[section]`.
- A line starting with `#` or `;` is a comment. A comment can also follow a
  value after a space: `timeout=3h   # long reads`.
- A mistyped section, setting name or threshold gives a warning with the
  nearest correct name (`did you mean [spades]?`); the mistyped line has
  no effect.
- A setting may be given only once on the command line; `threads=4
  threads=8` stops the run.

Other config files:

```bash
eurlc-wgs configfile=/db/salmonella.config     # a specific file
eurlc-wgs configfile=default                   # built-in defaults only
```

### Species settings and thresholds

```ini
[species__Salmonella enterica]
genomesize=4900000
maxdepth=100
warning_assembly_size=<4400000 >5800000
warning_assembly_contigs=>300
warning_typing_cgmlst_call_rate=<95
critical_typing_cgmlst_call_rate=<90
```

- The section name is `species__` (two underscores) plus the species name
  as reported by the pipeline.
- A threshold is a comparison, or several separated by a space; it applies
  when any of them is true. `<4400000 >5800000` means "below 4.4 Mb or
  above 5.8 Mb". A value without `<` or `>` (such as `4400000-5800000`) is
  not a threshold and gives a warning.
- Each measure can have `warning_`, `critical_` and `fail_` levels.
- Settings not given for a species come from its genus section, if there
  is one (`[species__Campylobacter]` for every *Campylobacter* species),
  and then from `[species__default]`. A genus section is the easy way to
  give *C. lari*, *L. innocua* or a sample identified only to genus
  sensible values.

The measures that can have thresholds (use the name after `warning_`,
`critical_` or `fail_`):

| Measure | What |
|---|---|
| `qscore_raw_q30_rate`, `qscore_trimmed_q30_rate` | Share of bases ≥ Q30, raw / trimmed reads, as a fraction (`<0.80` = below 80 %) |
| `remap_reads_mapped_pct` | Reads (after trimming and downsampling) that map back to the sample's own assembly (%). Low when part of the reads did not assemble into the genome, e.g. an organism Kraken does not know |
| `remap_properly_paired_pct` | Properly paired reads (%). Falls with long inserts (Bowtie2's default maximum insert is 500 bp), so it is not comparable between libraries; `remap_pairs_diff_contig_pct` is the better pairing check |
| `remap_pairs_diff_contig_pct` | Mapped pairs whose mates are on different contigs (%): a few percent at contig ends; most of the pairs when R1 and R2 come from different samples |
| `remap_breadth_10x_pct` | Assembly covered at ≥10× (%). Against the sample's own assembly, so higher than against a reference: regions with no reads are not in the assembly at all. *Campylobacter* has default warnings on the remapping measures (see the configuration reference); for other species they have no thresholds yet |
| `remap_depth_iqr_over_median` | Depth unevenness along the assembly (interquartile range / median); rises with library GC bias |
| `remap_error_rate_pct` | Mismatches against the assembly (% of mapped bases) |
| `remap_low_depth_contig_pct` | Share of the assembly (bases) in contigs ≥1 kb whose median depth is below 20 % of the genome's: a contaminant at low abundance assembles into its own contigs at a much lower depth (independent of Kraken) |
| `qscore_raw_gc_delta` | GC of the reads minus GC of the assembly (percentage points); a library with GC bias gives reads with higher GC than the genome. No default threshold |
| `qscore_raw_pair_name_mismatch_pct` | % of the read pairs checked by the pre-scan (the first 5 000) whose read names differ between R1 and R2. The R1 and R2 files of a sample have the same reads in the same order; if they come from two different samples (renamed or mixed up), nearly every pair differs, even when both were sequenced in the same run. Defaults: WARNING `>0.5` (a few differing names can occur in usable data), CRITICAL `>5`, FAIL `>50`. The log and the report name examples. Files where R1 holds read 2 and R2 read 1 (swapped) get a warning. |
| `qscore_raw_gc`, `qscore_trimmed_gc` | GC content of the reads |
| `qscore_raw_n_rate` | N bases in the raw reads (%), over the whole files (fastp) |
| `qscore_trimmed_n_rate` | N bases in the trimmed reads (%) |
| `qscore_raw_average_read_length`, `qscore_trimmed_average_read_length` | Mean read length (bp) |
| `qscore_trimmed_average_q_score` | Mean quality score after trimming |
| `qscore_trimmed_adapters` | Adapter content after trimming (%) |
| `qscore_raw_adapter_trimmed_pct` | Reads in which an adapter was found (%) |
| `qscore_trimmed_too_short_pct` | Reads removed as too short after trimming (%) |
| `coverage_raw_coverage`, `coverage_trimmed_coverage` | Depth (×), raw / trimmed reads |
| `coverage_raw_q30_coverage`, `coverage_trimmed_q30_coverage` | Depth counting only Q30 bases (×) |
| `taxonomy_species_score` | Score of the species determination (%) |
| `contamination_species_level`, `contamination_genus_level` | Largest other species / genus in the reads (%) |
| `contamination_mixed_windows` | Two strains of the same species: 1-kb windows of the assembly with mixed positions ([section 6](#two-strains-of-the-same-species-in-one-sample)) |
| `assembly_size` | Assembly size (bp) |
| `assembly_n50` | Assembly N50 (bp) |
| `assembly_contigs` | Number of contigs (all, also the short fragments an assembler writes) |
| `assembly_contigs_500` | Number of contigs of 500 bp or longer — the one to set limits on |
| `assembly_gc` | GC content of the assembly |
| `typing_mlst_incomplete_alleles` | MLST loci (of the seven) without an exact allele: missing (`-`), partial (`?`) or several copies; a new allele (`~12`) or a new ST is not counted |
| `typing_mlst_st_disagree` | 1 when mlst and fastMLST both give an ST and they differ |
| `typing_serotype_missing` | 1 when the serotyping ran but gave no serotype: *Salmonella* serovar from neither SISTR nor SeqSero2, *E. coli* O or H type missing (ECTyper), *Listeria* serogroup missing or nontypable (LisSero) |
| `typing_serotype_disagree` | *Salmonella*: 1 when SISTR and SeqSero2 name different serovars. Alternatives (SISTR `A\|B`, SeqSero2 `A or B`) agree when one name is shared; SISTR's Typhimurium without h2 agrees with SeqSero2's `I 4,[5],12:i:-`. When one tool gives only an antigenic formula, the antigens are compared instead (O factors of SeqSero2 among SISTR's, H1 and H2 equal where both are called). `-:-:-` from both tools counts as a missing serovar (`typing_serotype_missing`), not a disagreement |
| `typing_serotype_tool_flag` | 1 when the QC of the tool whose serotype is reported is not PASS: *Salmonella* -- SISTR `qc_status` when SISTR's serovar is used, otherwise SeqSero2's note (notes in `seqsero2.accepted_notes` do not count); SISTR's messages when it is not used are kept as information (`typing.qc.sistr_qc_info`); ECTyper `qc` with WARNING or FAIL, or ECTyper naming another species |
| `typing_cgmlst_call_rate` | cgMLST loci called (%). Every schema the sample was typed with is judged against its own thresholds; the one with the worst status is reported. Thresholds can be set per schema in `[chewbbaca_schema_<name>]` |
| `typing_cgmlst_inferred_pct` | cgMLST alleles new to the schema (% of the called): a lineage the schema covers poorly, or assembly and sequencing errors. No default threshold |
| `typing_cgmlst_paralogous` | cgMLST paralogous loci (NIPH + NIPHEM), in the schema the call rate comes from |

A threshold is compared with the value as it is shown in the detailed
sample report. A misspelt measure name gives a warning with the nearest
correct one.

### The settings most often changed

| Setting | Default | What |
|---|---|---|
| `threads` | 4 | Threads per tool |
| `parallel_mode` | off | Several samples at once |
| `species_scope` | the four main species | Which species' tools are installed and run |
| `validated_species` | empty | The species the configuration is validated for; samples of other species are marked and not reportable ([section 6](#can-the-results-be-reported)) |
| `main_assembly` | `fewest_contigs500` | How the main assembly is chosen; or the name of an assembler |
| `enable=shovill_spades` (or `shovill_skesa`) | off | Also assemble with Shovill. Not reproducible, see [section 13](#13-known-limitations) |
| `maxdepth` (species) | 100 | Downsampling target; `0` = use all reads |
| `targetbases_floor` (`[species__default]`) | 200000000 | When the genome size had to be estimated from the reads: downsample to no fewer bases than this (200 Mb), so that a too-low estimate cannot cut the data too hard |
| `fatal_mindepth` (species) | 30 | Below this depth the sample is abandoned |
| `timeout` | 30m | Time limit per step |

---

## 10. Species and typing tools

| Species | Specific tools | In scope by default |
|---|---|---|
| *Campylobacter* | (cgMLST schema, species thresholds) | yes |
| *Salmonella* | SISTR, SeqSero2 | yes |
| *E. coli*, *Shigella* | ECTyper, VirulenceFinder | yes |
| *Listeria monocytogenes* | LisSero | yes |
| any | PlasmidFinder, Bakta | off; `enable=` |
| any | CheckM | off; `enable=checkm`. Experimental: its results are not shown in the reports ([section 13](#13-known-limitations)) |

`species_scope` decides which of these are installed by `--setup` and run.
To add a species permanently, add it to `species_scope` in the config
file; for one run, use `enable=<species>`.

**Another species.** It is analysed with everything general: QC, assembly,
MLST, AMR, and cgMLST if you have installed a schema for it. To give it
proper QC limits, add a `[species__<name>]` section with at least
`genomesize` and the thresholds you want (`genomesize=kmer` estimates it
from the reads of every sample, also for a species in the list). Without
one, the genome size is
taken from a built-in list of about 120 species and genera, or estimated
from the reads.

---

## 11. cgMLST schemas

```bash
eurlc-wgs --list-schemas                        # installed and available
eurlc-wgs --install-efsa-schemas                # all four EFSA-compatible schemas
eurlc-wgs --install-efsa-schemas=campylobacter  # one of: campylobacter, ecoli, salmonella, listeria
eurlc-wgs --install-schema=chewie_ns_ecoli      # a schema from the catalog
```

Write these with `=`, not with a space.

| Species | Schema | Loci used |
|---|---|---|
| *C. jejuni* / *C. coli* | `CAMPISO-PubMLST-8` | all (the schema is cgMLST) |
| *E. coli* | `chewie_ns_ecoli` | 2 360 (EFSA filter) |
| *Salmonella* | `chewie_ns_salmonella` | 3 255 (EFSA filter) |
| *Listeria* | `chewie_ns_listeria` | all |

For *Campylobacter* there is also `chewie_ns_campylobacter`
(`--install-schema=chewie_ns_campylobacter`) with an EURL cgMLST selection,
`cgmlst_eurl`: an alternative if the EFSA schema is not available. It is
not EFSA-compatible.

A schema is used for a sample when the schema's species list contains the
sample's species. Schemas live in
`~/eurlc-wgs_db/chewbbaca/schemas/<name>/`, each with a small `schema.ini`
that holds its species list and locus filter. To use a schema for more
species, or switch it off, add to your config file:

```ini
[chewbbaca_schema_chewie_ns_listeria]
species=Listeria monocytogenes,Listeria innocua
```

The pipeline never adds new alleles to a schema during a run, so results
from different runs with the same schema are comparable.

---

## 12. Keeping an installation under control

For labs that need to show that results were produced with a fixed,
validated setup.

**Repair or update a single tool**

```bash
eurlc-wgs infotool=kraken2          # what is installed
eurlc-wgs installtool=kraken2       # install or repair
eurlc-wgs reinstalltool=kraken2     # remove and install again
```

**Update after a new pipeline version**

```bash
cd eurlc-wgs && git pull
bash install.sh --resources-only
conda activate eurlc-wgs && eurlc-wgs --setup
```

`--setup` notices changed tool definitions and offers to update those
environments.

The pipeline does not look for new versions itself, and contacts nothing
outside the computer during a run. To be told about a new version, open
<https://github.com/BoSegerman/eurlc-wgs>, choose *Watch → Custom →
Releases*, and GitHub sends an e-mail for each release. What changed is in
`CHANGELOG.md`. A sealed installation stays at its version: whether and
when it is updated is decided by whoever is responsible for the method.

**Freeze the databases.** Copies each database to a folder named after its
checksum and records it, so that later runs use, and can be shown to have
used, exactly that version:

```bash
eurlc-wgs --freeze-databases
eurlc-wgs --verify-databases     # full check of every database, e.g. before an audit
```

At every start the frozen copies are checked (large files by size and date,
so it is quick; `--verify-databases` checks every byte). The log and the
report name the version of each database where it is known, for example
`Kraken2, Standard-8, Release: 10/15/25`.

**Declare the validated species.** Before sealing, set
`validated_species` in the config file to the species the configuration is
validated for ([section 6](#can-the-results-be-reported)). The seal then
covers it: changing it on the command line gives
`SEAL VERIFIED WITH OVERRIDES`, changing it in the file breaks the seal.

**Seal the configuration.** Records fingerprints of the config file, the
frozen databases and every conda environment under a name:

```bash
eurlc-wgs --generate-seal="Campylobacter-v1.0"
```

The seal also records the pipeline version and its script, and the genome
size lists. Every report then shows one of:

| Status | Means |
|---|---|
| `SEAL VERIFIED` | Everything is as sealed |
| `SEAL VERIFIED WITH OVERRIDES` | As sealed, but the run was started with command-line settings that can change results; the report lists them |
| `SEAL BROKEN` | A file, a frozen database, a conda environment (a tool's, or the pipeline's own) or the pipeline itself has changed since; the report says what. This includes an installation that is no longer what the files describe: an environment that was updated, or a frozen database that could not be used |
| `UNSEALED` | No seal |

Settings that only steer the run (threads, time limits, `--resume`,
`outdir=`, cleanup, ...) do not count as overrides. A new pipeline version
breaks the seal: validate it and seal again.

**The same installation on another computer.** A conda environment made
from the pipeline's YML files gets the builds of the tool's dependencies
that are current that day. Two computers installed on different days
therefore have different environments, and a seal made on one is `SEAL
BROKEN` on the other. To avoid that, `--generate-seal` also writes the
exact package list of every environment in the seal to
`~/eurlc-wgs_db/conda_envs/<environment>.explicit`. On the other computer:

1. Copy the database folder of the sealed installation (config file,
   `db_freeze.config`, `conda_manifest.ini`, `config_seal.ini`,
   `conda_envs/`, `frozen_dbs/`, `installation_check/`) to
   `~/eurlc-wgs_db`.
2. Install the same pipeline version from its source folder:
   `./install.sh` (add `--database=DIR` if the database folder is
   elsewhere). `install.sh` makes the pipeline's own environment from its
   package list, and `eurlc-wgs --setup` makes each tool's environment from
   its list: the same builds, nothing is solved again. An environment
   that is already there and differs from its list is removed and made
   again (`--setup` asks first, unless started with `--assume-yes`); one
   that matches is left as it is.
3. `eurlc-wgs --installation-check` (below).

The package lists are for Linux on x86-64 (also WSL), and the packages are
downloaded from the conda channels when the environments are made. As long
as the lists are in the database folder, `--setup` does not update those
environments from the YML files. To change a sealed installation on
purpose (a new tool version), remove the environment's list from
`conda_envs/`, run `--setup`, verify, and seal again.

**Check an installation.** On a computer where an approved version has
been installed, one command shows that the installation works and gives the
results it should:

```bash
eurlc-wgs --installation-check            # every check set
eurlc-wgs --installation-check=<set>      # one set, or several: set1,set2
```

A *check set* is a small folder of samples with known results in
`~/eurlc-wgs_db/installation_check/<set>/`, made by the person responsible
for the method (below). For each set the command checks, in this order:

| Check | Passes when |
|---|---|
| Files of the check set | every file has the MD5 sum in the set's `.md5` list (nothing is run otherwise) |
| Run | the pipeline run finished |
| Config seal | the status is `SEAL VERIFIED` (without a configured seal: noted as UNSEALED, not a failure) |
| Expected results | every required check against the set's expected results agrees |
| Reference run | no unexpected differences from the set's reference fingerprint (skipped when the set has none) |

It ends with `Installation check: 1 set(s) PASSED` (exit code 0) or
`... FAILED` (exit code 1). Each run is kept, with its report and a record
of the check (`installation_check.txt`: result, check set, pipeline
version, seal, computer, user, time), in
`~/eurlc-wgs_db/installation_check_runs/<set>/<time>_<computer>/`, and one
line per check is added to `installation_check_runs/installation_checks.tsv`.
The test data are read where they are. Other arguments (`threads=`,
`database=`, ...) are passed on to the runs.

A larger set for verifying an update can be kept in the same place and run
by name; `--installation-check` without a name runs every set in the folder.

**Make a check set.** On the installation where the configuration is
sealed, from a validation dataset (a folder with
`<ID>_validation_profile.yml`, its expected results and the reads):

```bash
eurlc-wgs --make-installation-check=K1 from=/data/D1 samples=D1_011,D1_014
```

An unambiguous end of the sample id is enough (`D1_011` for
`EURLCAMPY_WGSVAL_D1_v1_011`). The command copies those samples' reads and
the profile, writes the expected results with only their rows, runs the set
once here, and, when the run finished with a verified seal and agrees with
the expected results, keeps its results fingerprint as the set's reference
and writes the `.md5` list. The set is then in
`~/eurlc-wgs_db/installation_check/K1/`, with a description
(`K1_about.txt`: who made it, when, pipeline version, seal, dataset,
samples), and is copied to other computers with the database folder. The
run it was made from is kept in `installation_check_runs/K1/`.

- If anything fails (a sample not found, the seal not verified, a result
  that does not agree), no set is made and the reason is given.
- An existing set is never overwritten: records refer to a set by name and
  MD5, so a changed set gets a new name.
- A set takes its samples from one dataset. For samples from two datasets,
  make two sets; `--installation-check` runs both.
- `--allow-unsealed` makes a set on an installation without a seal, for
  trying it out. Arguments such as `threads=16` are passed on to the run;
  arguments that change the configuration make the seal `VERIFIED WITH
  OVERRIDES`, and the set is then not made.

**What each run records**, in `log/versioning_explicit/`: the checksum of
each config file and the seal status, which database (path, version,
fingerprint) was used for each database, and the full package list of
every conda environment.

**Names for your instruments.** The report names the sequencing instrument
model from the read headers. To show your own name for an instrument, put
a line `id<TAB><instrument ID><TAB><name>` in
`~/eurlc-wgs_db/known_instruments.tsv`.

---

## 13. Known limitations

This version, 1.0.0-rc2.

**Validation and thresholds**
- The built-in QC thresholds are set from validation data for
  *Campylobacter jejuni*, *C. coli* and *Salmonella enterica*. For
  *E. coli* and *Listeria* only the assembly size has built-in thresholds;
  set the others for your own data before using the status for decisions.
- Contamination below about 4–5 % of the reads is not reliably detected,
  neither by the taxonomic classification nor by the assembly measures.
- With closely related species (for example *Escherichia* in
  *Salmonella*), Kraken2/Bracken can assign part of a clean isolate's reads
  to the related genus, a few per cent, and the sample then fails the
  contamination threshold. Check the assembly size, GC and the re-mapping
  measures before rejecting such a sample.
- A real mixture of *C. jejuni* and *C. coli* is not seen in the
  contamination measures (Bracken shares reads between them); it shows in
  the cgMLST paralogous loci, the assembly size and the call rate.
- The check for two strains of the same species is validated for
  *C. jejuni* (about 100×) and *Salmonella*; it does not see a mixture below
  about 5 % or between nearly identical strains.
- The cgMLST call rate depends on the schema: the same isolate can get a
  somewhat different call rate with another schema for the species. The
  call-rate thresholds are set per schema.

**Running**
- Species thresholds cannot be given on the command line; change them in
  the config file and run `summarize`.
- Some databases are downloaded in their latest version (ResFinder,
  PointFinder, VirulenceFinder, PlasmidFinder, AMRFinderPlus), so two
  installations made at different times can differ. Freeze the databases
  after installing; the frozen version is what a validation refers to.
- Folder paths with spaces or quotes are not supported (the run stops and
  says so).
- The genome size estimate from the reads (only for a species without a
  known size) runs before the status board starts and has no time limit.

**Reproducibility**
- With the default assemblers (SPAdes and SKESA), two runs on the same
  reads with the same settings give the same results, down to the assembly
  file. In tests (November 2026) the assembly files of both were also
  identical when the number of threads was changed.
- **Shovill does not.** With Shovill as the assembler, the assembly differs
  slightly from run to run, also with identical settings and number of
  threads (tested with Shovill and SPAdes on two *C. jejuni* samples: the
  assembly file differed in every run). In those tests the species, MLST,
  every cgMLST allele, the AMR genes and the QC status were the same, and
  the coverage measures differed in the last decimal only. A comparison
  with a reference run (`verify_reference`, `--installation-check`,
  `eurlc-wgs-inspect compare`) will report the assembly as an unexpected
  difference. The pipeline says so at start when Shovill is switched on.
  Do not use Shovill in a configuration that is to be validated on
  identical results.

**Experimental**
- CheckM (`enable=checkm`) runs, but is experimental in this version:
  completeness and contamination are written to the log and to
  `results/qc/stage3_assemblies/CheckM*/.../checkm_results.tab`, but are not
  shown in the reports and are not part of the QC status. The pipeline's
  own measures of the same things are the assembly size, the cgMLST call
  rate and the contamination measures. It takes 3–4 minutes per sample and
  14–16 GB of memory; the first use downloads its database (275 MB).
  Tested with two *Campylobacter* samples only.
- `eurlc-efsa-export` (files for a programmatic submission to the EFSA WGS
  System) is a preview and is not yet aligned with EFSA; it is off by
  default (`export_efsa=off`). See `docs/eurlc-efsa-export.md`.

---

## 14. Troubleshooting

**"Unknown argument given: ..."**
A misspelt argument, or a folder given without `datadir`. Nothing has been
run.

**"[fastp.argumetns] does not match an existing config parameter"**
The tool exists but not that setting. `eurlc-wgs infotool=fastp` shows
the settings of a tool, and `~/eurlc-wgs_db/eurlc-wgs.config` lists them
all.

**"Output directory [...] already exists and overwrite mode is 'prompt'"**
You used `--assume-yes`; add `--resume`, `overwrite=yes` or `overwrite=no`.

**"Cannot write the output folder"**
The data folder is read-only. Use `outdir`.

**"Perl module(s) not found: JSON::MaybeXS ..."**
The pipeline was started outside its conda environment:
`conda activate eurlc-wgs`.

**"[chewbbaca_schema_X] in the config file does not match an installed chewBBACA schema"**
The section's settings are not used. The schema name is misspelt, or the
schema is not installed; `eurlc-wgs --list-schemas` shows the names
(upper and lower case do not matter).

**"Installation check: no check set in [...]"**
There is no check set in `installation_check/` in the database folder.
See [section 12](#12-keeping-an-installation-under-control).

**A tool is "missing or broken" at every start**
`eurlc-wgs reinstalltool=<name>`, then `eurlc-wgs infotool=<name>`.

**A sample is `SE` but should be paired**
Its mate is missing or named differently. Both files need the same name
apart from `R1`/`R2`.

**A sample was abandoned for low coverage, but there is plenty of data**
Check the species: if it was not determined, the genome size used may be
wrong. The detailed report shows which genome size was used and where it
came from. A species section with the right `genomesize` fixes it.

**A step timed out**
`eurlc-wgs rerun=<step> <tool>.timeout=4h`.

**SPAdes gives a much larger assembly than expected**
Usually contamination; check the contamination results. The main-assembly
selection sets aside assemblies of implausible size when another assembler
did better. Keep SKESA enabled as a second opinion.

**A sample has many "windows with mixed positions"**
See [section 6](#two-strains-of-the-same-species-in-one-sample). Above
about 30 for *Campylobacter*, check assembly size and contig count; if
those are high too, the culture is probably mixed. The positions are
listed in `results/qc/stage3_assemblies/remapping/<sample>/<sample>.mixed_positions.tsv`
(rows with `PASS` in the last column): spread over many contigs points to
a mixture, a few tight groups to a repeated region.

**The first run says `db:<name> NOT_INSTALLED`**
The database is not installed yet; the question to install it follows.

**"The report template ... was not found"**
The pipeline's own files are incomplete. Reinstall with `bash install.sh`
(or `--resources-only`).

**The report says `SEAL VERIFIED WITH OVERRIDES`**
The run was started with command-line settings that can change results;
they are listed next to the seal status. For validated work, run without
them.

**A sample has a different name than its files**
Illumina's sample number and lane are removed (`PT43_S12_L001` → `PT43`),
and lanes of one sample are merged; see [section 4](#4-input-files).

**Finding something in the log**
`log/log.txt` has everything, with the time since start on each line. Each
start of the pipeline in that folder begins with a block marked
`EURLC-WGS RUN START`:

```bash
grep -n "EURLC-WGS RUN" eurlc-wgs/log/log.txt
```

The exact commands that were run are in `log/bash_commands.log`, and what
the tools printed in `log/stdout.txt` and `log/stderr.txt`.

**Reporting a problem**
Bugs and suggestions: open an issue at
https://github.com/BoSegerman/eurlc-wgs/issues, with the command you used
and `log/run_summary.txt` and `log/log.txt` from the output folder.
Questions and feedback, or if you do not have a GitHub account: email
bo.segerman@sva.se. Send logs by email rather than as an issue if they
contain sample names or paths that should not be public.

---

## 15. Quick reference

```bash
# run
eurlc-wgs                                   # analyse the current folder
eurlc-wgs datadir /data/run                 # analyse another folder
eurlc-wgs datadir /data/run outdir /out/run # results elsewhere
eurlc-wgs --list-tools                      # tool names (on/off) and step names
eurlc-wgs --recursive                       # include subfolders
eurlc-wgs --fastq | --fasta                 # only reads | only assemblies
eurlc-wgs --qc-screen                       # raw-read QC only

# resources
eurlc-wgs threads=8
eurlc-wgs parallel_mode=on max_threads=16 max_ram_gb=48

# existing results
eurlc-wgs --resume                          # continue
eurlc-wgs --overwrite                       # delete and start over
eurlc-wgs rerun=<step>[,<step>]             # run steps again
eurlc-wgs summarize                         # thresholds again, reports and rundata.json
eurlc-wgs-inspect compare <reference> <run>  # same results as an earlier run?
eurlc-cgmlst-compare explain <A> <B> ...     # why two cgMLST results differ

# tools and settings
eurlc-wgs enable=<tool|species> disable=<tool|species>
eurlc-wgs <tool>.<setting>=<value>
eurlc-wgs <tool>.timeout=3h
eurlc-wgs configfile=<file|default|write>
eurlc-wgs database /other/db

# unattended
eurlc-wgs --assume-yes --resume

# installation and maintenance
eurlc-wgs --setup [--optional] [species=<campylobacter,salmonella,ecoli,listeria|all>]
eurlc-wgs infotool=<tool> | installtool=<tool> | reinstalltool=<tool> | removetool=<tool>
eurlc-wgs --list-schemas | --install-efsa-schemas[=<species>] | --install-schema=<name>
eurlc-wgs --freeze-databases[=<db,...>] | --verify-databases
eurlc-wgs --generate-seal[=<name>]
eurlc-wgs --installation-check[=<set>]      # does this installation give the right results?
eurlc-wgs --make-installation-check=<set> from=<dataset folder> samples=<id,...>   # make a check set
eurlc-wgs --help | --version | --versions

# control a running pipeline
echo pause|resume|terminate > <output folder>/control/cmd
```
