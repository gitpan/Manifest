package Checksum::cksum;
require Checksum::External;
@ISA = 'Checksum::External';

sub new {
    my ($class) = @_;
    $class->SUPER::new('cksum');
}

1;
