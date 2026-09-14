use strict; use warnings;
use JSON::PP;
# xlsx (unzipped into ./mars_x) -> mars_data.json
# Sheets are resolved BY NAME (robust to week-to-week layout changes), not by
# fixed position. MTD is optional; raw-log sheets are any named "Raw Log*".
my $dir = "mars_x";

# ---- shared strings ----
my @ss;
{
  local $/; open my $f, "<:encoding(UTF-8)", "$dir/xl/sharedStrings.xml" or die "sharedStrings: $!";
  my $x = <$f>;
  while ($x =~ /<si>(.*?)<\/si>/sg) {
    my $si=$1; my $t="";
    while ($si =~ /<t\b[^>]*>(.*?)<\/t>/sg) { $t .= $1; }
    for ($t){ s/&amp;/&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;|&apos;/'/g; }
    push @ss, $t;
  }
}

# ---- map sheet NAME -> worksheet file (via workbook.xml + rels) ----
my (%name2file, @order);
{
  local $/;
  open my $wf, "<:encoding(UTF-8)", "$dir/xl/workbook.xml" or die "workbook: $!";
  my $wb = <$wf>;
  my %rid2name;
  while ($wb =~ /<sheet\b([^>]*)\/?>/g) {
    my $a=$1;
    my ($nm) = $a =~ /name="([^"]*)"/;
    my ($rid)= $a =~ /r:id="([^"]*)"/;
    next unless defined $nm && defined $rid;
    for ($nm){ s/&amp;/&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;|&apos;/'/g; }
    $rid2name{$rid}=$nm; push @order,$nm;
  }
  open my $rf, "<:encoding(UTF-8)", "$dir/xl/_rels/workbook.xml.rels" or die "rels: $!";
  my $rl = <$rf>;
  while ($rl =~ /<Relationship\b([^>]*)\/?>/g) {
    my $a=$1;
    my ($id)  = $a =~ /Id="([^"]*)"/;
    my ($tgt) = $a =~ /Target="([^"]*)"/;
    next unless defined $id && defined $tgt && exists $rid2name{$id};
    $tgt =~ s{^/?}{}; $tgt =~ s{^xl/}{};
    $name2file{ $rid2name{$id} } = "$dir/xl/$tgt";
  }
}
sub file_for { my $pat=shift; for my $n (@order){ return $name2file{$n} if $n =~ /$pat/i && $name2file{$n}; } return undef; }
sub name_for { my $pat=shift; for my $n (@order){ return $n if $n =~ /$pat/i; } return undef; }

