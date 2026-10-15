use strict; use warnings; use utf8; binmode STDOUT,":encoding(UTF-8)";
use JSON::PP; use File::Basename; my $base=dirname($0);
# build_manual.pl <LOB name> <sprints.tsv> <out.json>
# For LOBs sourced by hand (email / Confluence / one-off workbook) rather than a repeatable xlsx.
# TSV columns (tab-separated, '#'-comment lines skipped):
#   n  startDate  endDate  committed  completed  pct  note
# pct is the LOB's PUBLISHED completion % (0..1), taken verbatim. startDate/endDate/note optional.
my ($lob,$tsv,$out)=@ARGV;
die "usage: build_manual.pl <LOB> <sprints.tsv> <out.json>\n" unless $lob && $tsv && $out;
open my $f,"<:encoding(UTF-8)",$tsv or die "$tsv: $!";
my @sprints;
while(<$f>){ chomp; next if /^\s*#/ || /^\s*$/;
  my ($n,$start,$end,$committed,$completed,$pct,$note)=split /\t/, $_, 7;
  $_//='' for ($start,$end,$note); s/^\s+|\s+$//g for ($start,$end,$note);
  push @sprints, {
    n         => $n+0,
    label     => "Sprint $n",
    pct       => (defined $pct && $pct ne "" ? $pct+0 : undef),
    committed => ($committed ne "" ? $committed+0 : 0),
    closed    => ($completed ne "" ? $completed+0 : 0),
    ($start ne "" ? (startDate=>$start) : ()),
    ($end   ne "" ? (endDate=>$end)     : ()),
    pctSource => "stored",
    ($note ne "" ? (note=>$note) : ()),
  };
}
@sprints = sort { $a->{n} <=> $b->{n} } @sprints;
my %OUT=( lob=>$lob, goal=>0.80, sprints=>\@sprints,
          generated=>do{ my $g=`date +%Y-%m-%d`; chomp $g; $g||'2026-10-15' } );
open my $o,">:encoding(UTF-8)",$out or die "$out: $!";
print $o JSON::PP->new->canonical->pretty->encode(\%OUT); close $o;
printf "%s: %d sprints -> %s\n", $lob, scalar(@sprints), $out;
for my $s (@sprints){ printf "  %-10s pct=%-6s committed=%-4s closed=%-4s%s\n",
  $s->{label}, (defined $s->{pct}?sprintf("%.0f%%",$s->{pct}*100):"n/a"), $s->{committed}, $s->{closed},
  ($s->{note}?"  (note)":""); }
