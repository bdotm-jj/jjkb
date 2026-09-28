use strict; use warnings;
use JSON::PP;
use File::Basename;
# build_index.pl [out.html]
# Reads trends.json (aggregate per-week summaries) and writes the MARS weekly
# report INDEX / landing page: a sortable table with one row per week, linking
# to that week's full report. Aggregate only — no individual names. Run this
# after every build.pl so the index picks up the new week automatically.
my $out = $ARGV[0] // "../site/reports/mars-weekly.html";
my $base = dirname($0);

local $/;
open my $tf, "<:raw", "$base/trends.json" or die "trends.json: $!";
my $T = JSON::PP->new->decode(<$tf>);
die "trends.json is empty\n" unless @$T;

open my $tp, "<:raw", "$base/index_template.html" or die "index_template: $!";
my $tpl = <$tp>;
my $tj = JSON::PP->new->utf8->canonical->encode($T); $tj =~ s/</\\u003c/g;
$tpl =~ s/__TRENDS__/$tj/;

open my $o, ">:raw", $out or die "out: $!"; print $o $tpl; close $o;
print "wrote $out (".( -s $out )." bytes) — ".scalar(@$T)." week(s)\n";
