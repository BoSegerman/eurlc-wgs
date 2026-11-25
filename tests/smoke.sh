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
# A [chewbbaca_schema_<name>] section must reach a schema with capitals in its name
# (the section title is lower-cased when the file is read).
SD="$HOME/eurlc-wgs_db/chewbbaca/schemas/Smoke-Schema-1"; mkdir -p "$SD"
printf '[schema]\nname = Smoke-Schema-1\nspecies = Campylobacter jejuni\n' > "$SD/schema.ini"
printf '\n[chewbbaca_schema_Smoke-Schema-1]\narguments = --st 0.05\n\n[chewbbaca_schema_No-Such-Schema]\narguments = --st 0.05\n' >> "$CFG"
run "$T/c2b.out" datadir="$D" outdir="$T/out_c2b" --assume-yes disable=chewbbaca
check "schema section reaches a schema with capitals in its name" \
      python3 -c "import json,sys; s=json.load(open('$T/out_c2b/data/rundata.json'))['config']['effective']['chewbbaca_schemas']; sys.exit(not (s.get('Smoke-Schema-1',{}).get('arguments')=='--st 0.05' and 'smoke-schema-1' not in s))"
check "  ... and a section for a schema that is not installed: warning" \
      grep -q "chewbbaca_schema_no-such-schema\] in the config file does not match an installed" "$T/c2b.out"
cp "$T/cfg.bak" "$CFG"; rm -rf "$SD"

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
RM="$OUT/results/qc/stage3_assemblies/remapping/A"; mkdir -p "$RM"
echo bam > "$RM/A.sorted.bam"; echo bai > "$RM/A.sorted.bam.bai"; echo ">c" > "$RM/A.fasta"
run "$T/s3.out" outdir="$OUT" --resume --assume-yes disable=chewbbaca
check "cleanup removes the BAM and the assembly copy in the remapping folder (cleanup.bam=1)" \
      bash -c "[[ ! -e '$RM/A.sorted.bam' && ! -e '$RM/A.sorted.bam.bai' && ! -e '$RM/A.fasta' ]]"
check "cleanup removes trimmed and downsampled reads" \
      bash -c "[[ ! -e '$OUT/large_files/fastq/trimmed/dummy.t_R1.fastq.gz' && ! -e '$OUT/large_files/fastq/trimmed_downsampled/dummy.td_R1.fastq.gz' ]]"
check "  ... and records it in log/cleanup.json" grep -q trimmed_fastq "$OUT/log/cleanup.json"
check "  ... and the merged lane files (default)" bash -c "[[ ! -e '$M' ]]"
check "resume finds the data folder from the output folder" bash -c "! grep -q 'Cannot resume' '$T/s3.out'"
check "  ... and reports no new input files" bash -c "! grep -q 'are not part of this output directory' '$T/s3.out'"

# --- a moved / copied analysis (data folder with eurlc-wgs/ inside) --------
MV1="$T/move_a"; mkdir -p "$MV1"
cp "$D/A_S1_L001_R1_001.fastq.gz" "$D/A_S1_L001_R2_001.fastq.gz" "$MV1/"
run "$T/m1.out" datadir="$MV1" --assume-yes disable=chewbbaca
cp "$MV1/eurlc-wgs/log/filelist_fastq.txt" "$T/filelist.orig"
mv "$MV1" "$T/move_b"; MV2="$T/move_b"
run "$T/m2.out" outdir="$MV2/eurlc-wgs" --resume --assume-yes disable=chewbbaca
check "moved analysis: resume reads the raw data at the new place" grep -q "raw data read from \[$MV2\]" "$T/m2.out"
if [[ -s "$MV2/eurlc-wgs/results/qc/stage1_rawdata/md5/md5-A.txt" ]]; then
    check "  ... after checking the recorded MD5 sums" grep -q "2 file(s) MD5-verified" "$T/m2.out"
fi
check "  ... and does not take the moved files for new ones" bash -c "! grep -q 'are not part of this output directory' '$T/m2.out'"
check "  ... the recorded file list is not changed" cmp -s "$T/filelist.orig" "$MV2/eurlc-wgs/log/filelist_fastq.txt"
check "  ... input_dir.txt keeps both places" bash -c "[[ \$(wc -l < '$MV2/eurlc-wgs/log/input_dir.txt') -eq 2 ]]"
if [[ -s "$MV2/eurlc-wgs/results/qc/stage1_rawdata/md5/md5-A.txt" ]]; then
    cp -r "$MV2" "$T/move_c"; echo "@x" | gzip >> "$T/move_c/A_S1_L001_R1_001.fastq.gz"
    run "$T/m3.out" outdir="$T/move_c/eurlc-wgs" --resume --assume-yes disable=chewbbaca
    check "moved analysis with a changed raw file: stops (exit 1)" \
          bash -c "[[ $RC -eq 1 ]] && grep -q 'are not the files that were analysed' '$T/m3.out'"
fi
cp -r "$MV2" "$T/move_d"; rm "$T/move_d/A_S1_L001_R2_001.fastq.gz"
run "$T/m4.out" outdir="$T/move_d/eurlc-wgs" --resume --assume-yes disable=chewbbaca
check "moved analysis with raw data missing: resumes, with a warning" grep -q "the raw data of 1 sample(s) was not found" "$T/m4.out"
check "  ... and the sample stays paired" bash -c "! grep -q 'treating sample as SE' '$T/m4.out'"

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

