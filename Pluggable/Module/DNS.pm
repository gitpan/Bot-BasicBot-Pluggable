package Bot::BasicBot::Pluggable::Module::DNS;
use Bot::BasicBot::Pluggable::Module::Base;

=head1 NAME

Bot::BasicBot::Pluggable::Module::DNS

=head1 SYNOPSIS

Does DNS lookups for hosts

=head1 IRC USAGE

Commands:

=over 4

=item nslookup <name>

=item dns <ip address>

=back

=head1 TODO

=cut

use base qw(Bot::BasicBot::Pluggable::Module::Base);

use Socket;

sub said {
    my ($self, $mess, $pri) = @_;
    my $body = $mess->{body};

    my ($command, $param) = split(/\s+/, $body, 2);
    $command = lc($command);

    return unless ($pri == 2);
    
    if ($command eq "nslookup") {
        my @addr = gethostbyname($param);
        my $straddr = inet_ntoa($addr[4]);
        return "$param is $straddr";
    } elsif ($command eq "dns") {
        my $addr = inet_aton($param);
        my @addr = gethostbyaddr($addr, AF_INET);
        return "$param is $addr[0]";
    }
}

1;
