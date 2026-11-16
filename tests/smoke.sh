#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tests/smoke.sh -- quick checks of eurlc-wgs without tools or databases.
#
# Runs the pipeline script against a fake `conda` and a few tiny FASTQ files
# in a temporary folder, and checks what happens before any tool would run:
# arguments, settings files, sample names and lanes, output folders, exit
# codes, status file. Takes well under a minute. Run before every release
# (RELEASE.md) and after larger changes:
#
#     bash tests/smoke.sh            # from the repository root
#     KEEP=1 bash tests/smoke.sh     # keep the temporary folder for a look
#
# Needs perl with the pipeline's modules (the eurlc-wgs environment), gzip.
# Nothing outside the temporary folder is touched; HOME is redirected there.
# -----------------------------------------------------------------------------
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO/bin/eurlc-wgs"
[[ -f "$SCRIPT" ]] || { echo "Cannot find $SCRIPT"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/eurlc-wgs-smoke.XXXXXX")"
trap '[[ "${KEEP:-0}" == 1 ]] && echo "Kept: $T" || rm -rf "$T"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; }
check(){ # check "<what>" <condition...>
    local what="$1"; shift
    if "$@"; then ok "$what"; else bad "$what"; fi
}

# --- fake conda: knows every eurlc-wgs environment, runs nothing ------------
mkdir -p "$T/conda/bin" "$T/home/eurlc-wgs_db" "$T/work"
cat > "$T/conda/bin/conda" <<'EOF'
#!/bin/sh
case "$*" in
  "env list"*)
    echo "# conda environments:"
    for e in fastp fastqc jellyfish illumina-interop bbmap bowtie2 kraken2 bracken \
             krakentools krona mash spades shovill skesa checkm-genome quast \
             bakta mlst fastmlst weasyprint chewbbaca multiqc sistr seqsero2 ectyper \
             lissero virulencefinder plasmidfinder ncbi-amrfinderplus resfinder; do
      echo "eurlc-wgs-$e  /fake/envs/eurlc-wgs-$e"
    done
    echo "eurlc-wgs  /fake/envs/eurlc-wgs" ;;
  "info --base"*) echo /fake ;;
esac
exit 0
EOF
chmod +x "$T/conda/bin/conda"

export HOME="$T/home"
export CONDA_EXE="$T/conda/bin/conda"
export PATH="$T/conda/bin:$PATH"

run() { # run <outfile> <args...> ; sets RC
    local out="$1"; shift
    ( cd "$T/work" && timeout 120 perl "$SCRIPT" --no-color "$@" < /dev/null > "$out" 2>&1 )
    RC=$?
}

# --- tiny reads ------------------------------------------------------------
fq() { # fq <file> <n reads>
    local f="$1" n="$2" i
    for ((i=1; i<=n; i++)); do
        printf '@M01137:1:000000000-ABCDE:1:1101:%d:1000 1:N:0:1\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' "$i"
    done | gzip -c > "$f"
}
D="$T/data"; mkdir -p "$D"
fq "$D/A_S1_L001_R1_001.fastq.gz" 20;  fq "$D/A_S1_L001_R2_001.fastq.gz" 20
fq "$D/X_S3_L001_R1_001.fastq.gz" 20;  fq "$D/X_S3_L001_R2_001.fastq.gz" 20
fq "$D/X_S3_L002_R1_001.fastq.gz" 10;  fq "$D/X_S3_L002_R2_001.fastq.gz" 10
fq "$D/Y_S4_L001_R1_001.fastq.gz" 20;  fq "$D/Y_S4_L001_R2_001.fastq.gz" 20
fq "$D/Y_S5_L001_R1_001.fastq.gz" 20;  fq "$D/Y_S5_L001_R2_001.fastq.gz" 20
fq "$D/Lonely_R1.fastq.gz" 20
mkdir -p "$T/empty"

echo "eurlc-wgs smoke tests ($SCRIPT)"

# --- 1. the script itself --------------------------------------------------
echo "Script"
if out=$(perl -wc "$SCRIPT" 2>&1) && [[ "$out" == *"syntax OK"* ]] && [[ $(grep -c . <<<"$out") == 1 ]]; then
    ok "perl -wc: syntax OK, no warnings"
else
    bad "perl -wc: syntax OK, no warnings" "$(head -3 <<<"$out")"
fi

# --- 2. information without conda ------------------------------------------
echo "Information"
NOCONDA=( env -i HOME="$HOME" PATH=/usr/bin:/bin PERL5LIB="${PERL5LIB:-}" )
out=$( cd "$T/work" && "${NOCONDA[@]}" perl "$SCRIPT" --version 2>&1 ); rc=$?
if [[ $rc == 0 && "$out" == "eurlc-wgs "* ]]; then ok "--version without conda: exit 0, prints the version"
else bad "--version without conda: exit 0, prints the version" "exit $rc: ${out:0:100}"; fi
( cd "$T/work" && "${NOCONDA[@]}" perl "$SCRIPT" --help < /dev/null > "$T/help.out" 2>&1 ); rc=$?
check "--help without conda: exit 0" test "$rc" -eq 0
check "--help shows the help text (USAGE)" grep -q "USAGE\|eurlc-wgs \[datadir" "$T/help.out"