# --- validation against a validation dataset ---------------------------------
VAL="$REPO/scripts/eurlc-validate"; VD="$REPO/tests/data/validation"
if command -v python3 > /dev/null && [[ -f "$VAL" ]]; then
    check "eurlc-validate: matching results agree (exit 0)" \
          python3 "$VAL" --dataset "$VD" --observed "$VD/observed_ok.tsv" --distances "$VD/distances.tsv:10" --out "$T/val_ok"
    check "eurlc-validate: a missed contamination disagrees (exit 1)" \
          bash -c "! python3 '$VAL' --dataset '$VD' --observed '$VD/observed_bad.tsv' --distances '$VD/distances.tsv:10' --out '$T/val_bad' > /dev/null"
    # the pipeline finds a dataset in its data folder and validates
    VDATA="$T/valdata"; mkdir -p "$VDATA"
    cp "$D/A_S1_L001_R1_001.fastq.gz" "$D/A_S1_L001_R2_001.fastq.gz" "$VDATA/"
    cp "$VD/T1_validation_profile.yml" "$VDATA/"
    printf 'sample_id\texpected_species\texpected_species_is_target\texpected_st\texpected_mlst_alleles\texpected_qc_status\talternative_qc_status\texpected_qc_issue\texpected_cgmlst_min_called_percent\texpected_cluster\texpected_max_pairwise_distance_within_cluster\texpected_reportable\texpected_non_reportable_reason\nA\tCampylobacter jejuni\tyes\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tyes\tn/a\n' > "$VDATA/T1_expected_results.tsv"
    run "$T/v1.out" datadir="$VDATA" --assume-yes disable=chewbbaca
    check "pipeline writes report/tables/eurlc_observed_results.tsv" \
          bash -c "head -1 '$VDATA/eurlc-wgs/report/tables/eurlc_observed_results.tsv' | grep -q '^sample_id	species	st'"
    check "pipeline finds the validation dataset and validates" test -s "$VDATA/eurlc-wgs/report/validation/validation.json"
    check "  ... and says so in the run summary" grep -q "Validation:" "$T/v1.out"
    # results fingerprint; a reference in the data folder is compared with
    FPF="$VDATA/eurlc-wgs/report/tables/eurlc_results_fingerprint.json.gz"
    check "pipeline writes the results fingerprint" bash -c "gzip -dc '$FPF' | grep -q eurlc-wgs-results-fingerprint"
    mkdir -p "$VDATA/reference"; cp "$FPF" "$VDATA/reference/2026-01-01_ref.json.gz"
    run "$T/v2.out" datadir="$VDATA" --resume --assume-yes disable=chewbbaca
    check "pipeline compares with reference/ and finds no differences" \
          bash -c "grep -q 'Verification against .*NO UNEXPECTED DIFFERENCES' '$T/v2.out' && test -s '$VDATA/eurlc-wgs/report/verification/comparison.html'"
    INSP="$REPO/scripts/eurlc-wgs-inspect"
    gzip -dc "$FPF" | python3 -c 'import json,sys; d=json.load(sys.stdin); s=d["samples"]["A"]; s.setdefault("amr",{})["amrfinderplus.amr"]=["blaOXA-61"]; s.setdefault("qc",{})["coverage_raw"]="31.5"; json.dump(d,sys.stdout)' > "$T/fp_changed.json"
    check "inspect compare: a changed result is unexpected (exit 1)" \
          bash -c "! python3 '$INSP' compare '$FPF' '$T/fp_changed.json' > '$T/cmp1.out' && grep -q 'UNEXPECTED DIFFERENCES IN 1' '$T/cmp1.out'"
    check "  ... and not with --expect for its areas (exit 0)" \
          python3 "$INSP" compare "$FPF" "$T/fp_changed.json" --expect amr,qc.coverage --out "$T/cmp2" > /dev/null
    check "  ... the reference may be given as an output folder" \
          bash -c "python3 '$INSP' compare '$VDATA/eurlc-wgs' '$FPF' > /dev/null"

    # --installation-check: the check set in <database>/installation_check
    ICS="$HOME/eurlc-wgs_db/installation_check/T1"; mkdir -p "$ICS/fastq" "$ICS/reference"
    cp "$D/A_S1_L001_R1_001.fastq.gz" "$D/A_S1_L001_R2_001.fastq.gz" "$ICS/fastq/"
    cp "$VDATA/T1_validation_profile.yml" "$ICS/"
    # without tools the sample cannot be analysed: that is the expected result here
    printf 'sample_id\texpected_species\texpected_species_is_target\texpected_st\texpected_mlst_alleles\texpected_qc_status\talternative_qc_status\texpected_qc_issue\texpected_cgmlst_min_called_percent\texpected_cluster\texpected_max_pairwise_distance_within_cluster\texpected_reportable\texpected_non_reportable_reason\nA\tn/a\tyes\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tno\tn/a\n' > "$ICS/T1_expected_results.tsv"
    cp "$FPF" "$ICS/reference/2026-01-01_ref.json.gz"
    ( cd "$ICS" && md5sum fastq/* *.tsv *.yml reference/* > T1.md5 )
    run "$T/ic1.out" --installation-check disable=chewbbaca
    ICR="$HOME/eurlc-wgs_db/installation_check_runs"
    check "installation check: the set passes (exit 0)" bash -c "[[ $RC == 0 ]] && grep -q 'Installation check \[T1\]: PASSED' '$T/ic1.out'"
    check "  ... files, run, expected results and reference run are checked" \
          bash -c "grep -q 'ok   files of the check set: 5 files' '$T/ic1.out' && grep -q 'ok   run: finished' '$T/ic1.out' && grep -q 'ok   expected results: ALL' '$T/ic1.out' && grep -q 'ok   reference run: NO UNEXPECTED DIFFERENCES' '$T/ic1.out'"
    check "  ... and a record is kept with the run and in installation_checks.tsv" \
          bash -c "grep -q '\"result\" *: *\"PASSED\"' '$ICR'/T1/*/installation_check.json && grep -q '^Result: *PASSED' '$ICR'/T1/*/installation_check.txt && [[ \$(grep -c 'T1' '$ICR/installation_checks.tsv') == 1 ]]"
    echo "# changed after the list was made" >> "$ICS/T1_expected_results.tsv"
    run "$T/ic2.out" --installation-check=T1 disable=chewbbaca
    check "installation check: a changed file of the set fails before anything is run (exit 1)" \
          bash -c "[[ $RC == 1 ]] && grep -q 'FAIL files of the check set: T1_expected_results.tsv (changed)' '$T/ic2.out' && ! grep -q 'ok   run' '$T/ic2.out'"
    run "$T/ic3.out" --installation-check=NoSuchSet
    check "installation check: an unknown set is an error that names the sets (exit 1)" \
          bash -c "[[ $RC == 1 ]] && grep -q 'no check set named NoSuchSet.*sets there: T1' '$T/ic3.out'"

    # --make-installation-check: a check set from a validation dataset
    DS="$T/dataset"; mkdir -p "$DS/fastq"
    cp "$D/A_S1_L001_R1_001.fastq.gz" "$D/A_S1_L001_R2_001.fastq.gz" "$D/Lonely_R1.fastq.gz" "$DS/fastq/"
    cp "$VDATA/T1_validation_profile.yml" "$DS/"
    { head -1 "$ICS/T1_expected_results.tsv"
      for id in A Lonely SET_D1_011 SET_D2_011; do printf '%s\tn/a\tyes\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tno\tn/a\n' "$id"; done; } > "$DS/T1_expected_results.tsv"
    run "$T/mk0.out" --make-installation-check=M1 from="$DS" samples=A --assume-yes disable=chewbbaca
    check "make installation check: refused on an installation without a seal" \
          bash -c "[[ $RC == 1 ]] && grep -q 'has no configuration seal' '$T/mk0.out' && [[ ! -e '$HOME/eurlc-wgs_db/installation_check/M1' ]]"
    run "$T/mk1.out" --make-installation-check=M1 from="$DS" samples=011,Nope --assume-yes --allow-unsealed
    check "  ... a sample that is not there, or an end that fits two samples, stops it and says which" \
          bash -c "[[ $RC == 1 ]] && grep -q 'Nope: no such sample' '$T/mk1.out' && grep -q '011: fits more than one sample (SET_D1_011, SET_D2_011)' '$T/mk1.out'"
    run "$T/mk2.out" --make-installation-check=M1 from="$DS" samples=D1_011 --assume-yes --allow-unsealed
    check "  ... a sample without read files stops it" bash -c "[[ $RC == 1 ]] && grep -q 'no read files in .* for: SET_D1_011' '$T/mk2.out'"
    run "$T/mk3.out" --make-installation-check=M1 from="$DS" samples=A --assume-yes --allow-unsealed disable=chewbbaca
    MK="$HOME/eurlc-wgs_db/installation_check/M1"
    check "make installation check: the set is made (exit 0)" bash -c "[[ $RC == 0 ]] && grep -q 'set \[M1\] made' '$T/mk3.out' && [[ -d '$MK' ]]"
    check "  ... with the sample's reads only, its row of the expected results, the profile, a reference and a description" \
          bash -c "[[ \$(ls '$MK/fastq' | wc -l) == 2 ]] && [[ \$(grep -c . '$MK/T1_expected_results.tsv') == 2 ]] && grep -q '^A	' '$MK/T1_expected_results.tsv' && [[ -s '$MK/T1_validation_profile.yml' ]] && ls '$MK'/reference/*.json.gz > /dev/null && grep -q '^  A$' '$MK/M1_about.txt'"
    check "  ... and an .md5 list of all six files that holds" bash -c "[[ \$(grep -c . '$MK/M1.md5') == 6 ]] && ( cd '$MK' && md5sum -c --quiet M1.md5 )"
    check "  ... nothing is left of the building folder" bash -c "! ls -a '$HOME/eurlc-wgs_db/installation_check' | grep -q building"
    run "$T/mk4.out" --installation-check=M1 disable=chewbbaca
    check "  ... the set it made passes the installation check, reference run included" \
          bash -c "[[ $RC == 0 ]] && grep -q 'Installation check \[M1\]: PASSED' '$T/mk4.out' && grep -q 'ok   reference run: NO UNEXPECTED DIFFERENCES' '$T/mk4.out'"
    run "$T/mk5.out" --make-installation-check=M1 from="$DS" samples=A --assume-yes --allow-unsealed
    check "  ... an existing set is not overwritten" bash -c "[[ $RC == 1 ]] && grep -q 'already exists' '$T/mk5.out'"
    printf 'sample_id\texpected_species\texpected_species_is_target\texpected_st\texpected_mlst_alleles\texpected_qc_status\talternative_qc_status\texpected_qc_issue\texpected_cgmlst_min_called_percent\texpected_cluster\texpected_max_pairwise_distance_within_cluster\texpected_reportable\texpected_non_reportable_reason\nA\tn/a\tyes\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tn/a\tyes\tn/a\n' > "$DS/T1_expected_results.tsv"
    run "$T/mk6.out" --make-installation-check=M2 from="$DS" samples=A --assume-yes --allow-unsealed disable=chewbbaca
    check "  ... results that do not agree with the expected ones: no set is made, nothing is left behind" \
          bash -c "[[ $RC == 1 ]] && grep -q 'do not agree with the expected results' '$T/mk6.out' && [[ ! -e '$HOME/eurlc-wgs_db/installation_check/M2' ]] && ! ls -a '$HOME/eurlc-wgs_db/installation_check' | grep -q building"
    run "$T/mk7.out" samples=A datadir="$D"
    check "  ... samples= without --make-installation-check is refused" bash -c "[[ $RC != 0 ]] && grep -q 'used together with --make-installation-check' '$T/mk7.out'"
    rm -rf "$HOME/eurlc-wgs_db/installation_check" "$ICR"
fi

# --- R1/R2 read names (prescan) ------------------------------------------------
fqx() { # fqx <file> <n reads> <x offset> <mate>: like fq, other read coordinates
    local f="$1" n="$2" off="$3" m="$4" i
    for ((i=1; i<=n; i++)); do
        printf '@M01137:1:000000000-ABCDE:1:1101:%d:1000 %s:N:0:1\nACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n' "$((i+off))" "$m"
    done | gzip -c > "$f"
}
PN="$T/pairnames"; mkdir -p "$PN"
fqx "$PN/P_S1_L001_R1_001.fastq.gz" 20 0 1;    fqx "$PN/P_S1_L001_R2_001.fastq.gz" 20 0 2
fqx "$PN/Q_S2_L001_R1_001.fastq.gz" 20 0 1;    fqx "$PN/Q_S2_L001_R2_001.fastq.gz" 20 5000 2
run "$T/pn.out" datadir="$PN" outdir="$T/pn_out" --assume-yes disable=chewbbaca
check "prescan: R1/R2 files whose read names differ are reported" \
      grep -q "read names differ between R1 and R2 in 20 of 20 pairs" "$T/pn.out"
check "  ... as the QC measure (100 %), and not for the matching pair" \
      python3 -c "import json,sys; d={s['name']:s for s in json.load(open('$T/pn_out/data/rundata.json'))['samples']}; r=lambda n: float(d[n]['main_results']['qscore']['raw'].get('pair_name_mismatch_pct','nan')); sys.exit(not (r('Q')==100 and r('P')==0))"

# --- EFSA export ---------------------------------------------------------------
EFX="$REPO/scripts/eurlc-efsa-export"
if command -v python3 > /dev/null && [[ -f "$EFX" ]]; then
    python3 "$REPO/tests/data/efsa/make_run.py" "$T/efsa_run"
    python3 "$EFX" export "$T/efsa_run" --out "$T/efsa_out" > "$T/efx.out" 2>&1
    check "efsa export: the C. jejuni sample is ready (CAMPISO, with warnings)" \
          grep -q "^CJ1	Campylobacter jejuni	READY" "$T/efsa_out/manifest.tsv"
    check "  ... profile: EFSA header, missing loci as 0" \
          bash -c "head -1 '$T/efsa_out/CJ1/allelicProfile.tsv' | grep -q '^FILE	CAMP0001	' && [[ \$(sed -n 2p '$T/efsa_out/CJ1/allelicProfile.tsv' | tr '\t' '\n' | grep -cx 0) -eq 5 ]]"
    check "  ... the E. coli sample without an EFSA schema or locus map is stopped" \
          bash -c "grep -q '^EC1	Escherichia coli	STOPPED' '$T/efsa_out/manifest.tsv' && grep -q 'EC1	B14	STOP' '$T/efsa_out/preflight.tsv'"
    check "  ... E. coli pathotype in the B11 form" \
          python3 -c "import json,sys; p=json.load(open('$T/efsa_out/EC1/typingData.json'))['Results']['ParamCode']; sys.exit(not (p['PredictedPathotype']['Pathotype']=='STEC' and p['PredictedStxType']=='stx2a' and {g['GeneName'] for g in p['PredictedPathotype']['GeneList']}=={'eae','stx2'}))"
    check "  ... upload_cli.sh has a line for the ready sample only" \
          bash -c "grep -c '^wgs upload' '$T/efsa_out/upload_cli.sh' | grep -qx 1"
    check "efsa compat: an identical profile is Perfect" \
          bash -c "python3 '$EFX' compat --base '$T/efsa_out/CJ1/allelicProfile.tsv' --test '$T/efsa_out/CJ1/allelicProfile.tsv' --thresholds 5,10,15 | grep -q Perfect"
fi

# --- scripts/eurlc-wgs-inspect (read-only, on the output folder above) ------
INSPECT="$(cd "$(dirname "$0")/.." && pwd)/scripts/eurlc-wgs-inspect"
if command -v python3 > /dev/null && [[ -f "$INSPECT" ]]; then
    check "inspect inventory runs and writes a manifest" \
          bash -c "python3 '$INSPECT' inventory '$OUT' --md5 --manifest '$T/m.tsv' > '$T/inv.out' && grep -q '^path	size' '$T/m.tsv'"
    check "inspect extract makes a package" \
          bash -c "python3 '$INSPECT' extract '$OUT' --all-samples --anonymize -o '$T/pkg' > /dev/null && tar tzf '$T/pkg.tar.gz' | grep -q MANIFEST.tsv"
    check "inspect summarize reads the run" \
          bash -c "python3 '$INSPECT' summarize '$OUT' --tsv '$T/sum.tsv' > '$T/sum.out' && grep -q '^run	sample' '$T/sum.tsv'"
    check "inspect known-template: one row per sample, from inside the run" \
          bash -c "cd '$OUT/data' && python3 '$INSPECT' known-template -o '$T/known.tsv' 2> /dev/null && head -1 '$T/known.tsv' | grep -q '^run	sample	expected	note' && [[ \$(wc -l < '$T/known.tsv') -gt 1 ]]"
    check "  ... --update keeps what was filled in, summarize reads it" \
          bash -c "awk -F'\t' -v OFS='\t' 'NR==2{\$3=\"clean\"; \$4=\"filled in\"} 1' '$T/known.tsv' > '$T/k2.tsv' && python3 '$INSPECT' known-template '$OUT' --update '$T/k2.tsv' 2> /dev/null && grep -q 'clean	filled in' '$T/k2.tsv' && python3 '$INSPECT' summarize '$OUT' --expected '$T/k2.tsv' | grep -q '^clean '"
    check "  ... and refuses to scan a folder that is not a run without --all" \
          bash -c "cd '$T' && ! python3 '$INSPECT' known-template -o '$T/k3.tsv' 2> /dev/null"
    check "  ... and leaves the output folder unchanged" \
          bash -c "python3 '$INSPECT' inventory '$OUT' --md5 --manifest '$T/m2.tsv' > /dev/null && cmp -s <(cut -f1,2,9 '$T/m.tsv') <(cut -f1,2,9 '$T/m2.tsv')"
fi

# --- steps that fail on data that already failed: notes, not errors ------
echo "Expected failures"
KF=$(perl "$(dirname "$0")/unit/known_data_fail.pl" "$SCRIPT" 2>&1)
check "data that already failed is recognised (low Q30 coverage, swapped files, abandoned)" \
      bash -c "grep -qP '^low\tQC FAIL on the data: Trimmed read Q30' <<<'$KF' && grep -qP '^swap\tQC FAIL' <<<'$KF' && grep -qP '^ab\tsample abandoned' <<<'$KF'"
check "  ... and good data or data without values is not" \
      bash -c "grep -qP '^ok\t$' <<<'$KF' && grep -qP '^none\t$' <<<'$KF'"

# --- serovar comparison and MLST loci ------------------------------------
echo "Typing QC"
SC=$(perl "$(dirname "$0")/unit/serotype_compare.pl" "$SCRIPT" 2>&1)
check "SeqSero2 'A or B' agrees with SISTR A; formula-only calls are compared on antigens" \
      bash -c "[[ \$(grep -c 'disagree=0' <<<'$SC') -eq 7 ]] && grep -q '^Infantis .*disagree=1' <<<'$SC' && grep -q '^Typhimurium .*disagree=1' <<<'$SC'"
check "  ... '-:-:-' from both tools is a missing serovar, not a disagreement" \
      bash -c "grep -q '^-:-:- .*disagree=0 missing=1' <<<'$SC'"
check "  ... MLST: the list allele_names is not taken for a locus" \
      bash -c "! grep -q 'ARRAY' <<<'$SC' && grep -q '^Infantis .*mlst=1 dnaN(2?)' <<<'$SC'"
check "  ... SISTR not used (its QC): no disagreement; fastMLST's two alleles count" \
      bash -c "grep -q '^NotUsed|Berta .*disagree=0 .*mlst=2 dnaN(2?) \[mlst\], aroC(5|7) \[fastMLST\]' <<<'$SC'"

FM=$(perl "$(dirname "$0")/unit/fastmlst_parse.pl" "$SCRIPT" 2>&1)
check "  ... SISTR QC WARNING but SeqSero2 reported and fine: no tool flag" \
      bash -c "grep -q '^NotUsed|Berta .*toolflag=0' <<<'$SC' && [[ \$(grep -c 'toolflag=0' <<<'$SC') -eq 10 ]]"
check "  ... fastMLST: clonal_complex, CC, Lineage are not loci; two alleles and '-' are kept" \
      bash -c "[[ \$(grep -c 'loci=7' <<<'$FM') -eq 4 ]] && grep -q 'cc=ST-11 complex' <<<'$FM' && grep -q 'allele_aroC=5|7,allele_dnaN=-' <<<'$FM'"

SA=$(perl "$(dirname "$0")/unit/species_agreement.pl" "$SCRIPT" 2>&1)
check "species: Kraken2's species among Mash screen's is agreement, also when Mash screen names two" \
      bash -c "grep -q '^same	0	$' <<<'$SA' && grep -q '^mash-two	0	$' <<<'$SA' && grep -q '^mash-two-other	0	$' <<<'$SA'"
check "  ... another species is a disagreement, and says what each gave" \
      bash -c "grep -q '^disagree	1	Mash screen says Campylobacter upsaliensis, Kraken2 says Campylobacter helveticus$' <<<'$SA' && grep -q '^disagree-target	1	' <<<'$SA'"
check "  ... not judged when one of them gave no species" \
      bash -c "grep -q '^no-mash	n/a	$' <<<'$SA' && grep -q '^mash-na	n/a	$' <<<'$SA' && grep -q '^no-kraken	n/a	$' <<<'$SA' && grep -q '^no-species	n/a	$' <<<'$SA'"
check "  ... and the default is a WARNING, not CRITICAL" bash -c "grep -q 'warning_taxonomy_species_disagree *=> *\">0\"' '$SCRIPT' && ! grep -q '^ *critical_taxonomy_species_disagree *=>' '$SCRIPT'"
check "strain mixture: Campylobacter has WARNING >100 and CRITICAL >350" bash -c "grep -q 'warning_contamination_mixed_windows *=> *\">100\"' '$SCRIPT' && grep -q 'critical_contamination_mixed_windows *=> *\">350\"' '$SCRIPT'"
check "parallel: no command template writes a temporary file with the same name for every sample" bash -c "! grep -nE '__OUTDIR__/tmp[A-Za-z0-9_.]*\\.(fastq\\.gz|txt)' '$SCRIPT'"
check "fastMLST: its database is a managed database (installed under the database folder, in db_freeze) and is never read from ~/.cache" \
      bash -c "grep -q 'db_test *=> *\"__DB__/fastmlst/pubmlst/mlst.fasta\"' '$SCRIPT' && grep -q '\[ \"fastmlst\", *\"fastmlst\", *\"pubmlst/mlst.fasta\"' '$SCRIPT' && grep -q 'command = fastmlst_home_wrap' '$SCRIPT'"

# --- validated species of the configuration ---------------------------------
echo "Validated species"
VS=$(perl "$(dirname "$0")/unit/validated_scope.pl" "$SCRIPT" 2>&1)
check "samples of declared species are validated, others outside and not reportable" \
      bash -c "grep -q '^jejuni	validated	yes		Yes$' <<<'$VS' && grep -q '^coli	validated	yes		Yes$' <<<'$VS' && grep -q '^lari	outside	no	species outside the validated species of this configuration (Campylobacter lari)	Not validated$' <<<'$VS'"
check "  ... a genus covers its species; a failed sample keeps its QC reason; no species call: not reportable" \
      bash -c "grep -q '^genus-lari	validated	yes		Yes$' <<<'$VS' && grep -q '^lari-fail	outside	no	species outside the validated species of this configuration (Campylobacter lari); QC FAIL' <<<'$VS' && grep -q '^nospecies	undetermined	no	species not determined (validated species are declared for this configuration)	No$' <<<'$VS'"
check "  ... nothing declared: nothing is marked" bash -c "grep -q '^undeclared		yes		Yes$' <<<'$VS'"
check "report: CRITICAL is shown as Assess, FAIL as No" \
      bash -c "grep -q '^critical		no	QC CRITICAL	Assess$' <<<'$VS' && grep -q '^fail		no	QC FAIL	No$' <<<'$VS'"
check "a sample where a step failed or that was abandoned is CRITICAL, never PASS; steps failing on failed data do not count" \
      bash -c "grep -q '^runproblem-ok	-$' <<<'$VS' && grep -q '^runproblem-failed	Analysis not finished: step(s) failed: skesa (timeout)' <<<'$VS' && grep -q '^runproblem-abandoned	Analysis not finished: the sample was abandoned at step downsample' <<<'$VS' && grep -q '^runproblem-expected-only	-$' <<<'$VS'"
check "  ... it is not reportable, shown as No (not Assess), with what to do; QC FAIL on the data keeps its own reason" \
      bash -c "grep -q '^step-failed		no	step(s) failed: skesa (timeout) -- run the analysis again with --resume	No$' <<<'$VS' && grep -q '^step-failed-datafail		no	QC FAIL	No$' <<<'$VS' && grep -q '^abandoned		no	abandoned: reformat failed	No$' <<<'$VS'"
run "$T/vs1.out" datadir="$D" outdir="$T/out_vs" --assume-yes disable=chewbbaca validated_species="Campylobacter jejuni, Campylobacter coli"
check "main report: the sample table has a Reportable column" \
      bash -c "grep -q '>Reportable</th>' '$T/out_vs/report/main_report.html' && grep -q '<span class=\"rep-pill rep-[a-z]*\" title=\"[^\"]*\">\(Yes\|No\)</span>' '$T/out_vs/report/main_report.html' && grep -q 'class=\"rep-legend\"' '$T/out_vs/report/main_report.html' && grep -q 'rep-pill' '$T/out_vs/report/assets/style.css'"
check "run started from another folder: the tools' output goes to the output folder's log, not <current folder>/eurlc-wgs/log" \
      bash -c "grep -q '$T/out_vs/log/stdout.txt' '$T/out_vs/log/bash_commands.log' && ! grep -q '$T/work/eurlc-wgs/log/std' '$T/out_vs/log/bash_commands.log'"
check "run summary: an abandoned sample is counted as ABANDONED, not as QC PASS" \
      bash -c "grep -q '^  QC: *[0-9]* ABANDONED$' '$T/vs1.out' && ! grep -q '^  QC:.*PASS' '$T/vs1.out'"
check "validated_species= is a setting, recorded with the run" \
      bash -c "! grep -q 'Unknown argument' '$T/vs1.out' && python3 -c \"import json,sys; d=json.load(open('$T/out_vs/data/rundata.json')); sys.exit(0 if d['config']['effective']['general']['validated_species']=='Campylobacter jejuni, Campylobacter coli' else 1)\""

# --- the seal and the installation ---------------------------------------------
echo "Config seal"
SS=$(perl "$(dirname "$0")/unit/seal_state.pl" "$SCRIPT" 2>&1)
check "seal: files unchanged and installation as described: verified" bash -c "grep -q '^all-as-sealed	SEAL VERIFIED	SEAL VERIFIED	SEAL VERIFIED	$' <<<'$SS'"
check "  ... an updated conda environment breaks it, and says which" \
      bash -c "grep -q '^env-updated	SEAL VERIFIED	SEAL BROKEN	SEAL BROKEN	conda environment eurlc-wgs-spades: differs from conda_manifest.ini' <<<'$SS'"
check "  ... a frozen database that is not in use breaks it (also a seal with overrides)" \
      bash -c "grep -q '^db-live	SEAL VERIFIED WITH OVERRIDES	SEAL BROKEN	SEAL BROKEN	database kraken2: the frozen version is not in use' <<<'$SS'"
check "  ... a seal already broken keeps its own reasons" bash -c "grep -q '^files-changed	SEAL BROKEN	SEAL BROKEN	SEAL BROKEN	eurlc_wgs_config: changed$' <<<'$SS'"
EL=$(perl "$(dirname "$0")/unit/env_lists.pl" "$SCRIPT" 2>&1)
check "package lists: a missing environment is made from its list, a matching one is left alone" \
      bash -c "grep -q '^missing-with-list	1	create-from-list	yes$' <<<'$EL' && grep -q '^same-as-list	1	nothing	yes$' <<<'$EL'"
check "  ... one that differs is removed and made again; not without permission" \
      bash -c "grep -q '^differs-from-list	1	remove,create-from-list	yes$' <<<'$EL' && grep -q '^differs-not-allowed	1	nothing	no$' <<<'$EL'"
check "  ... without a list the YML file is used, as before" bash -c "grep -q '^no-list	1	create-from-yml	-$' <<<'$EL'"
check "install.sh: shell syntax" bash -n "$(dirname "$0")/../install.sh"
check "--version prints 1.0.0-rc3" bash -c "perl '$SCRIPT' --version 2>&1 | grep -q '1\.0\.0-rc3'"
check "downsampling reads gzip with Java's own reader (unbgzip=f unpigz=f), paired and single" \
      bash -c "[[ \$(grep -c '^       unbgzip=f unpigz=f \$' '$SCRIPT') == 2 ]]"

# --- input flags, lists and help -----------------------------------------
echo "Input flags, lists, help"
DR="$T/data_rec"; mkdir -p "$DR/sub" "$DR/earlier_run/data" "$DR/earlier_run/results"
cp "$D/A_S1_L001_R1_001.fastq.gz" "$D/A_S1_L001_R2_001.fastq.gz" "$DR/"
cp "$D/Y_S4_L001_R1_001.fastq.gz" "$D/Y_S4_L001_R2_001.fastq.gz" "$DR/sub/"
printf '>c\nACGTACGTACGT\n' > "$DR/C.fasta"
echo '{}' > "$DR/earlier_run/data/rundata.json"; printf '>z\nACGT\n' > "$DR/earlier_run/results/Z.fasta"
run "$T/in0.out" datadir="$DR" outdir="$T/o_in0"
check "input: without --recursive only the folder itself (1 PE + 1 FASTA)" grep -q 'Found 2 samples (1 PE, 0 SE, 1 FASTA)' "$T/in0.out"
run "$T/in1.out" datadir="$DR" outdir="$T/o_in1" --recursive
check "  ... --recursive also finds the reads in a subfolder" grep -q 'Found 3 samples (2 PE, 0 SE, 1 FASTA)' "$T/in1.out"
check "  ... but does not take the files of an earlier output folder for samples" bash -c "! grep -q 'Z \[FASTA\]' '$T/in1.out'"
run "$T/in2.out" datadir="$DR" outdir="$T/o_in2" --fastq
check "  ... --fastq: only the reads" grep -q 'Found 1 samples (1 PE, 0 SE, 0 FASTA)' "$T/in2.out"
run "$T/in3.out" datadir="$DR" outdir="$T/o_in3" --fasta
check "  ... --fasta: only the assemblies" grep -q 'Found 1 samples (0 PE, 0 SE, 1 FASTA)' "$T/in3.out"
run "$T/lt.out" --list-tools
check "--list-tools: the tool names with on/off, and the step names for rerun=" \
      bash -c "[[ $RC == 0 ]] && grep -q '^    spades  *on' '$T/lt.out' && grep -q 'select_main_assembly' '$T/lt.out' && grep -q 'chewbbaca_regenerate_per_batch' '$T/lt.out'"
run "$T/ls.out" --list-steps
check "  ... --list-steps shows the same" bash -c "diff <(sed -n '/^TOOLS/,\$p' '$T/lt.out') <(sed -n '/^TOOLS/,\$p' '$T/ls.out') > /dev/null"
run "$T/ha.out" --help-admin
check "--help-admin: the maintenance commands; --help points to it and no longer lists them" \
      bash -c "[[ $RC == 0 ]] && grep -q -- '--generate-seal' '$T/ha.out' && grep -q -- '--make-installation-check' '$T/ha.out' && grep -q -- '--help-admin' '$T/help.out' && ! grep -q -- '--generate-seal\|--remap-check' '$T/help.out'"
( cd "$T/work" && "${NOCONDA[@]}" perl "$SCRIPT" --manual < /dev/null > "$T/manual.out" 2>&1 ); rc=$?
check "--manual: says where the HTML and the PDF of the manual are (also outside conda)" \
      bash -c "[[ $rc == 0 ]] && grep -q 'eurlc-wgs-user-manual.html' '$T/manual.out' && grep -q 'eurlc-wgs-user-manual.pdf' '$T/manual.out'"
check "the built manual (HTML, PDF) is made from the manual as it is now (else: scripts/build-manual)" \
      bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/build-manual" --check
check "  ... one file with nothing fetched from elsewhere, and no broken link between its sections" \
      python3 -c "
import re,sys
s=open('$(cd "$(dirname "$0")/.." && pwd)/docs/eurlc-wgs-user-manual.html',encoding='utf-8').read()
ids=set(re.findall(r'id=\"([^\"]+)\"',s)); refs=set(re.findall(r'href=\"#([^\"]+)\"',s))
ext=re.findall(r'<(?:link|script|img)[^>]+(?:src|href)=\"https?://',s)
sys.exit(1 if (refs-ids) or ext else 0)"
run "$T/par1.out" datadir="$DR" outdir="$T/o_par1" --fasta --parallel
run "$T/par2.out" datadir="$DR" outdir="$T/o_par2" --fasta parallel_mode=on --no-parallel
check "--parallel is parallel_mode=on; --no-parallel is off (and, like any argument, not accepted twice)" \
      bash -c "grep -q '\"parallel\" *: *true' '$T/o_par1/log/run_status.json' && [[ $RC != 0 ]]"
run "$T/par3.out" datadir="$DR" outdir="$T/o_par3" --fasta --no-parallel
check "  ... --no-parallel alone: off" grep -q '"parallel" *: *false' "$T/o_par3/log/run_status.json"
run "$T/wc.out" --write-configfile=named.config
check "--write-configfile=<name>: written in the database folder, every setting in use" \
      bash -c "[[ $RC == 0 ]] && grep -q '^threads=' '$HOME/eurlc-wgs_db/named.config'"
run "$T/wc2.out" --write-configfile="$T/elsewhere.config"
check "  ... a path is used as given" bash -c "[[ $RC == 0 && -s '$T/elsewhere.config' ]]"

# --- setup: species, configuration file, what is in the database folder ---
echo "Setup"
# stand-ins, so that nothing is downloaded: wget and git clone fail at once
printf '#!/bin/sh\nexit 4\n' > "$T/conda/bin/wget"
printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "git version 2.0"; exit 0; }\nexit 1\n' > "$T/conda/bin/git"
chmod +x "$T/conda/bin/wget" "$T/conda/bin/git"
US=$(perl "$(dirname "$0")/unit/setup_species.pl" "$SCRIPT" 2>&1)
check "species choice: names, numbers, a species of the genus; unknown ones are named" \
      bash -c "grep -q '^species\[2, Listeria\]	salmonella,listeria	-$' <<<'$US' && grep -q '^species\[Campylobacter jejuni, E.coli, campy\]	campylobacter,ecoli	-$' <<<'$US' && grep -q '^species\[1,foo\]	campylobacter	foo$' <<<'$US'"
check "a database is there when its marker files are: not an empty folder, a .part file or an empty file" \
      bash -c "grep -q '^db-empty-folder	0$' <<<'$US' && grep -q '^db-part-file	0$' <<<'$US' && grep -q '^db-empty-file	0$' <<<'$US' && grep -q '^db-complete	1$' <<<'$US' && grep -q '^db-one-marker-missing	0$' <<<'$US'"
check "a schema is installed when it has loci and a schema.ini" \
      bash -c "grep -q '^schema-no-ini	0$' <<<'$US' && grep -q '^schema-complete	1$' <<<'$US'"
check "the Mash download never leaves a half file under the database's name" \
      grep -q 'wget -O refseq.genomes.k21s1000.msh.part .* && mv refseq.genomes.k21s1000.msh.part refseq.genomes.k21s1000.msh' "$SCRIPT"

DBN="$T/db_new"; mkdir -p "$DBN"
run "$T/setup1.out" --setup --assume-yes species=campylobacter,2 database="$DBN"
check "new installation: says so, and names the species" bash -c "grep -q 'New installation' '$T/setup1.out' && grep -q 'Species: Campylobacter, Salmonella$' '$T/setup1.out'"
check "  ... writes a configuration file with species_scope as the only setting in use" \
      bash -c "[[ \$(grep -v '^[#;\[]' '$DBN/eurlc-wgs.config' | grep -c .) == 1 ]] && grep -q '^species_scope=Campylobacter, Salmonella$' '$DBN/eurlc-wgs.config'"
check "  ... every other setting is listed, commented out" bash -c "grep -q '^#threads=' '$DBN/eurlc-wgs.config' && grep -q '^\[species__' '$DBN/eurlc-wgs.config'"
check "  ... schemas that could not be installed: not ready, exit 1" \
      bash -c "[[ $RC == 1 ]] && grep -q 'Salmonella  *cgMLST schema chewie_ns_salmonella is not installed' '$T/setup1.out'"
check "  ... setup keeps a log in the database folder (setup_logs/<time>/log/log.txt)" \
      bash -c "f=\$(ls '$DBN'/setup_logs/*/log/log.txt | head -1) && grep -q 'New installation' \"\$f\" && [[ ! -d '$T/work/eurlc-wgs' ]]"
