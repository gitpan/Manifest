package File::Manifest;
use strict;
use Carp;
use IO::File;
use File::Recurse;
use vars qw($VERSION);

$VERSION = '1.02';

sub new {
    my $o = bless { manifest=>'MANIFEST', cksum => {}, mode=>0644 }, shift;

    if (@_ == 1 or @_ == 2) {
	$o->bind(@_);
    } elsif (@_ != 0) {
	croak "new File::Manifest([dir,dest])";
    }
    $o;
}

sub add_cksum {
    my ($o, $pkg) = @_;
    croak "$o->add_cksum(package)" if @_ != 2;
    return if $pkg eq 'nm';
    $o->{cksum}{$pkg} = $pkg->new();
}

sub bind {
    my ($o, $dir, $dest) = @_;
    $o->{dir} = $dir;
    $o->{dest} = $dest || $dir;
}

sub read_tree {
    my ($o) = @_;

    chdir $o->{dir} or die "chdir $o->{dir}: $!";
    my @files;
    recurse(sub {
	my $f = substr(shift, 2);
	return 0 if (-d $f or $f eq $o->{manifest});
	my $z = {nm=>$f};
	while (my ($k,$box) = each %{$o->{cksum}}) {
	    # assume all cksums have the same interface as MD5...
	    $box->reset();
	    if (-l $f) { 
		# do something reasonable with symlinks
		$box->add(readlink($f));
	    } else {
		my $fh = new IO::File;
		if (!$fh->open($f)) {
		    warn "open $f: $!";
		} else {
		    $box->addfile($fh);
		}
	    }
	    $z->{$k} = $box->hexdigest();
	}
	push(@files, $z);
	0;
    }, '.');
    @files = sort { $a->{nm} cmp $b->{nm} } @files;
    \@files;
}
    
sub find_cksum {
    my ($o, $sums) = @_;
    for my $p (@$sums) { return if exists $o->{cksum}{$p} }
    my $ok=0;
    my @sums = @$sums;
    while (!$ok) {
	my $p = shift @sums;
	die "Basic checksum not found (tried ".join(',', @$sums).")" if !$p;
	next if $p eq 'nm';
	my $f = "$p.pm";
	$f =~ s,::,/,g;
	eval { require $f; $o->add_cksum($p); $ok=1; };
    }
}

sub write {
    my $o = shift;
    # bind @_?

    $o->find_cksum([qw(MD5 Checksum::cksum Checksum::sum)]);

    my $files = $o->read_tree;

    my $f = "$o->{dest}/$o->{manifest}";
    my $fh = new IO::File;
    $fh->open($f, O_WRONLY|O_CREAT|O_TRUNC, $o->{mode}) or die "open $f: $!";
    my @cols = ('nm', keys %{$o->{cksum}});
    print $fh join($;, @cols)."\n";
    for my $f (@$files) {
	print $fh join($;, map { $f->{$_} } @cols)."\n";
    }
}

sub diff {
    my $self = shift;

    my $orig;
    {
	my $fh = new IO::File;
	my $f = "$self->{dest}/$self->{manifest}";
	$fh->open($f) or die "open $f: $!";
	my $h = <$fh>;
	chomp $h;
	my @cols = split($;, $h);
	$self->find_cksum(\@cols);
	while (defined (my $l = <$fh>)) {
	    chomp $l;
	    my @z = split($;, $l);
	    my %z;
	    for (my $c=0; $c < @cols; $c++) { $z{$cols[$c]} = $z[$c]; }
	    $orig->{$z{nm}} = \%z;
	}
    };

    my $r = { '=' => [], '+' => [], '-' => [], '!' => [] };
    my $new = $self->read_tree;
    for my $f (@$new) {
	my $o = $orig->{$f->{nm}};
	delete $orig->{$f->{nm}};  #check once only
	if ($o) {
	    my $eq=1;
	    for my $k (keys %$f) {
		do {$eq=0; last} if (exists $o->{$k} and $o->{$k} ne $f->{$k});
	    }
	    push(@{$r->{$eq? '=':'!'}}, $f);
	} else {
	    push(@{$r->{'+'}}, $f);
	}
    }
    for my $o (values %$orig) { push(@{$r->{'-'}}, $o) }

    $r;
}

1;
