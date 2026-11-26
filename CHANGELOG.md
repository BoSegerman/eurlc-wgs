# Changelog

Changes that a user of the pipeline can notice. The newest version first.

## 1.0.0-rc3 (26 November 2026)

### Changed

- **Installation is done in one step, for the species you choose.**
  `install.sh` asks which species the installation is for (or takes
  `--species=campylobacter,salmonella`; without a terminal: all), and
  `eurlc-wgs --setup` then installs the tools, the databases and the cgMLST
  schema of each chosen species. It ends with the species the installation
  is ready for. Schemas no longer need a separate
  `--install-efsa-schemas` (which still works).
- **`eurlc-wgs --setup species=<name>`** adds a species to an existing
  installation.
- **A new installation gets a configuration file**
  (`<database>/eurlc-wgs.config`) with `species_scope` set and every other
  setting listed, commented out, with its built-in value.
- **`--setup` looks at what is in the database folder**: a sealed
  installation is used as it is (nothing downloaded, `species=` refused),
  an existing one is checked and completed, a new one is installed.
- **With `database=<folder>` the configuration file is
  `<folder>/eurlc-wgs.config`.** Before, the file in the default database
  folder was used unless `configfile=` was given.
- **`--parallel` and `--no-parallel`** are short for `parallel_mode=on` and
  `parallel_mode=off`.
- `--installation-check` on an installation without a check set explains
  what a check set is and how to get or make one, instead of an error line
  (the exit code is still 1: nothing was checked).
- **The user manual is installed as one HTML file and as a PDF**, and
  `eurlc-wgs --manual` says where they are. Both are built from
  `docs/eurlc-wgs-user-manual.md` with `scripts/build-manual` and are also
  in `docs/`.
- **`--help` is for running an analysis; `--help-admin` is new** and holds
  what belongs to looking after an installation: single tools, schemas,
  freezing, sealing, check sets, and comparing with validation datasets and
  earlier runs. `--remap-check` is no longer listed (it still works).
- **`--list-tools` / `--list-steps`** show the tool names for `enable=`,
  `disable=`, `<tool>.<setting>=` and `installtool=` (with whether each is
  on), and the step names for `rerun=`.
- **`--write-configfile[=<file>]`** is the new way to write a settings file
  with every setting in use; a name without a folder is written in the
  database folder. `configfile=write` still works.
- `--list-schemas` ends with the ways to install a schema, the usual one
  (`--setup species=...`) first.
- **`--make-installation-check=<set> from=<dataset folder> samples=<ids>`**
  makes a check set for `--installation-check` from a validation dataset in
  one step: the samples' reads and expected results, a run on the sealed
  installation, and that run's results as the set's reference. Before, a
  set was put together by hand.
- **A sample that was not analysed to the end is CRITICAL, not PASS.** When
  a step failed or hit its time limit, or the sample was abandoned, its QC
  status stayed at PASS (with Reportable: No), so a run where many samples
  had failed could look fine at first sight. The status is now CRITICAL,
  with what happened as the reason; Reportable is No as before. The run
  summary has a new block "Not finished:" with the samples and the
  `--resume` command that runs the failed steps again. Results made with an
  earlier version show these samples as PASS in `qc_status`; a comparison
  with such a reference reports the difference.
- **A report shows the seal the analysis was made under.** The seal was
  verified when a report was written, so `--summarize` after a new seal
  gave a report that said `SEAL VERIFIED` with the new seal name and the
  new script MD5 for an analysis made under the old ones. The seal (status,
  name, pipeline version and script MD5) is now written to the run's data
  when the analysis ends, and is what the report, the validation label,
  the EFSA export and the results fingerprint show. A report made later
  under another seal or script says `SEAL CHANGED SINCE THE ANALYSIS` and
  shows both; a run resumed under another seal is `SEAL BROKEN`; a run
  from before this was recorded says `SEAL OF THE ANALYSIS NOT RECORDED`
  when it is summarized under a verified seal. The run summary in the
  terminal has a `Seal:` line.
- **Main report, sample overview: the ST shown is the selected one**
  (`general.mlst_determination`, by default fastMLST), with the other
  tool's ST beside it in the tooltip. The cell showed the ST of the tool
  that finished first, labelled "mlst (tseemann)| fastmlst (CC)" -- the
  same ST whenever the tools agree.