check "  ... freezing and sealing are not given as commands, only as a pointer to the manual" \
      bash -c "! grep -q -- '--freeze-databases\|--generate-seal' '$T/setup1.out' && grep -q 'user manual, section 12' '$T/setup1.out'"
run "$T/setup1b.out" datadir="$D" outdir="$T/out_cfg" database="$DBN" --assume-yes
check "  ... the written file is read without complaint by a run" bash -c "! grep -q 'could not parse\|Could not parse' '$T/setup1b.out'"

run "$T/setup2.out" --setup --assume-yes species=listeria,campylobacter database="$DBN"
check "existing installation: recognised; a species is added, none removed" \
      bash -c "grep -q 'Found an existing installation' '$T/setup2.out' && grep -q '^species_scope = Campylobacter, Salmonella, Listeria$' '$DBN/eurlc-wgs.config'"

# everything in place: databases and the three schemas
mkdir -p "$DBN/kraken2" "$DBN/mash" "$DBN/resfinder/resfinder_db" "$DBN/fastmlst/pubmlst"
for f in kraken2/hash.k2d kraken2/database150mers.kmer_distrib mash/refseq.genomes.k21s1000.msh resfinder/resfinder_db/all.fsa fastmlst/pubmlst/mlst.fasta; do echo x > "$DBN/$f"; done
for n in CAMPISO-PubMLST-8 chewie_ns_salmonella chewie_ns_listeria; do
    mkdir -p "$DBN/chewbbaca/schemas/$n"; echo ">a" > "$DBN/chewbbaca/schemas/$n/l1.fasta"; printf '[schema]\nname=%s\n' "$n" > "$DBN/chewbbaca/schemas/$n/schema.ini"
