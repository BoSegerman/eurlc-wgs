# eurlc-efsa-export: results for the EFSA WGS System

`eurlc-efsa-export` turns an EURLC-WGS run into the files the **EFSA WGS
System** takes in a programmatic submission (WGS CLI `wgs upload`, or the WGS
API). It also checks every sample against EFSA's business rules before
anything is sent, and makes EFSA's **compatibility report** (our cgMLST
profiles against the EFSA Analytical Pipeline's).

**It never sends anything.** An upload creates *and releases* an entry, and
must be made by an appointed Data Provider. The tool prepares the files and
says which samples are ready.

Sources:
- EFSA (2025) *Guidelines for reporting WGS-based typing data via the EFSA WGS System*, EN-9830, in force from August 2026.
- EFSA WGS System User Manual: "Programmatic submission", with business rules B1–B20, and "Analytical pipeline".
- EFSA's One Health pipeline code (efsa.wgs.onehealth, chewBBACA 3.3.10).

**Status (November 2026): first version.** Several points still have to be
settled with EFSA (see [Open questions](#open-questions)). Until they are,
check the files before the first upload.

---

## Quick start

EURLC-WGS runs the export by itself at the end of every run that has
*Salmonella*, *E. coli*, *Listeria* or *Campylobacter* samples
(`export_efsa=auto`; `off` switches it off). The files are in
`results/export/efsa/`, and the run summary has an `EFSA export:` line. By hand,
also for older runs:

```bash
eurlc-efsa-export export /data/run192/eurlc-wgs --metadata efsa_metadata.tsv
```

Then:

1. Read `results/export/efsa/manifest.tsv` and `preflight.tsv`.
2. Add what the pipeline cannot know (instrument code, sampling data) to the metadata table and run the export again.
3. An appointed Data Provider runs `upload_cli.sh`, or uploads the files through the API.

## What is written

```
results/export/efsa/
  README.txt
  manifest.tsv        one row per sample: READY / READY, WITH WARNINGS / STOPPED / NOT EXPORTED, and why
  preflight.tsv       every check per sample: OK / WARNING / STOP / INFO
  summary.json        counts (read by the pipeline)
  upload_cli.sh       one `wgs upload` line per ready sample
  <sample>/experimentalData.json
  <sample>/typingData.json
  <sample>/allelicProfile.tsv
  <sample>/epidemiologicalData.json   only when the metadata table has sampling data
  <sample>/sampleData.json            the same as one payload, for the WGS API
```

**Which samples are exported.** Only samples that are *reportable* (QC PASS
or WARNING, not abandoned) and of one of EFSA's five species. Other samples
are listed in the manifest as `NOT EXPORTED`, with the reason. A sample with a
`STOP` in the preflight still gets its files, so you can see what is wrong,
but it is not in `upload_cli.sh`.

**Through the API.** The API takes two calls:
1. `sampleData.json` with *UploadResults*.
2. `allelicProfile.tsv` with *UploadResultsAllelicProfiles*, passing the `id` from the first answer as `analyticalPipelineRunId`.

If the second call fails, EFSA deletes the entry, so the preflight matters.

## The metadata table (`--metadata`, setting `efsa_metadata`)

Tab-separated, one row per sample. The first column is the sample name as in
the run. The pipeline uses `efsa_metadata.tsv` in the data folder when there is
one. All columns except the first are optional.

| Column | Goes to | Note |
|---|---|---|
| `sample` | – | the sample name in the run |
| `localRawReadId` | all files | the ID in EFSA's system (at most 50 characters, unique in your organisation); default: the sample name |
| `instrumentModelCode` | experimentalData | code from EFSA's catalogue **INSTRUM** (portal, "Download dataset"); mandatory for typing results according to the guidelines |
| `serotypeId` | experimentalData | catalogue PARAM, optional |
| `sampling_local_id`, `isolation_local_id` | epidemiologicalData | both needed for the file to be written |
| `programme_type_id`, `programme_info_id`, `sampler_id`, `sampling_point_id`, `sampling_country_id`, `sampling_country_origin_id`, `sampling_area_id`, `sampling_year`, `sampling_month`, `sampling_day`, `sampling_matrix_code`, `sampling_matrix_free_text`, `isolation_year`, `isolation_month`, `isolation_day` | epidemiologicalData | catalogue codes PRGTYP, SAMPLR, SAMPNT, COUNTRY, NUTS, MTX (not checked here) |

## The EFSA folder (`--efsa-dir`, setting `efsa_dir`, default `<database>/efsa_export/`)

The files that link a cgMLST schema to EFSA's locus names, one pair per schema
folder name:

| File | Content |
|---|---|
| `<schema>.loci.txt` | EFSA's loci for the species, one per line, **in EFSA's order** (EFSA names; a `.fasta` ending is ignored) |
| `<schema>.locus_map.tsv` | our locus name → EFSA's locus name, two columns, for a schema whose names are not EFSA's (the chewie-NS schemas; the mapping is published on Zenodo, doi:10.5281/zenodo.17084918) |

Which profile is used for a species:
1. `--schema species=<schema>` when given.
2. Otherwise EFSA's own schema, when the run has it: `CAMPISO-PubMLST-8`, `senterica_INNUENDO_cgMLST`, `ecoli_INNUENDO_wgMLST`, or `lmonocytogenes_Pasteur_cgMLST`.
3. Otherwise a schema that has a `locus_map.tsv`.
4. With none of these, the sample is stopped (B14).

*Campylobacter* (CAMPISO-PubMLST-8) is EFSA's own schema and needs no files.

## How the values are made

| EFSA field | From | EFSA's own pipeline |
|---|---|---|
| `allelicProfile.tsv` | the sample's hashed profile (`per_sample/tsv/<sample>.profile.tsv`), translated and ordered as above; anything not a number becomes `0` (B13); row 2 starts with `localRawReadId` | chewBBACA 3.3.10 `--hash-profile crc32`, `-` → `0` |
| `Fastp.ReadMeanLength`, `Q30Rate`, `TotalBases` | fastp in the run, *after filtering*: mean of R1 and R2 length; Q30 as a fraction, 2 decimals | the same fields, fastp with default settings |
| `AssemblyCoverage` | mean depth of the reads re-mapped to the main assembly (Bowtie2, remap step), rounded | Pilon's mean coverage in Shovill |
| `N50Contigs`, `GenomeSize`, `NumberOfContigs` | the main assembly, contigs ≥ 200 bp (when the assembly file is there; else the run's values, with a warning) | CheckM on Shovill contigs (`--minlen 200`) |
| `MLSTSequenceType` | mlst (tseemann): ST as an integer (null when none), the seven alleles | mlst (tseemann) |
| `PredictedSerotype`, *Salmonella* | SeqSero2, else SISTR | SeqSero2 |
| `PredictedSerotype`, *E. coli* | ECTyper | ECTyper 2.0.0 |
| `PredictedPathotype`, *E. coli* | VirulenceFinder (eae, aatA, aggR, aaiC, stx1/2) and AMRFinderPlus (stx); `STEC` / `non-STEC`; gene names as B11 lists them (`eae`, `aat`, `aggr`, `aaic`, `stx1`, `stx2`), best hit each | VirulenceFinder + NCBI stxtyper |
| `PredictedStxType` | stx subtypes from AMRFinderPlus (stxtyper), ECTyper, VirulenceFinder; empty when no stx (B11) | stxtyper; `NA` when none |
| `AMRProfile` | ResFinder hits: name, identity, coverage, database; `NumberPredictedAMResistance` = number of distinct phenotypes | ResFinder 4.1 on reads, `--acquired --point`, DB March 2024 |
| `AnalyticalPipelineInfoTag` | `EURLC-WGS <version>` (+ seal name); setting `efsa_pipeline_tag` | |

## The checks (preflight.tsv)

| Rule | Checked | STOP when |
|---|---|---|
| B1/B5 | mandatory fields present: FASTQ names and MD5, fastp values, serotype where mandatory | missing (instrument code missing: WARNING) |
| B7 | MLST gene names of the species | other genes |
| B8 | Q30 after filtering, by mean read length | < 0.70 (warning: ≤ 0.85 / 0.80 / 0.75 / 0.70 for ≤ 75 / 150 / 250 / > 250 bp) |
| B9 | AssemblyCoverage | < 40× *E. coli*, 30× *Salmonella*, 20× *Listeria* (*Campylobacter*: 30×, warning only) |
| B10 | genome size, N50 > 30 000, contigs | warning only, as at EFSA |
| B11 | *E. coli* pathotype logic | – (warning: stx without subtype) |
| B13 | profile values are numbers, missing = 0 | – (made so) |
| B14 | the loci are EFSA's: names, number, order | no EFSA schema or locus map; a locus of EFSA's list missing |
| B15 | missing loci | > 325 *Salmonella*, 236 *E. coli*, 174 *Listeria* (*Campylobacter*: > 10 %, warning only) |
| B19 | sampling year 1900 – this year | outside |
| ID | `localRawReadId` ≤ 50 characters | longer |

Not checked here: uniqueness in EFSA's database (B2 `localRawReadId`, B3 MD5,
B18 `sampling_local_id`), and catalogue codes (B4, B20).

## Compatibility report

EFSA asks a Data Provider who submits profiles to show that its allele calling
is compatible:
1. Take 10 public entries per species, with different STs, from the EFSA WGS portal.
2. Analyse their reads with your pipeline.
3. Compare the profiles with EFSA's.
4. Send the report to zoonoses_report@efsa.europa.eu.

The manual names EOHsender for this. The same comparison:

```bash
eurlc-efsa-export compat --base efsa_profiles.tsv --test export/*/allelicProfile.tsv --species salmonella --tsv compat.tsv
```

| Verdict | When |
|---|---|
| Perfect | missing + different = 0 |
| Acceptable | missing + different ≤ MAX_DIFF |
| Warning | MIN_ALLELES_DIFF < different < MAX_ALLELES_DIFF |
| Fail | different ≥ MAX_ALLELES_DIFF, or missing + different > MAX_DIFF |

Here *missing* means loci missing in ours but called by EFSA, and *different*
means loci called in both with different alleles. The thresholds are:

| Species | MIN_ALLELES_DIFF | MAX_ALLELES_DIFF | MAX_DIFF |
|---|---|---|---|
| *Listeria* | 4 | 7 | 10 |
| *Salmonella* | 5 | 10 | 15 |
| STEC | 5 | 10 | 15 |
| *Campylobacter* | not given; use `--thresholds` | | |

`--id-map` pairs IDs that differ.

## Open questions

What has to be settled before routine uploads, and where the choice is made:

| # | Question | Now | Where to change |
|---|---|---|---|
| 1 | Do the locus names in `allelicProfile.tsv` end in `.fasta`? EFSA's code adds it to its own profile; B14 points to EN-7413. | no ending | `efsa_locus_suffix=.fasta` / `--locus-suffix` |
| 2 | *Salmonella*, *E. coli*, *Listeria*: EFSA's original INNUENDO/Pasteur schemas (on request from Zoonoses Support; no translation), or chewie-NS schemas with the Zenodo map? | neither installed: these samples are stopped (B14) | install the schema, or put the map and locus list in `<database>/efsa_export/` |
| 3 | chewBBACA size threshold: EFSA's code uses `--st 0.05` for *Campylobacter*, *Salmonella* and *E. coli* (0.2 *Listeria*); the guidelines say 0.2. It decides which alleles are ASM/ALM (missing). | chewBBACA's default 0.2 | `[chewbbaca_schema_<name>] arguments=--st 0.05`, then `rerun=chewbbaca`; validate again (D1–D3 were run with 0.2) |
| 4b | B9 (upload) rejects *E. coli* below 40× assembly coverage, but EFSA's own pipeline uses `minCoverage=30` for *E. coli*. Which is meant? | the preflight stops below 40× (B9); the pipeline's QC fails only below 30× | `SPECIES` table in the script |
| 4 | *Campylobacter*: the business rules (B9, B15) do not name it | EFSA's code values (30×; 10 % missing loci as a warning) | `SPECIES` table in the script |
| 5 | `instrumentModelCode`: the INSTRUM catalogue codes; may it be null? (the manual's example has null, the guidelines make it mandatory) | WARNING when empty | metadata table |
| 6 | AMR: EFSA runs ResFinder 4.1 on reads (`-l 0.6 -t 0.9`, DB March 2024) and puts ResFinder's whole gene object in `GeneList`, PointFinder variations separately; we run ResFinder on the assembly and send name, identity, coverage, database. Is that accepted? Are PointFinder results expected? | our ResFinder | `amr_block()` |
| 7 | *Salmonella* serovar: SeqSero2 (as EFSA) or SISTR when they differ; the Kauffmann–White form | SeqSero2 first | `serotype_block()` |
| 8 | *E. coli* `PredictedStxType` when there is no stx: empty (B11) or `NA` (EFSA's code) | empty | `ecoli_pathotype()` |
| 9 | fastp values: ours come from our trimming settings (adapter detection, `--cut_right`, poly-G, ≥ 36 bp), EFSA's from fastp defaults; read length and total bases differ somewhat | ours | – |
| 10 | Assembly values come from our main assembly (SPAdes or SKESA, chosen per sample) and Bowtie2 depth, EFSA's from Shovill and Pilon | ours | – |
| 11 | chewBBACA version: ours 3.5.x, EFSA's 3.3.10 (guidelines: ≥ 2.8.5) | ours | – |
| 12 | CRC32: the pipeline hashes alleles itself (with SHA-256 alongside, for the collision check). It must equal chewBBACA's `--hash-profile crc32` and zlib. | to be shown by the compatibility report | – |
| 13 | Is there a JSON schema for typingData, and can the catalogues be downloaded machine-readably? | – | – |
| 14 | A local log of what has been uploaded (`localRawReadId`, MD5), to catch B2/B3 before EFSA does | not built | – |
| 15 | A script for the two API calls (key in an environment variable) | not built: `upload_cli.sh` only | – |
