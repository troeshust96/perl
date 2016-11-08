package Local::TCP::Calc::Server;

use Local::TCP::Calc::Server::Queue;
use Local::TCP::Calc::Server::Worker;
use Extended::Subs;
use Extended::Protocol;
use Extended::Constants;

use strict;
use warnings;
use IO::Socket qw(getnameinfo SOCK_STREAM);
use Fcntl qw(:DEFAULT :flock);
use POSIX ":sys_wait_h";

my $max_worker = 0;
my $receiver_count = 0;
my $max_forks_per_task = 0;
my $max_queue_task = 0;
my $max_receiver = 0;

my @rec_pids = ();
my @worker_pids = ();

sub REAPER {
    local $!;
    while ((my $pid = waitpid(-1, WNOHANG)) > 0 && WIFEXITED($?)) {
        @rec_pids = grep { $_ ne $pid } @rec_pids;
        @worker_pids = grep { $_ ne $pid } @worker_pids;
    }
    $SIG{CHLD} = \&REAPER;  # loathe SysV
}
$SIG{CHLD} = \&REAPER;

# Receive request from Client
sub get_request {
    my $client = shift;
    
    my %info = receive_header($client);
    if ( scalar(keys(%info)) == 0 ) { return }
    my $message = receive_message($client, $info{size});
    my %request = (
        type => $info{type},
        size => $info{size},
        msg  => $message,
    );
    return %request;
}

# Reading result from files to array
sub get_results {
    my $task_id = shift;
    
    my @ans = ();
    open my $fh_in, '<', get_input_filename($task_id); 
    open my $fh_out, '<', get_output_filename($task_id);
    while ( my $res = <$fh_out> ) {
        my $expr = <$fh_in>;
        chomp( $res );
        chomp( $expr );
        push @ans, $expr." == ".$res;
    }
    close $fh_in;
    close $fh_out;
    return @ans;
}

# Delete task from queue and clean files
sub erase_task {
    my $id = shift;
    my $queue = shift;
    unlink (get_input_filename($id), get_output_filename($id));
    $queue->delete($id);
}

# Handling request
sub solve_request {
    my $request = shift;
    my $queue = shift;
    
# New task
    if ( $request->{type} == TYPE_START_WORK() ) {
        my $id = $queue->add();
        if ( $id ) {        
            write_task_input($request->{msg}, $id);
            punch_workers($queue);
        }
        return $id;
    }
# Check status
    if ( $request->{type} == TYPE_CHECK_WORK() ) {
        my $id = $request->{msg};
        $id =~ s/^#//;
        
        my @response = ();
        my $status = $queue->get_status($id);
        push @response, $status; 
        if ( $status == STATUS_DONE() || $status == STATUS_ERROR() ) {
            @response = (@response, get_results($id));
            erase_task($id, $queue);
        }
        if ( $status == STATUS_NEW() || $status == STATUS_WORK() ) {
            @response = (@response, queue->get_time_unchanged($id));
        } 
        return @response;
    } 
}

sub start_server {
    
# Starting server
    my ($pkg, $port, %opts) = @_;
	$max_worker         = $opts{max_worker} // die "max_worker required"; 
	$max_forks_per_task = $opts{max_forks_per_task} // die "max_forks_per_task required";
    $max_queue_task     = $opts{max_queue_task} // die "max_queue_task required"; 
    $max_receiver    = $opts{max_receiver} // die "max_receiver required"; 

    my $host = "127.0.0.1";	
    my $server = IO::Socket::IP->new(
        LocalPort => $port,
        LocalAddr => $host,
        Proto     => 'tcp',
        Listen    => 5,
        Type      => SOCK_STREAM,
        V6Only    => 1,
        (($^O eq 'MSWin32') ? () : (ReuseAddr => 1)),
    ) or die "Cannot open server socket: $!";
    
# Starting queue
    my $queue = Local::TCP::Calc::Server::Queue->new(max_task => $max_queue_task);
    $queue->init();
    
# Accepting connections
    while (1) {        
        my $client = $server->accept;
        if ( !defined $client) { next }
        if ( $#rec_pids + 1 == $max_receiver ) {
            print "Reached limit of receivers".$/; 
            print {$client} TYPE_CONN_ERR().$/;
            close ( $client );
            next;
        }
        my $child = fork();
    #parent
        if ( $child ) { 
            push(@rec_pids, $child);
            close ($client); 
            next; 
        }
    #child
		if ( defined $child ) {
            close $server;
            $client->send(TYPE_CONN_OK()."\n");
            my %request = get_request($client);
            if ( scalar(keys(%request)) == 0 ) { exit } # empty request
            my @ans = solve_request(\%request, $queue); 
            send_message($client, \@ans);
            close $client;
            exit;
        } else { die "Can't fork: $!" }
    }
} 

# If any worker done his task or task added
sub punch_workers {
	my $queue = shift;
    
    if ( $#worker_pids + 1 == $max_worker ) { return } # No free workers :(
    
    my $task_id = $queue->get();
    if ( !$task_id ) { return } # No tasks to do :)
    my $pid = fork();
#parent
    if ( $pid ) {
        push @worker_pids, $pid;
        return;
    }
#child (i.e. worker)
    if ( defined $pid ) {
        my $worker = Local::TCP::Calc::Server::Worker->new(
            task_id => $task_id,
            max_forks   => $max_forks_per_task,
        ); 
        $worker->start();
        $queue->to_done($task_id);
        exit 0; 
    }  else { die "Cant start worker: $!" }
}

1;
