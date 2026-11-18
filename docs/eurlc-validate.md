# eurlc-validate: checking a pipeline against the EURL-Campylobacter validation datasets

`eurlc-validate` compares the results of any WGS pipeline with the expected
results of an EURL-Campylobacter WGS validation dataset (D1, D2, D3, and
later versions). It reads the dataset's own files and **one table of your
results** in the simple format described below, and writes a validation
report: one line per sample and check, a summary per check, and an overall
verdict.

It needs only Python 3.7 or later (no packages to install) and works with
any pipeline: the only thing your pipeline has to provide is the results
table, and, for the cluster check, a cgMLST distance matrix.

EURLC-WGS writes the results table itself and runs the validation
automatically when it finds a dataset (see the end of this document).

---

## Quick start

```bash
python3 eurlc-validate \
    --dataset  EURLCAMPY_WGSVAL_D1_v1/ \
    --observed my_results.tsv \
    --distances cgmlst_distances.tsv:15 \
    --fastq-dir EURLCAMPY_WGSVAL_D1_v1/fastq/ \
    --out      D1_validation/
```

| Option | What |
|---|---|
| `--dataset <folder>` | The dataset folder: it holds `<ID>_validation_profile.yml` and the expected-results file the profile names (and `<ID>_file_manifest.tsv`) |
| `--observed <file>` | Your results, one row per sample (format below) |
| `--distances <file>[:<threshold>]` | A cgMLST allele distance matrix; repeat the option for several matrices (one per species or scheme). The threshold is the allele distance at or below which your pipeline clusters samples |
| `--cluster-threshold <n>` | The threshold for matrices given without one |
| `--fastq-dir <folder>` or `--fastq-md5 <file>` | Checks that the FASTQ files you analysed are the dataset's files: MD5 computed from the folder, or read from an `md5sum`-style list, and compared with the file manifest |
| `--out <folder>` | Where the report goes (default `validation/`) |
| `--label "<text>"` | Shown in the report, e.g. your pipeline's name and version |

Exit code 0 when every required check agrees, 1 when at least one does not,
2 on a usage error.

Output in `--out`:

| File | What |
|---|---|
| `validation_report.html` | Verdict, summary per check, every check per sample |
| `validation_results.tsv` | The same, one row per sample and check |
| `validation_summary.tsv` | Counts per check |
| `validation.json` | Everything, for archiving or other programs |

---

## The results table (`--observed`)

Tab-separated, one header line, one row per sample. Column order does not
matter; unknown columns are ignored; a value that does not apply is left
empty (or `n/a`).

| Column | Content | Example |
|---|---|---|
| `sample_id` | **Required.** The dataset's sample ID: the FASTQ file name without `_R1.fastq.gz` | `EURLCAMPY_WGSVAL_D1_v1_001` |
| `species` | The species your pipeline reports | `Campylobacter jejuni` |
| `st` | MLST sequence type, with or without `ST` | `257` or `ST257` |
| `mlst_alleles` | The seven alleles, `gene(allele)` separated by `;` (`gene:allele` also works) | `aspA(9);glnA(2);gltA(4);glyA(62);pgm(4);tkt(5);uncA(6)` |
| `qc_status` | Your QC verdict: `PASS`, `WARNING`, `CRITICAL` or `FAIL` | `PASS` |
| `qc_issues` | The QC problems your pipeline found, as the words in the table below, separated by `;` | `contamination;high_contig_count` |
| `cgmlst_called_percent` | Percentage of cgMLST loci called | `99.2` |
| `cgmlst_scheme` | The scheme used (shown in the report) | `CAMPISO-PubMLST-8` |
| `reportable` | `yes` or `no`: would you report this result? If left out, it is derived from `qc_status` (below) | `yes` |
| `reportable_reason` | Free text, shown in the report | `QC FAIL: contamination` |
| `abandoned` | `yes` when the sample could not be analysed to the end | `no` |
| `cluster` | Optional: your cluster label, used only when no distance matrix is given | `C12` |

