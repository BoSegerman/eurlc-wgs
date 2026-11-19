import random, sys, os, gzip
random.seed(int(sys.argv[2]) if len(sys.argv)>2 else 7)
d=sys.argv[1]; base=os.path.basename(d.rstrip('/')); os.makedirs(d, exist_ok=True)
contigs=[("Contig_1",4000),("Contig_2",2600),("Contig_3",1200)] if os.environ.get("SMALL") else [("Contig_1",12000),("Contig_2",6500),("Contig_3",1500)]
B="ACGT"
pl=gzip.open(f"{d}/{base}.pileup.gz","wt"); dp_f=open(f"{d}/{base}.depth.tsv","w")
mixed=set(random.sample(range(200,3800),30)) if os.environ.get("SMALL") else set(random.sample(range(200,11800),60))
for name,L in contigs:
    for pos in range(1,L+1):
        ref=random.choice(B)
        depth=max(0,int(random.gauss(90 if name!="Contig_3" else 300,20)))
        if pos<30: depth=random.randint(0,25)
        dp_f.write(f"{name}\t{pos}\t{depth+random.randint(0,3)}\n")
        if depth<15 and random.random()<0.3: 
            pl.write(f"{name}\t{pos}\t{ref}\t{depth}\t{'.'*depth}\t{'I'*depth}\n"); continue
        alt=random.choice([b for b in B if b!=ref])
        out=[]
        frac = 0.12 if (name=="Contig_1" and pos in mixed) else 0
        for i in range(depth):
            fwd=random.random()<0.5
            r=random.random()
            if random.random()<0.02: out.append("^"+random.choice("I+-5"))
            if r<frac: c=alt
            elif r<frac+0.004: c=random.choice(B)
            elif r<frac+0.006: c="*"
            elif r<frac+0.007: c="N"
            else: c="."
            if c==".": c="." if fwd else ","
            else: c=c if fwd else c.lower()
            out.append(c)
            if random.random()<0.004 or (pos%997==0 and random.random()<0.4):
                k=random.randint(1,3); out.append(random.choice("+-")+str(k)+"".join(random.choice("ACGTacgt") for _ in range(k)))
            if random.random()<0.01: out.append("$")
        pl.write(f"{name}\t{pos}\t{ref}\t{depth}\t{''.join(out)}\t{'I'*depth}\n")
pl.close(); dp_f.close()
with open(f"{d}/{base}.coverage","w") as f:
    f.write("#rname\tstartpos\tendpos\tnumreads\tcovbases\tcoverage\tmeandepth\tmeanbaseq\tmeanmapq\n")
    for n,L in contigs: f.write(f"{n}\t1\t{L}\t1000\t{L}\t100\t90\t36\t42\n")
for ext in ("stats","flagstats"): open(f"{d}/{base}.{ext}","w").write("")
with open(f"{d}/{base}.idxstats","w") as f:
    for n,L in contigs: f.write(f"{n}\t{L}\t5000\t10\n")
    f.write("*\t0\t0\t40\n")