- Main report: the date range read "â€“" for the dash; the cgMLST tooltip
  had no schema name; "k-mer coverage: 0.00x" was shown for SKESA
  assemblies; the AMRFinderPlus database is shown with its version;
  "Infered" is spelled "Inferred".
- **A sealed installation copied to another computer** (found the first
  time it was done, 25 November):
  - `--setup` passed tool environments that were already on the computer
    as "installed" without comparing them with the package lists of the
    seal, so they kept their own builds and the seal broke at the first
    run. An existing environment is now compared with its list and made
    again from it when it differs (the pipeline's own environment already
    was, by `install.sh`).
  - `--setup` reported every cgMLST schema as missing, because it looked
    for the live schema folders and a copied installation has the frozen
    copies only. A frozen copy now counts.
  - A run did not find the cgMLST schemas: they were only looked for as
    live folders (`chewbbaca/schemas/<name>`), so their frozen copies were
    reported `NO_PATH`, the seal was BROKEN and no cgMLST was made. A
    schema that is here as a frozen copy only is now registered from it.
  - The AMRFinderPlus database, which is inside its environment and so
    cannot be copied, is installed by `--setup` also in a sealed
    installation when it is missing.
- `install.sh --resources-only` no longer ends by saying that tools and
  databases are not installed.
- **SKESA: the assembly graph can no longer cost the assembly.** The
  graph step (`gfa_connector`) ran between the assembly and the copy of
  the result, with every core of the computer and no time limit of its
  own. On a 68-core workstation it hung for one sample until SKESA's
  2-hour limit, and the finished assembly was lost with it (the sample
  became CRITICAL). The assembly is now copied first; the graph step
  gets the same number of threads as SKESA and 10 minutes, and when it
  fails or runs out of time the sample only lacks the SKESA graph.
- Start of a run: a verified seal is shown (`Config seal [name]: SEAL
  VERIFIED`); before, only a broken seal gave a line.
- Setup and freeze: Bracken is no longer reported as "database
  installed" (it has none of its own); the Listeria schema is labelled
  cgMLST; the fastMLST database gets a source label when it is installed;
  `--verify-databases` no longer suggests naming databases that have a
  git commit as their label, and says "full check" instead of "once";
  several log lines ran into the next one.
- Main report: the links to the matrix viewer, the downloads and the AMR
  profile viewer have no symbol before the text (the PDF showed an empty
  box). The QC note "Assess mash-screen status do not pass" reads "Mash
  screen status is not PASS". The start-up line about a tool's database
  names the file it measures, and gives the AMRFinderPlus database
  version (it said "Database size 13.00 B").
- **The fastMLST database is part of the installation.** fastMLST kept
  its PubMLST database in `~/.cache/fastmlst/pubmlst`: one copy per user,
  downloaded at that user's first run, outside the conda environment, not
  frozen, not sealed and not in the report. It is now installed by
  `--setup` in `<db>/fastmlst/pubmlst`, frozen and sealed like the other
  databases, and listed under Database versions. **Run `--setup`, then
  `--freeze-databases`** (and `--generate-seal`). A run stops at start
  when the database is missing or not complete; `~/.cache/fastmlst` is no
  longer used and can be removed.
- **A cgMLST schema gets the same version ID in every installation.** The
  ID is the MD5 of the schema's marker file, and that file held the schema
  name and the time of freezing, so two installations with the same schema
  showed two versions. The marker now holds only the loci (name and size)
  and the filter. **Run `--freeze-databases` again** (and `--generate-seal`
  for a sealed installation): markers from earlier versions are made
  again and every schema gets a new ID. Until then an installation keeps
  working with its old ID. The schemas and the results are unchanged.
- `eurlc-wgs-inspect compare`: when the reference and the run have the same
  loci under two schema IDs, the results are compared locus by locus, and
  the ID difference is one line per sample (`cgmlst.reported.schema`; name
  it with `--expect` when it is known). Before, every cgMLST value was
  listed as missing on one side.
- **A mixture of two strains of the same species is CRITICAL for
  *Campylobacter*** when more than 350 1-kb windows have mixed positions
  (`critical_contamination_mixed_windows`; about a fifth of the genome, the
  same share as the *Salmonella* limit). Before, there was only the WARNING
  above 100, so a sample with 20 % of a second strain, where 20 cgMLST
  alleles were changed, was reportable without review. The limit can be
  changed in the species' section of the config file.
