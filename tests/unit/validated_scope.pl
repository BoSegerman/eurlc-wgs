#!/usr/bin/env perl
# Unit test of the validated species (general.validated_species): pulls
# set_reportable and what it needs out of bin/eurlc-wgs and runs it on
# hand-made samples. Prints one line per sample:
# name<TAB>validated_scope<TAB>reportable<TAB>reason<TAB>shown in the report
use strict; use warnings;
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my $code = "our (\$R_samples, \$R_cfg);\n";
for my $n (qw(set_reportable validated_species_list sample_validation_scope reportable_display)) {
    my ($s) = $src =~ /^(sub \Q$n\E \{.*?^\})/ms or die "no $n\n"; $code .= "$s\n";
}
$code .= 'sub qc_root_cause_message { return undef }' . "\n";
our ($R_samples, $R_cfg);
eval $code; die $@ if $@;
my $smp = sub { my ($name, $species, $status) = @_;
    return { name => $name, qc => { status => $status // "PASS", issues => {} },
             main_results => { taxonomy => { species => $species } } } };
my @cases = (
  [ "Campylobacter jejuni, Campylobacter coli", $smp->( "jejuni", "Campylobacter jejuni" ) ],
  [ "Campylobacter jejuni, Campylobacter coli", $smp->( "coli", "Campylobacter  Coli" ) ],
  [ "Campylobacter jejuni, Campylobacter coli", $smp->( "lari", "Campylobacter lari" ) ],
  [ "Campylobacter jejuni, Campylobacter coli", $smp->( "lari-fail", "Campylobacter lari", "FAIL" ) ],
  [ "Campylobacter jejuni, Campylobacter coli", $smp->( "nospecies", "n/a" ) ],
  [ "Campylobacter",                            $smp->( "genus-lari", "Campylobacter lari" ) ],
  [ "",                                         $smp->( "undeclared", "Salmonella enterica" ) ],
  [ "",                                         $smp->( "critical", "Campylobacter jejuni", "CRITICAL" ) ],
  [ "",                                         $smp->( "fail", "Campylobacter jejuni", "FAIL" ) ],
);
for my $c (@cases) {
    $R_cfg = { general => { validated_species => $c->[0] } };
    $R_samples = [ $c->[1] ];
    set_reportable(0);
    my $mr = $R_samples->[0]{main_results};
    print join( "\t", $c->[1]{name}, $mr->{validated_scope}, $mr->{reportable}{value}, $mr->{reportable}{reason}, ( reportable_display( $R_samples->[0] ) )[0] ), "\n";
}
