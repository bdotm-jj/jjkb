use strict; use warnings;
use JSON::PP;
use File::Basename;
# build_mtd.pl <month label> <range> <workdays> <data.json> <out.html>
#   e.g. perl build_mtd.pl "September 2026" "Sep 1 - 30, 2026" 21 monthly/data-2026-09.json ../site/reports/mars-monthly-2026-09.html
# Produces a self-contained Month-to-Date dashboard from a MARS MTD workbook
# (the "<Month> Month-to-Date" sheet + Dev/QA Closes sheets). AGGREGATE + per
# person for the month; NOT part of the weekly trend series.
my ($month,$range,$workdays,$dataPath,$outHtml)=@ARGV;
die "usage: perl build_mtd.pl <month> <range> <workdays> <data.json> <out.html>\n" unless $outHtml;
my $base=dirname($0);

local $/;
open my $df,"<:raw",$dataPath or die "data: $!"; my $D=JSON::PP->new->utf8->decode(<$df>);

sub isnum { my $v=shift; return defined($v) && $v=~/^-?\d+(?:\.\d+)?$/; }
sub num { my $v=shift; return isnum($v)? $v+0 : 0; }
sub rgroup { my $r=lc(shift//''); return 'Developer' if $r eq 'developer';
  return 'Jr Dev' if $r eq 'jr dev'; return 'Senior/Staff' if $r=~/senior|staff|lead/;
  return 'QA' if $r eq 'qa'; return 'Data/Other'; }

# ----- MTD sheet -----
my $MH=$D->{mtd}{headers};
sub midx { my $p=shift; for my $i (0..$#$MH){ return $i if ($MH->[$i]//'')=~/$p/i; } return -1; }
my $Inm=midx('^name'); my $Iro=midx('^role'); my $Iew=midx('exp/?wk');
my $Iml=midx('mtd logged'); my $Itx=midx('tickets worked'); my $Ibr=midx('bounce rate');
my $Ibf=midx('bounce flag'); my $Ilv=midx('low volume'); my $Ilh=midx('low hours'); my $Idc=midx('dev closes');

my (@people,%role,$logged,$expected,$tickets,$lhR,$lvR,$bH);
for my $r (@{$D->{mtd}{rows}}){
  my $nm=$r->[$Inm]//''; next if $nm eq '';
  my $ro=$r->[$Iro]//''; my $g=rgroup($ro);
  my $lg=num($r->[$Iml]); my $tx=num($r->[$Itx]); my $cl=num($r->[$Idc]);
  my $ew=num($r->[$Iew]); my $exp=sprintf('%.0f', ($ew/5)*$workdays);  # month target = daily goal x workdays
  my $br=$r->[$Ibr]//''; my ($bpn)= $br=~/(\d+(?:\.\d+)?)\s*%/; $bpn//= 0;
  my $lh=uc($r->[$Ilh]//''); my $lv=uc($r->[$Ilv]//''); my $bf=uc($r->[$Ibf]//'');
  $lhR++ if $lh eq 'RED'; $lvR++ if $lv eq 'RED'; $bH++ if $bf eq 'HIGH';
  $logged+=$lg; $expected+=$exp; $tickets+=$tx;
  my $fs = ($lh eq 'RED'?4:0)+($lv eq 'RED'?2:0)+($bf eq 'HIGH'?1:0);
  push @people, { name=>$nm, role=>$ro, group=>$g, logged=>0+sprintf('%.2f',$lg),
    expected=>$exp+0, util=>0+sprintf('%.4f', $exp? $lg/$exp : 0), tickets=>$tx+0,
    bouncePct=>($br ne '' ? $br : '—'), bouncePctNum=>$bpn+0, closes=>$cl+0,
    lowHours=>$lh, lowVol=>$lv, bounce=>$bf, flagScore=>$fs };
  $role{$g}//={role=>$g,count=>0,logged=>0,expected=>0,tickets=>0,closes=>0};
  $role{$g}{count}++; $role{$g}{logged}+=$lg; $role{$g}{expected}+=$exp; $role{$g}{tickets}+=$tx; $role{$g}{closes}+=$cl;
}
my @ROLE_ORDER=('Developer','Jr Dev','Senior/Staff','QA','Data/Other');
my @byRole; for my $g (@ROLE_ORDER){ next unless $role{$g};
  my $x=$role{$g}; push @byRole,{ role=>$g, count=>$x->{count}+0,
    logged=>0+sprintf('%.1f',$x->{logged}), expected=>$x->{expected}+0,
    util=>0+sprintf('%.4f',$x->{expected}?$x->{logged}/$x->{expected}:0),
    tickets=>$x->{tickets}+0, closes=>$x->{closes}+0 }; }

# ----- Dev Closes detail (name, role, count, keys) -----
my @closers;
for my $r (@{$D->{devCloses}{rows}}){
  my $nm=$r->[0]//''; next if $nm eq '';
  my $ro=$r->[1]//''; my $ct=num($r->[2]); my $keys=$r->[3]//'';
  push @closers, { name=>$nm, role=>$ro, group=>rgroup($ro), count=>$ct+0, keys=>$keys };
}
@closers = sort { $b->{count} <=> $a->{count} || $a->{name} cmp $b->{name} } @closers;

# ----- QA closes -----
my @qa;
for my $r (@{$D->{qaCloses}{rows}}){
  my $nm=$r->[0]//''; next if $nm eq '';
  push @qa, { name=>$nm, count=>num($r->[1])+0, keys=>($r->[2]//'') };
}

my $devCloses=0; $devCloses+=$_->{count} for @closers;
my $qaCloses=0;  $qaCloses+=$_->{count} for @qa;
my $people=scalar(@people);

my %OUT = (
  month=>$month, range=>$range, workingDays=>$workdays+0,
  kpi=>{ people=>$people+0, logged=>0+sprintf('%.0f',$logged), expected=>$expected+0,
    capacity=>0+sprintf('%.4f',$expected?$logged/$expected:0), tickets=>$tickets+0,
    devCloses=>$devCloses+0, qaCloses=>$qaCloses+0, avgHours=>0+sprintf('%.2f',$people?$logged/$people:0) },
  flags=>{ lowHoursRed=>$lhR+0, lowVolRed=>$lvR+0, bounceHigh=>$bH+0 },
  byRole=>\@byRole, people=>\@people, closers=>\@closers, qa=>\@qa,
  legend=>[ "Expected = each person's weekly goal / 5 x $workdays working days (September excludes the Sep 7 Labor Day closure).",
            "Flags: hrs = low logged hours (RED); vol = low ticket volume (RED); bnc = high bounce rate. Some low-hours flags reflect partial-month PTO.",
            "Dev / QA closes are September month-to-date (9/1-9/30) with ticket keys as recorded in the source workbook." ],
);

# inject
open my $tp,"<:raw","$base/mtd_template.html" or die "template: $!"; my $tpl=<$tp>;
my $dj=JSON::PP->new->utf8->canonical->encode(\%OUT); $dj=~s/</\\u003c/g;
my $gen=`date +%Y-%m-%d`; chomp $gen; $gen ||= '';
$tpl=~s/__DATA__/$dj/;
$tpl=~s/__MONTH__/$month/g; $tpl=~s/__RANGE__/$range/g; $tpl=~s/__WORKDAYS__/$workdays/g;
my $gstamp = $gen ne '' ? $gen : $range;
$tpl=~s/__GENERATED__/$gstamp/g;
open my $o,">:raw",$outHtml or die "out: $!"; print $o $tpl; close $o;

printf "MTD %s: people=%d logged=%.0fh expected=%dh capacity=%.0f%% tickets=%d devCloses=%d qaCloses=%d\n",
  $month,$people,$logged,$expected,100*($expected?$logged/$expected:0),$tickets,$devCloses,$qaCloses;
printf "flags: lowHours=%d lowVol=%d bounceHigh=%d\n",$lhR,$lvR,$bH;
print "wrote $outHtml (".(-s $outHtml)." bytes)\n";
