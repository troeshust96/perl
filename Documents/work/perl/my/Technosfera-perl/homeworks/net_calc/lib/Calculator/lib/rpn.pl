=head1 DESCRIPTION
Realization of algorithm described at 
https://en.wikipedia.org/wiki/Shunting-yard_algorithm
=cut

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
use FindBin;
require "$FindBin::Bin/../lib/Calculator/lib/tokenize.pl";

sub get_priority {
    my $op = shift;
    given ( $op ) {
        when (/U\+|U\-|\^/) { return 3 }
        when (/[*\/]/)      { return 2 }  
        when (/[-+]/)       { return 1 }
        when (/[()]/)       { return 0 }
    }
}

sub is_right_associative {
    my $op = shift;
    return $op =~ /U\+|U\-|\^/;
}

sub rpn 
{
    my $expr = shift;
    my $source = tokenize($expr);
    my @rpn;
    my @stack;
    
    for my $token ( @$source ) {
        given ( $token ) {
            when (/\d/) { push(@rpn, $token) ; }
            when (/U\+|U\-|[-+\/*^]/) {
                my $op1 = $token;
                while ( @stack ) {
                    my $op2 = $stack[-1]; 
                    if ( (!is_right_associative($op1) && get_priority($op1) <= get_priority($op2)) ||
                         (is_right_associative($op1) && get_priority($op1) < get_priority($op2)) ) {
                        push(@rpn, pop(@stack));
                    } else {
                        last;
                    }
                }
                push(@stack, $op1);
            }
            when (/\(/) { push(@stack, $token) }
            when (/\)/) { 
                while ( (my $op = pop(@stack)) ne "(" ) {
                    push(@rpn, $op);
                }
            }
        }
    }
    while ( @stack ) {
        push(@rpn, pop(@stack));
    }
    return \@rpn;
}
1;
