#!/usr/bin/env python3
import os
import sys
import json
import argparse
import zlib
from Bio import SeqIO
import hashlib

def parse_args():
    parser = argparse.ArgumentParser(description="Extract sequences and compute hashes (CRC32, SHA256, optionally MD5).")
    parser.add_argument("base_dir", help="Base directory where FASTA files are located.")
    parser.add_argument("--writesequences", action="store_true", help="Write extracted sequences to FASTA files.")
    parser.add_argument("--write-md5", action="store_true",
                         help="Also write results_alleles_md5.tsv. Off by default -- "
                              "CRC32 (fast, for everyday use) + SHA256 (strong, for "
                              "collision verification) is the standard pair; MD5 is "
                              "rarely needed in addition to those.")
    return parser.parse_args()

def extract_sequence(record_dict, contig_name, coords, strand):
    # record_dict: this sample's already-parsed FASTA (SeqIO.to_dict), built
    # once per sample in process_file and passed in here -- previously this
    # function re-opened and linearly re-scanned the entire FASTA file from
    # disk for every single locus, even though the caller had already
    # parsed it into a dict; for a schema with thousands of loci, that was
    # thousands of redundant full-genome scans per sample. Using the
    # already-built dict turns each lookup into a single dict access.
    record = record_dict.get(contig_name)
    if record is None:
        return None
    start, end = map(int, coords.split("-"))
    seq = record.seq[start-1:end]  # Convert to 0-based index
    return str(seq if strand == "1" else seq.reverse_complement()).upper()

def process_file(base_dir, write_sequences, write_md5):
    input_file = "results_contigsInfo.tsv"
    output_file_crc32 = "results_alleles_crc32.tsv"
    output_file_sha256 = "results_alleles_sha256.tsv"
    output_file_md5 = "results_alleles_md5.tsv"
    report_file = "hashing_report.json"
    allele_dir = "alleles"

    report = {
        "samples_processed": 0,
        "samples_missing_fasta": [],   # list of sample names
        "extraction_failures": [],     # list of {sample, locus} -- chewBBACA
                                        # called something (coordinate data
                                        # present) but the sequence could
                                        # not actually be extracted
        "md5_written": write_md5,
    }

    os.makedirs(allele_dir, exist_ok=True)

    outfiles = {"crc32": open(output_file_crc32, "w"), "sha256": open(output_file_sha256, "w")}
    if write_md5:
        outfiles["md5"] = open(output_file_md5, "w")

    try:
        with open(input_file, "r") as infile:
            header = infile.readline().strip().split("\t")
            for fh in outfiles.values():
                fh.write("\t".join(header) + "\n")
            allele_ids = header[1:]

            fasta_files = {}
            fasta_outputs = {}

            for line in infile:
                parts = line.strip().split("\t")
                sample = parts[0]
                report["samples_processed"] += 1
                fasta_path = os.path.join(base_dir, sample + ".fasta")

                if fasta_path not in fasta_files:
                    if not os.path.exists(fasta_path):
                        print(f"Warning: Missing FASTA for {sample}")
                        report["samples_missing_fasta"].append(sample)
                        fasta_files[fasta_path] = None
                    else:
                        fasta_files[fasta_path] = SeqIO.to_dict(SeqIO.parse(fasta_path, "fasta"))

                record_dict = fasta_files[fasta_path]

                new_rows = {key: [sample] for key in outfiles}
                sequences_to_write = []

                for allele_id, data in zip(header[1:], parts[1:]):
                    seq = None

                    # record_dict is None only when this sample's own FASTA
                    # was missing entirely -- every locus for this sample
                    # is unavoidably "-" in that case, same as any other
                    # no-call, deliberately NOT a different symbol (see
                    # the design note below).
                    if record_dict is not None and "&" in data:
                        contig_name, coords, strand = data.split("&")
                        contig_name = contig_name.split()[0]
                        seq = extract_sequence(record_dict, contig_name, coords, strand)
                        if seq is None:
                            # chewBBACA DID call something here (real
                            # coordinate data present) but extraction still
                            # failed -- worth flagging specifically, unlike
                            # an ordinary no-call.
                            report["extraction_failures"].append({"sample": sample, "locus": allele_id})

                    if seq is None:
                        hash_values = {key: "-" for key in outfiles}
                    else:
                        encoded = seq.encode("utf-8")
                        hash_values = {}
                        if "crc32" in outfiles:
                            hash_values["crc32"] = str(zlib.crc32(encoded) & 0xFFFFFFFF)
                        if "sha256" in outfiles:
                            hash_values["sha256"] = hashlib.sha256(encoded).hexdigest()
                        if "md5" in outfiles:
                            hash_values["md5"] = hashlib.md5(encoded).hexdigest()

                        if write_sequences:
                            sequences_to_write.append(f">{allele_id} {fasta_path} {contig_name}|{coords}|{strand}\n{seq}\n")

                    for key in outfiles:
                        new_rows[key].append(hash_values[key])

                for key, fh in outfiles.items():
                    fh.write("\t".join(new_rows[key]) + "\n")

                if write_sequences and sequences_to_write:
                    fasta_out_path = os.path.join(allele_dir, f"{sample}_alleles.fasta")
                    if fasta_out_path not in fasta_outputs:
                        fasta_outputs[fasta_out_path] = open(fasta_out_path, "w")
                    fasta_outputs[fasta_out_path].writelines(sequences_to_write)

        for f in fasta_outputs.values():
            f.close()

    finally:
        for fh in outfiles.values():
            fh.close()

    with open(report_file, "w") as rfh:
        json.dump(report, rfh, indent=2)

    # Exit code: 0 = clean, 2 = completed but with warnings worth a human
    # noticing (missing FASTA / extraction failures), distinct from a
    # genuine crash (which would already exit non-zero on its own, e.g. if
    # results_contigsInfo.tsv can't be opened at all). The full detail
    # always lives in hashing_report.json regardless -- the exit code is
    # just a coarse, easily-scriptable summary signal alongside it.
    if report["samples_missing_fasta"] or report["extraction_failures"]:
        sys.exit(2)

if __name__ == "__main__":
    args = parse_args()
    process_file(args.base_dir, args.writesequences, args.write_md5)
