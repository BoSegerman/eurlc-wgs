# eurlc-cgmlst-compare: why two cgMLST analyses of the same isolate differ

`eurlc-cgmlst-compare` compares chewBBACA results and schemas. It answers
the question behind a call rate that differs between two pipelines (for
example eurlc-wgs with the chewie-NS *Salmonella* schema against the SVA
*Salmonella* pipeline with the INNUENDO cgMLST schema): is it the schema,
the assembly, or the settings?

Python standard library only. Installed by `install.sh`.

## Commands

```
eurlc-cgmlst-compare profiles A B [--map M] [--tsv T] [--list-loci L]
eurlc-cgmlst-compare schemas  SCHEMA_A SCHEMA_B [--loci L] [--map M] [--tsv T]
eurlc-cgmlst-compare explain  A B --schema-a SCHEMA_A --schema-b SCHEMA_B [--map M] [--tsv T]
```

- **A, B**: a chewBBACA AlleleCall output folder, or its `results_alleles.tsv`.
  The hashed profile next to it is read too: `results_alleles_hashed.tsv`
  (chewBBACA `--hash-profile crc32`) or `results_alleles_crc32.tsv`
  (eurlc-wgs). With several samples in one file: `--sample-a`, `--sample-b`.
- **--map**: two columns, a locus name in A and the same locus in B, for
  schemas with different locus names.
- **profiles** compares locus by locus: same allele (same CRC32 hash),
  different allele, called on one side only, called on neither; and a table
  of the classes on the two sides (`EXC -> LNF` and so on).
- **schemas** compares the allele content: per locus the alleles both hold,
  the alleles only one holds, whether the representatives (`short/`) are the
  same, the length range; and the md5 of the Prodigal training file and the
  settings files. `.schema_config` is a Python pickle and is only read with
  `--read-config` (only for schemas you trust).
- **explain** runs `profiles`, then for every locus that differs looks up the
  allele one side called (by its hash) in the other side's schema. It first
  checks that the hashes are made the same way as the schemas' sequences
  (CRC32 of the DNA sequence).

## Reading the result

| explain says | means | look at |
|---|---|---|
| only B called; B's allele **IS** in schema A | schema A knows the allele, A did not find it | the assembly (locus missing, split over two contigs: PLOT3/PLOT5/LOTSC), the CDS prediction (training file; ASM/ALM), the settings (`--st`, BSR) |
| only B called; B's allele is **NOT** in schema A | schema B holds an allele schema A lacks | schema content: alleles added locally (runs without `--no-inferred`), a newer or older schema download |
| different allele | both called, different sequences | normally the assembly (a base differing), rarely the schema |

`LNF` on one side with the allele missing from that side's schema: with
`--no-inferred` chewBBACA still calls `INF` when a representative is close
enough (BSR ≥ 0.6); `LNF` means none is. A schema with other representatives
can then call the same locus.

## Separating schema, assembly and settings: a 2 × 2 run

For one or two isolates that differ (for example one ST145 Choleraesuis):

1. Take both assemblies: the one eurlc-wgs made and the one the other
   pipeline made (SVA pipeline: Shovill with SKESA).
2. Run chewBBACA with the **same version and the same options** four times:
   each assembly against each schema.

   ```
   for asm in ours sva; do for schema in chewie_ns innuendo; do
     chewBBACA.py AlleleCall -i asm_$asm/ -g $schema_dir \
       --genes-list <the same 3 255-locus filter, in that schema's names> \
       --hash-profile crc32 --no-inferred --cpu 8 -o run_${asm}_${schema}
   done; done
   ```

3. Compare:
   - `profiles run_ours_chewie_ns run_ours_innuendo` (same assembly): the
     difference that is left is the **schema** (with `explain` and both
     schemas: content or representatives?).
   - `profiles run_ours_innuendo run_sva_innuendo` (same schema): the
     difference is the **assembly**.
   - If neither explains the difference between the two pipelines: the
     **settings** (chewBBACA version, `--st`, BSR, training file, filter) --
     `schemas` shows whether the training files and settings files are the
     same.
4. `schemas SCHEMA_A SCHEMA_B --loci <the loci that differ>` (from
   `profiles --list-loci`) shows what those loci look like in the two
   schemas.

For the EFSA WGS System only the result with EFSA's schema and settings
matters (INNUENDO/Pasteur schema, chewBBACA 3.3.10, `--st 0.05`,
`--no-inferred`, `--hash-profile crc32`; see `eurlc-efsa-export.md`).