- **Kraken2 and Mash screen naming different species is a WARNING**, not
  CRITICAL (`warning_taxonomy_species_disagree`), until it is better
  understood. The reported species is Kraken2's. It can be raised per
  species with `critical_taxonomy_species_disagree = >0`.
- **`--setup` writes a log**, to
  `<database>/setup_logs/<date-time>/log/log.txt`. Before, its messages
  were only on the screen, and an empty `eurlc-wgs/log` folder was left in
  the folder it was started from.
- The closing message of `--setup` no longer lists `--freeze-databases` and
  `--generate-seal` as next steps; it points to the manual.

### Fixed

- **Parallel mode: the Kraken2 pre-check of two samples could use the same
  temporary files.** The first 100 000 read pairs of every sample were
  written to one file name in a shared folder. When two samples reached
  the step at the same time, the files were overwritten or removed while
  Kraken2 read them: the step could hang until its time limit, or finish
  on a few thousand reads, possibly from the other sample. Each sample now
  has its own files. Sequential runs were not affected.

- **Parallel mode could start a step on reads that were still being
  written.** A step's input counted as ready as soon as the file existed
  and was not empty, which it is from the moment the step before starts
  writing it. Downsampling could read the trimmed reads while fastp was
  writing them, and the assemblers, Mash screen, Kraken2 and the read
  statistics could read the downsampled reads while they were being
  written. Small samples were finished before the next tool had opened the
  file; a large sample failed (SPAdes, SKESA and Mash screen with errors,
  downsampling at its time limit), and a tool that does not notice a
  truncated file could have given a result from part of the reads. A step
  now waits until every step that produces its input has finished, and is
  skipped ("an earlier step failed") when that step failed or timed out,
  instead of running on what was written. Sequential mode (the default) was
  not affected. **Results made in parallel mode with an earlier version
  should be compared with a sequential run** (`eurlc-wgs-inspect compare`).
- **`--recursive` did not look in subfolders.** It now does. Output folders
  of the pipeline itself (this run's, or an earlier run's inside the data
  folder) are not searched, so trimmed reads and assemblies are not taken
  for samples.
- **`--fastq` and `--fasta` stopped the run** with "not a recognized
  yes/no value". They work again: only the reads, or only the assemblies,
  of the folder are analysed.
- **The reports named a frozen cgMLST schema by its checksum.** In the
  Clustering table, the matrix viewer and the download page, the schema of
  a frozen database was shown as its 32-character version checksum. They
  now show the schema's name and the number of loci typed, with the frozen
  version as a detail: "CAMPISO-PubMLST-8 (1142 loci; frozen version ...)".
  Folder and file names are unchanged.
- **The "Database versions" table of the reports was incomplete.** With a
  `db_freeze.config` it listed only the Mash sketch and the databases
  inside tool environments (mlst, AMRFinderPlus); Kraken2, ResFinder,
  VirulenceFinder, PlasmidFinder and the cgMLST schemas were missing. It
  now lists every database resolved for the run, with its version, the MD5
  of its marker files and whether the frozen or the live copy was used,
  Bracken beside Kraken2 (same database), and the cgMLST schemas the
  clustering was made with (name, version, loci, frozen version).
- **`schema.ini` was written with characters encoded twice**: the dash in
  its first line and in the CAMPISO label showed as "â" and two control
  characters, and each time a filter was set, every non-ASCII character of
  the file was encoded once more. The file is now written as it is, and the
  pipeline's own text in it is plain ASCII. Existing files work as they are
  (the label and the comment are not used for anything).
- **`--setup` could report a database as present when only its folder
  was.** After a failed download, the next `--setup` did not offer the
  database again (seen with the Mash database). The database's files must
  now be there and not empty.
- The Mash database is downloaded under a temporary name, so an interrupted
  download cannot be taken for the database. The Kraken2 download stops at
  the first failing step.
- A cgMLST schema folder left by an interrupted installation is moved to
  `chewbbaca/incomplete/` and the schema installed again.
- `install.sh` ends with "Installation is NOT complete" and exit code 1
  when setup reported problems.

## 1.0.0-rc2 (21 November 2026)

### Fixed

