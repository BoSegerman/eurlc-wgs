# Changelog

Changes that a user of the pipeline can notice. The newest version first.

## 1.0.0 (November 2026)

The first public release.

**What it does**
- Takes Illumina paired-end reads or finished assemblies of bacterial
  isolates and runs read QC and trimming, species identification and
  contamination checks, assembly, MLST, cgMLST with chewBBACA, AMR and
  virulence genes, serotyping and cgMLST clustering.
- Gives every sample a QC status (PASS, WARNING, CRITICAL or FAIL) with the
  reasons, and says whether it is reportable. A sample whose analysis did
  not finish is CRITICAL, never PASS.
- Writes an HTML report for the run and an HTML and PDF report per sample.
- Specific support for *Campylobacter jejuni* and *C. coli* (EFSA schema
  CAMPISO-PubMLST-8 as the default), *Salmonella enterica*,
  *Escherichia coli* and *Listeria monocytogenes*.

**Traceability**
- Tool versions are locked in conda package lists; databases are frozen
  under a version ID that depends only on their content.
- A configuration seal ties the config file, the frozen databases, the
  conda environments and the pipeline script together under a name. Every
  report shows the seal and its status at the time of the analysis.
- A sealed installation can be copied to another computer and checked there
  with a small set of samples with known results
  (`eurlc-wgs --installation-check`).
- `eurlc-wgs-inspect compare` compares two runs of the same samples, result
  by result.

**Known limitations** are listed in section 13 of the manual.
