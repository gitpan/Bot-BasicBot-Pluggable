package App::Bot::BasicBot::Pluggable;
use Config::Find;
use Bot::BasicBot::Pluggable;
use Bot::BasicBot::Pluggable::Store;
use Moose;
with 'MooseX::Getopt::Dashes';
with 'MooseX::SimpleConfig';
use Moose::Util::TypeConstraints;
use List::MoreUtils qw(any uniq);

use Module::Pluggable sub_name => '_available_stores', search_path => 'Bot::BasicBot::Pluggable::Store';

subtype 'App::Bot::BasicBot::Pluggable::Channels'
	=> as 'ArrayRef'
	## Either it's an empty ArrayRef or all channels start with #
	=> where { @{$_} ? any { /^#/ } @{$_} : 1 };

coerce 'App::Bot::BasicBot::Pluggable::Channels'
	=> from 'ArrayRef'
	=> via { [ map { /^#/ ? $_ : "#$_" } @{$_} ] };

subtype 'App::Bot::BasicBot::Pluggable::Store'
	=> as 'Bot::BasicBot::Pluggable::Store';

MooseX::Getopt::OptionTypeMap->add_option_type_to_map(
    'App::Bot::BasicBot::Pluggable::Store' => '=s%'
);

coerce 'App::Bot::BasicBot::Pluggable::Store'
	=> from 'Str'
	=> via { Bot::BasicBot::Pluggable::Store->new_from_hashref({ type => 'Str' }) };

coerce 'App::Bot::BasicBot::Pluggable::Store'
	=> from 'HashRef'
	=> via { Bot::BasicBot::Pluggable::Store->new_from_hashref( shift ) };

has server  => ( is => 'rw', isa => 'Str', default => 'localhost' );
has nick    => ( is => 'rw', isa => 'Str', default  => 'basicbot' );
has charset => ( is => 'rw', isa => 'Str', default  => 'utf8' );
has channel => ( is => 'rw', isa => 'App::Bot::BasicBot::Pluggable::Channels', coerce => 1, default => sub { []  });
has password => ( is => 'rw', isa => 'Str' );
has port     => ( is => 'rw', isa => 'Int', default => 6667 );

has list_modules => ( is => 'rw', isa => 'Bool', default => 0 );
has list_stores => ( is => 'rw', isa => 'Bool', default => 0 );

has store    => ( is => 'rw', isa => 'App::Bot::BasicBot::Pluggable::Store', coerce => 1,  builder => '_create_store' );
has settings => ( metaclass => 'NoGetopt', is => 'rw', isa => 'HashRef', default => sub {{}} );

has configfile => (
    is      => 'rw',
    isa     => 'Str',
    default => Config::Find->find( name => 'bot-basicbot-pluggable.yaml' ),
);

has bot => (
    metaclass => 'NoGetopt',
    is        => 'rw',
    isa       => 'Bot::BasicBot::Pluggable',
    builder   => '_create_bot',
    lazy      => 1,
);

has module => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { return [qw( Auth Loader )] }
);

sub BUILD {
    my ($self) = @_;

    if ( $self->password() ) {
        $self->module( [ uniq @{ $self->module }, 'Auth' ] );
    }
    $self->_load_modules();
}

sub _load_modules {
    my ($self) = @_;
    my %settings = %{ $self->settings() };

    # Implicit loading of modules via $self->settings
    my @modules = uniq @{ $self->module() }, keys %settings;
    $self->module([@modules]);

    for my $module_name ( @modules ) {
        my $module = $self->bot->load($module_name);
        if ( exists( $settings{$module_name} ) ) {
            for my $key ( keys %{ $settings{$module_name} } ) {
                $module->set( $key, $settings{$module_name}->{$key} );
            }
        }
        if ( $module_name eq 'Auth' and $self->password() ) {
            $module->set( 'password_admin', $self->password() );
        }
    }
}

sub _create_store {
    return Bot::BasicBot::Pluggable::Store->new_from_hashref(
        { type => 'Memory' } );
}

sub _create_bot {
    my ($self) = @_;
    return Bot::BasicBot::Pluggable->new(
        channels => $self->channel(),
        server   => $self->server(),
        nick     => $self->nick(),
        charset  => $self->charset(),
        port     => $self->port(),
        store    => $self->store(),
    );
}

sub run {
    my ($self) = @_;

    if ( $self->list_modules() ) {
        print "$_\n" for $self->bot->available_modules;
        exit 0;
    }

    if ( $self->list_stores() ) {
        for ( $self->_available_stores ) {
            s/Bot::BasicBot::Pluggable::Store:://;
            print "$_\n";
        }
        exit 0;
    }
    $self->bot->run();
}

1;