- **Downsampling failed for some samples with "truncated or corrupt
  input".** BBMap 40.02 reads `.gz` files with its own multithreaded
  reader by default, and that reader lost part of a line in files written
  by fastp, although the files were intact. `reformat.sh` is now run with
  `unbgzip=f unpigz=f`, which makes it use Java's own gzip reader. In the
  D1 validation dataset this stopped 14 of 50 samples.

  Before 1.0.0-rc1 this failure was not noticed by the pipeline (the exit
  code of `reformat.sh` was not the one that counted): a sample could go on
  with only the reads that had been written before `reformat.sh` stopped.
  Look for `truncated or corrupt input` in `log/stderr.txt` of earlier
  runs made with BBMap 40.

## 1.0.0-rc1 (20 November 2026)

Release candidate for 1.0.0. Feature-frozen: only corrections from here to
1.0.0.

### New

- **`--installation-check`**: runs the check set(s) in
  `<database>/installation_check/` and compares the results with their
  expected results and reference run. Keeps a record of every check.
  See `docs/installation-check.md`.
- **Validated species** (`validated_species` in `[general]`): the species a
  configuration is validated for. Samples of other species are analysed,
  but marked and not reportable. A config seal covers the setting.
- **Reportable in the reports**: the sample table of the main report has a
  column *Reportable* (`Yes`, `Assess`, `No`, `Not validated`; the reason
  is the tooltip), and each sample report a line with the reason. New column `validated_scope` in
  `report/tables/eurlc_observed_results.tsv` and in `log/run_status.json`.

- **The same installation on another computer**: `--generate-seal` writes
  the exact package list of every conda environment to
  `<database>/conda_envs/`. With those lists in the database folder,
  `install.sh` and `--setup` make the environments from them, so that a
  seal made on one computer verifies on another. `install.sh` has a new
  option `--database=DIR`.

- **QC: the two species methods against each other.** When the species
  Kraken2 reports is not among those Mash screen finds, the sample is
  CRITICAL (`critical_taxonomy_species_disagree`). Before, the disagreement
  was only a line in the log. A reference fingerprint made with an earlier
  version does not have this measure, so a comparison reports it as a
  difference once: make the reference again.

### Changed

- The log message for a species difference between Mash screen and
  Kraken2 says in words what each found.
- CheckM (`enable=checkm`) now says at start that it is experimental: its
  results are not shown in the reports.
- With Shovill switched on, the pipeline says at start that its assemblies
  are not reproducible (Known limitations in the manual).
- **A config seal now also breaks when the installation is not what its
  files describe**: a conda environment that differs from
  `conda_manifest.ini`, or a frozen database that could not be used.
  Before, these gave a warning while the report said `SEAL VERIFIED`.
- **The pipeline's own conda environment (`eurlc-wgs`) is part of the
  seal** and is recorded with every run. A seal made with an earlier
  version must be generated again.
- A step whose tool fails is now always reported as failed. In several
  steps a closing `rm`, `cp` or `cat` decided the outcome, so a failed
  downsampling, assembly (SPAdes, SKESA, Shovill) or Kraken2 run could
  count as done. After a failed downsampling the incomplete read files are
  removed.
- SISTR, SeqSero2, ECTyper, VirulenceFinder and PlasmidFinder remove an
  earlier result before they run, and the step succeeds only when a result
  file was written.
- The run summary counts an abandoned sample as `ABANDONED`, not as QC
  `PASS`.
- A sample without a species call is not reportable when validated species
  are declared.

### Fixed

- A `[chewbbaca_schema_<name>]` section for a schema with capitals in its
  name (such as `CAMPISO-PubMLST-8`) was ignored without a message. The
  name is now matched without regard to case, and a section that matches no
  installed schema gives a warning.
- Started from another folder than the data folder (`datadir=`, `outdir=`),
  the tools' stdout and stderr went to `<current folder>/eurlc-wgs/log`,
  and every tool failed when that folder did not exist.
- `--version` and `--help` work outside the conda environment; anything
  else started there stops with a message that says what to do.
- `tests/data/` was left out of the repository by `.gitignore`, so the
  smoke test failed on a fresh clone.

### Removed

- The Unicycler environment file (Unicycler has not been part of the
  pipeline since 0.1.0). An old config that names it still works, with a
  notice.

## 0.1.0-beta1 (November 2026)

First version given to external testers.
