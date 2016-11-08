package Local::TCP::Calc::Server::Worker;

use strict;
use warnings;
use Mouse;
use POSIX;
use Fcntl qw(:DEFAULT :flock);

use Extended::Subs;
require "Calculator/bin/Calculator.pm";

has task_id     => (is => 'ro', isa => 'Int', required => 1);
has max_forks   => (is => 'ro', isa => 'Int', required => 1);
has in_file     => (is => 'rw', isa => 'Str');
has out_file    => (is => 'rw', isa => 'Str');
has forks       => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });
has error       => (is => 'rw', isa => 'Int', default => 0);

sub wait_fork {
    my $self = shift;

    my $wpid = waitpid(0, 0);
    if ( $wpid == -1 ) { return -1 } # No childs to wait
    @{$self->{forks}} = grep { $_ ne $wpid } @{$self->{forks}};    
    if ( !WIFEXITED($?) ) {
        print "Suddenly worker died =/$/";
        for my $child ( @{$self->{forks}} ) {
            kill("TERM", $child);     
        }
        $self->{error} = 1;
    }
    return $wpid;
}

sub start {
    $SIG{CHLD} = "DEFAULT";
    my $self = shift;
    
    $self->{in_file} = "/tmp/task".$self->{task_id}.".in";	
    $self->{out_file} = "/tmp/task".$self->{task_id}.".out";	
    open my $fh_in, '<', $self->{in_file} or die $!;
    open my $fh_out, '>', $self->{out_file} or die $!;
    my @forks_list = ();
    $self->{forks} = \@forks_list;

    EXPR: while ( my $expr = <$fh_in> ) {
        chomp($expr);
        while ( $#forks_list + 1 == $self->{max_forks} ) { 
            $self->wait_fork();    
            if ( $self->{error} ) { 
                try_write($fh_out, "Something bad happens while processing the task$/", "rewrite"); 
                last EXPR;
            }
        }
        my $pid = fork();
    #parent
        if ( $pid ) {
            push @forks_list, $pid;
            next;
        } 
    #child
        if ( defined $pid ) {
            my $res = calculate($expr);  
            try_write($fh_out, $res.$/);
            exit 0;
        } else { die "Can't fork: $!" }
    }
    
    while ( $self->wait_fork() != -1 ) { }
    close $fh_in;
    close $fh_out;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
