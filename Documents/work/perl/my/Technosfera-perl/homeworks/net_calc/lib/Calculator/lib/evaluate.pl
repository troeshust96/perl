use 5.010;
use strict;
use warnings;
use diagnostics;

BEGIN{
    if ($] < 5.018) {
        package experimental;
        use warnings::register;
    }
}

no warnings 'experimental';

sub eval_bin {
    my ($op, $a, $b) = @_; 
    given ( $op ) {
        when (/\-/) { return $a - $b }
        when (/\+/) { return $a + $b }
        when (/\*/) { return $a * $b }
        when (/\//) { return $a / $b }
        when (/\^/) { return $a ** $b }
    }
}

sub eval_un {
    my ($op, $a) = @_;
    return ( $op eq "U+" ) ? ( 0 + $a ) : ( 0 - $a );
}

sub evaluate {
    my $rpn = shift;
    my @eval_stack;
    for my $op ( @$rpn ) {
        given ( $op ) {
            when (/(?<!U)[-+\/*^]/) {
                my ($b, $a) = (pop(@eval_stack), pop(@eval_stack));
                push(@eval_stack, eval_bin($op, $a, $b));
            }
            when (/U\+|U\-/) {
                my $a = pop(@eval_stack);
                push(@eval_stack, eval_un($op, $a));
            }
            default { push(@eval_stack, 0 + $op) }
        }
    }
    return $eval_stack[0];
}
1;
