#-*-perl-*-
BEGIN { $| = 1; $tx=1; print "1..4\n"; }
END {print "not ok 1\n" unless $loaded;}

use IO::File;
$loaded=1;

sub ok { print "ok $tx\n"; $tx++; }
sub not_ok { print "not ok $tx\n"; $tx++; }

my $fh = new IO::File;
$fh->open("$^X -Mblib -w ./manifest -d t/1 t/2 2>/dev/null | sort |") or die 1;

<$fh> =~ m'\! ne' ? ok:not_ok;
<$fh> =~ m'\+ plus' ? ok:not_ok;
<$fh> =~ m'\- minus' ? ok:not_ok;
<$fh> ? not_ok:ok;
