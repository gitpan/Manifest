#-*-perl-*-
BEGIN { $| = 1; $tx=1; print "1..9\n"; }
END {print "not ok 1\n" unless $loaded;}

use File::Manifest;
$loaded=1;

sub ok { print "ok $tx\n"; $tx++; }
sub not_ok { print "not ok $tx\n"; $tx++; }

system("$^X -Mblib -w manifest t/1 t 2>/dev/null")==0 or die 1;

my $m = new File::Manifest('t/2', 't');
my $r = $m->diff;
for my $c (qw(+ - ! =)) {
    for my $f (@{$r->{$c}}) {
	my $n = $f->{nm};
	if (($n =~ m'plus' && $c eq '+') or
	    ($n =~ m'minus' && $c eq '-') or
	    ($n =~ m'(eq|ne.link)' && $c eq '=') or
	    ($n =~ m/ne$/ && $c eq '!')) {
	    ok;
	} else {
	    warn "$c $n";
	    not_ok;
	}
    }
}

ok;