**QC status and reportability.** `PASS` and `WARNING` count as reportable
(a `WARNING` is noted in the report); `CRITICAL` and `FAIL` count as not
reportable. A sample whose species is outside the dataset's target species
(*C. jejuni* and *C. coli*) is never counted as reportable, whatever its
QC status.

**QC problem words.** Your pipeline does not need to use these names
internally, but the `qc_issues` column must use them, so that problems can be
compared across pipelines:

| Word | Meaning |
|---|---|
| `contamination` | Contamination with another species or genus, or a mixture of strains |
| `low_coverage` | Too low sequencing depth |
| `assembly_size_outside_range` | Assembly size outside the expected range |
| `large_assembly` / `small_assembly` | ... above / below it |
| `high_contig_count` | Too many contigs |
| `low_cgmlst_call_rate` | Too few cgMLST loci called |
| `no_st_determined` | No sequence type |
| `low_n50`, `gc_outside_range`, `low_read_quality`, `low_species_score`, `cgmlst_paralogous_loci` | Other QC findings |

**Distance matrix** (`--distances`): a square tab-separated matrix of
allele differences, first row and first column the sample IDs:

```
Sample	EURLCAMPY_WGSVAL_D1_v1_001	EURLCAMPY_WGSVAL_D1_v1_002	...
EURLCAMPY_WGSVAL_D1_v1_001	0	58	...
```

Several matrices (for example one per species) can be given; a sample is
looked for in each.

---

## What is checked

The dataset's validation profile decides which checks apply; a check is
only made for a sample where the expected value is given (not `n/a`).

| Check | Agrees when |
|---|---|
| `dataset_files` | Every FASTQ file in the manifest was analysed and has the manifest's MD5 (only with `--fastq-dir` / `--fastq-md5`) |
| `species` | Target species: the same species. Non-target challenge species (D3): not reported as *C. jejuni* or *C. coli* (the exact species is shown, not required) |
| `mlst_st` | The same ST (`ST257` = `257`) |
| `mlst_alleles` | Every allele the same |
| `qc_status` | The same class: expected `PASS` and observed `PASS` or `WARNING`; expected `FAIL` and observed `CRITICAL` or `FAIL`. An `alternative_qc_status` in the dataset is also accepted |
| `qc_issue` | The expected QC problem is among the observed `qc_issues` |
| `possible_additional_qc_issues` | Information only: which of the possible secondary problems were seen |
| `cgmlst_call_rate` | Observed percentage ≥ the expected minimum |
| `reportable` | Observed reportability = expected (D3) |
| `cluster` | Samples with the same expected cluster fall in one cluster at your pipeline's threshold (single linkage); for D2 also every pairwise distance ≤ the dataset's maximum. Samples outside the expected cluster that fall into it are listed in the note |

The verdict counts the required checks: `ALL n REQUIRED CHECKS AGREE`, or
`k OF n REQUIRED CHECKS DISAGREE`.

**cgMLST scheme.** Use the scheme your pipeline is configured with; that is
the one being validated. The datasets' reference values are based on the
PubMLST *C. jejuni/coli* cgMLST scheme v2 (1142 loci), which EFSA uses as
`CAMPISO-PubMLST-8`.

---

## With EURLC-WGS

EURLC-WGS writes the results table after every run, as
`report/tables/eurlc_observed_results.tsv`. When the data folder, or the
folder above it, holds a validation profile (as in an unpacked dataset,
where the FASTQ files are in `fastq/` next to the documentation), it runs
the validation by itself, with the distance matrices of the run at each
schema's cluster threshold and the MD5 sums of the raw files:

```bash
cd EURLCAMPY_WGSVAL_D1_v1/fastq
eurlc-wgs
```

The result is in `report/validation/`, at the top of the main report, and
in the run summary. `validate=<dataset folder>` points to a dataset
elsewhere; `validate=off` switches it off. `eurlc-wgs summarize` validates
an existing output folder again without re-analysing.
