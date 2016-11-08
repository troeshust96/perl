package Local::TCP::Calc::Server;

use strict;
use Local::TCP::Calc;
use Local::TCP::Calc::Server::Queue;
use Local::TCP::Calc::Server::Worker;
use IO::Socket;

my $max_worker;
my $in_process = 0;

my $pids_master = {};
my $receiver_count = 0;
my $max_forks_per_task = 0;
my $max_queue_task = 0;
my $queue_filename = "/tmp/queue.log";

sub REAPER {
	...
	# Функция для обработки сигнала CHLD
};
$SIG{CHLD} = \&REAPER;

sub start_server {
	my ($pkg, $port, %opts) = @_;
	$max_worker         = $opts{max_worker} // die "max_worker required"; 
	$max_forks_per_task = $opts{max_forks_per_task} // die "max_forks_per_task required";
    my $max_receiver    = $opts{max_receiver} // die "max_receiver required"; 
    $max_queue_task     = $opts{max_queue_task} // die "max_queue_task required";
    	
	# Инициализируем сервер my $server = IO::Socket::INET->new(...);

    my $server = IO::Socket::INET->new(
        LocalPort => $port,
        Type => SOCK_STREAM,
        ReuseAddr => 1,
        Listen => 10)
    or die "Can't create server on port $port : $@ $/";
    

	# Инициализируем очередь my $q = Local::TCP::Calc::Server::Queue->new(...);
    
    
    my $queue_fh = FileHandle->new($queue_filename, O_RDWR|O_CREAT);
    if ( !defined $fh ) {
        die "Cant open file for queue";
    }
    my $queue = Local::TCP::Calc::Server::Queue->new(
        f_handle       => $queue_fh,
        queue_filename => $queue_filename,
        max_task       => $max_queue_task)
	$queue->init();
    
	while(my $client = $server->accept()){
		my $child = fork();
		if ( $child ) { 
            close ($client); 
            next; 
        }
		if ( defined $child ) {
            close($server);
			my $other = getpeername($client);
			my ($err, $host, $service)=getnameinfo($other);
			print "Client $host:$service $/";
			$client->autoflush(1);
			my $message = <$client>;
			chomp( $message );
			print $client "Echo: ".$message;
			close( $client );
			exit;
		} else { 
            die "Can't fork: $!"; 
        }
	}


	
	# Начинаем accept-тить подключения
	# Проверяем, что количество принимающих форков не вышло за пределы допустимого ($max_receiver)
	# Если все нормально отвечаем клиенту TYPE_CONN_OK() в противном случае TYPE_CONN_ERR()
	# В каждом форке читаем сообщение от клиента, анализируем его тип (TYPE_START_WORK(), TYPE_CHECK_WORK()) 
	# Не забываем проверять количество прочитанных/записанных байт из/в сеть
	# Если необходимо добавляем задание в очередь (проверяем получилось или нет) 
	# Если пришли с проверкой статуса, получаем статус из очереди и отдаём клиенту
	# В случае если статус DONE или ERROR возвращаем на клиент содержимое файла с результатом выполнения
	# После того, как результат передан на клиент зачищаем файл с результатом
}

sub check_queue_workers {
	my $self = shift;
	my $q = shift;
	...
	# Функция в которой стартует обработчик задания
	# Должна следить за тем, что бы кол-во обработчиков не превышало мексимально разрешённого ($max_worker)
	# Но и простаивать обработчики не должны
	# my $worker = Local::TCP::Calc::Server::Worker->new(...);
	# $worker->start(...);
	# $q->to_done ...
}

1;
