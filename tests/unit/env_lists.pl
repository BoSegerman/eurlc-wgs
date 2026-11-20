#!/usr/bin/env perl
# Unit test of the package lists of a sealed installation (sealed_env_list):
# ensure_conda_tool with a stand-in conda that keeps its "environments" as
# files. Prints one line per case: name<TAB>returned<TAB>conda calls<TAB>fingerprint as in the list?
use strict; use warnings;
use File::Temp qw(tempdir); use File::Basename; use File::Path (); use Digest::MD5 ();
my $src = do { local $/; open my $f, '<', $ARGV[0] or die "cannot read the script\n"; <$f> };
my $code = "";
for my $n (qw(ensure_conda_tool sealed_env_list_dir sealed_env_list explicit_list_fingerprint conda_env_fingerprint conda_env_exists)) {
    my ($s) = $src =~ /^(sub \Q$n\E \{.*?^\})/ms or die "no $n\n"; $code .= "$s\n";
}
our ( $R_cfg, $ASSUME_YES, $S_CONDA_ENVS );
my $T = tempdir( CLEANUP => 1 );
mkdir "$T/bin"; mkdir "$T/envs"; mkdir "$T/db"; mkdir "$T/db/conda_envs";
# stand-in conda: an environment is the file $T/envs/<name> with its package lines
open my $c, '>', "$T/bin/conda" or die; print {$c} <<"SH"; close $c; chmod 0755, "$T/bin/conda";
#!/bin/sh
echo "\$*" >> "$T/calls"
case "\$1 \$2" in
  "env list")   for e in "$T"/envs/*; do [ -f "\$e" ] && echo "\$(basename "\$e")  /x/\$(basename "\$e")"; done ;;
  "list --explicit") n=""; while [ \$# -gt 0 ]; do [ "\$1" = "-n" ] && n=\$2; shift; done; [ -f "$T/envs/\$n" ] || exit 1; echo "# platform: linux-64"; echo "\@EXPLICIT"; cat "$T/envs/\$n" ;;
  "env remove") n=""; while [ \$# -gt 0 ]; do [ "\$1" = "-n" ] && n=\$2; shift; done; rm -f "$T/envs/\$n" ;;
  "create -y")  n=""; f=""; while [ \$# -gt 0 ]; do [ "\$1" = "-n" ] && n=\$2; [ "\$1" = "--file" ] && f=\$2; shift; done
                [ -n "\$f" ] || exit 1; grep '^http' "\$f" | sed 's/#.*//' > "$T/envs/\$n" ;;
  "env create"|"env update") echo "https://c/linux-64/from-yml-1.0-0.conda" > "$T/envs/eurlc-wgs-t" ;;
esac
exit 0
SH
$ENV{PATH} = "$T/bin:$ENV{PATH}";
sub log_message { }
sub peekdir { "$T/db" }
sub find_env_yml { "$T/t.yml" }
sub validate_tool_installation { 1 }
sub prompt_yes_no_yesstoall { 0 }
sub parse_conda_yml_dependencies { () }
eval $code; die $@ if $@;
my $A = "https://c/linux-64/a-1.0-h1_0.conda";  my $B = "https://c/linux-64/b-2.0-h2_1.tar.bz2";  my $OLD = "https://c/linux-64/b-1.9-h2_0.tar.bz2";
my $list = "$T/db/conda_envs/eurlc-wgs-t.explicit";
my $write_list = sub { open my $f, '>', $list or die; print {$f} "# platform: linux-64\n\@EXPLICIT\n$B#00112233445566778899aabbccddeeff\n$A#ffeeddccbbaa99887766554433221100\n"; close $f };
my $set_env = sub { my @p = @_; if (@p) { open my $f, '>', "$T/envs/eurlc-wgs-t" or die; print {$f} "$_\n" for @p; close $f } else { unlink "$T/envs/eurlc-wgs-t" } };
my @cases = (
  [ "missing-with-list",   1, sub { $write_list->(); $set_env->() } ],
  [ "same-as-list",        1, sub { $write_list->(); $set_env->( $A, $B ) } ],
  [ "differs-from-list",   1, sub { $write_list->(); $set_env->( $A, $OLD ) } ],
  [ "differs-not-allowed", 0, sub { $write_list->(); $set_env->( $A, $OLD ) } ],
  [ "no-list",             1, sub { unlink $list; $set_env->() } ],
);
for my $c (@cases) {
    $c->[2]->(); unlink "$T/calls"; undef $S_CONDA_ENVS;
    $ASSUME_YES = $c->[1];
    $R_cfg = { t => { env => "eurlc-wgs-t", yml => "core/t.yml" }, general => { seal => "$T/db/config_seal.ini" } };
    my $r = ensure_conda_tool( "t", $c->[1] );
    my @calls = do { open my $f, '<', "$T/calls" or (); $f ? <$f> : () }; chomp @calls;
    my @did = map { /^env remove/ ? "remove" : /^create .*--file/ ? "create-from-list" : /^env create/ ? "create-from-yml" : /^env update/ ? "update-from-yml" : () } @calls;
    my $same = -s $list ? ( ( conda_env_fingerprint("eurlc-wgs-t") // "" ) eq explicit_list_fingerprint($list) ? "yes" : "no" ) : "-";
    print join( "\t", $c->[0], $r, join( ",", @did ) || "nothing", $same ), "\n";
}
