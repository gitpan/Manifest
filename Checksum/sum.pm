package Checksum::sum;
require Checksum::External;
@ISA = 'Checksum::External';

sub new {
    my ($class) = @_;
    $class->SUPER::new('sum');
}

1;
