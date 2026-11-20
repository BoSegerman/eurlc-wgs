#!/usr/bin/env perl
# Unit test of species_agreement_value: do Kraken2 and Mash screen agree?
# Prints one line per case: name<TAB>species_disagree<TAB>detail
use strict; use warnings;
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my ($sub) = $src =~ /^(sub species_agreement_value \{.*?^\})/ms or die "no species_agreement_value\n";
our $R_samples; eval $sub; die $@ if $@;
my @c = (
  [ "same",            "Campylobacter jejuni",     "bracken",     "Campylobacter jejuni" ],
  [ "mash-two",        "Campylobacter coli",       "bracken",     "Campylobacter coli, Campylobacter lari" ],
  [ "mash-two-other",  "Campylobacter jejuni",     "bracken",     "Salmonella enterica,  campylobacter  Jejuni" ],
  [ "disagree",        "Campylobacter helveticus", "bracken",     "Campylobacter upsaliensis" ],
  [ "disagree-target", "Campylobacter coli",       "bracken",     "Campylobacter jejuni" ],
  [ "no-mash",         "Campylobacter jejuni",     "bracken",     undef ],
  [ "mash-na",         "Campylobacter jejuni",     "bracken",     "n/a" ],
  [ "no-kraken",       "Campylobacter jejuni",     "Mash-screen", "Campylobacter jejuni" ],
  [ "no-species",      "n/a",                      "bracken",     "Campylobacter jejuni" ],
);
for my $c (@c) {
    $R_samples = [ { main_results => { taxonomy => { species => $c->[1], species_method => $c->[2], species_disagree_detail => "old" } },
                     results => { defined $c->[3] ? ( mash_screen => { main => { species => $c->[3] } } ) : () } } ];
    species_agreement_value(0);
    my $t = $R_samples->[0]{main_results}{taxonomy};
    print join( "\t", $c->[0], $t->{species_disagree}, $t->{species_disagree_detail} // "" ), "\n";
}
