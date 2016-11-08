package Extended::Subs;

use Exporter 'import';
our @EXPORT = qw(
	try_lock try_write
    get_input_filename get_output_filename
    write_task_input	
);

use strict;
use warnings;
use POSIX;
use Fcntl qw(:DEFAULT :flock);

use Extended::Constants;

sub try_lock {
    my $fh = shift;

    alarm(TIMEOUT());
    eval {
        flock($fh, LOCK_EX) or die "Can't flock: $!";
    };
    alarm(0);
}

sub try_write {
    my $fh = shift;
    my $str = shift;
    my $mode = shift;

    try_lock($fh);
    if ( defined $mode && $mode eq "rewrite" ) { 
        truncate $fh, 0;
        seek $fh, 0, SEEK_SET;
    }
    print { $fh } $str;
    flock($fh, LOCK_UN) or die "Can't unflock: $!";
}

sub get_input_filename {
	my $task_id = shift;
    return "/tmp/task$task_id.in";	
}

sub get_output_filename {
	my $task_id = shift;
    return "/tmp/task$task_id.out";	
}

# Print expressions from Client message to input file
sub write_task_input {
    my $msg = shift;
    my $id = shift;

    $msg =~ s/^#//;
    $msg =~ s/#/\n/g;
    sysopen(my $fh, get_input_filename($id), O_RDWR|O_CREAT)
        or die "Can't create input file for task #$id: $!";
    print {$fh} $msg;
}

1;

