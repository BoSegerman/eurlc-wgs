#!/usr/bin/env perl
# Unit test: the schema name the reports show for a clustering result, and
# the bytes schema.ini is written with.
# Prints one line per case: name<TAB>result
use strict; use warnings;
use File::Temp qw(tempdir);
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my $code = "";
for my $n (qw(clustering_schema_info clustering_schema_text clustering_schema_html _write_schema_ini report_database_rows _chewbbaca_schema_fingerprint _generate_chewbbaca_schema_marker _chewbbaca_marker_has_local_header)) {
    my ($sub) = $src =~ /^(sub \Q$n\E \{.*?^\})/ms or die "sub $n not found\n";
    $code .= "$sub\n";
}
our ( $R_cfg, %rundata, $R_samples );
sub fill_placeholders { $_[0] }
sub encode_entities   { my $t = $_[0]; $t =~ s/&/&amp;/g; $t =~ s/</&lt;/g; $t }
sub log_message       { }
my $FROZEN_ROOT = "";
sub get_frozen_dbs_root { $FROZEN_ROOT }
eval $code; die $@ if $@;

my $d   = tempdir( CLEANUP => 1 );
my $md5 = "0123456789abcdef0123456789abcdef";
mkdir "$d/live"; mkdir "$d/$md5"; mkdir "$d/$md5/filters";
for my $dir ( "$d/live", "$d/$md5" ) { for my $l ( 1 .. 5 ) { open my $o, '>', "$dir/locus$l.fasta" or die; print $o ">1\nA\n"; close $o; } }
{ open my $o, '>', "$d/$md5/filters/cg.txt" or die; print $o "locus1.fasta\nlocus2.fasta\nlocus3.fasta\n\n"; close $o; }
$R_cfg = { chewbbaca_schemas => {
    "LIVE-1"   => { path => "$d/live", filter => "",                      version => "1" },
    "FROZEN-8" => { path => "$d/$md5", filter => "$d/$md5/filters/cg.txt", version => "8" },
} };
print "live\t",    clustering_schema_text( { schema => "live" } ), "\n";
print "frozen\t",  clustering_schema_text( { schema => $md5 } ), "\n";
print "unknown\t", clustering_schema_text( { schema => "gone" } ), "\n";
print "html\t",    clustering_schema_html( { schema => $md5 } ), "\n";

# rebuilding the reports (summarize): the configured path is the live one,
# the result is filed under the frozen version -- found in frozen_dbs
my $md5b = "fedcba9876543210fedcba9876543210";
$FROZEN_ROOT = "$d/frozen";
make_path( "$d/schemas/CAMP/filters", "$d/frozen/chewbbaca_CAMP/$md5b/filters" );
for my $l ( 1 .. 5 ) { open my $o, '>', "$d/schemas/CAMP/l$l.fasta" or die; close $o; }
for my $l ( 1 .. 4 ) { open my $o, '>', "$d/frozen/chewbbaca_CAMP/$md5b/l$l.fasta" or die; close $o; }
{ open my $o, '>', "$d/schemas/CAMP/filters/cg.txt" or die; print $o "l1\nl2\nl3\n"; close $o; }
{ open my $o, '>', "$d/frozen/chewbbaca_CAMP/$md5b/filters/cg.txt" or die; print $o "l1\nl2\n"; close $o; }
$R_cfg->{chewbbaca_schemas}{CAMP} = { path => "$d/schemas/CAMP", filter => "$d/schemas/CAMP/filters/cg.txt", version => "8" };
print "frozen-live-path\t", clustering_schema_text( { schema => $md5b } ), "\n";

# the "Database versions" table: resolved databases (with Bracken beside
# Kraken2), the schemas of the clustering results, then databases inside
# tool environments -- each once
%rundata = (
    provenance => { run => { db_versions => {
        kraken2    => { fingerprint => "k" x 32, version => "Standard-8", status => "OK [FROZEN]", files => { a => 1, b => 2, c => 3 } },
        mashscreen => { fingerprint => "m" x 32, version => "RefSeq sketch", status => "OK [LIVE]", files => { a => 1 } },
    } } },
    clustering => { results => [ { species => "Campylobacter jejuni", schema => $md5b }, { species => "Campylobacter coli", schema => $md5b },
                                 { species => "Other species", schema => "live" } ] },
);
$R_samples = [ { main_results => { taxonomy => { species => "Campylobacter coli" } } } ];
my $old = { Mashscreen => { md5 => "x", version_label => "old" }, mlst => { md5 => "l" x 32, version_label => "mlst db", file_date => "2026-11-12" } };
my @all = report_database_rows( [ "Mashscreen", "mlst" ], $old, undef );
print "dbrows-run\t", join( " / ", map { "$_->[0]=$_->[3]" } @all ), "\n";
my @one = report_database_rows( [ "Mashscreen", "mlst" ], $old, 0 );
print "dbrows-sample\t", join( " / ", map { $_->[0] } @one ), "\n";
print "dbrows-schema\t", join( "|", @{ ( grep { $_->[0] =~ /^cgMLST schema CAMP/ } @all )[0] } ), "\n";

# schema.ini: plain ASCII where the pipeline writes the text itself, and a
# non-ASCII character of an entry is written once, not encoded twice
_write_schema_ini( "$d/live", { name => "LIVE-1", label => "Caf\xc3\xa9 schema", description => "x", version => 1, species => ["A b"] }, undef );
my $ini = do { local $/; open my $f, '<:raw', "$d/live/schema.ini" or die; <$f> };
print "ini-header-ascii\t", ( ( split /\n/, $ini )[0] =~ /^[\x20-\x7e]+$/ ? 1 : 0 ), "\n";
print "ini-not-double-encoded\t", ( $ini =~ /Caf\xc3\xa9 schema/ && $ini !~ /\xc3\x83/ ? 1 : 0 ), "\n";

# Schema version marker: the same schema gives the same bytes under another
# name, in another folder and at another time; a marker made before
# 1.0.0-rc3 (name and date in the header) is recognised
use Digest::MD5 qw(md5_hex);
for my $n ( "one", "two" ) {
    mkdir "$d/m_$n";
    for my $l ( "L1.fasta", "L2.fasta" ) { open my $f, '>', "$d/m_$n/$l" or die; print $f ">a\nACGT\n"; close $f; }
}
_generate_chewbbaca_schema_marker( "$d/m_one", "NAME-A" );
sleep 1;
_generate_chewbbaca_schema_marker( "$d/m_two", "another name" );
my @mk = map { my $p = "$d/m_$_/schema_version.md5"; local $/; open my $f, '<:raw', $p or die; scalar <$f> } qw(one two);
print "marker-same-everywhere\t", ( md5_hex( $mk[0] ) eq md5_hex( $mk[1] ) ? 1 : 0 ), "\n";
print "marker-no-date-or-name\t", ( $mk[0] !~ /Generated|NAME-A|\d{4}-\d\d-\d\d/ ? 1 : 0 ), "\n";
print "marker-new-not-old-format\t", _chewbbaca_marker_has_local_header("$d/m_one/schema_version.md5"), "\n";
open my $of, '>', "$d/m_two/schema_version.md5" or die;
print $of "# chewBBACA schema version marker\n# Schema:    x\n# Generated: 2026-11-20 10:00:00\n# Loci:      2\n#\nL1.fasta:8\nL2.fasta:8\n"; close $of;
print "marker-old-format-found\t", _chewbbaca_marker_has_local_header("$d/m_two/schema_version.md5"), "\n";
