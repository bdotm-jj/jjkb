use strict; use warnings;
use JSON::PP;
use File::Basename;
use Time::Local;
# build.pl <week YYYY-MM-DD (Monday)> <label> <data.json> <out.html>
# - computes an aggregate per-week summary from the week's DATA json
# - upserts it into trends.json (keyed by week; sorted oldest->newest)
# - injects DATA + TRENDS into report_template.html -> writes out.html
my ($week,$label,$dataPath,$outHtml)=@ARGV;
die "usage: perl build.pl <week YYYY-MM-DD> <label> <data.json> <out.html>\n" unless $outHtml;
my $base=dirname($0);

local $/;
open my $df,"<:raw",$dataPath or die "data: $!"; my $D=JSON::PP->new->utf8->decode(<$df>);
my $H=$D->{weekly}{headers};

sub idx { my $p=shift; for my $i (0..$#$H){ return $i if $H->[$i]=~/$p/i; } return -1; }
sub isnum { my $v=shift; return defined($v) && $v=~/^-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?$/; }
sub tonum { my $v=shift; return isnum($v)? $v+0 : undef; }
sub expwk { my $s=shift//''; return ($1+$2)/2 if $s=~/(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)/; return isnum($s)? $s+0:0; }
sub rgroup { my $r=lc(shift//''); return 'Developer' if $r eq 'developer'; return 'Jr Dev' if $r eq 'jr dev';
  return 'Senior/Staff' if $r=~/senior|staff/; return 'QA' if $r eq 'qa'; return 'Data/Other'; }

my $Iexp=idx('exp'); my $Iwk=idx('wk total'); my $Itix=idx('tickets worked');
my $Ibf=idx('bounce flag'); my $Ilv=idx('low volume'); my $Ilh=idx('low hours'); my $Idc=idx('dev closes');
my @dayCols; for my $i (0..$#$H){ push @dayCols,$i if $H->[$i]=~/^(mon|tue|wed|thu|fri)/i; }

my ($people,$hours,$expected,$tickets,$wcloses)=(0,0,0,0,0);
my @day=(0)x scalar(@dayCols); my ($lhR,$lvR,$bH)=(0,0,0); my %role;
for my $r (@{$D->{weekly}{rows}}){
  $people++;
  my $wk=tonum($r->[$Iwk])//0; $hours+=$wk;
  my $ex=expwk($r->[$Iexp]); $expected+=$ex;
  my $tx=tonum($r->[$Itix])//0; $tickets+=$tx;
  my $dc=tonum($r->[$Idc])//0; $wcloses+=$dc;
  for my $k (0..$#dayCols){ my $v=tonum($r->[$dayCols[$k]]); $day[$k]+=$v if defined $v; }
  $lhR++ if uc($r->[$Ilh]//'') eq 'RED';
  $lvR++ if uc($r->[$Ilv]//'') eq 'RED';
  $bH++  if uc($r->[$Ibf]//'') eq 'HIGH';
  my $g=rgroup($r->[1]); $role{$g}//={count=>0,logged=>0,expected=>0,tickets=>0,closes=>0};
  $role{$g}{count}++; $role{$g}{logged}+=$wk; $role{$g}{expected}+=$ex; $role{$g}{tickets}+=$tx; $role{$g}{closes}+=$dc;
}
# Prefer the sheet's prorated capacity target (holiday/PTO-adjusted) when present,
# so utilisation stays comparable across full and short weeks.
my $mp = $D->{meta} && $D->{meta}{expectedProrated};
my $expectedBasis = 'exp/wk';
if (defined $mp && $mp > 0) { $expected = $mp; $expectedBasis = 'prorated'; }
my $monThu = @dayCols>=5 ? ($day[0]+$day[1]+$day[2]+$day[3])/4 : 0;
my $fri    = @dayCols>=5 ? $day[4] : 0;
my $friDrop= $monThu ? ($monThu-$fri)/$monThu : 0;
my $closesMTD=0; for my $r (@{$D->{devCloses}{rows}}){ $closesMTD += tonum($r->[2])//0; }
# round role aggregates
for my $g (keys %role){ $role{$g}{logged}=0+sprintf('%.1f',$role{$g}{logged}); $role{$g}{expected}=0+sprintf('%.1f',$role{$g}{expected}); }

my $summary={ week=>$week, label=>$label, people=>$people+0,
  teamHours=>0+sprintf('%.2f',$hours), expected=>0+sprintf('%.1f',$expected),
  util=>0+sprintf('%.4f',$expected?$hours/$expected:0), tickets=>$tickets+0, weeklyCloses=>$wcloses+0,
  closesMTD=>$closesMTD+0, avgHours=>0+sprintf('%.2f',$people?$hours/$people:0),
  flags=>{lowHoursRed=>$lhR+0, lowVolRed=>$lvR+0, bounceHigh=>$bH+0},
  friDrop=>0+sprintf('%.4f',$friDrop), expectedBasis=>$expectedBasis, byRole=>\%role };

# upsert into trends.json
my $tf="$base/trends.json"; my @T;
if(-e $tf){ open my $t,"<:raw",$tf; my $c=<$t>; @T=@{JSON::PP->new->decode($c)} if $c && $c=~/\S/; }
@T = grep { ($_->{week}//'') ne $week } @T;
push @T, $summary;
@T = sort { ($a->{week}//'') cmp ($b->{week}//'') } @T;
open my $to,">:raw",$tf; print $to JSON::PP->new->canonical->pretty->encode(\@T); close $to;

# derive the report-window date strings from the week's Monday (+4 = Friday)
my @MON = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my ($wy,$wm,$wd) = $week =~ /(\d+)-(\d+)-(\d+)/;
my $friEpoch = Time::Local::timegm(0,0,12,$wd,$wm-1,$wy) + 4*86400;
my @fr = gmtime($friEpoch);
my ($fMo,$fDd,$fYr) = ($MON[$fr[4]], $fr[3], $fr[5]+1900);
my $titleRange = sprintf('%s %d – %s %d, %d', $MON[$wm-1], $wd+0, $fMo, $fDd, $fYr);
my $weekRange  = sprintf('Mon %s %d – Fri %s %d, %d', $MON[$wm-1], $wd+0, $fMo, $fDd, $fYr);
my $weekIso    = sprintf('%04d.%02d.%02d', $wy, $wm, $wd);

# inject into template
open my $tp,"<:raw","$base/report_template.html" or die "template: $!"; my $tpl=<$tp>;
my $dj=JSON::PP->new->utf8->canonical->encode($D); $dj=~s/</\\u003c/g;
my $tj=JSON::PP->new->utf8->canonical->encode(\@T); $tj=~s/</\\u003c/g;
$tpl=~s/__DATA__/$dj/; $tpl=~s/__TRENDS__/$tj/;
$tpl=~s/__TITLE_RANGE__/$titleRange/g; $tpl=~s/__WEEK_RANGE__/$weekRange/g; $tpl=~s/__WEEK_ISO__/$weekIso/g;
open my $o,">:raw",$outHtml or die "out: $!"; print $o $tpl; close $o;

print "week $week: people=$people hours=".sprintf('%.1f',$hours)." util=".sprintf('%.1f',100*($expected?$hours/$expected:0))."% tickets=$tickets weeklyCloses=$wcloses\n";
print "trends.json now has ".scalar(@T)." week(s)\n";
print "wrote $outHtml (".( -s $outHtml )." bytes)\n";
