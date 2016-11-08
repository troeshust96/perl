package Extended::Protocol;

use Exporter 'import';
our @EXPORT = qw(
	try_send send_message
	receive_header receive_message
    msg_to_str
    pack_header pack_message unpack_header unpack_message	
);

use strict;
use warnings;
use Extended::Constants;

# Send message through socket
sub try_send {
    my $dest = shift;
    my $msg = shift;
    
    my $len_sended = $dest->send($msg);
    if ( $len_sended != length($msg) ) { die "Cant send message" }
}

# Send response from Server to Client
sub send_message {
    my $client = shift;
    my $aref = shift;  
    my $type = shift;

    if ( !defined $type ) { $type = 0 }
	my $string_msg = msg_to_str($aref);
    my $p_header = pack_header($type, length($string_msg));
    my $p_msg = pack_message($string_msg);
    try_send($client, $p_header.$p_msg.$/);
}

# Receive header from Client
sub receive_header {
	my $client = shift;

	my $packed_header;
	$client->recv($packed_header, HEADER_SIZE);
    if ( length($packed_header) == 0) { return }
    if ( length($packed_header) < HEADER_SIZE)  { die "broken header" }
	return unpack_header($packed_header);
}

# Receive message from Client
sub receive_message {
	my $client = shift;
	my $len = shift;

    my $packed_msg;	
    $client->recv($packed_msg, BUF_SIZE());
    chomp($packed_msg);
    my $message = unpack_message($packed_msg);
    if ( length($message) != $len ) { die "broken message" }
	return $message;
}

# (1, 2, 3, ...) -> #1#2#3...
sub msg_to_str {
    my $arr = shift;

    my $string_msg = "";
    for my $i ( @$arr ) {
        $string_msg = $string_msg."#".$i;
    }
    return $string_msg;
}

sub pack_header {
    my $type = shift;
    my $size = shift;
    return pack "CL", $type, $size;
}

sub unpack_header {
    my $header = shift;
    my @unpacked = unpack "CL", $header;
    my %h = (
        type => $unpacked[0],
        size => $unpacked[1],
    );
    return %h;
}

sub pack_message {
    my $message = shift;
    my $packed = pack "a*", $message;
    return $packed;
}

sub unpack_message {
    my $message = shift;
    return unpack "a*", $message;
}

1;