done
run "$T/setup3.out" --setup --assume-yes database="$DBN"
check "  ... complete: ready for its three species, exit 0" \
      bash -c "[[ $RC == 0 ]] && grep -q 'Setup complete. This installation is ready for:' '$T/setup3.out' && [[ \$(grep -c 'cgMLST schema [Cc]' '$T/setup3.out') == 3 ]]"
rm "$DBN/chewbbaca/schemas/chewie_ns_listeria/schema.ini"
run "$T/setup4.out" --setup --assume-yes database="$DBN"
check "  ... a schema folder left by an interrupted installation is moved aside, not used" \
      bash -c "[[ $RC == 1 ]] && ls '$DBN/chewbbaca/incomplete' | grep -q '^chewie_ns_listeria-' && [[ ! -d '$DBN/chewbbaca/schemas/chewie_ns_listeria' ]]"

touch "$DBN/config_seal.ini"
run "$T/setup5.out" --setup --assume-yes species=ecoli database="$DBN"
check "sealed installation: species= is refused" bash -c "[[ $RC != 0 ]] && grep -q 'sealed installation' '$T/setup5.out'"
run "$T/setup6.out" --setup --assume-yes database="$DBN"
check "  ... used as it is: the missing schema is reported, not downloaded" \
      bash -c "[[ $RC == 1 ]] && grep -q 'Found a sealed installation' '$T/setup6.out' && ! grep -q 'Download & install' '$T/setup6.out'"
