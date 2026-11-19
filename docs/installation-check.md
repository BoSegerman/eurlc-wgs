# Installation check

`eurlc-wgs --installation-check` answers one question on the computer where
it is run: does this installation work, and does it give the results it
should? It runs one or more small check sets through the pipeline and compares
the results with what the set says they should be.

It is meant for the person who installs an approved version on a computer.
Verifying an *update* (a new version of the pipeline, a tool or a database) is
a larger task for the person responsible for the method; the same command can
run a larger set for that (`--installation-check=<set>`).

## Running it

```bash
eurlc-wgs --installation-check              # every set in <database>/installation_check/
eurlc-wgs --installation-check=<set>        # one set (or several: set1,set2)
```

Other arguments (`database=`, `configfile=`, `threads=` ...) are passed on to
the runs. The exit code is 0 when every set passes and 1 otherwise.

## What is checked

For each set, in this order:

| Check | Passes when |
|---|---|
| Files of the check set | every file named in the set's `.md5` list is there and has the listed MD5 sum. Nothing is run if this fails. |
| Run | the pipeline run finished. |
| Config seal | a seal is configured and its status is `SEAL VERIFIED`. Without a configured seal the check is noted as UNSEALED and does not fail: the results are checked, the configuration is not. |
| Expected results | every required check against the set's expected results agrees (`eurlc-validate`, `docs/eurlc-validate.md`). |
| Reference run | the comparison with the set's reference fingerprint shows no unexpected differences (`eurlc-wgs-inspect compare`). Skipped when the set has no `reference/`. |

## What is kept

Each run is kept in

    <database>/installation_check_runs/<set>/<date-time>_<computer>/

with the usual output folder (report, log) and a record of the check:
`installation_check.txt` (to read) and `installation_check.json` (the same,
for programs). The record names the result, the check set and the MD5 of its
`.md5` list, the pipeline version, the seal's name and status, the computer,
the user and the times. One line per check is added to
`<database>/installation_check_runs/installation_checks.tsv`.

The test data are read where they are; nothing is copied.

## Making a check set

A check set is a folder laid out as a validation dataset:

    <database>/installation_check/<set>/
        <ID>_validation_profile.yml      what to compare (docs/eurlc-validate.md)
        <ID>_expected_results.tsv        the expected results
        <set>.md5                        md5sum lines for every file of the set
        fastq/                           the reads (or directly in the set folder)
        reference/<date>_<version>.json.gz   optional: results fingerprint of the approved run

1. Copy the reads, the validation profile and the expected results for the
   chosen samples into the folder.
2. Run the set once with the approved version and copy
   `report/tables/eurlc_results_fingerprint.json.gz` from that run to
   `reference/`.
3. Make the list, from inside the set folder:
   `md5sum fastq/* *.tsv *.yml reference/* > <set>.md5`

The MD5 of the `.md5` list identifies the set in the record, so a changed set
is a different set.