# --- 3. arguments ----------------------------------------------------------
echo "Arguments"
run "$T/a1.out" datadir="$D" threads=4 threads=8
check "repeated argument with two values: exit 1" test "$RC" -eq 1
check "  ... and says so" grep -q "given twice with different values" "$T/a1.out"
run "$T/a2.out" datadir="$D" --no-such-flag
check "unknown argument: exit 1" test "$RC" -eq 1
run "$T/a3.out" datadir="$D" --resume --overwrite
check "--resume with --overwrite: exit 1" test "$RC" -eq 1
run "$T/a4.out" datadir="$T/empty"
check "folder without input files: exit 2" test "$RC" -eq 2
mkdir -p "$T/with space"; fq "$T/with space/S_R1.fastq.gz" 5
run "$T/a5.out" datadir="$T/with space"
check "data folder with a space: exit 1" test "$RC" -eq 1
check "  ... names the folder" grep -q "contain a space" "$T/a5.out"
# chewBBACA has version_check=strict, which the fake conda cannot satisfy;
# switched off for the runs below.
run "$T/a6.out" datadir="$D" spades.timeout=abc
check "invalid time limit: exit 1" test "$RC" -eq 1

# --- 4. settings files -----------------------------------------------------
echo "Settings files"
mkdir -p "$HOME/eurlc-wgs_db"
run "$T/c1.out" configfile=write --assume-yes
CFG="$HOME/eurlc-wgs_db/eurlc-wgs.config"
check "configfile=write writes the file" test -s "$CFG"
check "  ... without ARRAY(0x...) values" bash -c "! grep -q 'ARRAY(0x' '$CFG'"
cp "$CFG" "$T/cfg.bak"
printf '\n[spadess]\ntimeout = 2h\n\n[species__Campylobacter jejuni]\nwarning_assembly_sise = <1400000\nwarning_qscore_raw_q30_rate = 0.85-1.15\n' >> "$CFG"
run "$T/c2.out" datadir="$D" outdir="$T/out_c2" --assume-yes disable=chewbbaca
check "unknown section: warning with the right name" grep -q "\[spadess\] is not a section.*did you mean \[spades\]" "$T/c2.out"
check "misspelt threshold: warning" grep -q "warning_assembly_sise.*is not a QC measure" "$T/c2.out"
check "threshold without operator: warning" grep -q "cannot be read as a threshold" "$T/c2.out"
check "written file reads back without parse warnings" bash -c "! grep -q 'could not parse' '$T/c2.out'"
cp "$T/cfg.bak" "$CFG"

run "$T/c3.out" datadir="$D" outdir="$T/out_c3" --assume-yes disable=chewbbaca enable=shovill_skesa
check "enable=shovill_skesa also switches on [shovill]" grep -q "Overriding from launch-arguments: shovill.enabled=1" "$T/c3.out"
run "$T/c4.out" datadir="$D" outdir="$T/out_c4" --assume-yes disable=chewbbaca shovill_skesa.enabled=1
check "shovill_skesa.enabled=1 without shovill: warning" grep -q "shovill_skesa switched on, but shovill.enabled=0" "$T/c4.out"
cp "$CFG" "$T/cfg.bak"
printf '\n[unicycler]\nenabled = 1\n' >> "$CFG"
run "$T/c5.out" datadir="$D" outdir="$T/out_c5" --assume-yes disable=chewbbaca main_assembly=unicycler
check "old config with Unicycler: notice, not an error" bash -c "grep -q 'unicycler. in the config file: Unicycler is no longer' '$T/c5.out' && grep -q 'main_assembly=unicycler: Unicycler is no longer' '$T/c5.out' && [ $RC -ne 2 ]"
cp "$T/cfg.bak" "$CFG"

# --- 5. samples, lanes, output folder --------------------------------------
echo "Samples and output folder"
OUT="$T/out"
# cleanup.merged_fastq=0: keep the merged lane file to check its content
# (cleanup at the end of a run would remove it otherwise).
run "$T/s1.out" datadir="$D" outdir="$OUT" --assume-yes disable=chewbbaca cleanup.merged_fastq=0
LIST="$OUT/log/filelist_fastq.txt"
check "file list written" test -s "$LIST"
check "Illumina suffix removed (A_S1_L001 -> A)" grep -qP '\tA$' "$LIST"
check "two lanes of one sample merged (X)" grep -qP '\tX\tmerge\t' "$LIST"
check "different sample numbers keep full names (Y_S4_L001, Y_S5_L001)" \
      bash -c "grep -qP '\tY_S4_L001$' '$LIST' && grep -qP '\tY_S5_L001$' '$LIST'"