rm "$DBN/config_seal.ini"
run "$T/setup7.out" species=listeria datadir="$D"
check "species= without --setup is refused" bash -c "[[ $RC != 0 ]] && grep -q 'used together with --setup' '$T/setup7.out'"
IS="$(cd "$(dirname "$0")/.." && pwd)/install.sh"
check "install.sh: an unknown species stops it before anything is installed" \
      bash -c "out=\$(bash '$IS' --species=campylobacter,foo 2>&1); [[ \$? == 1 ]] && grep -q 'choose from campylobacter' <<<\"\$out\""
check "install.sh: --species is refused for a sealed database folder" \
      bash -c "touch '$DBN/config_seal.ini'; out=\$(bash '$IS' --species=listeria --database='$DBN' 2>&1); rc=\$?; rm '$DBN/config_seal.ini'; [[ \$rc == 1 ]] && grep -q 'sealed installation' <<<\"\$out\""

SD=$(perl "$(dirname "$0")/unit/schema_display.pl" "$SCRIPT" 2>&1)
check "schema version: the same schema gets the same ID in every installation (no name or date in the marker)" bash -c "grep -qP '^marker-same-everywhere\t1$' <<<\"\$0\" && grep -qP '^marker-no-date-or-name\t1$' <<<\"\$0\" && grep -qP '^marker-new-not-old-format\t0$' <<<\"\$0\"" "$SD"
check "schema version: a marker made before rc3 is recognised and made again at freeze" bash -c "grep -qP '^marker-old-format-found\t1$' <<<\"\$0\"" "$SD"
check "report: a clustering result shows the schema's name and loci, the frozen version as a detail (not as the name)" \
      bash -c "grep -q '^live	LIVE-1 (5 loci)$' <<<'$SD' && grep -q '^frozen	FROZEN-8 (3 loci, filter cg.txt; frozen version 0123456789abcdef0123456789abcdef)$' <<<'$SD' && grep -q '^html	<b>FROZEN-8</b>' <<<'$SD'"
