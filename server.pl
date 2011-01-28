use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

my $cv = AE::cv;

my %clients;

# control
my $stdin; $stdin = AE::io *STDIN, 0, sub {
    my $input = <STDIN>;
    send_client($input) if $input =~ /\S/;
    scalar $stdin;
};

# iphone
tcp_server undef, 4423, sub {
    my ($fh) = @_
        or die 'accept failed: ', $!;

    my $fd = fileno $fh;

    my $h = AnyEvent::Handle->new( fh => $fh );
    $clients{ $fd } = $h;

    $h->on_error(sub {
        warn sprintf "network error: %d %s\n", $fd, $_[2];
        undef $h;
        delete $clients{ $fd };
    });
    
    $h->on_read(sub {
        warn sprintf "recv: %d: %s\n", $fd, delete $_[0]->{rbuf};
    });

    warn "connected $fd\n";
};

sub send_client {
    for my $h (values %clients) {
        $h->push_write($_[0]) if defined $h;
    }
}

$cv->recv;
