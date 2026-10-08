use strict; use warnings; use JSON::PP;
my $f = $ARGV[0];
local $/; open my $fh,"<:raw",$f or die $!; my $J=JSON::PP->new->decode(<$fh>);
# virtualColumnId map
my %C = (
  '5010489278238596'=>'round','7883145941913476'=>'project',
  '8784255850418052'=>'duration','4199534894026628'=>'startdate',
  '5224649232519044'=>'section',
);
my @rows;
for my $r (@{$J->{rows}}){
  my %o;
  for my $c (@{$r->{cells}}){
    my $vid = $c->{virtualColumnId} // next;
    next unless $C{$vid};
    my $v = defined $c->{displayValue} ? $c->{displayValue} : $c->{value};
    $o{$C{$vid}} = $v;
  }
  push @rows, \%o;
}
# parse duration "Nd" -> number; startdate -> YYYY-MM-DD
for my $o (@rows){
  my $d = $o->{duration}//''; my ($n)= $d=~/([\d.]+)\s*d/i; $o->{dur}= defined $n? $n+0 : undef;
  my $s = $o->{startdate}//''; my ($ymd)= $s=~/(\d{4}-\d{2}-\d{2})/; $o->{sd}=$ymd//'';
}
# print sorted by startdate
@rows = sort { ($a->{sd}||'9999') cmp ($b->{sd}||'9999') } @rows;
printf "%-3s %-11s %-34s %-7s %s\n","#","StartDate","Project","Dur","Round";
my $i=0;
for my $o (@rows){ $i++;
  printf "%-3d %-11s %-34.34s %-7s %s\n",$i,($o->{sd}||'(none)'),($o->{project}//''),(defined $o->{dur}?$o->{dur}."d":'-'),($o->{round}//''); }
print "\nTOTAL rows: ".scalar(@rows)."\n";
# save clean tsv
open my $out,">","cathy_clean.tsv"; print $out "startdate\tproject\tdur\tround\tsection\n";
for my $o (@rows){ print $out join("\t",($o->{sd}||''),($o->{project}//''),(defined $o->{dur}?$o->{dur}:''),($o->{round}//''),($o->{section}//'')),"\n"; }
