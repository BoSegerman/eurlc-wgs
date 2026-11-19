#!/usr/bin/env perl
# Unit test of parse_fastmlst: pulls the sub out of bin/eurlc-wgs and runs it
# on hand-made fastMLST result lines. Prints one line per case:
# name<TAB>schema=..<TAB>st=..<TAB>cc=..<TAB>lineage=..<TAB>loci=N<TAB>allele_x=..,allele_y=..
use strict; use warnings;
use File::Temp qw(tempdir);
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my ($sub) = $src =~ /^(sub parse_fastmlst \{.*?^\})/ms or die "no parse_fastmlst\n";
our $R_samples = [ { name => "T" } ];
sub log_message { }
eval $sub; die $@ if $@;
my @c = (
 # Campylobacter: clonal_complex(...) has the form of a locus, and is not one
 [ "campy",   "T.fasta,cjejuni,257,aspA(9),glnA(2),gltA(4),glyA(62),pgm(4),tkt(5),uncA(6),clonal_complex(ST-257 complex)" ],
 # Listeria: CC(...) and Lineage(...) likewise
 [ "listeria","T.fasta,listeria_2,5,abcZ(2),bglA(1),cat(11),dapE(3),dat(3),ldh(1),lhkA(7),CC(CC5),Lineage(I)" ],
 # two alleles of one locus and a missing locus are kept as written
 [ "salm",    "T.fasta,senterica_achtman_2,-,aroC(5|7),dnaN(-),hemD(3),hisD(7),purE(6),sucA(6),thrA(11),clonal_complex(ST-11 complex)" ],
 # no clonal complex known: nan
 [ "nocc",    "T.fasta,cjejuni,9999,aspA(~9),glnA(2?),gltA(4),glyA(62),pgm(4),tkt(5),uncA(6),clonal_complex(nan)" ],
);
my $dir = tempdir( CLEANUP => 1 );
for my $c (@c) {
    my $file = "$dir/$c->[0].csv";
    open my $o, '>', $file or die; print {$o} "$c->[1]\n"; close $o;
    my $r = parse_fastmlst( $file, 0 );
    my @names = @{ $r->{allele_names} // [] };
    print join( "\t", $c->[0], "schema=$r->{schema}", "st=$r->{st}", "cc=$r->{clonal_complex}",
                "lineage=" . ( $r->{lineage} // "" ), "loci=" . scalar(@names),
                join( ",", map { "allele_$_=$r->{\"allele_$_\"}" } @names ) ), "\n";
}
