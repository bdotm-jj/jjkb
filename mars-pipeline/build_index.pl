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

# ---- discover monthly roll-up reports (mars-monthly-YYYY-MM.html) ----
my @MON = qw(January February March April May June July August September October November December);
my $outdir = dirname($out);
my @months;
for my $f (sort { $b cmp $a } glob("$outdir/mars-monthly-*.html")) {  # newest first
  my ($ym) = basename($f) =~ /mars-monthly-(\d{4}-\d{2})\.html/; next unless $ym;
  my ($y,$m) = split /-/, $ym;
  my $label = $MON[$m-1]." ".$y;
  # enrich from the archived monthly data if present
  my $sub = "Full-month roll-up &mdash; hours, tickets &amp; closes";
  my $dj = "$base/monthly/data-$ym.json";
  if (-e $dj) {
    local $/; open my $mf, "<:raw", $dj; my $MD = JSON::PP->new->decode(<$mf>);
    my $ppl = scalar(@{$MD->{mtd}{rows} || []});
    my $cl = 0; $cl += ($_->[2]//0) for @{$MD->{devCloses}{rows} || []};
    $sub = "$ppl developers &middot; $cl dev closes" if $ppl;
  }
  push @months, { file => basename($f), label => $label, sub => $sub };
}

open my $tp, "<:raw", "$base/index_template.html" or die "index_template: $!";
my $tpl = <$tp>;
my $tj = JSON::PP->new->utf8->canonical->encode($T); $tj =~ s/</\\u003c/g;
my $mj = JSON::PP->new->utf8->canonical->encode(\@months); $mj =~ s/</\\u003c/g;
$tpl =~ s/__TRENDS__/$tj/;
$tpl =~ s/__MONTHS__/$mj/;

open my $o, ">:raw", $out or die "out: $!"; print $o $tpl; close $o;
print "wrote $out (".( -s $out )." bytes) — ".scalar(@$T)." week(s), ".scalar(@months)." month(s)\n";
