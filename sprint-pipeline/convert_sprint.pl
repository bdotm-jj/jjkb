use strict; use warnings; use utf8; binmode STDOUT,":encoding(UTF-8)";
use JSON::PP;
# convert_sprint.pl <unzip_dir> <LOB name> <out.json>
# Turns ONE unzipped sprint workbook (one LOB) into a per-LOB JSON of sprint summaries.
# Each "Sprint N" sheet is a ticket list + a stored "Total Tickets Committed" / "Sprint Completion %".
# Robust to column drift: status column + committed/pct are found by content/label, not fixed position.
my ($dir,$lob,$out,$mode)=@ARGV;
die "usage: convert_sprint.pl <unzip_dir> <LOB> <out.json> [compute]\n" unless $dir && $lob && $out;
# $mode eq "compute": where a sprint has no STORED completion %, compute it from statuses using the
# documented methodology  (Done + Awaiting-Publish-to-Live) / (total - Pending-3rd - Waiting-for-customer).
# This reproduces Commercial Lines' own stored "% Complete" exactly. Leave off for Stabilization (its stored
# numerator is hand-keyed and not reconstructable from statuses) so its missing sprint stays a gap.
my $COMPUTE = ($mode||"") =~ /compute/i;

# shared strings
my @ss; { local $/; open my $f,"<:encoding(UTF-8)","$dir/xl/sharedStrings.xml" or die "sharedStrings: $!";
  my $x=<$f>; while($x=~/<si>(.*?)<\/si>/gs){ my $si=$1; my $t=""; $t.=$1 while $si=~/<t[^>]*>(.*?)<\/t>/gs;
  $t=~s/&amp;/&/g;$t=~s/&lt;/</g;$t=~s/&gt;/>/g;$t=~s/&#10;/ /g; push @ss,$t; } }
my %rel; { local $/; open my $f,"<","$dir/xl/_rels/workbook.xml.rels" or die $!; my $x=<$f>;
  while($x=~/Id="(rId\d+)"[^>]*Target="([^"]*)"/g){ $rel{$1}=$2; } }
my (@order,%sheet); { local $/; open my $f,"<:encoding(UTF-8)","$dir/xl/workbook.xml" or die $!; my $x=<$f>;
  while($x=~/<sheet[^>]*name="([^"]*)"[^>]*r:id="(rId\d+)"/g){ push @order,$1; $sheet{$1}=$rel{$2}; } }
sub colnum { my $c=shift; my $n=0; $n=$n*26+(ord($_)-64) for split //,$c; $n }
# statuses that mean "closed / shipped"
my @CLOSED=("Done","Closed","Resolved");
my %isClosed=map{lc($_)=>1}@CLOSED;
# for the computed-% fallback: "Awaiting Publish to Live" counts as complete (per CL's note); the
# denominator drops work blocked outside the team (pending 3rd party / waiting on the customer).
sub isCompleteExtra { my $s=lc shift; $s=~/awaiting.*publish.*to.*live/ }   # beyond Done/Closed/Resolved
sub isExcluded      { my $s=lc shift; $s=~/pending\s*3rd\s*party/ || $s=~/waiting\s*for\s*customer/ }
my @KNOWN=("Done","In Progress","Ready","Backlog","Acceptance Testing","Alpha Testing",
  "Pending 3rd Party","Waiting for customer","Awaiting Publish to Test","Awaiting Publish To Dev",
  "Awaiting Publish to Live","Code Review","To Do","Closed","Resolved");
my %known=map{lc($_)=>1}@KNOWN;

my @sprints;
for my $sname (@order){
  next unless $sname=~/(?:^|\s)Sprint\s+(\d+)\s*$/i; my $num=$1;  # matches "Sprint 19" and "CL Sprint 47"
  my $tgt=$sheet{$sname}; local $/; open my $f,"<:encoding(UTF-8)","$dir/xl/$tgt" or next; my $x=<$f>;
  my %cell;
  while($x=~/<c r="([A-Z]+)(\d+)"([^>]*)>(.*?)<\/c>/gs){
    my($col,$r,$attr,$inner)=($1,$2,$3,$4);
    my $v=""; if($inner=~/<v>(.*?)<\/v>/s){ $v=$1; } if($attr=~/t="s"/){ $v=$ss[$v]//""; }
    elsif($inner=~/<is>.*?<t[^>]*>(.*?)<\/t>/s){ $v=$1; }
    $cell{$r}{$col}=$v;
  }
  # ticket key column = col with the most PREFIX-#### values
  my %keyvote; for my $r (keys %cell){ for my $c (keys %{$cell{$r}}){ $keyvote{$c}++ if ($cell{$r}{$c}//"")=~/^[A-Z]+-\d+$/; } }
  my ($keyCol)=sort {($keyvote{$b}||0)<=>($keyvote{$a}||0)} keys %keyvote;
  my $committedTickets=$keyCol?$keyvote{$keyCol}:0;
  # status column: header matches /status/i, else the column with the most known-status values
  my $statusCol; for my $c (keys %{$cell{1}||{}}){ $statusCol=$c if ($cell{1}{$c}//"")=~/^status$/i; }
  unless($statusCol){ my %v; for my $r (keys %cell){ next if $r==1; for my $c (keys %{$cell{$r}}){ $v{$c}++ if $known{lc($cell{$r}{$c}//"")}; } }
    ($statusCol)=sort {($v{$b}||0)<=>($v{$a}||0)} keys %v; }
  my %statuses; my ($closed,$completeExtra,$excluded)=(0,0,0);
  if($statusCol){ for my $r (sort {$a<=>$b} keys %cell){ next if $r==1; my $st=$cell{$r}{$statusCol}//"";
    next if $st eq "" || $st=~/Total Tickets|Sprint Completion|% Complete/i; $statuses{$st}++;
    $closed++ if $isClosed{lc $st}; $completeExtra++ if isCompleteExtra($st); $excluded++ if isExcluded($st); } }
  # committed + pct via label; value = rightmost numeric cell in the label's row.
  # Two workbook formats are supported:
  #   Stabilization: bottom block "Total Tickets Committed" / "Sprint Completion %"
  #   Commercial Lines: top block "Total tickets:" / "% Complete:" (B6 = completed / (total - pending3rd - waiting),
  #     the SAME in-our-control basis as Stabilization's %). NOT "% Complete (excl. blocked)", which also strips Jira flags.
  my ($committedRaw,$pct);
  sub rowval { my($cellref,$r,$c)=@_; my @n=grep {defined&&/^-?[\d.]+$/} map {$cellref->{$r}{$_}}
    sort {colnum($b)<=>colnum($a)} grep {$_ ne $c} keys %{$cellref->{$r}}; @n?$n[0]+0:undef; }
  for my $r (keys %cell){ for my $c (keys %{$cell{$r}}){ my $lab=$cell{$r}{$c}//"";
    if($lab=~/Total Tickets Committed/i || $lab=~/^\s*Total tickets:?\s*$/i){ my $v=rowval(\%cell,$r,$c); $committedRaw=$v if defined $v; }
    if($lab=~/Sprint Completion/i || ($lab=~/^\s*%\s*Complete\s*:?\s*$/i && $lab!~/excl/i)){ my $v=rowval(\%cell,$r,$c); $pct=$v if defined $v; }
  }}
  # computed-% fallback (only when enabled and no stored %): documented in-our-control methodology
  my $pctComputed;
  if(!defined $pct && $COMPUTE){ my $denom=$committedTickets-$excluded;
    $pctComputed = $denom>0 ? sprintf('%.4f',($closed+$completeExtra)/$denom)+0 : undef; }
  my $pctFinal = defined $pct ? $pct : $pctComputed;
  push @sprints, {
    n            => $num+0,
    label        => "Sprint $num",
    pct          => defined $pctFinal ? $pctFinal+0 : undef,  # completion % (stored, else computed when enabled)
    pctSource    => defined $pct ? "stored" : (defined $pctComputed ? "computed" : "none"),
    committedRaw => defined $committedRaw ? $committedRaw+0 : undef, # as stored (hours in early sprints, tickets later)
    committed    => $committedTickets+0,                # ticket-row count (apples-to-apples)
    closed       => $closed+0,                           # Done/Closed/Resolved count
    statuses     => \%statuses,
  };
}
@sprints = sort { $a->{n} <=> $b->{n} } @sprints;
my %OUT=( lob=>$lob, goal=>0.80, sprints=>\@sprints, generated=>scalar_gen() );
sub scalar_gen { my $g=`date +%Y-%m-%d`; chomp $g; $g || '2026-10-15' }
open my $o,">:encoding(UTF-8)",$out or die "$out: $!";
print $o JSON::PP->new->canonical->pretty->encode(\%OUT); close $o;
printf "%s: %d sprints -> %s\n", $lob, scalar(@sprints), $out;
for my $s (@sprints){ printf "  %-10s pct=%-6s committedTix=%-3d closed=%-3d (rawCommit=%s)\n",
  $s->{label}, (defined $s->{pct}?sprintf("%.0f%%",$s->{pct}*100):"n/a"), $s->{committed}, $s->{closed},
  (defined $s->{committedRaw}?$s->{committedRaw}:"?"); }
