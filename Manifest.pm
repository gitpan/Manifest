use strict;

=head1 NAME

File::Manifest - objects representing trees of files

=head1 SYNOPSIS

  my $m = new File::Manifest($dir);
  $m->write();

  my $old = File::Manifest->load($d1);
  my $new = File::Manifest->new($d2);
  $old->diff($new);

=head1 DESCRIPTION

Not yet.

=cut

package File::Manifest;
use Carp;
use IO::File;
use File::Recurse;
use vars qw($VERSION $DEFAULT_CKSUM);

$VERSION = '1.04';

$DEFAULT_CKSUM = 'Checksum::Simple';

# unfactor ? XXX
sub FILE() { 'file' }
sub ECONF() { 'MANICKSUM' }

sub require_pm {
  my $class = shift;
  my $file = $class;
  $file =~ s|::|/|g;
  $file .= ".pm";
  eval { require $file };
  if ($@ and $@ !~ m"Can't locate .*? in \@INC") { die $@ }
}

sub mode {
  my ($o, $mode) = @_;
  $o->{mode} = $mode if defined $mode;
  $o->{mode}
}

sub cksums {
  my $o = shift;
  my @boxes;
  push(@boxes, $DEFAULT_CKSUM->new());
  push(@boxes, $o->{cksum}) if $o->{cksum};
  @boxes;
}

sub get_default_cksum {
  my ($o) = @_;
  my $cksum = $ENV{ &ECONF };
  if ($cksum) {
    require_pm($cksum);
    $o->{cksum} = $cksum->new();
  }
}

sub new {
  my ($class, $dir) = @_;
  -d $dir or croak "$class->new: $dir is not a directory";
  my $o = bless { dir => $dir, 'mode' =>0644 }, $class;
  $o->get_default_cksum;
  $o;
}

sub load {
  my ($class, $f) = @_;
  if (-f $f) {
    my $fh = new IO::File;
    $fh->open($f) or die "open $f: $!";
    my $h = <$fh>;
    chomp $h;
    my @cols = split($;, $h);
    my $line=1;
    my @files;
    while (defined(my $l = <$fh>)) {
      ++$line;
      chomp $l;
      my @f = split($;, $l);
      if (@f != @cols) { warn "Field mismatch file $f line $l\n"; next }
      
      my %z;
      for (my $c=0; $c < @cols; $c++) { $z{ $cols[$c] } = $f[$c]; }
      push(@files, \%z);
    }
    @files = sort { $a->{&FILE} cmp $b->{&FILE} } @files;
    bless { files => \@files }, $class
  } elsif (-d $f) {
    if (-f "$f/".'MANIFEST') { $class->load("$f/".'MANIFEST'); }
    else { $class->new($f)->reread_tree(); }
  } else {
    croak "$class->load: can't read $f";
  }
}

sub reread_tree {
    my ($o) = @_;
    croak "$o->reread_tree: no directory" if !$o->{dir};
    my @boxes = $o->cksums;
    my $fh = new IO::File;
    my @files;
    recurse(sub {
	my $f = shift;
	my $nm = substr($f, 1+length $o->{dir});
	return 0 if (-d $f or $f =~ m,/MANIFEST$,);
	my $z = {&FILE=>$nm};
	for my $box (@boxes) {
	    $box->reset();
	    if (-l $f) { 
		# do something reasonable with symlinks
		$box->add(readlink($f));
	    } else {
		if (!$fh->open($f)) { warn "open $f: $!"; } 
		else { $box->addfile($fh); $fh->close(); }
	    }
	    $z->{ ref($box) } = $box->hexdigest();
	}
	push(@files, $z);
	0;
    }, $o->{dir});
    @files = sort { $a->{&FILE} cmp $b->{&FILE} } @files;
    $o->{files} = \@files;
    $o;
}
    
sub write {
    my ($o, $to) = @_;

    $o->reread_tree() if !$o->{files};

    if (!$to) {
      $to = new IO::File;
      my $f = "$o->{dir}/".'MANIFEST';
      $to->open($f, O_WRONLY|O_CREAT|O_TRUNC, $o->{'mode'}) 
	or die "open $f: $!";
    }

    my @cols = (&FILE, map { ref } $o->cksums);
    $to->print(join($;, @cols)."\n");
    for my $f (@{$o->{files}}) {
      $to->print(join($;, map { $f->{$_} } @cols)."\n");
    }
}

sub diff {
    my ($old, $new) = @_;
    $old->{files} or croak "Old $old is empty";
    $new->{files} or croak "New $new is empty";

    my $r;
    for (qw(= + - !)) { $r->{$_} = [] }

    my $hash;
    for my $z (@{$old->{files}}) { $hash->{ $z->{&FILE} } = $z; }

    for my $f (@{$new->{files}}) {
	my $o = $hash->{ $f->{&FILE} };
	delete $hash->{ $f->{&FILE} };  #check once only
	if ($o) {
	    my $eq=1;
	    for my $k (keys %$f) {
		do {$eq=0; last} if (exists $o->{$k} and $o->{$k} ne $f->{$k});
	    }
	    push(@{$r->{ $eq? '=':'!' }}, $f);
	} else {
	    push(@{$r->{'+'}}, $f);
	}
    }
    for my $o (values %$hash) { push(@{$r->{'-'}}, $o) }
    $r;
}

package Checksum::Simple;
use IO::File;

# This is similar to Solaris 2.5.1 /usr/bin/sum, but doesn't match
# exactly.  Hopefully it portable, since it's all written in perl.

sub new {
  my ($class) = @_;
  my $o = bless { sum => 0 }, $class;
  $o;
}

sub reset {
  my ($o) = @_;
  $o->{sum} = 0;
}

sub add {
  use integer;
  my $o = shift;
  for my $l (@_) {
    $o->{sum} += unpack("%16C*", $l);
    $o->{sum} %= 65536;
  }
}

sub addfile {
  my ($o, $fh) = @_;
  my $data;
  while (1) {
    my $st = sysread($fh, $data, 1024);
    die $! if !defined $st;
    last if $st == 0;
    $o->add($data);
  }
}

sub hexdigest {
  my $o = shift;
  $o->{sum};
}

1;
