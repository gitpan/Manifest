# Pretend to provide the same basic interface that is offered by MD5.

package Checksum::External;
use strict;
use Symbol;
use IPC::Open2;
use vars qw($VERSION);

$VERSION = '1.00';

sub new {
    my ($class, $exe) = @_;
    my $o = bless { buf=>'' }, $class;
    if (system("$exe /dev/null 1>/dev/null")==0) { $o->{exe} = $exe; }
    else { die "Cksum program '$exe' doesn't seem to work"; }
    $o;
}

sub reset {
    my $o = shift;
    delete $o->{sum};
    $o->{buf} = '';
}

sub add {
    my $o = shift;
    $o->{buf} .= join('', @_);
}

sub addfile {
    my ($o, $fh) = @_;
    my ($r,$w) = (gensym,gensym);
    my $pid = open2($r, $w, $o->{exe});
    die "Can't fork $o->{exe}" unless $pid;
    if (ref $fh) {
	my $data;
	while (read $fh, $data, 1024) { print $w $data; }
    } else {
	print $w $fh;
    }
    close($w);
    my $sum = <$r>;
    close($r);
    if ($sum =~ m/^(\d+)/) {
	$o->{sum} = $1;
    } else {
	die "Checksum program $o->{exe} didn't return a number";
    }
}

sub hexdigest {
    my $o = shift;
    $o->addfile($o->{buf}) if !$o->{sum};
    die "No checksum found" if !$o->{sum};
    $o->{sum}
}

1;