sub colnum { my $c=shift; $c=~s/\d+//; my $n=0; $n=$n*26+(ord($_)-64) for split//,$c; return $n; }
sub rgroup { my $r=lc(shift//''); return 'Developer' if $r eq 'developer'; return 'Jr Dev' if $r eq 'jr dev';
  return 'Senior/Staff' if $r=~/senior|staff/; return 'QA' if $r eq 'qa'; return 'Data/Other'; }
sub rows_of {
  my $file=shift; return () unless $file && -e $file;
  local $/; open my $f,"<:encoding(UTF-8)",$file or die "$file: $!";
  my $x=<$f>; my @rows;
  while ($x =~ /<row\b[^>]*r="(\d+)"[^>]*>(.*?)<\/row>/sg) {
    my ($rn,$cells)=($1,$2); my %r; my $maxc=0;
    while ($cells =~ /<c\b([^>]*)>(.*?)<\/c>/sg) {
      my ($attr,$body)=($1,$2);
      my ($ref)=$attr=~/r="([A-Z]+)\d+"/; next unless $ref;
      my ($t)=$attr=~/t="([^"]+)"/; $t//="";
      my ($v)=$body=~/<v>(.*?)<\/v>/s;
      my $val;
      if($t eq "s"){ $val=defined $v?($ss[$v]//""):""; }
      elsif($t eq "inlineStr"){ ($val)=$body=~/<t\b[^>]*>(.*?)<\/t>/s; $val//=""; }
      else { $val=defined $v?$v:""; }
      for ($val){ s/&amp;/&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;|&apos;/'/g;
                  s/&#0*1[03];/ /g; s/[\r\n]+/ /g; s/\s{2,}/ /g; s/^\s+|\s+$//g; }
      my $ci=colnum($ref); $r{$ci}=$val; $maxc=$ci if $ci>$maxc;
    }
    push @rows, [$rn,\%r,$maxc];
  }
  return @rows;
}
# header row1; data rows must have the role/key column populated. Footer/Note
# rows (Total/Scope/etc.) are collected as caption notes.
sub table_by_name {
  my ($pat,$rolecol)=@_; $rolecol//=2;
  my @rows = rows_of(file_for($pat));
  return {headers=>[],rows=>[],notes=>[]} unless @rows;
  my (undef,$hr,$hmax)=@{$rows[0]};
  my $nc=$hmax; my @headers=map { $hr->{$_}//"" } (1..$nc);
  # drop trailing scratch/helper columns after "Notes" (presentation cut)
  for my $i (0..$#headers){ if(lc($headers[$i]) eq 'notes'){ $nc=$i+1; @headers=@headers[0..$i]; last; } }
  my (@data,@notes);
  for my $i (1..$#rows){
    my (undef,$r,undef)=@{$rows[$i]};
    my $c1=$r->{1}//""; next if $c1 eq "";
    my $role=$r->{$rolecol}//"";
    if($role eq "" || $c1 =~ /^(Total|Scope|Limitation|Note|Grand|Summary)\b/i){
      my @cells; for my $ci (1..$nc){ push @cells,$r->{$ci} if defined $r->{$ci} && $r->{$ci} ne ""; }
      push @notes, join(" ",@cells) if @cells; next;
    }
    push @data,[ map { $r->{$_}//"" } (1..$nc) ];
  }
  return {headers=>\@headers, rows=>\@data, notes=>\@notes};
}

my %out;
$out{weekly}    = table_by_name('^Weekly Summary$',2);
# Capture the sheet's prorated capacity target (holiday/PTO-adjusted) from the
# FULL Weekly Summary before helper columns are trimmed, so build.pl can use it
# as the utilisation denominator for short/holiday weeks.
{
  my @rows = rows_of(file_for('^Weekly Summary$'));
  my $sum = 0; my $have = 0; my %byrole;
  if (@rows) {
    my (undef,$hr,$hmax)=@{$rows[0]};
    my $pcol; for my $ci (1..$hmax){ if(($hr->{$ci}//'')=~/prorat/i){ $pcol=$ci; last; } }
    if (defined $pcol) {
      for my $i (1..$#rows){ my (undef,$r)=@{$rows[$i]}; next if ($r->{1}//'') eq '';
        my $v=$r->{$pcol}; if(defined $v && $v=~/^-?\d+(?:\.\d+)?$/){ $sum+=$v; $have=1;
          my $g=rgroup($r->{2}); $byrole{$g}+=$v; } }
    }
  }
  $byrole{$_}=0+sprintf('%.1f',$byrole{$_}) for keys %byrole;
  $out{meta} = { expectedProrated => ($have ? 0+sprintf('%.1f',$sum) : undef),
                 expectedProratedByRole => ($have ? \%byrole : undef) };
}
$out{mtd}       = (name_for('Month-?to-?Date|\bMTD\b')) ? table_by_name('Month-?to-?Date|\bMTD\b',2) : {headers=>[],rows=>[],notes=>[]};
$out{devCloses} = table_by_name('^Dev Closes$',2);
# QA closes: numeric col2 only; scope/limitation captured as a note
{
  my @rows = rows_of(file_for('^QA Closes$'));
  my (@data,@headers); my $note="";
  if(@rows){ @headers = map { $rows[0][1]{$_}//"" } (1..3);
    for my $i (1..$#rows){ my (undef,$r)=@{$rows[$i]};
      my $c1=$r->{1}//""; my $c2=$r->{2}//"";
      if($c1 ne "" && $c2 =~ /^\d+(\.\d+)?$/){ push @data,[ $c1,$c2,($r->{3}//"") ]; }
      elsif($c1 =~ /Scope|Limitation/i){ $note.=($note?" ":"").$c1; }
    }
  }
  $out{qaCloses}={headers=>\@headers, rows=>\@data, note=>$note};
}
# raw logs: every sheet named "Raw Log*", in workbook order, with a Day label
{
  my @data;
  for my $n (@order){
    next unless $n =~ /^Raw Log/i;
    my $lbl=$n; $lbl=~s/^Raw Log\s*//i; $lbl=~s/[-.]/\//g; $lbl=~s{/(\d{4})$}{};
    $lbl="Day" if $lbl eq "";
    my @rows=rows_of($name2file{$n});
    for my $i (1..$#rows){ my (undef,$r)=@{$rows[$i]};
      my $u=$r->{1}//""; next if $u eq "";
      push @data,[ $lbl, $u, ($r->{2}//""), ($r->{3}//"") ];
    }
  }
  $out{raw}={headers=>["Day","User","Ticket","Hours"], rows=>\@data};
}
# legend
{
  my @rows=rows_of(file_for('^Legend$')); my @lines;
  for my $row (@rows){ my (undef,$r,$mx)=@$row;
    my @cells; for my $ci (1..($mx||1)){ push @cells,$r->{$ci} if defined $r->{$ci} && $r->{$ci} ne ""; }
    my $line=join(" ",@cells); $line=~s/^\s+|\s+$//g; push @lines,$line if $line ne "";
  }
  $out{legend}=\@lines;
}
open my $o,">:raw","mars_data.json"; print $o JSON::PP->new->utf8->canonical->encode(\%out);
printf "weekly=%d mtd=%d devCloses=%d qaCloses=%d raw=%d legend=%d\n",
  scalar(@{$out{weekly}{rows}}),scalar(@{$out{mtd}{rows}}),scalar(@{$out{devCloses}{rows}}),
  scalar(@{$out{qaCloses}{rows}}),scalar(@{$out{raw}{rows}}),scalar(@{$out{legend}});
print "weekly headers: ",join(" | ",@{$out{weekly}{headers}}),"\n";