check "  ... with a warning" grep -q "would all be called \[Y\]" "$T/s1.out"
check "R1 without R2: warning" grep -q "Lonely_R1.fastq.gz\] has no matching R2" "$T/s1.out"
M="$OUT/large_files/fastq/merged/X.merged_R1.fastq.gz"
if [[ -f "$M" ]]; then
    check "merged file = lane 1 + lane 2" \
          bash -c "cmp -s <(zcat '$M') <(zcat '$D/X_S3_L001_R1_001.fastq.gz' '$D/X_S3_L002_R1_001.fastq.gz')"
else
    bad "merged file = lane 1 + lane 2" "not made (the run may have stopped before the analysis; see $T/s1.out with KEEP=1)"
fi
ST="$OUT/log/run_status.json"
check "run_status.json written" test -s "$ST"
check "  ... with a final state" grep -q '"state" : "\(finished\|failed\|interrupted\|stopped\)"' "$ST"
check "events.jsonl has run_finished" grep -q '"type":"run_finished"' "$OUT/log/events.jsonl"
check "RUN START and RUN END in the log" \
      bash -c "grep -q 'EURLC-WGS RUN START' '$OUT/log/log.txt' && grep -q 'EURLC-WGS RUN END' '$OUT/log/log.txt'"
run "$T/s2.out" datadir="$D" outdir="$OUT" --assume-yes disable=chewbbaca
check "existing output folder + --assume-yes, no decision: exit 1" test "$RC" -eq 1
mkdir -p "$OUT/large_files/fastq/trimmed" "$OUT/large_files/fastq/trimmed_downsampled"
fq "$OUT/large_files/fastq/trimmed/dummy.t_R1.fastq.gz" 2
fq "$OUT/large_files/fastq/trimmed_downsampled/dummy.td_R1.fastq.gz" 2
run "$T/s3.out" outdir="$OUT" --resume --assume-yes disable=chewbbaca
check "cleanup removes trimmed and downsampled reads" \
      bash -c "[[ ! -e '$OUT/large_files/fastq/trimmed/dummy.t_R1.fastq.gz' && ! -e '$OUT/large_files/fastq/trimmed_downsampled/dummy.td_R1.fastq.gz' ]]"
check "  ... and records it in log/cleanup.json" grep -q trimmed_fastq "$OUT/log/cleanup.json"
check "  ... and the merged lane files (default)" bash -c "[[ ! -e '$M' ]]"
check "resume finds the data folder from the output folder" bash -c "! grep -q 'Cannot resume' '$T/s3.out'"
check "  ... and reports no new input files" bash -c "! grep -q 'are not part of this output directory' '$T/s3.out'"

# A folder with only logs (a run that stopped early) is started anew.
mkdir -p "$T/out_logs/log"; echo x > "$T/out_logs/log/log.txt"
run "$T/s4.out" datadir="$D" outdir="$T/out_logs" --assume-yes disable=chewbbaca
check "output folder with only logs: started anew without asking" grep -q "holds only logs" "$T/s4.out"

# --- remap step: streaming way and earlier way against a fixed reference -----
if [[ -d "$REPO/tests/data/remap" ]]; then
    check "remap: streaming and earlier way identical to the reference (tests/data/remap)" \
          bash -c "perl '$SCRIPT' --remap-check '$REPO/tests/data/remap' > '$T/remapcheck.out' 2>&1"
    check "remap: --remap-summary=depth writes a summary" \
          bash -c "perl '$SCRIPT' --remap-summary=depth --out '$T/ds.json' < '$REPO/tests/data/remap/smoke/eurlc-wgs/results/qc/stage3_assemblies/remapping/T1/T1.depth.tsv' && grep -q format_version '$T/ds.json'"
fi

# --- scripts/eurlc-wgs-inspect (read-only, on the output folder above) ------
INSPECT="$(dirname "$0")/../scripts/eurlc-wgs-inspect"
if command -v python3 > /dev/null && [[ -f "$INSPECT" ]]; then
    check "inspect inventory runs and writes a manifest" \
          bash -c "python3 '$INSPECT' inventory '$OUT' --md5 --manifest '$T/m.tsv' > '$T/inv.out' && grep -q '^path	size' '$T/m.tsv'"
    check "inspect extract makes a package" \
          bash -c "python3 '$INSPECT' extract '$OUT' --all-samples --anonymize -o '$T/pkg' > /dev/null && tar tzf '$T/pkg.tar.gz' | grep -q MANIFEST.tsv"
    check "  ... and leaves the output folder unchanged" \
          bash -c "python3 '$INSPECT' inventory '$OUT' --md5 --manifest '$T/m2.tsv' > /dev/null && cmp -s <(cut -f1,2,9 '$T/m.tsv') <(cut -f1,2,9 '$T/m2.tsv')"
fi

# --- result ----------------------------------------------------------------
echo
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
