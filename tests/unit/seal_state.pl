#!/usr/bin/env perl
# Unit test of the seal's verdict (_verify_config_seal): the files of the
# seal are unchanged, but the installation is not what they describe.
# Prints one line per case: name<TAB>status<TAB>mismatches
use strict; use warnings;
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my ($sub) = $src =~ /^(sub _verify_config_seal \{.*?^\})/ms or die "no _verify_config_seal\n";
our ( %S_SEAL_STATE_PROBLEMS, $S_SEAL_STATE_LOGGED, $S_SEAL_RESULT, $FILES );
sub log_message { }
sub _verify_config_seal_files { return $S_SEAL_RESULT if $S_SEAL_RESULT; return $S_SEAL_RESULT = { %$FILES } }
eval $sub; die $@ if $@;
my @cases = (
  [ "all-as-sealed",  "SEAL VERIFIED", [] ],
  [ "env-updated",    "SEAL VERIFIED", [ "conda environment eurlc-wgs-spades: differs from conda_manifest.ini (packages added, removed or updated)" ] ],
  [ "db-live",        "SEAL VERIFIED WITH OVERRIDES", [ "database kraken2: the frozen version is not in use (LIVE_OK: using live database at /db/kraken2)" ] ],
  [ "files-changed",  "SEAL BROKEN", [ "conda environment x: not found (it is in conda_manifest.ini)" ] ],
);
for my $c (@cases) {
    ( %S_SEAL_STATE_PROBLEMS, $S_SEAL_RESULT, $S_SEAL_STATE_LOGGED ) = ();
    $FILES = { status => $c->[1], name => "T", detail => "", mismatches => $c->[1] eq "SEAL BROKEN" ? ["  eurlc_wgs_config: changed"] : [], overrides => [] };
    my $first = _verify_config_seal();            # before the installation was looked at
    $S_SEAL_STATE_PROBLEMS{$_} = 1 for @{ $c->[2] };
    my $r = _verify_config_seal();
    print join( "\t", $c->[0], $first->{status}, $r->{status}, $S_SEAL_RESULT->{status}, join( " | ", map { s/^\s+//r } @{ $r->{mismatches} } ) ), "\n";
}
