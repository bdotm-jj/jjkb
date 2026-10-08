use strict; use warnings; use utf8; use JSON::PP;
use File::Basename; my $base=dirname($0);
# cathy_gen.pl : reads cathy_series.json -> writes ../site/reports/<month>-2026.html for each month
# Convention: current period = testing started on/after Apr 8 2026, cumulative through month-end,
# compared to the fixed Nov 2025 - Mar 2026 baseline. KB-styled 5-slide deck.
local $/;
open my $sf,"<:raw","$base/cathy_series.json" or die $!; my $S=JSON::PP->new->decode(<$sf>);
open my $tf,"<:raw","$base/cathy_template.html" or die $!; my $TPL=<$tf>;
my $B=$S->{baseline};
my %MEND=(April=>['Apr 30','Apr'],May=>['May 31','Apr–May'],June=>['Jun 30','Apr–Jun'],
  July=>['Jul 31','Apr–Jul'],August=>['Aug 31','Apr–Aug'],September=>['Sep 30','Apr–Sep']);
sub d1 { sprintf('%.1f',$_[0]) }
sub pct { my ($cur,$b)=@_; return 0 if !$b; ($cur-$b)/$b*100 }
sub deltaCell { # for durations: lower is better (down=ok)
  my ($cur,$b,$unit)=@_; my $p=pct($cur,$b); my $dir= abs($p)<0.5?'flat':($p>0?'up':'down');
  my $arrow= $p>0?'▲':($p<0?'▼':'—'); return { base=>d1($b).$unit, cur=>d1($cur).$unit,
    delta=>sprintf('%s %.1f%%',$arrow,abs($p)), dir=>$dir }; }
sub qoqPctDelta { # duration-style % delta, lower=better(down=ok)
  my ($cur,$b)=@_; return {delta=>'—',dir=>'flat'} if !$b;
  my $p=pct($cur,$b); my $dir= abs($p)<0.5?'flat':($p>0?'up':'down');
  return { delta=>sprintf('%s %.0f%%',($p>0?'▲':($p<0?'▼':'—')),abs($p)), dir=>$dir }; }

