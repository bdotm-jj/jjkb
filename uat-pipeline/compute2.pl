use strict; use warnings; use JSON::PP;
open my $fh,"<","cathy_clean.tsv" or die $!; my $h=<$fh>; my @R;
while(<$fh>){ chomp; my($sd,$proj,$dur,$round,$sec)=split/\t/; push @R,{sd=>$sd,proj=>$proj,dur=>($dur ne ''?$dur+0:undef),round=>$round}; }
sub period {
  my ($start,$end)=@_;
  my %bp;
  for my $r (@R){ next unless $r->{sd} && $r->{sd} ge $start && $r->{sd} le $end && defined $r->{dur};
    push @{$bp{$r->{proj}}}, $r; }
  my @projects; my (@r1,@r2,@r3);
  for my $p (sort keys %bp){
    my @rs = sort { $a->{sd} cmp $b->{sd} } @{$bp{$p}};
    my $tot=0; $tot+=$_->{dur} for @rs;
    push @projects, { name=>$p, rounds=>[map {$_->{dur}} @rs], total=>$tot, firstsd=>$rs[0]{sd} };
    push @r1,$rs[0]{dur} if @rs>=1; push @r2,$rs[1]{dur} if @rs>=2; push @r3,$rs[2]{dur} if @rs>=3;
  }
  @projects = sort { $a->{firstsd} cmp $b->{firstsd} } @projects;
  my $av=sub{ my $a=shift; return 0 unless @$a; my $s=0;$s+=$_ for @$a; $s/@$a };
  my $sumtot=0; $sumtot+=$_->{total} for @projects;
  my $np=scalar(@projects); my $nt=0; $nt+=scalar(@{$_->{rounds}}) for @projects;
  my ($long)= sort { $b->{total}<=>$a->{total} } @projects;
  my $a1=$av->(\@r1); my $a2=$av->(\@r2); my $a3=$av->(\@r3);
  return { projects=>\@projects, nproj=>$np, ntasks=>$nt,
    avgTotal=>($np?$sumtot/$np:0), avgR1=>$a1,avgR2=>$a2,avgR3=>$a3,
    nR1=>scalar(@r1),nR2=>scalar(@r2),nR3=>scalar(@r3),
    r1r2=>($a1?($a2-$a1)/$a1*100:0),
    longest=>($long?{name=>$long->{name},total=>$long->{total}}:undef) };
}
my $base = period('2025-11-01','2026-03-31');
my @MONTHS=(['April','2026-04-30'],['May','2026-05-31'],['June','2026-06-30'],['July','2026-07-31'],['August','2026-08-31'],['September','2026-09-30']);
my %series; for my $m (@MONTHS){
  my $mend=$m->[1];
  my $s = period('2026-04-08',$mend);
  # Quarter-over-quarter within the current period: rounds grouped by the quarter
  # their START date falls in (a project spanning both quarters is regrouped
  # independently in each). Q2 = Apr 8 - Jun 30, Q3 = Jul 1 - month-end.
  $s->{q2} = period('2026-04-08', ($mend lt '2026-06-30' ? $mend : '2026-06-30'));
  $s->{q3} = ($mend ge '2026-07-01') ? period('2026-07-01', $mend) : undef;
  $series{$m->[0]} = $s;
}
my %OUT=(baseline=>$base, months=>\%series, order=>[map {$_->[0]} @MONTHS]);
open my $o,">","cathy_series.json"; print $o JSON::PP->new->canonical->pretty->encode(\%OUT); close $o;
# print table
printf "BASELINE (Nov'25-Mar'26): proj=%d tasks=%d avgTot=%.2fd R1=%.2f R2=%.2f R3=%.2f R1->R2=%.1f%% longest=%s %dd\n\n",
  $base->{nproj},$base->{ntasks},$base->{avgTotal},$base->{avgR1},$base->{avgR2},$base->{avgR3},$base->{r1r2},$base->{longest}{name},$base->{longest}{total};
printf "%-10s %5s %5s %8s %7s %7s %7s %9s  %s\n","MONTH","proj","task","avgTot","R1","R2","R3","R1->R2","longest";
for my $m (@{$OUT{order}}){ my $s=$series{$m};
  printf "%-10s %5d %5d %7.2fd %6.2f %6.2f %6.2f %8.1f%%  %s %dd\n",
   "$m",$s->{nproj},$s->{ntasks},$s->{avgTotal},$s->{avgR1},$s->{avgR2},$s->{avgR3},$s->{r1r2},$s->{longest}{name},$s->{longest}{total}; }
