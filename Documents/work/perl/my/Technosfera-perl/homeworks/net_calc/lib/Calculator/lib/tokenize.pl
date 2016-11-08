use 5.010;
use strict;
use warnings;
use diagnostics;
 
BEGIN
{
    if ($] < 5.018)
    {
        package experimental;
        use warnings::register;
    }
}
no warnings 'experimental';
 
sub del_element {
    my ($aref, $idx) = @_;
    splice(@$aref, $idx, 1);
}
 
sub del_empty_elements {
    my $aref = shift;
    my $i = 0;
    while ( $i <= $#$aref) {
        if ( $aref->[$i] eq "" ) {
            del_element($aref, $i);
        } else {
            ++$i;
        }
    }
}

sub delete_spaces {
    my $str = shift;
    $str =~ s/\s+//g;
    return $str;
}

sub unary_transform {
    my $expr = "(".shift;
    $expr =~ s/(?<=[-(+*\/^])-/U-/g;
    $expr =~ s/(?<=[-(+*\/^])\+/U+/g;
    return substr($expr, 1, length($expr) - 1);
}

sub split_expr {
    my $expr = shift;
    my @res = split m{((?<![eU])[-+]|[*^/()]|U\+|U-)}, $expr; 
    del_empty_elements(\@res);
    return @res;
}

sub is_number {
    my $expr = shift;
    return $expr =~ /[0-9]/g;
}

sub is_operation {
    my $expr = shift;
    return !is_number($expr);
}

sub normalize {
    my $expr = shift;
    my $val = 0 + $expr;
    return "$val";
}

#correct bracket sequence
sub check_CBS {
    
    
    my $cap = 0;
    my $str = shift;
    my @expr = split("", $str);
    for my $i ( 0 .. $#expr ) {
        if ( $expr[$i] eq "(" ) {
            ++$cap;
        }
        if ( $expr[$i] eq ")" ) {
            --$cap;
        }
        if ( $cap < 0 ) { 
            die "Wrong bracket sequence";
        }
    }
    if ( $cap > 0 ) { die "Wrong bracket sequece" }
}

sub check_number {
    my $expr = shift;
    if ( $expr =~ /.*e.*e.*|.*\..*\..*/ ) {
        die "Wrong number : $expr";
    } 
}

sub check_numbers_beside {
    my $expr = shift;
    my @tok = split m{((?<!e)[-+]|[*^/()]|\s+)}, $expr; 
    my $last_is_number = 0;
    for my $i ( @tok ) {
        if ( is_number($i) && $last_is_number ) {
                die "2 numbers in a row";
        }
        if ( $i =~ /\s/ ) {
            next;
        }
        $last_is_number = is_number($i);
    }
}

sub check_sequence {
    my $expr = shift;
    # UO-O | O-O | (-O
    if ( $expr =~ /(?<=U\+|U-|.[-+*\/^(])[-+*\/^]/ ) {
        my $len = $+[0] - $-[0];
        die "Wrong sequence : ".substr($expr, $-[0], $len); 
    }
    # O-EOE | UO-EOE  
    if ( $expr =~ /([-+*\/^]|U\+|U-)$/ ) {
        my $len = $+[0] - $-[0];
        die substr($expr, $-[0], $len)." at the end of expression"; 
    }
    # O-)
    if ( $expr =~ /[-+*\/^]\)/ ) {
        my $len = $+[0] - $-[0];
        die "Wrong sequence : ".substr($expr, $-[0], $len);
    }
}

sub tokenize($) {
    chomp(my $expr = shift);
    check_numbers_beside($expr);
    $expr = delete_spaces($expr);
    $expr = unary_transform($expr);
    check_CBS($expr); # correct bracket sequence
    check_sequence($expr);
    my @res = split_expr($expr);

    for my $i ( 0 .. $#res ) {
        my $cur_element = $res[$i];
        if ( is_number($cur_element) ) {
            check_number($cur_element);
            $cur_element = normalize($cur_element);
        }
        $res[$i] = $cur_element;
    }
    return \@res;
}
1;
