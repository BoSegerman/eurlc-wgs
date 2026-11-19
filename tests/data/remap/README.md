# Test data for the remap step

`smoke/eurlc-wgs/results/qc/stage3_assemblies/remapping/T1/` is a small
synthetic remap result (three contigs, about 30 mixed positions at 12 %,
random sequencing errors, indels, deletions, read-start markers):
`T1.pileup.gz`, `T1.depth.tsv` and the samtools files, as the earlier
version of the step wrote them, plus `T1.remap_qc.json` and
`T1.mixed_positions.tsv` made from them by the code of mixture method 2 as
it was before the streaming way (November 2026).

`tests/smoke.sh` runs `eurlc-wgs --remap-check tests/data/remap`: the
streaming way and the earlier way must both give exactly these results.

When the mixture method changes on purpose (`REMAP_MIXTURE_METHOD_VERSION`
raised), the reference must be made again with the new code: generate the
files with `make_remap.py` (`SMALL=1 python3 make_remap.py <folder> 20261116`
gives the same input), compute the reference, check the differences by hand,
and commit it.
