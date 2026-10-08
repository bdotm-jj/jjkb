use strict; use warnings; use utf8; use JSON::PP;
binmode(STDOUT,":encoding(UTF-8)");
local $/; open my $f,"<:encoding(UTF-8)","phase_data.json" or die $!; my $D=JSON::PP->new->decode(<$f>);
my @PHASES=("Intake & Planning","Requirements & Design","Development","Alpha Testing (Dev Testing)","Acceptance Testing (UAT/Pre-Prod)","Release","Stabilization (Hypercare)","Retrospective and Closeout");
my @Q=("Q1","Q2","Q3");
my %g; # phase -> quarter -> [ {proj,days,hdr,start,end} ]
for my $r (@$D){ push @{$g{$r->{phase}}{$r->{quarter}}}, $r; }
sub median { my @v=sort {$a<=>$b} @_; my $n=@v; return undef unless $n; return $n%2? $v[($n-1)/2] : ($v[$n/2-1]+$v[$n/2])/2; }
sub mean { my $s=0;$s+=$_ for @_; return @_? $s/@_:0; }
my %OUT; my @outliers; my @headerInflate;
printf "%-34s %-16s %-16s %-16s\n","PHASE","Q1 (n)","Q2 (n)","Q3 (n)";
for my $p (@PHASES){
  my %row;
  for my $q (@Q){
    my $rows=$g{$p}{$q}||[];
    my @days=map {$_->{activeDays}} @$rows;
    my $med=median(@days); my $n=scalar(@days);
    my ($mn,$mx)=$n?((sort{$a<=>$b}@days)[0],(sort{$a<=>$b}@days)[-1]):(undef,undef);
    $row{$q}={ median=>(defined $med?0+sprintf('%.0f',$med):undef), n=>$n, min=>$mn, max=>$mx,
      projects=>[ map { {name=>$_->{project}, days=>$_->{activeDays}} } sort {$b->{activeDays}<=>$a->{activeDays}} @$rows ] };
    # collect outliers (>=90d active) and header-inflation (header much > active)
    for my $x (@$rows){ push @outliers, "$x->{project} / $p ($q): ".$x->{activeDays}."d (".$x->{activeStart}." to ".$x->{activeEnd}.")" if $x->{activeDays}>=90;
      push @headerInflate, "$x->{project} / $p: header ".$x->{headerDays}."d vs active ".$x->{activeDays}."d" if $x->{headerDays}>=$x->{activeDays}*2 && $x->{headerDays}>=30; }
  }
  $OUT{$p}=\%row;
  printf "%-34s %-16s %-16s %-16s\n",$p,
    (defined $row{Q1}{median}?"$row{Q1}{median}d (n$row{Q1}{n}, $row{Q1}{min}-$row{Q1}{max})":"— (n0)"),
    (defined $row{Q2}{median}?"$row{Q2}{median}d (n$row{Q2}{n}, $row{Q2}{min}-$row{Q2}{max})":"— (n0)"),
    (defined $row{Q3}{median}?"$row{Q3}{median}d (n$row{Q3}{n}, $row{Q3}{min}-$row{Q3}{max})":"— (n0)");
}
# quarter rollups: distinct projects + total phase-completions + overall median across all phases
print "\n";
for my $q (@Q){
  my (%proj,@all);
  for my $r (@$D){ next unless $r->{quarter} eq $q; $proj{$r->{project}}=1; push @all,$r->{activeDays}; }
  printf "%s: %d projects, %d phase-completions, overall median %.0fd\n",$q,scalar(keys %proj),scalar(@all),median(@all)//0;
}
print "\n=== LONG-RUNNING OUTLIERS (active >= 90d) ===\n"; print "  $_\n" for @outliers;
print "\n=== HEADER-SPAN INFLATED (header >= 2x active) ===\n"; print "  $_\n" for @headerInflate;
open my $o,">:encoding(UTF-8)","phase_series.json"; print $o JSON::PP->new->canonical->pretty->encode({phases=>\@PHASES, data=>\%OUT}); close $o;
print "\nwrote phase_series.json\n";
