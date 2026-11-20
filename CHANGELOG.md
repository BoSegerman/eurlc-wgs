# Changelog

Changes that a user of the pipeline can notice. The newest version first.

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
