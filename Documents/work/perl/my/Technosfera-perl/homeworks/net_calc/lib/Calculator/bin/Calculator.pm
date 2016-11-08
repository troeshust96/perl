#!/usr/bin/env perl

use 5.010;  # for say, given/when
use strict;
use warnings;
BEGIN{
    if ($] < 5.018) {
        package experimental;
        use warnings::register;
    }
}
no warnings 'experimental';
our $VERSION = 1.0;

BEGIN{
    $|++;     # Enable autoflush on STDOUT
    $, = " "; # Separator for print x,y,z
    $" = " "; # Separator for print "@array";
}

use FindBin;
require "$FindBin::Bin/../lib/Calculator/lib/evaluate.pl";
require "$FindBin::Bin/../lib/Calculator/lib/rpn.pl";

sub calculate {
    my $expression = shift;
    next if $expression =~ /^\s*$/;

    eval {
        my $rpn = rpn($expression);
        my $value = evaluate($rpn);
        return "$value";
    1} or do {
        print "Error: $@";
        return "NaN";
    };
}
