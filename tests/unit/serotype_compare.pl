#!/usr/bin/env perl
# Unit test of typing_qc_values (serovar comparison SISTR/SeqSero2, MLST loci):
# pulls the sub out of bin/eurlc-wgs and runs it on hand-made results.
use strict; use warnings;
my $src = do { local $/; open my $f, '<', $ARGV[0] or die; <$f> };
my $sub = "";
for my $n (qw(serotype_display_name typing_qc_values)) {
    my ($s) = $src =~ /^(sub \Q$n\E \{.*?^\})/ms or die "no $n\n"; $sub .= "$s\n";
}
our $R_samples; eval $sub; die $@ if $@;
my @c = (
 ["Enteritidis",{o_antigen=>"1,9,12",h1=>"g,m",h2=>"-"},"Gallinarum or Enteritidis",{o_antigen=>"9",h1_antigen=>"g,m",h2_antigen=>"-"}],
 ["Choleraesuis",{o_antigen=>"6,7",h1=>"c",h2=>"1,5"},"Paratyphi C or Choleraesuis or Typhisuis",{}],
 ["-:-:-",{o_antigen=>"-",h1=>"-",h2=>"-"},"- -:-:-",{o_antigen=>"-",h1_antigen=>"-",h2_antigen=>"-"}],
 ["Reading",{o_antigen=>"1,4,[5],12",h1=>"e,h",h2=>"1,5"},"I -:e,h:1,5",{o_antigen=>"-",h1_antigen=>"e,h",h2_antigen=>"1,5"}],
 ["I 4,5,[12],1:b:-",{o_antigen=>"1,4,[5],12",h1=>"b",h2=>"-"},"I 4:b:-",{o_antigen=>"4",h1_antigen=>"b",h2_antigen=>"-"}],
 ["Infantis",{o_antigen=>"6,7,14",h1=>"r",h2=>"1,5"},"Bradford",{o_antigen=>"4,12,27",h1_antigen=>"r",h2_antigen=>"1,5"}],
 ["Berta|Pensacola|Sangalkam",{o_antigen=>"1,9,12",h1=>"f,g,t",h2=>"-"},"Gallinarum or Enteritidis",{o_antigen=>"9",h1_antigen=>"g,m",h2_antigen=>"-"}],
 ["Dublin",{o_antigen=>"1,9,12",h1=>"g,p",h2=>"-"},"I -:g,p:-",{o_antigen=>"-",h1_antigen=>"g,p",h2_antigen=>"-"}],
 ["Typhimurium",{o_antigen=>"4,12",h1=>"i",h2=>"1,2"},"I 4:r:-",{o_antigen=>"4",h1_antigen=>"r",h2_antigen=>"-"}],
 ["NotUsed|Berta",{not_used_reason=>"QC status WARNING",qc_status=>"WARNING",o_antigen=>"1,9,12",h1=>"f,g,t",h2=>"-"},"Gallinarum or Enteritidis",{}, {main=>{st=>"-", allele_aroC=>"5|7", allele_dnaN=>"2"}}],
);
for my $c (@c) {
  # the reported serovar is SISTR's, or SeqSero2's when SISTR's is not used
  # (serotype_tool_flag follows the QC of the tool that is reported)
  my $method = $c->[1]{not_used_reason} ? "seqsero2" : "sistr";
  $R_samples = [ { main_results=>{taxonomy=>{species=>"Salmonella enterica"}, typing=>{serotype=>{method=>$method}}}, results=>{
     sistr=>{status=>"done", serovar=>$c->[0], serotype=>$c->[0], qc_status=>"PASS", %{$c->[1]}},
     seqsero2=>{status=>"done", serotype=>$c->[2], %{$c->[3]}},
     mlst=>{main=>{st=>"11", allele_aroC=>"5", allele_names=>["aroC"], allele_dnaN=>"2?"}},
     ( $c->[4] ? ( fastmlst => $c->[4] ) : () ) } } ];
  typing_qc_values(0); my $q=$R_samples->[0]{main_results}{typing}{qc};
  printf "%-28s vs %-42s disagree=%s missing=%s toolflag=%s mlst=%s %s\n", $c->[0], $c->[2], $q->{serotype_disagree}, $q->{serotype_missing}, $q->{serotype_tool_flag}, $q->{mlst_incomplete_alleles}, $q->{mlst_incomplete_alleles_detail}//'';
}
