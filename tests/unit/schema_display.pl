#!/usr/bin/env perl
# Unit test: the schema name the reports show for a clustering result, and
# the bytes schema.ini is written with.
# Prints one line per case: name<TAB>result
use strict; use warnings;
use File::Temp qw(tempdir);
use File::Basename qw(basename);
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my $code = "";
for my $n (qw(clustering_schema_info clustering_schema_text clustering_schema_html _write_schema_ini)) {
    my ($sub) = $src =~ /^(sub \Q$n\E \{.*?^\})/ms or die "sub $n not found\n";
    $code .= "$sub\n";
}
our $R_cfg;
sub fill_placeholders { $_[0] }
sub encode_entities   { my $t = $_[0]; $t =~ s/&/&amp;/g; $t =~ s/</&lt;/g; $t }
sub log_message       { }
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

# schema.ini: plain ASCII where the pipeline writes the text itself, and a
# non-ASCII character of an entry is written once, not encoded twice
_write_schema_ini( "$d/live", { name => "LIVE-1", label => "Caf\xc3\xa9 schema", description => "x", version => 1, species => ["A b"] }, undef );
my $ini = do { local $/; open my $f, '<:raw', "$d/live/schema.ini" or die; <$f> };
print "ini-header-ascii\t", ( ( split /\n/, $ini )[0] =~ /^[\x20-\x7e]+$/ ? 1 : 0 ), "\n";
print "ini-not-double-encoded\t", ( $ini =~ /Caf\xc3\xa9 schema/ && $ini !~ /\xc3\x83/ ? 1 : 0 ), "\n";