for my $m (@{$S->{order}}){
  my $M=$S->{months}{$m}; my ($mend,$short)=@{$MEND{$m}};
  my @proj = @{$M->{projects}};
  # table + chart
  my (@table,@labels,@totals);
  for my $p (@proj){
    my @r=@{$p->{rounds}};
    push @table, { name=>$p->{name}, r1=>(defined $r[0]?$r[0]:undef), r2=>(defined $r[1]?$r[1]:undef),
      r3=>(defined $r[2]?$r[2]:undef), total=>$p->{total} };
    push @labels, $p->{name}; push @totals, $p->{total}+0;
  }
  # baseline comparison rows
  my $redDelta = sprintf('%.1f pp', abs($M->{r1r2}-$B->{r1r2}));
  my $redDir = ($M->{r1r2} < $B->{r1r2}) ? 'down' : (($M->{r1r2}>$B->{r1r2})?'up':'flat'); # more negative = better = down/ok
  my @btable = (
    { metric=>'Avg Total Duration / Project', %{ deltaCell($M->{avgTotal},$B->{avgTotal},'d') } },
    { metric=>'Avg R1 Duration', %{ deltaCell($M->{avgR1},$B->{avgR1},'d') } },
    { metric=>'Avg R2 Duration', %{ deltaCell($M->{avgR2},$B->{avgR2},'d') } },
    { metric=>'R1→R2 Reduction', base=>sprintf('%.1f%%',$B->{r1r2}), cur=>sprintf('%.1f%%',$M->{r1r2}),
      delta=>($M->{r1r2}<$B->{r1r2}?'▼ ':'▲ ').$redDelta.($M->{r1r2}<$B->{r1r2}?' (steeper)':' (softer)'), dir=>$redDir },
    { metric=>'Projects Tested', base=>$B->{nproj}, cur=>$M->{nproj},
      delta=>sprintf('%+d', $M->{nproj}-$B->{nproj}), dir=>'flat' },
  );
  # callouts
  my $pt=pct($M->{avgTotal},$B->{avgTotal});
  my $finding= sprintf('Across %d project%s (%d testing round%s), average total duration is %sd — %s%.0f%% versus the Nov–Mar baseline of %sd.',
    $M->{nproj},($M->{nproj}==1?'':'s'),$M->{ntasks},($M->{ntasks}==1?'':'s'),d1($M->{avgTotal}),
    ($pt>0?'up ':'down '),abs($pt),d1($B->{avgTotal}));
  my $outlier= sprintf('%s is the longest engagement at %dd total — %.1f× the current-period average (%sd/project).',
    $M->{longest}{name},$M->{longest}{total}, ($M->{avgTotal}?$M->{longest}{total}/$M->{avgTotal}:0), d1($M->{avgTotal}));
  my $p1=pct($M->{avgR1},$B->{avgR1});
  my $watch= sprintf('Avg R1 duration is %sd (%s%.0f%% vs baseline %sd); retests (R2) average %sd. %s',
    d1($M->{avgR1}),($p1>0?'up ':'down '),abs($p1),d1($B->{avgR1}),d1($M->{avgR2}),
    ($M->{nR2}<$M->{nproj} ? sprintf('%d of %d projects have no completed retest yet, so totals may still grow.',$M->{nproj}-$M->{nR2},$M->{nproj}) : 'Most projects have reached a second round.'));
  # findings
  my @findings=(
    sprintf('<b>Testing volume:</b> %d project%s completed %d testing round%s in the current period (started on/after Apr 8, 2026).',$M->{nproj},($M->{nproj}==1?'':'s'),$M->{ntasks},($M->{ntasks}==1?'':'s')),
    sprintf('<b>Average duration %s %.0f%% vs baseline:</b> %sd per project now versus %sd in the Nov 2025–Mar 2026 baseline.',($pt>0?'up':'down'),abs($pt),d1($M->{avgTotal}),d1($B->{avgTotal})),
    sprintf('<b>First-round testing %s %.0f%%:</b> avg R1 is %sd (baseline %sd)%s.',($p1>0?'up':'down'),abs($p1),d1($M->{avgR1}),d1($B->{avgR1}),($M->{longest}{total}>=15?', pulled up by '.$M->{longest}{name}:'')),
    sprintf('<b>Retest efficiency:</b> the R1→R2 reduction is %.1f%% (baseline −42.9%%) — second rounds run %s relative to first rounds than at baseline.',$M->{r1r2},($M->{r1r2}<$B->{r1r2}?'proportionally shorter':'proportionally longer')),
    sprintf('<b>Longest cycle:</b> %s at %dd total%s.',$M->{longest}{name},$M->{longest}{total},($M->{longest}{total}>$B->{longest}{total}?sprintf(' — above the baseline high (%s, %dd)',$B->{longest}{name},$B->{longest}{total}):'')),
  );
  my @recs=(
    ($p1>0 ? sprintf('Review R1 entry criteria for large integrations (e.g. %s) — earlier readiness checks may shorten first-round durations.',$M->{longest}{name})
           : 'Maintain the current R1 readiness practices — first-round durations are holding at or below baseline.'),
    'Track the R1→R2 reduction as the primary throughput metric — it is the most responsive indicator of retest efficiency.',
    ($M->{nR2}<$M->{nproj} ? sprintf('Confirm retest plans for the %d project%s still showing only a first round; their totals are likely understated.',$M->{nproj}-$M->{nR2},($M->{nproj}-$M->{nR2}==1?'':'s'))
                           : 'Revisit next month once additional rounds are logged to keep the trend based on complete cycles.'),
  );
  # Quarter-over-quarter (shown once Q3 has data — July onward)
  my $qoq = undef;
  if (defined $M->{q3} && $M->{q3}{nproj} > 0) {
    my $q2=$M->{q2}; my $q3=$M->{q3};
    my $ppd = $q3->{r1r2}-$q2->{r1r2}; # reduction: more negative = better
    my $ppdir = abs($ppd)<0.5?'flat':($ppd<0?'down':'up');
    my @qr = (
      { metric=>'Avg Total Duration / Project', q2=>d1($q2->{avgTotal}).'d', q3=>d1($q3->{avgTotal}).'d', %{ qoqPctDelta($q3->{avgTotal},$q2->{avgTotal}) } },
      { metric=>'Avg R1 Duration', q2=>d1($q2->{avgR1}).'d', q3=>d1($q3->{avgR1}).'d', %{ qoqPctDelta($q3->{avgR1},$q2->{avgR1}) } },
      { metric=>'Avg R2 Duration', q2=>d1($q2->{avgR2}).'d', q3=>d1($q3->{avgR2}).'d', %{ qoqPctDelta($q3->{avgR2},$q2->{avgR2}) } },
      { metric=>'R2 Duration vs R1 (% shorter)', q2=>sprintf('%.1f%%',$q2->{r1r2}), q3=>sprintf('%.1f%%',$q3->{r1r2}),
        delta=>sprintf('%s %.1f pp',($ppd<0?'▼':'▲'),abs($ppd)), dir=>$ppdir },
      { metric=>'Projects Tested', q2=>$q2->{nproj}+0, q3=>$q3->{nproj}+0, delta=>sprintf('%+d',$q3->{nproj}-$q2->{nproj}), dir=>'flat' },
    );
    my $note = ($q3->{nR2}<=1)
      ? sprintf("Q3\x{2019}s Avg R2 and \x{201c}R2 vs R1\x{201d} rest on %s so far \x{2014} low confidence. Projects spanning both quarters are regrouped independently in each.",
          ($q3->{nR2}==0?'no completed R2 rounds':'a single completed R2 round'))
      : 'Projects spanning both quarters are regrouped independently in each quarter.';
    $qoq = { label=>"Quarter over Quarter \x{2014} Q3 2026 (Jul\x{2013}Sep) vs Q2 2026 (Apr\x{2013}Jun)", rows=>\@qr, note=>$note };
  }
  my %D=(
    month=>$m, year=>'2026', rangeLabel=>"Apr 8 – $mend, 2026", qoq=>$qoq,
    foot=>"Generated from Smartsheet \x{201c}Cathy Parmley Task Report\x{201d} \x{b7} current period = testing started on/after Apr 8, 2026 \x{b7} baseline Nov 2025 \x{2013} Mar 2026",
    cover=>{ projects=>$M->{nproj}+0, tasks=>$M->{ntasks}+0, rangeShort=>$short },
    metrics=>{ avgTotal=>$M->{avgTotal}+0, avgR1=>$M->{avgR1}+0, avgR2=>$M->{avgR2}+0,
      longestName=>$M->{longest}{name}, longestTotal=>$M->{longest}{total}+0 },
    callouts=>{ finding=>$finding, outlier=>$outlier, watch=>$watch },
    baselineLabel=>'Comparison vs Nov 2025 – Mar 2026 Baseline',
    baselineTable=>\@btable,
    chart3=>{ labels=>\@labels, totals=>\@totals },
    chart4=>{ r1=>0+sprintf('%.2f',$M->{avgR1}), r2=>0+sprintf('%.2f',$M->{avgR2}), r3=>0+sprintf('%.2f',$M->{avgR3}) },
    table=>\@table, findings=>\@findings, recs=>\@recs,
  );
  my $dj=JSON::PP->new->utf8->canonical->encode(\%D); $dj=~s/</\\u003c/g;
  my $out=$TPL; $out=~s/__DATA__/$dj/; $out=~s/__MONTH__/$m/g; $out=~s/__YEAR__/2026/g;
  my $lc=lc($m); my $file="$base/../site/reports/$lc-2026.html";
  open my $o,">:raw",$file or die "$file: $!"; print $o $out; close $o;
  printf "wrote %s (%d proj, %.1fd avg) -> %s\n",$m,$M->{nproj},$M->{avgTotal},"$lc-2026.html";
}
print "done.\n";
