package Extended::Constants;

use Exporter 'import';
our @EXPORT = qw(
	TYPE_START_WORK TYPE_CHECK_WORK TYPE_CONN_ERR TYPE_CONN_OK 
	STATUS_NEW STATUS_WORK STATUS_DONE STATUS_ERROR 
	HEADER_SIZE BUF_SIZE TIMEOUT   
);

use strict;
use warnings;

sub TYPE_START_WORK {1}
sub TYPE_CHECK_WORK {2}
sub TYPE_CONN_ERR   {3}
sub TYPE_CONN_OK    {4}

sub STATUS_NEW   {1}
sub STATUS_WORK  {2}
sub STATUS_DONE  {3}
sub STATUS_ERROR {4}

sub HEADER_SIZE {5}
sub BUF_SIZE    {1024}
sub TIMEOUT     {15}

1;
