#!/usr/bin/env perl
# Unit test of the --setup helpers: species choice, "is the live database
# there", "is the schema installed".
# Prints one line per case: name<TAB>result
use strict; use warnings;
use File::Temp qw(tempdir);
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my $code = "";
for my $re ( qr/^(our \@SETUP_SPECIES = \(.*?^\);)/ms,
             qr/^(sub setup_species_keys \{.*?^\})/ms,
             qr/^(sub live_db_present \{.*?^\})/ms,
             qr/^(sub schema_is_installed \{.*?^\})/ms ) {
    my ($part) = $src =~ $re or die "part not found: $re\n";
    $code .= "$part\n";
}
our @SETUP_SPECIES; eval $code; die $@ if $@;

for my $t ( "campylobacter,salmonella", "2, Listeria", "Campylobacter jejuni, E.coli, campy", "all", "1,foo", "", "7" ) {
    my ( $k, $u ) = setup_species_keys($t);
    print join( "\t", "species[$t]", join( ",", @$k ) || "-", join( ",", @$u ) || "-" ), "\n";
}

my $d = tempdir( CLEANUP => 1 );
my $w = sub { my ( $f, $txt ) = @_; open my $o, '>', $f or die; print $o $txt; close $o; };
mkdir "$d/mash"; mkdir "$d/k2"; mkdir "$d/schema";
my $mash = { marker_file => "refseq.genomes.k21s1000.msh", config_key => "mashscreen.db_path" };
print "db-no-folder\t",    live_db_present( "mashscreen", $mash, "$d/none" ), "\n";
print "db-empty-folder\t", live_db_present( "mashscreen", $mash, "$d/mash" ), "\n";
$w->( "$d/mash/refseq.genomes.k21s1000.msh.part", "x" );
print "db-part-file\t",    live_db_present( "mashscreen", $mash, "$d/mash" ), "\n";
$w->( "$d/mash/refseq.genomes.k21s1000.msh", "" );
print "db-empty-file\t",   live_db_present( "mashscreen", $mash, "$d/mash" ), "\n";
$w->( "$d/mash/refseq.genomes.k21s1000.msh", "x" );
print "db-complete\t",     live_db_present( "mashscreen", $mash, "$d/mash" ), "\n";
my $k2 = { marker_file => "hash.k2d, taxo.k2d, database*mers.kmer_distrib", config_key => "kraken2.db_path" };
$w->( "$d/k2/hash.k2d", "x" ); $w->( "$d/k2/taxo.k2d", "x" );
print "db-one-marker-missing\t", live_db_present( "kraken2", $k2, "$d/k2" ), "\n";
$w->( "$d/k2/database150mers.kmer_distrib", "x" );
print "db-all-markers\t",  live_db_present( "kraken2", $k2, "$d/k2" ), "\n";
print "db-schema-folder\t", live_db_present( "chewbbaca_x", { marker_file => "schema_version.md5", config_key => "chewbbaca_schemas.x.path" }, "$d/schema" ), "\n";

print "schema-empty\t",   schema_is_installed("$d/schema"), "\n";
$w->( "$d/schema/l1.fasta", ">a\n" );
print "schema-no-ini\t",  schema_is_installed("$d/schema"), "\n";
$w->( "$d/schema/schema.ini", "[schema]\n" );
print "schema-complete\t", schema_is_installed("$d/schema"), "\n";