check "  ... also when only the reports are rebuilt (summarize): the frozen copy is found, and its own filter counted" \
      bash -c "grep -q '^frozen-live-path	CAMP (2 loci, filter cg.txt; frozen version fedcba9876543210fedcba9876543210)$' <<<'$SD'"
check "report: Database versions lists every resolved database (Bracken with Kraken2), the schemas used and the databases inside tool environments, each once" \
      bash -c "grep -q '^dbrows-run	kraken2=frozen copy | MD5 of 3 marker files / bracken=frozen copy / mashscreen=live copy / cgMLST schema CAMP=frozen copy / cgMLST schema LIVE-1=live copy / mlst=date: 2026-11-12$' <<<'$SD'"
check "  ... in a sample's report only the schema of its species; the schema row has version, loci and the frozen version" \
      bash -c "grep -q '^dbrows-sample	kraken2 / bracken / mashscreen / cgMLST schema CAMP / mlst$' <<<'$SD' && grep -q '^dbrows-schema	cgMLST schema CAMP|version 8, 2 loci, filter cg.txt|fedcba9876543210fedcba9876543210|frozen copy$' <<<'$SD'"
check "schema.ini is written as plain bytes: no character encoded twice" \
      bash -c "grep -q '^ini-header-ascii	1$' <<<'$SD' && grep -q '^ini-not-double-encoded	1$' <<<'$SD'"

# --- eurlc-cgmlst-compare -------------------------------------------------
echo "cgMLST comparison"
CGC="$(cd "$(dirname "$0")/.." && pwd)/scripts/eurlc-cgmlst-compare"
python3 "$(dirname "$0")/data/cgmlst/make.py" "$T/cg"
python3 -I "$CGC" explain "$T/cg/pA" "$T/cg/pB" --schema-a "$T/cg/sA" --schema-b "$T/cg/sB" > "$T/cg/explain.out" 2>&1
check "explain: the hashes match the schemas' sequences" bash -c "grep -q 'hash check A: 2 of 2' '$T/cg/explain.out' && grep -q 'hash check B: 3 of 3' '$T/cg/explain.out'"
check "  ... an allele only schema B holds is named as the reason" grep -q "only B called; B's allele is NOT in schema A (LNF -> EXC)" "$T/cg/explain.out"
check "schemas: the extra allele is found" bash -c "python3 -I '$CGC' schemas '$T/cg/sA' '$T/cg/sB' | grep -q 'B has alleles A lacks *1'"

# --- result ----------------------------------------------------------------
echo
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
