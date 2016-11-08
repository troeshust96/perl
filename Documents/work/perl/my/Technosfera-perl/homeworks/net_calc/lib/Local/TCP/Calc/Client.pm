package Local::TCP::Calc::Client;

use strict;
use warnings;
use IO::Socket;
use Fcntl ':flock';
use IO::Socket::IP;

use Extended::Constants;
use Extended::Protocol;

sub set_connect {
    my $pkg = shift;
	my $ip = shift;
	my $port = shift;
    
	my $sock = IO::Socket::IP->new(
		PeerPort => $port,
		PeerAddr => $ip,
		Proto    => 'tcp',
		V6Only   => 1,
	) or die "Cannot open client socket: $!";
   
    my $code = <$sock>;
    if ( $code == TYPE_CONN_ERR() ) { die "Server denied the connection" }
    return $sock;
}

sub do_request { 
	my $pkg = shift;
	my $server = shift;
	my $type = shift;
	my $message = shift;
   
# Send request to server 
    send_message($server, $message, $type);

# Receive response
	my %info = receive_header($server);
    my $rec_message = receive_message($server, $info{size});
    $rec_message =~ s/#//;
    my @ans = split(/#/, $rec_message);
    return @ans;
}

1;
