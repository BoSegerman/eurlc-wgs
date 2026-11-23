#!/usr/bin/env perl
# Unit test of the validated species (general.validated_species): pulls
# set_reportable and what it needs out of bin/eurlc-wgs and runs it on
# hand-made samples. Prints one line per sample:
# name<TAB>validated_scope<TAB>reportable<TAB>reason<TAB>shown in the report
use strict; use warnings;
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my $code = "our (\$R_samples, \$R_cfg);\n";
for my $n (qw(set_reportable validated_species_list sample_validation_scope reportable_display run_problem_text)) {
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
  # a step failed: the sample is CRITICAL (run_problem_text), not reportable, and shown as No, not Assess
  [ "", { %{ $smp->( "step-failed", "Campylobacter jejuni", "CRITICAL" ) }, failed_steps => [ { runstep => "skesa", reason => "timeout" } ] } ],
  [ "", { %{ $smp->( "step-failed-datafail", "Campylobacter jejuni", "FAIL" ) }, failed_steps => [ { runstep => "skesa", reason => "timeout" } ] } ],
  [ "", { %{ $smp->( "abandoned", "Campylobacter jejuni", "CRITICAL" ) }, fatal_error => 1, fatal_error_runstep => "downsample", fatal_error_message => [ "reformat failed" ] } ],
);
for my $c ( [ "ok", {} ], [ "failed", { failed_steps => [ { runstep => "skesa", reason => "timeout" } ] } ],
            [ "abandoned", { fatal_error => 1, fatal_error_runstep => "downsample" } ],
            [ "expected-only", { expected_failed_steps => [ { runstep => "spades" } ] } ] ) {
    print join( "\t", "runproblem-$c->[0]", run_problem_text( $c->[1] ) // "-" ), "\n";
}
for my $c (@cases) {
    $R_cfg = { general => { validated_species => $c->[0] } };
    $R_samples = [ $c->[1] ];
    set_reportable(0);
    my $mr = $R_samples->[0]{main_results};
    print join( "\t", $c->[1]{name}, $mr->{validated_scope}, $mr->{reportable}{value}, $mr->{reportable}{reason}, ( reportable_display( $R_samples->[0] ) )[0] ), "\n";
}
