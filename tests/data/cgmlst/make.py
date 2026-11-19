"""Tiny schemas and profiles for the smoke test of eurlc-cgmlst-compare."""
import os, sys, zlib
d = sys.argv[1]
def crc(s): return str(zlib.crc32(s.encode()) & 0xffffffff)
seqs = {"L1": ["ATGAAA", "ATGAAC"], "L2": ["ATGCCC"], "L3": ["ATGGGG", "ATGGGT"]}
for lab, extra in (("sA", {}), ("sB", {"L2": ["ATGCCT"]})):
    os.makedirs(os.path.join(d, lab, "short"), exist_ok=True)
    for l, ss in seqs.items():
        ss = ss + extra.get(l, [])
        with open(os.path.join(d, lab, l + ".fasta"), "w") as fh:
            for i, s in enumerate(ss, 1):
                fh.write(">%s_%d\n%s\n" % (l, i, s))
        with open(os.path.join(d, lab, "short", l + "_short.fasta"), "w") as fh:
            fh.write(">%s_1\n%s\n" % (l, ss[0]))
# A: L1=1, L2=LNF, L3=2 ; B: L1=1, L2=2 (ATGCCT, only in schema B), L3=1 (different)
for lab, al, hs in (("pA", ["1", "LNF", "2"], [crc("ATGAAA"), "-", crc("ATGGGT")]),
                    ("pB", ["1", "2", "1"], [crc("ATGAAA"), crc("ATGCCT"), crc("ATGGGG")])):
    os.makedirs(os.path.join(d, lab), exist_ok=True)
    for fn, vals in (("results_alleles.tsv", al), ("results_alleles_hashed.tsv", hs)):
        with open(os.path.join(d, lab, fn), "w") as fh:
            fh.write("FILE\tL1\tL2\tL3\n%s\t%s\n" % (lab, "\t".join(vals)))
