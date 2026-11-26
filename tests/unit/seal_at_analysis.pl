#!/usr/bin/env perl
# The seal a report shows is the one the ANALYSIS was made under
# (effective_seal, record_analysis_seal in bin/eurlc-wgs).
# Usage: perl tests/unit/seal_at_analysis.pl bin/eurlc-wgs   -> lines "<case>\t<status>\t<name>\t<flags>"
use strict; use warnings;
use File::Temp qw(tempdir);
my $script = shift or die "usage: $0 <eurlc-wgs>\n";
my $src = do { local $/; open my $f, '<', $script or die; <$f> };
my $code = "";
for my $n (qw(effective_seal _seal_record_text record_analysis_seal)) {
    my ($sub) = $src =~ /^(sub \Q$n\E \{.*?^\})/ms or die "no sub $n";
    $code .= "$sub\n";
}
our %rundata; our $S_SUMMARIZE_MODE = 0; our $NOW;
sub current_seal_record { return { %$NOW, detail => "", time => "t" } }
sub load_hash_from_json { my $f = shift; open my $fh, '<', $f or die; local $/; my $t = <$fh>; return eval $t }   # test files hold a Perl hash
eval $code; die $@ if $@;

my $K2 = { status => "SEAL VERIFIED", name => "K2", pipeline_version => "1.0.0", pipeline_md5 => "aaaa" };
my $K3 = { status => "SEAL VERIFIED", name => "K3", pipeline_version => "1.0.0", pipeline_md5 => "bbbb" };
my $UN = { status => "UNSEALED",      name => "",   pipeline_version => "1.0.0", pipeline_md5 => "aaaa" };
my $d = tempdir( CLEANUP => 1 );
my $show = sub {
    my ($case) = @_;
    my $e = effective_seal();
    print join( "\t", $case, $e->{status}, $e->{name},
                ( $e->{detail} =~ /Analysis: .*K2.*aaaa/s && $e->{detail} =~ /This report: .*K3.*bbbb/s ? "both-shown" : "" )
              . ( $e->{detail} =~ /was not recorded/ ? "not-recorded" : "" )
              . ( $e->{detail} =~ /in parts/ ? "parts" : "" ) ), "\n";
};
# 1. an analysis, and its own report
%rundata = (); $NOW = $K2; record_analysis_seal("$d/none.json"); $show->("analysis");
# 2. summarize later under the same seal and script
$S_SUMMARIZE_MODE = 1; $show->("summarize-same");
# 3. summarize after a new seal and a changed script
$NOW = $K3; $show->("summarize-new-seal");
# 4. an analysis made unsealed, summarized under a seal
%rundata = (); $S_SUMMARIZE_MODE = 0; $NOW = $UN; record_analysis_seal("$d/none.json");
$S_SUMMARIZE_MODE = 1; $NOW = $K3; $show->("unsealed-then-sealed");
# 5. a run from before the seal was recorded, summarized now
%rundata = (); $show->("old-run");
# 6. a run resumed under another seal: the earlier part is read from rundata.json
open my $fh, '>', "$d/r.json" or die; print $fh "{ provenance => { run => { seal_history => [ { status => 'SEAL VERIFIED', name => 'K2', pipeline_version => '1.0.0', pipeline_md5 => 'aaaa', time => 't0' } ] } } }"; close $fh;
%rundata = (); $S_SUMMARIZE_MODE = 0; $NOW = $K3; record_analysis_seal("$d/r.json"); $show->("resumed-other-seal");
# 7. a run resumed under the same seal
%rundata = (); $NOW = $K2; record_analysis_seal("$d/r.json"); $show->("resumed-same-seal");
