package Local::TCP::Calc::Server::Queue;

use strict;
use warnings;

use Mouse;
use Fcntl qw(:DEFAULT :flock);
use IO::Handle;
use JSON::XS;
use Time::HiRes qw/gettimeofday/;
use POSIX;

use Extended::Subs;
use Extended::Constants;

has queue_filename => (is => 'ro', isa => 'Str', default => '/tmp/local_queue.log');
has max_task       => (is => 'rw', isa => 'Int', default => 0);
has changed        => (is => 'rw', isa => 'Int', default => 0);
has f_handle       => (is => 'rw', isa => 'FileHandle');

$SIG{ALRM} = sub { die "Can't get access for queue file for ".TIMEOUT()." secs! =/" };

# Get unused ID for new task
sub get_next_id {
    my $tasks = shift;

    my $cur = 1;
    L: while (1) {
        for my $i ( @$tasks ) {
            if ( $i->{id} == $cur) { 
                ++$cur;
                next L; 
            }
        }
        return $cur;
    }
}

sub init {
    my $self = shift;    	
   
    sysopen(my $fh, $self->queue_filename, O_RDWR|O_CREAT)
        or die "Can't open queue file: $!";
    truncate $fh, 0;
    close $fh;
}

sub my_open {
	my $self = shift;

    open my $fh, '+<', $self->queue_filename or die $!;
    $self->{f_handle} = $fh;
    try_lock($fh);
    $self->changed(0);
    my @tasks = ();
    while ( my $str = <$fh> ) {
        my $struct = decode_json($str);
        push @tasks, $struct;
    }
    return \@tasks;
}

sub my_close {
	my $self = shift;
	my $tasks = shift;

    my $fh = $self->{f_handle};
    if ($self->changed) {
        truncate $fh, 0;
        seek $fh, 0, SEEK_SET;    
        for my $i ( @$tasks ) {
            my $json_text = encode_json $i; 
            print { $fh } $json_text.$/;
        }
    }
    flock($fh, LOCK_UN) or die "Cannot unflock: $!";
    close $fh;
}

sub to_done {
	my $self = shift;
	my $task_id = shift;
    
    my $tasks = $self->my_open();
    for my $i ( @$tasks ) {
        if ( $i->{id} == $task_id ) {
            $i->{status} = STATUS_DONE();
        }
    }
    $self->changed(1);
    $self->my_close($tasks);
}

sub get_status {
	my $self = shift;
	my $id = shift;
	
    my $tasks = $self->my_open();
    for my $i ( @$tasks ) {
        if ( $i->{id} == $id ) {
            my $ans = $i->{status};
            
            $self->my_close($tasks);
            return $ans;
        }
    }
}

sub get_time_unchanged {
    my $self = shift;
    my $id = shift;

    my $tasks = $self->my_open();
    for my $i ( @$tasks ) {
        if ( $i->{id} == $id ) {
            my $ans = (gettimeofday() - $i->{time_changed});
            $self->my_close($tasks);
            return $ans;
        }
    } 
}

sub delete {
    my $self = shift;
	my $id = shift;
	
    my $tasks = $self->my_open();
    @$tasks = grep { $_->{id} ne $id } @$tasks;
    $self->changed(1);
    $self->my_close($tasks);
}

sub get {
    my $self = shift;
	
    my $task_id = 0;
    my $tasks = $self->my_open();
    for my $i ( @$tasks ) {
        if ( $i->{status} == STATUS_NEW() ) {
            $task_id = $i->{id};
            $i->{status} = STATUS_WORK();
            $i->{time_changed} = gettimeofday();
            last;
        }
    }
    $self->changed(1);
    $self->my_close($tasks);
    return $task_id;
}

sub add {
	my $self = shift;
    my $tasks = $self->my_open();
    
    if ( scalar(@$tasks) == $self->{max_task} ) {
        print "QUEUE OVERFLOW\n";
        return 0;
    }
    my $time = gettimeofday();
    my $new = {
        id => get_next_id($tasks),
        status => STATUS_NEW(),
        time_changed => $time, 
    };
    push @$tasks, $new;
    $self->changed(1);
    $self->my_close($tasks);
    return $new->{id};
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
