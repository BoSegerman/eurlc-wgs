# Changelog

Changes that a user of the pipeline can notice. The newest version first.

## 1.0.0-rc3 (23 November 2026)

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
