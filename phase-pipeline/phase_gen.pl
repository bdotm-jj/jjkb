use strict; use warnings; use utf8; use JSON::PP;
use File::Basename; my $base=dirname($0);
# phase_gen.pl : phase_data.json + phase_template.html -> ../site/reports/phase-duration-baseline.html
# Duration = active span of child tasks (first child start -> last child end). Grouped into the
# quarter the phase COMPLETED in. Headline = MEDIAN per phase/quarter (robust to long-idle outliers),
# with n + min-max range; n<3 flagged provisional. Recomputed whole each run (no frozen drift).
local $/;
open my $f,"<:encoding(UTF-8)","$base/phase_data.json" or die $!; my $D=JSON::PP->new->decode(<$f>);
my @PHASES=("Intake & Planning","Requirements & Design","Development","Alpha Testing (Dev Testing)","Acceptance Testing (UAT/Pre-Prod)","Release","Stabilization (Hypercare)","Retrospective and Closeout");
my @Q=("Q1","Q2","Q3");
sub median { my @v=sort {$a<=>$b} @_; my $n=@v; return undef unless $n; return $n%2? $v[($n-1)/2]+0 : ($v[$n/2-1]+$v[$n/2])/2; }
my %g; for my $r (@$D){ push @{$g{$r->{phase}}{$r->{quarter}}}, $r; }
my %table;
for my $p (@PHASES){ for my $q (@Q){
  my $rows=$g{$p}{$q}||[]; my @days=sort{$a<=>$b} map {$_->{activeDays}} @$rows; my $n=@days;
  $table{$p}{$q}= $n ? { median=>0+sprintf('%.0f',median(@days)), n=>$n+0, min=>$days[0]+0, max=>$days[-1]+0 }
                     : { median=>undef, n=>0, min=>undef, max=>undef };
}}
my %quarters;
for my $q (@Q){ my %pj; my @all; for my $r (@$D){ next unless $r->{quarter} eq $q; $pj{$r->{project}}=1; push @all,$r->{activeDays}; }
  $quarters{$q}={ projects=>scalar(keys %pj)+0, completions=>scalar(@all)+0, median=>0+sprintf('%.0f',median(@all)//0) }; }
# ---- project classification (from the Projects Intake Sheet; see project_classifications.json) ----
open my $cf,"<:encoding(UTF-8)","$base/project_classifications.json" or die "classifications: $!";
my $CLS=JSON::PP->new->decode(<$cf>); delete $CLS->{_source};
for my $r (@$D){ $r->{classification} = $CLS->{$r->{project}} // "Unclassified"; }
my %bc;
for my $r (@$D){ my $c=$r->{classification};
  push @{$bc{$c}{all}}, $r->{activeDays}; $bc{$c}{proj}{$r->{project}}=1; push @{$bc{$c}{ph}{$r->{phase}}}, $r->{activeDays}; }
# per-PROJECT duration = first phase start -> last phase end (of its completed phases), inclusive days.
# Answers "how long does a project of this type run", vs a pooled-phase median. Median across projects
# absorbs idle-gap outliers. Needs a civil-date -> day-number helper.
sub ymd2n { my $s=shift//''; return undef unless $s=~/^(\d{4})-(\d{2})-(\d{2})$/;
  my($y,$m,$d)=($1+0,$2+0,$3+0); $y-=($m<=2?1:0); my $era=int(($y>=0?$y:$y-399)/400); my $yoe=$y-$era*400;
  my $doy=int((153*($m+($m>2?-3:9))+2)/5)+$d-1; my $doe=$yoe*365+int($yoe/4)-int($yoe/100)+$doy; return $era*146097+$doe-719468; }
my %pinfo;
for my $r (@$D){ my $s=ymd2n($r->{activeStart}); my $e=ymd2n($r->{activeEnd}); next unless defined $s && defined $e;
  my $p=$r->{project}; $pinfo{$p}{class}=$r->{classification};
  $pinfo{$p}{min}=$s if !defined $pinfo{$p}{min} || $s<$pinfo{$p}{min};
  $pinfo{$p}{max}=$e if !defined $pinfo{$p}{max} || $e>$pinfo{$p}{max}; }
my %classSpans; for my $p (keys %pinfo){ push @{$classSpans{$pinfo{$p}{class}}}, $pinfo{$p}{max}-$pinfo{$p}{min}+1; }
my @byClass;
for my $c (sort { scalar(keys %{$bc{$b}{proj}}) <=> scalar(keys %{$bc{$a}{proj}}) || $a cmp $b } keys %bc){
  my $o=$bc{$c}; my %phmed;
  for my $p (@PHASES){ my $arr=$o->{ph}{$p}; $phmed{$p}= ($arr&&@$arr) ? {median=>0+sprintf('%.0f',median(@$arr)), n=>scalar(@$arr)+0} : undef; }
  my $sp=$classSpans{$c}||[];
  push @byClass, { classification=>$c, projects=>scalar(keys %{$o->{proj}})+0, completions=>scalar(@{$o->{all}})+0,
    projMedian=>(@$sp? 0+sprintf('%.0f',median(@$sp)) : undef), byPhase=>\%phmed };
}
# outliers (active >= 90d)
my @outliers;
for my $r (sort { $b->{activeDays} <=> $a->{activeDays} } @$D){ next unless $r->{activeDays}>=90;
  push @outliers, sprintf(qq{<b>%s</b> \x{2014} %s (%s): <b>%dd</b> <span class="proj">(%s \x{2192} %s)</span>},
    $r->{project}, phaseShort($r->{phase}), $r->{quarter}, $r->{activeDays}, $r->{activeStart}, $r->{activeEnd}); }
# data-quality: header-inflation + known structural issues
my @dq;
for my $r (sort { ($b->{headerDays}-$b->{activeDays}) <=> ($a->{headerDays}-$a->{activeDays}) } @$D){
  next unless $r->{headerDays}>=$r->{activeDays}*2 && $r->{headerDays}>=30;
  push @dq, sprintf(qq{<b>Header-span inflation \x{2014} %s / %s:</b> the phase header spans %dd but active child work was only %dd. The old header-span method would have reported %dd; the active span (%dd) is used here.},
    $r->{project}, phaseShort($r->{phase}), $r->{headerDays}, $r->{activeDays}, $r->{headerDays}, $r->{activeDays}); }
push @dq, qq{Two projects are not standard phase plans and were excluded: <b>Indexing Automation</b> uses a different template (Design/Build/Beta/Production, no Level/Start/End columns), and <b>Casper Cyber Program</b> has malformed WBS levels (phase headers tagged Level 1 with blank Phase cells) \x{2014} its three qualifying phases were recovered by matching the task name.};
push @dq, qq{A handful of phase headers carry an end date but no dated child tasks; those fall back to the header\x{2019}s own start/end. Two end-date-only headers (API Service Acceptance &amp; Retrospective) were non-computable and skipped.};

sub phaseShort { my $p=shift; my %s=("Intake & Planning","Intake & Planning","Requirements & Design","Requirements & Design","Development","Development","Alpha Testing (Dev Testing)","Alpha Testing","Acceptance Testing (UAT/Pre-Prod)","Acceptance Testing (UAT)","Release","Release","Stabilization (Hypercare)","Stabilization","Retrospective and Closeout","Retrospective"); return $s{$p}//$p; }

my $gen=`date +%Y-%m-%d`; chomp $gen; $gen ||= '2026-10-08';
my %OUT=( phases=>\@PHASES, table=>\%table, quarters=>\%quarters, byClass=>\@byClass, outliers=>\@outliers, dq=>\@dq, generated=>$gen );
open my $tp,"<:encoding(UTF-8)","$base/phase_template.html" or die $!; my $tpl=<$tp>;
my $dj=JSON::PP->new->canonical->encode(\%OUT); # chars; template file written/read as UTF-8
$dj=~s/</\\u003c/g;
$tpl=~s/__DATA__/$dj/;
open my $o,">:encoding(UTF-8)","$base/../site/reports/phase-duration-baseline.html" or die $!; print $o $tpl; close $o;
print "wrote ../site/reports/phase-duration-baseline.html\n";
printf "quarters: Q1 %dproj/%dcomp/med %dd | Q2 %d/%d/%d | Q3 %d/%d/%d\n",
  (map {$quarters{$_}{projects},$quarters{$_}{completions},$quarters{$_}{median}} @Q);
print "outliers=".scalar(@outliers)." dq=".scalar(@dq)."\n";
