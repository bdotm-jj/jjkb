use strict; use warnings; use utf8; binmode STDOUT,":encoding(UTF-8)";
use JSON::PP; use File::Basename; my $base=dirname($0);
# sprint_gen.pl : lobs/data-*.json -> ../site/reports/sprint-<lob>.html (per LOB) + sprints.html (landing)
# Each LOB json = { lob, goal, generated, sprints:[{n,label,pct,committed,closed,committedRaw,statuses}] }.
my $REPORTS="$base/../site/reports";
sub slug { my $s=lc(shift); $s=~s/[^a-z0-9]+/-/g; $s=~s/^-|-$//g; $s }
sub readjson { my $p=shift; local $/; open my $f,"<:encoding(UTF-8)",$p or die "$p: $!"; JSON::PP->new->decode(<$f>) }
sub inject { my($tplf,$out,%rep)=@_; local $/; open my $t,"<:encoding(UTF-8)",$tplf or die $!; my $h=<$t>;
  for my $k (keys %rep){ my $v=$rep{$k}; $h=~s/\Q$k\E/$v/g; } open my $o,">:encoding(UTF-8)",$out or die "$out: $!"; print $o $h; close $o; }

my @files = sort glob("$base/lobs/data-*.json");
die "no lobs/data-*.json found\n" unless @files;

# per-LOB goal overrides (Stabilization = 60%, others default 80%); see lob_goals.json
my $GOALS = -e "$base/lob_goals.json" ? readjson("$base/lob_goals.json") : {};
my $GDEF = $GOALS->{_default} // 0.80;
sub goalFor { my $lob=shift; exists $GOALS->{$lob} ? $GOALS->{$lob}+0 : $GDEF+0 }

my @index;  # trimmed per-LOB summaries for the landing page
for my $fp (@files){
  my $D = readjson($fp);
  my $lob = $D->{lob}; my $file = "sprint-".slug($lob).".html";
  $D->{goal} = goalFor($lob);   # central override wins over the data json's baked goal
  # per-LOB report
  my $dj = JSON::PP->new->canonical->encode($D); $dj=~s/</\\u003c/g;
  inject("$base/sprint_lob_template.html", "$REPORTS/$file", '__LOB__'=>$lob, '__DATA__'=>$dj);
  my @sp = map { { n=>$_->{n}+0, label=>$_->{label}, pct=>$_->{pct}, committed=>$_->{committed}+0, closed=>$_->{closed}+0 } } @{$D->{sprints}};
  push @index, { lob=>$lob, file=>$file, goal=>goalFor($lob), sprints=>\@sp };
  print "wrote $file (".scalar(@sp)." sprints)\n";
}
# order LOBs by latest completion % desc for a tidy landing
sub latestpct { my $L=shift; my @w=grep {defined $_->{pct}} @{$L->{sprints}}; @w? $w[-1]{pct} : -1 }
@index = sort { latestpct($b) <=> latestpct($a) } @index;
my $ij = JSON::PP->new->canonical->encode(\@index); $ij=~s/</\\u003c/g;
inject("$base/sprint_index_template.html", "$REPORTS/sprints.html", '__DATA__'=>$ij);
print "wrote sprints.html (".scalar(@index)." LOB".(@index==1?"":"s").")\n";
