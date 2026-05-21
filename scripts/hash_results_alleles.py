#!/usr/bin/env python3
import os
import sys
import argparse
import zlib
from Bio import SeqIO
import hashlib

def parse_args():
    parser = argparse.ArgumentParser(description="Extract sequences and compute CRC32 hashes.")
    parser.add_argument("base_dir", help="Base directory where FASTA files are located.")
    parser.add_argument("--writesequences", action="store_true", help="Write extracted sequences to FASTA files.")
    return parser.parse_args()

def extract_sequence(fasta_path, contig_name, coords, strand):
    with open(fasta_path, "r") as fasta_file:
        for record in SeqIO.parse(fasta_file, "fasta"):
            if record.id.split()[0] == contig_name:  # Match only the first part of the name
                start, end = map(int, coords.split("-"))
                seq = record.seq[start-1:end]  # Convert to 0-based index
                return str(seq if strand == "1" else seq.reverse_complement()).upper()
    return None

def process_file(base_dir, write_sequences):
    input_file = "results_contigsInfo.tsv"
    output_file_crc32 = "results_alleles_crc32.tsv"
    output_file_md5 = "results_alleles_md5.tsv"
    output_file_sha256 = "results_alleles_sha256.tsv"        
    allele_dir = "alleles"
    os.makedirs(allele_dir, exist_ok=True)
    
    with open(input_file, "r") as infile, open(output_file_crc32, "w") as outfile_crc32, open(output_file_md5, "w") as outfile_md5, open(output_file_sha256, "w") as outfile_sha256:
        header = infile.readline().strip().split("\t")
        outfile_crc32.write("\t".join(header) + "\n")
        outfile_md5.write("\t".join(header) + "\n")
        outfile_sha256.write("\t".join(header) + "\n")
        allele_ids = header[1:]
         
        fasta_files = {}
        sequence_cache = {}
        fasta_outputs = {}
        
        for line in infile:
            parts = line.strip().split("\t")
            sample = parts[0]
            fasta_path = os.path.join(base_dir, sample + ".fasta")
            
            if fasta_path not in fasta_files:
                if not os.path.exists(fasta_path):
                    print(f"Warning: Missing FASTA for {sample}")
                    continue
                fasta_files[fasta_path] = SeqIO.to_dict(SeqIO.parse(fasta_path, "fasta"))
            
            new_row_crc32 = [sample]
            new_row_md5 = [sample]
            new_row_sha256 = [sample]
            sequences_to_write = []
            
            for allele_id, data in zip(header[1:], parts[1:]):
                if "&" in data:
                    contig_name, coords, strand = data.split("&")
                    contig_name = contig_name.split()[0]
      
                    
                    seq = extract_sequence(fasta_path, contig_name, coords, strand)
                    if seq is None:
                        crc32_hash_value = "-"
                        md5_hash_value = "-"
                        sha256_hash_value = "-"
                    else:
                        crc32_hash_value = str(zlib.crc32(seq.encode('utf-8')) & 0xFFFFFFFF)
                        md5_hash_value = hashlib.md5(seq.encode('utf-8')).hexdigest()
                        sha256_hash_value = hashlib.sha256(seq.encode('utf-8')).hexdigest()
                        
                        if write_sequences:
                            sequences_to_write.append(f">{allele_id} {fasta_path} {contig_name}|{coords}|{strand}\n{seq}\n")
                else:
                    crc32_hash_value = "-"
                    md5_hash_value = "-"
                    sha256_hash_value = "-"
                    
                new_row_crc32.append(crc32_hash_value)
                new_row_md5.append(md5_hash_value)
                new_row_sha256.append(sha256_hash_value)
                
            outfile_crc32.write("\t".join(new_row_crc32) + "\n")
            outfile_md5.write("\t".join(new_row_md5) + "\n")
            outfile_sha256.write("\t".join(new_row_sha256) + "\n")
            
            if write_sequences and sequences_to_write:
                fasta_out_path = os.path.join(allele_dir, f"{sample}_alleles.fasta")
                if fasta_out_path not in fasta_outputs:
                    fasta_outputs[fasta_out_path] = open(fasta_out_path, "w")
                fasta_outputs[fasta_out_path].writelines(sequences_to_write)
    
    for f in fasta_outputs.values():
        f.close()

if __name__ == "__main__":
    args = parse_args()
    process_file(args.base_dir, args.writesequences)

