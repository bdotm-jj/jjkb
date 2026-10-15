use strict; use warnings; use utf8; binmode STDOUT,":encoding(UTF-8)";
use JSON::PP; use File::Basename; my $base=dirname($0);
# build_pl.pl : pl_sprints.tsv -> lobs/data-personal-lines.json
# Personal Lines (PL Pod) is EMAIL-sourced (Abdoul Balla's "PL - Sprint NN Final Report" emails),
# not a spreadsheet, so its figures are transcribed into pl_sprints.tsv and assembled here.
my $tsv="$base/pl_sprints.tsv"; my $out="$base/lobs/data-personal-lines.json";
open my $f,"<:encoding(UTF-8)",$tsv or die "$tsv: $!";
my @sprints;
while(<$f>){ chomp; next if /^\s*#/ || /^\s*$/;
  my ($n,$start,$end,$committed,$completed,$pct,$note)=split /\t/, $_, 7;
  $note="" unless defined $note; $note=~s/^\s+|\s+$//g;
  push @sprints, {
    n         => $n+0,
    label     => "Sprint $n",
    pct       => ($pct ne "" ? $pct+0 : undef),  # published Completion % (completed / committed), verbatim
    committed => $committed+0,                    # tickets committed at sprint start
    closed    => $completed+0,                    # PL's "Tickets completed" count (their throughput)
    startDate => $start, endDate => $end,
    pctSource => "stored",
    ($note ne "" ? (note=>$note) : ()),
  };
}
@sprints = sort { $a->{n} <=> $b->{n} } @sprints;
my %OUT=( lob=>"Personal Lines", goal=>0.80, sprints=>\@sprints,
          generated=>do{ my $g=`date +%Y-%m-%d`; chomp $g; $g||'2026-10-15' } );
open my $o,">:encoding(UTF-8)",$out or die "$out: $!";
print $o JSON::PP->new->canonical->pretty->encode(\%OUT); close $o;
printf "Personal Lines: %d sprints -> %s\n", scalar(@sprints), $out;
for my $s (@sprints){ printf "  %-10s pct=%-6s committed=%-3d completed=%-3d%s\n",
  $s->{label}, (defined $s->{pct}?sprintf("%.0f%%",$s->{pct}*100):"n/a"), $s->{committed}, $s->{closed},
  ($s->{note}?"  (note)":""); }
