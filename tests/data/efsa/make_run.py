#!/usr/bin/env python3
"""Make a tiny synthetic eurlc-wgs output folder for testing eurlc-efsa-export:
one C. jejuni sample (CAMPISO-PubMLST-8 profile, 1142 loci, 5 missing) and one
E. coli sample with only a chewie-NS profile (must be stopped: no locus map).
Usage: make_run.py <outdir>"""
import json, os, sys, zlib, random
out = sys.argv[1]
random.seed(1)
def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
def sample(name, species, mlst, extra=None):
    s = {"name": name, "type": "PE",
         "paths": {"raw": {"R1": "<DATADIR>/%s_R1.fastq.gz" % name, "R2": "<DATADIR>/%s_R2.fastq.gz" % name, "SE": ""}},
         "qc": {"status": "PASS"}, "fatal_error": 0,
         "main_results": {"taxonomy": {"species": species}, "reportable": {"value": "yes", "reason": "", "note": ""},
                          "assembly": {"remap_mean_depth": "85.4", "N50": "185831", "size": "1699778", "contigs": "36"},
                          "run_data": {"instrument_type_guess": "MiSeq"}},
         "results": {"fastp_rawdata": {"summary": {"after_filtering": {"read1_mean_length": "229", "read2_mean_length": "200",
                                                                         "q30_rate": 0.947, "total_bases": 695712385}}},
                     "mlst": {"main": dict(mlst)},
                     "resfinder_fasta": {"resfinder_hits": [{"resistance_gene": "blaOXA-61", "identity": "100.00", "coverage": "100.0",
                                                             "phenotype": "Amoxicillin, Ampicillin"}]}}}
    if extra:
        s["results"].update(extra)
    w(os.path.join(out, "results/qc/stage1_rawdata/md5/md5-%s.txt" % name),
      "%032x  /x/%s_R1.fastq.gz\n%032x  /x/%s_R2.fastq.gz\n" % (random.getrandbits(128), name, random.getrandbits(128), name))
    return s
cj = sample("CJ1", "Campylobacter jejuni", {"allele_aspA": "2", "allele_glnA": "4", "allele_gltA": "1", "allele_glyA": "2",
                                              "allele_pgm": "7", "allele_tkt": "1", "allele_uncA": "5", "st": "48"})
ec = sample("EC1", "Escherichia coli", {"allele_adk": "6", "allele_fumC": "4", "allele_gyrB": "12", "allele_icd": "16",
                                          "allele_mdh": "9", "allele_purA": "7", "allele_recA": "7", "st": "29"},
            {"ectyper": {"serotype": "O26:H11", "stx_subtypes": "stx2a"},
             "virulencefinder": {"hits": [{"gene": "eae-b01a", "identity": "99.9", "coverage": "100"},
                                          {"gene": "stx2a-o157", "identity": "99.9", "coverage": "100"}]}})
loci = ["CAMP%04d" % i for i in range(1, 1143)]
vals = [str(zlib.crc32(("seq%d" % i).encode())) for i in range(1142)]
for i in (3, 50, 77, 300, 1000):
    vals[i] = "-"
w(os.path.join(out, "results/clustering/chewbbaca/Campylobacter_jejuni/CAMPISO-PubMLST-8/per_sample/tsv/CJ1.profile.tsv"),
  "FILE\t" + "\t".join(loci) + "\nCJ1\t" + "\t".join(vals) + "\n")
w(os.path.join(out, "results/clustering/chewbbaca/Escherichia_coli/chewie_ns_ecoli/per_sample/tsv/EC1.profile.tsv"),
  "FILE\tL1\tL2\nEC1\t1\t2\n")
run = {"pipeline_info": {"version": "0.1.0-test"}, "samples": [cj, ec],
       "provenance": {"run": {"tools": {"mlst": {"version": "2.35.0"}, "resfinder": {"version": "4.7.2"}}}}}
w(os.path.join(out, "data/rundata.json"), json.dumps(run))
