#!/usr/bin/env perl
# Unit test of sample_known_data_fail: pulls the sub and what it needs out of
# bin/eurlc-wgs (the script cannot be loaded as a module) and runs it on
# hand-made samples. Prints one line per sample: name<TAB>reason.
use strict; use warnings;
my $src = do { local $/; open my $f, '<', $ARGV[0] or die; <$f> };
my ($def) = $src =~ /^(my %QC_MEASURE_DEF = \(.*?^\);)/ms or die "no def";
my $code = "our (\$R_samples, \$R_cfg); my %CFG;\n$def\n";
for my $n (qw(sample_known_data_fail parse_threshold_string threshold_matches _normalize_numeric_value get_main_result_value)) {
    my ($s) = $src =~ /^(sub \Q$n\E \{.*?^\})/ms or die "no $n"; $code .= "$s\n";
}
$code .= 'sub get_config_value_for_species { my ($sp,$k)=@_; return $CFG{$k} } sub log_message {}
%CFG = (fail_coverage_trimmed_q30_coverage => "<30", fail_qscore_trimmed_q30_rate => "<0.70", fail_qscore_raw_pair_name_mismatch_pct => ">50", fail_assembly_size => "<1000000");
$R_samples = [
  { name=>"ok",  main_results=>{ coverage=>{trimmed=>{q30_coverage=>90}}, qscore=>{trimmed=>{q30_rate=>0.95}}, assembly=>{size=>10} } },
  { name=>"low", main_results=>{ coverage=>{trimmed=>{q30_coverage=>5.7}} } },
  { name=>"swap",main_results=>{ qscore=>{raw=>{pair_name_mismatch_pct=>100}} } },
  { name=>"ab",  fatal_error=>1, fatal_error_message=>["Coverage is below mindepth"] },
  { name=>"none" },
];
for my $i (0..$#$R_samples) { printf "%s\t%s\n", $R_samples->[$i]{name}, sample_known_data_fail($i) }
';
eval $code; die $@ if $@;
