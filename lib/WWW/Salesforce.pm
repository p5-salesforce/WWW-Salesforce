package WWW::Salesforce;

use strict;
use warnings;

use Carp ();
use DateTime ();
use Scalar::Util ();
use SOAP::Lite ();    # ( +trace => 'all', readable => 1, );#, outputxml => 1, );

# use Data::Dumper;
use WWW::Salesforce::Constants;
use WWW::Salesforce::Deserializer;
use WWW::Salesforce::Serializer;

our $VERSION = '0.302';
$VERSION = eval $VERSION;

our $SF_PROXY       = 'https://login.salesforce.com/services/Soap/u/40.0';
our $SF_URI         = 'urn:partner.soap.sforce.com';
our $SF_PREFIX      = 'sforce';
our $SF_SOBJECT_URI = 'urn:sobject.partner.soap.sforce.com';
our $SF_URIM        = 'http://soap.sforce.com/2006/04/metadata';
our $SF_APIVERSION  = '40.0';
# set webproxy if firewall blocks port 443 to SF_PROXY
our $WEB_PROXY  = ''; # e.g., http://my.proxy.com:8080

sub password {
    my $self = shift;
    # getter
    return $self->{sf_pass} || '' unless @_;

    # setter
    my $pass = shift;
    if (defined($pass) && !ref($pass)) {
        $self->{sf_pass} = $pass;
    }
    else {
        $self->{sf_pass} = '';
    }
    return $self; # method-chaining possible
}

sub username {
    my $self = shift;
    # getter
    return $self->{sf_user} || '' unless @_;

    # setter
    my $string = shift;
    if (defined($string) && !ref($string)) {
        $self->{sf_user} = $string;
    }
    else {
        $self->{sf_user} = '';
    }
    return $self; # method-chaining possible
}

# for historical purposes (for a time)
sub get_username { shift->username() }

=encoding utf8

=head1 NAME

WWW::Salesforce - This class provides a simple abstraction layer between SOAP::Lite and Salesforce.com.

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use strict;
    use warnings;
    use v5.14;

    use WWW::Salesforce;
    use Syntax::Keyword::Try;

    my $sf;
    try {
        $sf = WWW::Salesforce->new(
            username => 'foo',
            password => 'bar'
        );
    }
    catch {
        warn "Could not login to Salesforce: $@";
        exit(1);
    }

    # try, try, try
    # Things can go wrong unexpectedly.  Be prepared
    # by try-ing and catch-ing any exceptions that occur.

=head1 DESCRIPTION

This class provides a simple abstraction layer between L<SOAP::Lite> and
L<Salesforce|http://www.Salesforce.com>.

=head1 ATTRIBUTES

L<WWW::Salesforce> makes the following attributes available.

=head2 password

    $sf = $sf->password('my super secret password'); # method chaining
    my $password = $sf->password();

The password is the password you set for your user account in
L<Salesforce|http://www.salesforce.com>.

Note, this attribute is only used to generate the access token during
L<WWW::Salesforce/"login">. You may want to L<WWW::Salesforce/"logout"> before
changing this attribute.

=head2 username

    $sf = $sf->username('foo@bar.com'); # method chaining
    my $username = $sf->username;

The username is the email address you set for your user account in
L<Salesforce|http://www.salesforce.com>.

Note, this attribute is only used to generate the access token during
L<WWW::Salesforce/"login">. You may want to L<WWW::Salesforce/"logout"> before
changing this attribute.

=head1 CONSTRUCTORS

L<WWW::Salesforce> makes the following constructors available.

=head2 new

    my $sf = WWW::Salesforce->new(
        username => 'foo@bar.com',
        password => 'super secrety goodness',
    );

Creates a new L<WWW::Salesforce> object and then calls the
L<WWW::Salesforce/"login"> method.

Any of the L<WWW::Salesforce/"ATTRIBUTES"> above can be passed in as a
parameter via either a hash reference or a hash.

=cut

sub _parse_args {
    my $args;
    if ( @_ == 1 && ref $_[0] ) {
        my %copy = eval { %{ $_[0] } }; # try shallow copy
        Carp::croak("Argument could not be dereferenced as a hash.") if $@;
        $args = \%copy;
    }
    elsif ( @_ % 2 == 0 ) {
        $args = {@_};
    }
    else {
        Carp::croak("Got an odd number of elements.");
    }
    return $args;
}

sub new {
    my $class = shift;
    my $args = _parse_args(@_);

    my $href = {
        sf_user => $args->{username} || '',
        sf_pass => $args->{password} || '',
        sf_serverurl => $args->{login_url} || $SF_PROXY,
        sf_sid => undef,
    };
    my $self = bless $href, $class;
    return $self->login($args) unless $args->{no_login};
    return $self;
}

=head1 METHODS

L<WWW::Salesforce> makes the following methods available.

=head2 login

    $sf = $sf->login(); # chaining is possible
    # specify different credentials:
    $sf->login(username => 'override@bar.com');
    # capture error messages!
    try { $sf->login(); }
    catch {
        warn "We couldn't login: $@";
    }

    # This method can also act as a constructor
    # although this is discouraged now
    $sf = WWW::Salesforce->login(
        username => 'foo@bar.com'
        password => 'hahaha',
    );

The C<login> method makes use of the soap login method:
L<Salesforce SOAP-based username and password login flow|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_login.htm>.

Upon success, it will return your L<WWW::Salesforce> object. On failure, it will
die with some useful error string.

On a successful login, the C<session id> is saved and the C<server URL> is set
properly and used as the endpoint for API communication from here on out.

=cut

sub login {
    my $self = shift;
    my $args = _parse_args(@_);
    # if this isn't an instance, create one
    unless ($self && Scalar::Util::blessed($self) && $self->isa('WWW::Salesforce')) {
        $self ||= 'WWW::Salesforce';
        $args->{no_login} = 1;
        $self = new($self, $args);
    }
    # allow overriding current attributes
    $self->username($args->{username} || $self->username());
    $self->password($args->{password} || $self->password());

    my $user = $self->username();
    my $pass = $self->password();
    die("WWW::Salesforce::login() requires a username") unless $user;
    die("WWW::Salesforce::login() requires a password") unless $pass;

    my $client = $self->get_client();
    my $r      = $client->login(
        SOAP::Data->name('username' => $user),
        SOAP::Data->name('password' => $pass)
    );
    die "could not login, user $user, pass $pass" unless $r;

    if ( $r->fault() ) {
        die( $r->faultstring() );
    }

    $self->{'sf_sid'}       = $r->valueof('//loginResponse/result/sessionId');
    $self->{'sf_uid'}       = $r->valueof('//loginResponse/result/userId');
    $self->{'sf_serverurl'} = $r->valueof('//loginResponse/result/serverUrl');
    $self->{'sf_metadataServerUrl'} = $r->valueof('//loginResponse/result/metadataServerUrl');
    return $self;
}

=head2 convertLead

    $sf->convertLead(
        leadId => ['01t500000016RuaAAE', '01t500000016RuaAAF']
        contactId => ['01t500000016RuaAAC'],
    );

The L<convertLead|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_convertlead.htm>
method converts a L<Lead|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_lead.htm#topic-title>
into an L<Account|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_account.htm#topic-title>
and L<Contact|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contact.htm#topic-title>,
as well as (optionally) an L<Opportunity|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_opportunity.htm#topic-title>.

To convert a Lead, your account must have the C<Convert Leads> permission and
the C<Edit> permission on leads, as well as C<Create> and C<Edit> on the
Account, Contact, and Opportunity objects.

Returns an object of type L<SOAP::SOM> if the attempt was successful and
dies otherwise.

=cut

sub convertLead {
    my $self = shift;
    my (%in) = @_;

    if ( !keys %in ) {
        die("Expected a hash of arrays.");
    }

    #take in data to be passed in our call
    my @data;
    for my $key ( keys %in ) {
        if ( ref( $in{$key} ) eq 'ARRAY' ) {
            for my $elem ( @{ $in{$key} } ) {
                my $dat = SOAP::Data->name( $key => $elem );
                push @data, $dat;
            }
        }
        else {
            my $dat = SOAP::Data->name( $key => $in{$key} );
            push @data, $dat;
        }
    }
    if ( scalar @data < 1 || scalar @data > 200 ) {
        die("convertLead converts up to 200 objects, no more.");
    }

    #got the data lined up, make the call
    my $client = $self->get_client(1);
    my $r      = $client->convertLead(
        SOAP::Data->name( "leadConverts" => \SOAP::Data->value(@data) ),
        $self->get_session_header() );

    unless ($r) {
        die "cound not convertLead";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 create

    my $res = $sf->create(
        'type'      => 'Lead',
        'FirstName' => 'conversion test',
        'LastName'  => 'lead',
        'Company'   => 'Acme Inc.',
    );
    if ($res->valueof('//success') eq 'true') {
        say "Yay! New Lead with ID: ", $res->valueof('//id');
    }

The L<create|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_create.htm>
method adds one record, such as an C<Account> or C<Contact> record, to
your organization's information. The C<create> call is analogous to the
C<INSERT> statement in SQL.

A hash or hash-reference is accepted, but must contain a C<type> key to tell us
what we're inserting.

Returns a L<SOAP::SOM> object or dies.


=cut

sub create {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("create")->prefix($SF_PREFIX)->uri($SF_URI)
      ->attr( { 'xmlns:sfons' => $SF_SOBJECT_URI } );

    my $type = delete $in{type} || '';

    my @elems;
    foreach my $key ( keys %in ) {
        push @elems,
          SOAP::Data->prefix('sfons')->name( $key => $in{$key} )
          ->type( WWW::Salesforce::Constants->type( $type, $key ) );
    }

    my $r = $client->call(
        $method => SOAP::Data->name( 'sObjects' => \SOAP::Data->value(@elems) )
          ->attr( { 'xsi:type' => 'sfons:' . $type } ),
        $self->get_session_header()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 delete

    # delete just one item
    my $res = $sf->delete('01t500000016RuaAAE');
    # delete many items
    $res = $sf->delete('01t500000016RuaAAE', '01t500000016RuaAAF');

The L<delete|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_delete.htm>
method will delete one or more individual objects from your organization's data.

=cut

sub delete {
    my $self = shift;

    my $client = $self->get_client(1);
    my $method = SOAP::Data->name("delete")->prefix($SF_PREFIX)->uri($SF_URI);

    my @elems;
    foreach my $id (@_) {
        push @elems, SOAP::Data->name( 'ids' => $id )->type('tns:ID');
    }

    if ( scalar @elems < 1 || scalar @elems > 200 ) {
        die("delete takes anywhere from 1 to 200 ids to delete.");
    }

    my $r = $client->call(
        $method => @elems,
        $self->get_session_header()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 describeGlobal

    my $res = $sf->describeGlobal();

The L<describeGlobal|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describeglobal.htm>
method is used to obtain a list of available objects for your organization. You
can then iterate through this list and use L<WWW::Salesforce/"describeSObject">
to obtain metadata about individual objects.

=cut

sub describeGlobal {
    my $self = shift;

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("describeGlobal")->prefix($SF_PREFIX)->uri($SF_URI);

    my $r = $client->call( $method, $self->get_session_header() );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 describeLayout

    # must provide a type to lookup
    my $res = $sf->describeLayout(type => 'Contact');

The L<describeLayout|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describelayout.htm>
method returns metadata about a given page layout, including layouts for edit
and display-only views and record type mappings.

=cut

sub describeLayout {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    if ( !defined $in{'type'} or !length $in{'type'} ) {
        die("Expected hash with key 'type'");
    }
    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("describeLayout")->prefix($SF_PREFIX)->uri($SF_URI);
    my $r = $client->call(
        $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'sObjectType' => $in{'type'} )
          ->type('xsd:string'),
        $self->get_session_header()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 describeSObject

    # must provide a type to lookup
    my $res = $sf->describeLayout(type => 'Contact');

The L<describeSObject|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describesobject.htm>
method is used to get metadata (field list and object properties) for the
specified object.

=cut

sub describeSObject {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    if ( !defined $in{'type'} or !length $in{'type'} ) {
        die("Expected hash with key 'type'");
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("describeSObject")->prefix($SF_PREFIX)->uri($SF_URI);

    my $r = $client->call(
        $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'sObjectType' => $in{'type'} )
          ->type('xsd:string'),
        $self->get_session_header()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 describeSObjects

    # must provide an array of types to lookup
    my $res = $sf->describeLayout(type => ['Contact', 'Account', 'Custom__c']);

The L<describeSObjects|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describesobjects.htm>
method is used to obtain metadata for a given object or array of objects.

=cut

sub describeSObjects {
    my $self = shift;
    my %in   = @_;

    if (  !defined $in{type}
        or ref $in{type} ne 'ARRAY'
        or !scalar @{ $in{type} } )
    {
        die "Expected hash with key 'type' containing array reference";
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("describeSObjects")->prefix($SF_PREFIX)->uri($SF_URI);

    my $r = $client->call(
        $method => SOAP::Data->prefix($SF_PREFIX)->name('sObjectType')
          ->value( @{ $in{'type'} } )->type('xsd:string'),
        $self->get_session_header()
    );

    unless ($r) {
        die "could not execute method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 describeTabs

    my $res = $sf->describeTabs();

The L<describeTabs|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describetabs.htm>
method obtains information about the standard and custom apps to which the
logged-in user has access. It returns the minimum required metadata that can be
used to render apps in another user interface. Typically this call is used by
partner applications to render Salesforce data in another user interface.

=cut

sub describeTabs {
    my $self   = shift;
    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("describeTabs")->prefix($SF_PREFIX)->uri($SF_URI);

    my $r = $client->call( $method, $self->get_session_header() );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

sub get_client {
    my $self = shift;
    my ($readable) = @_;
    $readable = ($readable) ? 1 : 0;

    my $client =
      SOAP::Lite->readable($readable)
      ->deserializer( WWW::Salesforce::Deserializer->new )
      ->serializer( WWW::Salesforce::Serializer->new )
      ->on_action( sub { return '""' } )->uri($SF_URI)->multirefinplace(1);

    if($WEB_PROXY) {
        $client->proxy( $self->{'sf_serverurl'}, proxy => ['https' => $WEB_PROXY ] );
    } else {
        $client->proxy( $self->{'sf_serverurl'} );
    }
    return $client;
}


sub get_session_header {
    my ($self) = @_;
    return SOAP::Header->name( 'SessionHeader' =>
          \SOAP::Header->name( 'sessionId' => $self->{'sf_sid'} ) )
      ->uri($SF_URI)->prefix($SF_PREFIX);
}


=head2 get_session_id

    my $id = $sf->get_session_id();

Gets the Salesforce SID captured during login.

=cut

sub get_session_id {
    my ($self) = @_;

    return $self->{sf_sid};
}


=head2 get_user_id

    my $id = $sf->get_user_id();

Gets the Salesforce UID captured during login.

=cut

sub get_user_id {
    my ($self) = @_;

    return $self->{sf_uid};
}


=head2 getDeleted

    # get a list of deleted records within a given timespan
    # times are in GMT
    my $res = $sf->getDeleted(
        type => 'Account',
        start => '2017-09-21T08:42:42',
        end   => '2017-09-21T08:43:42',
    );

The L<getDeleted|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getdeleted.htm>
method retrieves the list of individual objects that have been deleted within
the given time span for the specified object.

=cut

sub getDeleted {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    if ( !defined $in{'type'} || !length $in{'type'} ) {
        die("Expected hash with key of 'type'");
    }
    if ( !defined $in{'start'} || !length $in{'start'} ) {
        die("Expected hash with key of 'start' which is a date");
    }
    if ( !defined $in{'end'} || !length $in{'end'} ) {
        die("Expected hash with key of 'end' which is a date");
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("getDeleted")->prefix($SF_PREFIX)->uri($SF_URI);
    my $r = $client->call(
        $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'sObjectType' => $in{'type'} )
          ->type('xsd:string'),
        SOAP::Data->prefix($SF_PREFIX)->name( 'startDate' => $in{'start'} )
          ->type('xsd:dateTime'),
        SOAP::Data->prefix($SF_PREFIX)
          ->name( 'endDate' => $in{'end'} )
          ->type('xsd:dateTime'),
        $self->get_session_header()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 getServerTimestamp

    my $res = $sf->getServerTimestamp();

The L<getServerTimestamp|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getservertimestamp.htm>
method retrieves the current system timestamp (GMT) from the Salesforce web service.

=cut

sub getServerTimestamp {
    my $self   = shift;
    my $client = $self->get_client(1);
    my $r      = $client->getServerTimestamp( $self->get_session_header() );
    unless ($r) {
        die "could not getServerTimestamp";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 getUpdated

    # get a list of updated records within a given timespan
    # times are in GMT
    my $res = $sf->getUpdated(
        type => 'Account',
        start => '2017-09-21T08:42:42',
        end   => '2017-09-21T08:43:42',
    );

The L<getUpdated|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getupdated.htm>
method retrieves the list of individual objects that have been updated (added
or changed) within the given time span for the specified object.

=cut

sub getUpdated {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    if ( !defined $in{'type'} || !length $in{'type'} ) {
        die("Expected hash with key of 'type'");
    }
    if ( !defined $in{'start'} || !length $in{'start'} ) {
        die("Expected hash with key of 'start' which is a date");
    }
    if ( !defined $in{'end'} || !length $in{'end'} ) {
        die("Expected hash with key of 'end' which is a date");
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("getUpdated")->prefix($SF_PREFIX)->uri($SF_URI);
    my $r = $client->call(
        $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'sObjectType' => $in{'type'} )
          ->type('xsd:string'),
        SOAP::Data->prefix($SF_PREFIX)->name( 'startDate' => $in{'start'} )
          ->type('xsd:dateTime'),
        SOAP::Data->prefix($SF_PREFIX)
          ->name( 'endDate' => $in{'end'} )
          ->type('xsd:dateTime'),
        $self->get_session_header()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 getUserInfo

    my $res = $sf->getUserInfo();

The L<getUserInfo|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getuserinfo.htm>
method retrieves personal information for the user associated with the current
session.

=cut

sub getUserInfo {
    my $self   = shift;
    my $client = $self->get_client(1);
    my $r      = $client->getUserInfo( $self->get_session_header() );
    unless ($r) {
        die "could not getUserInfo";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 logout

    $sf->logout();

Ends the session for the logged-in user issuing the call. No arguments are needed.
Useful to avoid hitting the limit of ten open sessions per login.
L<Logout API Call|http://www.salesforce.com/us/developer/docs/api/Content/sforce_api_calls_logout.htm>

=cut

sub bye { shift->logout() }

sub logout {
    my $self = shift;

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("logout")->prefix($SF_PREFIX)->uri($SF_URI);
    my $r = $client->call( $method, $self->get_session_header() );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}



=head2 query

    my $soql = "SELECT Id, Name FROM Account";
    my $limit = 25;

    my $res = $sf->query(query => $soql);
    # or limit our result set
    $res = $sf->query(query => $soql, limit => $limit);

The L<query|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_query.htm>
method executes the given
L<SOQL Statement|https://developer.salesforce.com/docs/atlas.en-us.208.0.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_sosl_intro.htm>
and returns the result set. This query will not include deleted records.

=cut

sub query {
    my $self = shift;
    my %in = %{_parse_args(@_)};
    if ( !defined $in{'query'} || !length $in{'query'} ) {
        die("A query is needed for the query() method.");
    }
    if ( !defined $in{'limit'} || $in{'limit'} !~ m/^\d+$/ ) {
        $in{'limit'} = 500;
    }
    if ( $in{'limit'} < 1 || $in{'limit'} > 2000 ) {
        die("A query's limit cannot exceed 2000. 500 is default.");
    }

    my $limit = SOAP::Header->name(
        'QueryOptions' => \SOAP::Header->name( 'batchSize' => $in{'limit'} ) )
      ->prefix($SF_PREFIX)->uri($SF_URI);
    my $client = $self->get_client();
    my $r = $client->query( SOAP::Data->type( 'string' => $in{'query'} ),
        $limit, $self->get_session_header() );

    unless ($r) {
        die "could not query " . $in{'query'};
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 queryAll

    my $soql = "SELECT Id, Name FROM Account";
    my $limit = 25;

    my $res = $sf->queryAll(query => $soql);
    # or limit our result set
    $res = $sf->queryAll(query => $soql, limit => $limit);

The L<queryAll|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_queryall.htm>
method is exactly like the L<WWW::Salesforce/"query"> method with the exception
that it has read-only access to deleted records as well.

=cut

sub queryAll {
    my $self = shift;
    my %in = %{_parse_args(@_)};
    if ( !defined $in{'query'} || !length $in{'query'} ) {
        die("A query is needed for the query() method.");
    }
    if ( !defined $in{'limit'} || $in{'limit'} !~ m/^\d+$/ ) {
        $in{'limit'} = 500;
    }
    if ( $in{'limit'} < 1 || $in{'limit'} > 2000 ) {
        die("A query's limit cannot exceed 2000. 500 is default.");
    }

    my $limit = SOAP::Header->name(
        'QueryOptions' => \SOAP::Header->name( 'batchSize' => $in{'limit'} ) )
      ->prefix($SF_PREFIX)->uri($SF_URI);
    my $client = $self->get_client();
    my $r = $client->queryAll( SOAP::Data->name( 'queryString' => $in{'query'} ),
        $limit, $self->get_session_header() );

    unless ($r) {
        die "could not query " . $in{'query'};
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 queryMore

    my $res = $sf->query(query => "select Name from Contact");
    my @rows;
    push @rows, $res->valueof('//queryResponse/result/records')
      if ( $res->valueof('//queryResponse/result/size') > 0 );

    # do the extra queries if we aren't done
    my $done = $res->valueof('//queryResponse/result/done');
    my $locator = $res->valueof('//queryResponse/result/queryLocator');
    while (!$done || $done eq 'false') {
        # requires a queryLocator parameter
        my $more = $sf->queryMore(queryLocator => $locator);
        push @rows, $more->valueof('//queryResponse/result/records')
          if ( $more->valueof('//queryResponse/result/size') > 0 );

        $done = $more->valueof('//queryResponse/result/done');
        $locator = $more->valueof('//queryResponse/result/queryLocator');
    }
    say "Found ", scalar(@rows), " rows";

The L<queryMore|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_querymore.htm>
method retrieves the next batch of objects from a L<WWW::Salesforce/"query"> or
L<WWW::Salesforce/"queryAll"> method call.

=cut

sub queryMore {
    my $self = shift;
    my %in = %{_parse_args(@_)};
    if ( !defined $in{'queryLocator'} || !length $in{'queryLocator'} ) {
        die("A hash expected with key 'queryLocator'");
    }
    $in{'limit'} = 500
      if ( !defined $in{'limit'} || $in{'limit'} !~ m/^\d+$/ );
    if ( $in{'limit'} < 1 || $in{'limit'} > 2000 ) {
        die("A query's limit cannot exceed 2000. 500 is default.");
    }

    my $limit = SOAP::Header->name(
        'QueryOptions' => \SOAP::Header->name( 'batchSize' => $in{'limit'} ) )
      ->prefix($SF_PREFIX)->uri($SF_URI);
    my $client = $self->get_client();
    my $r      = $client->queryMore(
        SOAP::Data->name( 'queryLocator' => $in{'queryLocator'} ),
        $limit, $self->get_session_header() );

    unless ($r) {
        die "could not queryMore " . $in{'queryLocator'};
    }

    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 resetPassword

    my $res = $sf->resetPassword(userId => '01t500000016RuaAAE');

The L<resetPassword|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_resetpassword.htm>
method will change a user's password to a server-generated value.

=cut

sub resetPassword {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    if ( !defined $in{'userId'} || !length $in{'userId'} ) {
        die("A hash expected with key 'userId'");
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("resetPassword")->prefix($SF_PREFIX)->uri($SF_URI);
    my $r = $client->call(
        $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'userId' => $in{'userId'} )
          ->type('xsd:string'),
        $self->get_session_header()
    );

    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

=head2 retrieve

    # all parameters are strings and are required
    my $res = $sf->retrieve(
        type => 'Contact',
        fields => 'FirstName,LastName,Id', # comma separated list in a string
        ids => '01t500000016RuaAAE,01t500000016RuaAAF',
        # however, limit is optional and is an integer
        limit => 500,
    );

The L<retrieve|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_retrieve.htm>
method retrieves individual records from a given object type.

=cut

sub retrieve {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    $in{'limit'} = 500
      if ( !defined $in{'limit'} || $in{'limit'} !~ m/^\d+$/ );
    if ( $in{'limit'} < 1 || $in{'limit'} > 2000 ) {
        die("A query's limit cannot exceed 2000. 500 is default.");
    }
    if ( !defined $in{'fields'} || !length $in{'fields'} ) {
        die("Hash with key 'fields' expected.");
    }
    if ( !defined $in{'ids'} || !length $in{'ids'} ) {
        die("Hash with key 'ids' expected.");
    }
    if ( !defined $in{'type'} || !length $in{'type'} ) {
        die("Hash with key 'type' expected.");
    }

    my @elems;
    my $client = $self->get_client(1);
    my $method = SOAP::Data->name("retrieve")->prefix($SF_PREFIX)->uri($SF_URI);
    foreach my $id ( @{ $in{'ids'} } ) {
        push( @elems,
            SOAP::Data->prefix($SF_PREFIX)->name( 'ids' => $id )
              ->type('xsd:string') );
    }
    my $r = $client->call(
        $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'fieldList' => $in{'fields'} )
          ->type('xsd:string'),
        SOAP::Data->prefix($SF_PREFIX)->name( 'sObjectType' => $in{'type'} )
          ->type('xsd:string'),
        @elems,
        $self->get_session_header()
    );

    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 search

    my $res = $sf->search(
        searchString => 'FIND {4159017000} IN Phone FIELDS RETURNING Account(Id, Phone, Name)',
    );

The L<search|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_search.htm>
method searches for records based on a search string
(L<SOSL String|https://developer.salesforce.com/docs/atlas.en-us.208.0.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_sosl_intro.htm>).

=cut

sub search {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    if ( !defined $in{'searchString'} || !length $in{'searchString'} ) {
        die("Expected hash with key 'searchString'");
    }
    my $client = $self->get_client(1);
    my $method = SOAP::Data->name("search")->prefix($SF_PREFIX)->uri($SF_URI);
    my $r      = $client->call(
        $method => SOAP::Data->prefix($SF_PREFIX)
          ->name( 'searchString' => $in{'searchString'} )->type('xsd:string'),
        $self->get_session_header()
    );

    unless ($r) {
        die "could not search with " . $in{'searchString'};
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 setPassword

    my $res = $sf->setPassword(
        userId => '01t500000016RuaAAE',
        password => 'Some new password!',
    );

The L<setPassword|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_setpassword.htm>
method sets the specified user's password to the specified value.

=cut

sub setPassword {
    my $self = shift;
    my %in = %{_parse_args(@_)};

    if ( !defined $in{'userId'} || !length $in{'userId'} ) {
        die("Expected a hash with key 'userId'");
    }
    if ( !defined $in{'password'} || !length $in{'password'} ) {
        die("Expected a hash with key 'password'");
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("setPassword")->prefix($SF_PREFIX)->uri($SF_URI);
    my $r = $client->call(
        $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'userId' => $in{'userId'} )
          ->type('xsd:string'),
        SOAP::Data->prefix($SF_PREFIX)->name( 'password' => $in{'password'} )
          ->type('xsd:string'),
        $self->get_session_header()
    );

    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 sf_date

    my $date = $sf->sf_date(time);
    # Or, as a class method
    $date = WWW::Salesforce->sf_date(time);
    say $date; # 2017-09-21T08:42:42.000-0400

Converts a time in Epoch seconds to the date format that Salesforce likes.

=cut

sub sf_date {
    my $self = shift;
    my $secs = shift || time;
    my $dt = DateTime->from_epoch(epoch=>$secs);
    $dt->set_time_zone('local');
    return $dt->strftime(q(%FT%T.%3N%z));
}


=head2 update

    # an array of hash-refs representing SObjects is expected
    my $res = $sf->update({
        Id => '01t500000016RuaAAE',
        Type => 'Account',
        Name => "Bender's Shiny Metal Co.", # Update our Account name
    });

The L<update|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_update.htm>
method is analogous to a SQL C<UPDATE> statement.

The only requirement is that each object represented by a hash reference must
contain one key called C<id> or C<Id> and a C<type> or C<Type> key. The other
keys in the hash reference are the fields we'll be updating for the given object.

B<* Note:> As of version C<20.0> of the Salesforce API, you can now update
objects of differing types. This makes passing the object C<type> as the first
argument no longer necessary. Just pass an array of hash references.

=cut

sub update {
    my $self = shift;
    die "Expected an array of hash references" unless @_;

    my $type;
    unless (ref($_[0])) {
        my $spec = shift;
        my $type = shift;
        if ($spec ne 'type' || !$type) {
            die "Expected a hash with key 'type'";
        }
    }

    my %tmp      = ();
    my @sobjects = @_;
    if ( ref $sobjects[0] ne 'HASH' ) {
        %tmp      = @_;
        @sobjects = ( \%tmp );    # create an array of one
    }

    my @updates;
    foreach (@sobjects) {         # arg list is now an array of hash refs
        my %in = %{$_};

        my $id = $in{id} || $in{Id};
        my $otype = $in{type} || $in{Type} || $type;
        delete $in{id};
        delete $in{Id};
        delete $in{type};
        delete $in{Type};
        die("Expected a hash with key 'id'") unless $id;

        my @elems;
        my @fieldsToNull;
        push @elems,
          SOAP::Data->prefix($SF_PREFIX)->name( 'Id' => $id )
          ->type('sforce:ID');
        foreach my $key ( keys %in ) {
            if ( !defined $in{$key} ) {
                push @fieldsToNull, $key;
            }
            else {
                push @elems,
                  SOAP::Data->prefix($SF_PREFIX)->name( $key => $in{$key} )
                  ->type( WWW::Salesforce::Constants->type( $otype, $key ) );
            }
        }
        for my $key ( @fieldsToNull ) {
            push @elems,
            SOAP::Data->prefix($SF_PREFIX)->name( fieldsToNull => $key )
            ->type( 'xsd:string' );
        }
        push @updates,
          SOAP::Data->name( 'sObjects' => \SOAP::Data->value(@elems) )
          ->attr( { 'xsi:type' => 'sforce:' . $type } );
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("update")->prefix($SF_PREFIX)->uri($SF_URI)
      ->attr( { 'xmlns:sfons' => $SF_SOBJECT_URI } );
    my $r = $client->call(
        $method => $self->get_session_header(),
        @updates
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


=head2 upsert

    my $res = $sf->upsert('externalIDFieldName',
        {
            Type => 'Account', # each object must have a type
            externalIDFieldName => '01t500000016RuaAAE', # key field name
            Name => "Bender's Shiny Metal Co.",
        },
        # up to 200 objects possible for upsert
        {
            Type => 'Contact', # each object must have a type
            externalIDFieldName => '01t500000016RuaAAE', # key field name
            Name => "Bender Robot",
        }
    );
    # or, the old way
    $res = $sf->upsert(
        type => 'Account',
        key => 'externalIDFieldName',
        {
            externalIDFieldName => '01t500000016RuaAAE', # key field name
            Name => "Bender's Shiny Metal Co.",
        }
    );

The L<upsert|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_upsert.htm>
method creates new records and updates existing records; uses a custom field to
determine the presence of existing records. In most cases, we recommend that
you use C<upsert> instead of L<WWW::Salesforce/"create"> to avoid creating
unwanted duplicate records (idempotent).

=cut

sub upsert {
    my $self = shift;
    my @sobjects;
    # bugwards compatible param checking. *sigh*
    # the last parameters should always be hash references (SObjects)
    while ($_[-1] && ref($_[-1]) eq 'HASH') {
        push @sobjects, pop;
    }

    # Whatever's left on the call stack tells us what we're dealing with
    # we no longer need the type from here, but it used to be required
    # key and externalIDFieldName are synonymous
    # type => 'Account', key => 'Id'
    # type => 'Account', 'Id'
    # 'Account', 'Id'
    # 'Id'
    my ($type, $field_name);
    if (@_ == 4) {
        (undef, $type, undef, $field_name) = @_;
    }
    elsif (@_ == 3) {
        (undef, $type, $field_name) = @_;
    }
    elsif (@_ == 2) {
        ($type, $field_name) = @_;
    }
    elsif (@_ == 1) {
        $field_name = shift;
    }
    elsif (@_ % 2 == 0 && !@sobjects) {
        push @sobjects, _parse_args(@_);
    }

    unless (@sobjects) {
        die("Expected an array of SObjects (hash references) to be upserted");
    }
    # Defaults
    $type ||= '';
    $field_name ||= 'id';

    my %tmp = ();
    my @updates =
      ( SOAP::Data->prefix($SF_PREFIX)->name( 'externalIDFieldName' => $field_name )
          ->attr( { 'xsi:type' => 'xsd:string' } ) );

    foreach (@sobjects) {         # arg list is now an array of hash refs
        my %in = %{$_};

        my @elems;
        my @fieldsToNull;
        my $otype = $in{type} || $in{Type} || $type;
        delete $in{type};
        delete $in{Type};
        foreach my $key ( keys %in ) {
            if ( !defined $in{$key} ) {
                push @fieldsToNull, $key;
            }
            else {
                push @elems,
                SOAP::Data->prefix($SF_PREFIX)->name( $key => $in{$key} )
                ->type( WWW::Salesforce::Constants->type( $otype, $key ) );
            }
        }
        for my $key ( @fieldsToNull ) {
            push @elems,
            SOAP::Data->prefix($SF_PREFIX)->name( fieldsToNull => $key )
            ->type( 'xsd:string' );
        }
        push @updates,
          SOAP::Data->name( 'sObjects' => \SOAP::Data->value(@elems) )
          ->attr( { 'xsi:type' => 'sforce:' . $otype } );
    }

    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("upsert")->prefix($SF_PREFIX)->uri($SF_URI)
      ->attr( { 'xmlns:sfons' => $SF_SOBJECT_URI } );
    my $r = $client->call(
        $method => $self->get_session_header(),
        @updates
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}


sub get_clientM {
    my $self = shift;
    my ($readable) = @_;
    $readable = ($readable) ? 1 : 0;

    my $client =
      SOAP::Lite->readable($readable)
      ->deserializer( WWW::Salesforce::Deserializer->new )
      ->serializer( WWW::Salesforce::Serializer->new )
      ->on_action( sub { return '""' } )->uri($SF_URI)->multirefinplace(1)
      ->proxy( $self->{'sf_metadataServerUrl'} )
      ->soapversion('1.1');
    return $client;
}

sub get_session_headerM {
    my ($self) = @_;
    return SOAP::Header->name( 'SessionHeader' =>
          \SOAP::Header->name( 'sessionId' => $self->{'sf_sid'} ) )
      ->uri($SF_URIM)->prefix($SF_PREFIX);
}

=head2 describeMetadata

Get some metadata info about your instance.

=cut

sub describeMetadata {
    my $self = shift;
    my $client = $self->get_clientM(1);
    my $method = SOAP::Data->name("describeMetadata")->prefix($SF_PREFIX)->uri($SF_URIM);

    my $r = $client->call(
        $method =>
            SOAP::Data->prefix($SF_PREFIX)->name( 'asOfVersion' )->value( $SF_APIVERSION ), $self->get_session_headerM()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r->valueof('//describeMetadataResponse/result');
}


=head2 retrieveMetadata

=cut

sub retrieveMetadata {
    my $self = shift;
    my %list = @_;
    my @req;
    foreach my $i (keys %list) {
       push (@req,SOAP::Data->name('types'=>
                        \SOAP::Data->value(
                            SOAP::Data->name('members'=>$list{$i}),
                            SOAP::Data->name('name'=>$i)
                        )
                    ));
    }
    my $client = $self->get_clientM(1);
    my $method =
      SOAP::Data->name('retrieve')->prefix($SF_PREFIX)->uri($SF_URIM);
    my $r = $client->call(
            $method,
            $self->get_session_headerM(),
SOAP::Data->name('retrieveRequest'=>
       \SOAP::Data->value(
       SOAP::Data->name( 'apiVersion'=>$SF_APIVERSION),
       SOAP::Data->name( 'singlePackage'=>'true'),
       SOAP::Data->name('unpackaged'=>
                   \SOAP::Data->value( @req
           ,SOAP::Data->name('version'=>$SF_APIVERSION))
         )
       )
     )
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    $r = $r->valueof('//retrieveResponse/result');
    return $r;
}


=head2 checkAsyncStatus

=cut

sub checkAsyncStatus {
    my $self = shift;
    my $pid = shift;
    #print "JOB - ID $pid\n";
    my $client = $self->get_clientM(1);
    my $method = SOAP::Data->name('checkStatus')->prefix($SF_PREFIX)->uri($SF_URIM);
    my $r;
    my $waitTimeMilliSecs = 1;
    my $Count =1 ;
    my $MAX_NUM_POLL_REQUESTS = 50;
    while (1) {
        sleep($waitTimeMilliSecs);
        $waitTimeMilliSecs *=2;
        $r = $client->call(
                $method,
                SOAP::Data->name('asyncProcessId'=>$pid)->type('xsd:ID'),
                $self->get_session_headerM()
        );
        unless ($r) {
            die "could not call method $method";
        }
        if ( $r->fault() ) {
            die( $r->faultstring() );
        }
        $r = $r->valueof('//checkStatusResponse/result');
        last if ($r->{'done'} eq 'true' || $Count >$MAX_NUM_POLL_REQUESTS);
        $Count++;
    }
    if ($r->{'done'} eq 'true') {
        return $self->checkRetrieveStatus($r->{'id'});
    }
    return;
}


=head2 checkRetrieveStatus

=cut

sub checkRetrieveStatus {
    my $self = shift;
    my $pid = shift;
    my $client = $self->get_clientM(1);
    my $method = SOAP::Data->name('checkRetrieveStatus')->prefix($SF_PREFIX)->uri($SF_URIM);

    my $r = $client->call(
            $method,
            SOAP::Data->name('asyncProcessId'=>$pid),
            $self->get_session_headerM()
    );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r->valueof('//checkRetrieveStatusResponse/result');
}


=head2 getErrorDetails

Returns a hash with information about errors from API calls - only useful if ($res->valueof('//success') ne 'true')

  {
      'statusCode' => 'INVALID_FIELD_FOR_INSERT_UPDATE',
      'message' => 'Account: bad field names on insert/update call: type'
      ...
  }

=cut

sub getErrorDetails {
    my $self = shift;
    my $result = shift;
    return $result->valueof('//errors');
}


=head2 bye

Synonym for L<WWW::Salesforce/"logout">.


=head2 do_query

Returns a reference to an array of hash refs

=cut

sub do_query {
    my ( $self, $query, $limit ) = @_;

    if ( !defined $query || $query !~ m/^select/i ) {
        die('Param1 of do_query() should be a string SQL query');
    }

    $limit = 2000
      unless defined $limit
          and $limit =~ m/^\d+$/
          and $limit > 0
          and $limit < 2001;

    my @rows = ();    #to be returned

    my $res = $self->query( query => $query, limit => $limit );
    unless ($res) {
        die "could not execute query $query, limit $limit";
    }
    if ( $res->fault() ) {
        die( $res->faultstring() );
    }

    push @rows, $res->valueof('//queryResponse/result/records')
      if ( $res->valueof('//queryResponse/result/size') > 0 );

    #we get the results in batches of 2,000... so continue getting them
    #if there are more to get
    my $done = $res->valueof('//queryResponse/result/done');
    my $ql   = $res->valueof('//queryResponse/result/queryLocator');
    if ( $done eq 'false' ) {
        push @rows, @{$self->_retrieve_queryMore($ql, $limit)};
    }

    return \@rows;
}


=head2 do_queryAll

    my $soql_query = "Select Name from Contact";
    my $limit = 10;

    # get all contacts
    my $res = $sf->do_queryAll($soql_query);
    # only get 10 contacts
    $res = $sf->do_queryAll($soql_query, $limit)

Returns a reference to an array of hash refs

=cut

sub do_queryAll {
    my ( $self, $query, $limit ) = @_;

    if ( !defined $query || $query !~ m/^select/i ) {
        die('Param1 of do_queryAll() should be a string SQL query');
    }

    $limit = 2000
      unless defined $limit
          and $limit =~ m/^\d+$/
          and $limit > 0
          and $limit < 2001;

    my @rows = ();    #to be returned

    my $res = $self->queryAll( query => $query, limit => $limit );
    unless ($res) {
        die "could not execute query $query, limit $limit";
    }
    if ( $res->fault() ) {
        die( $res->faultstring() );
    }

    push @rows, $res->valueof('//queryAllResponse/result/records')
      if ( $res->valueof('//queryAllResponse/result/size') > 0 );

    #we get the results in batches of 2,000... so continue getting them
    #if there are more to get
    my $done = $res->valueof('//queryAllResponse/result/done');
    my $ql   = $res->valueof('//queryAllResponse/result/queryLocator');
    if ( $done eq 'false' ) {
        push @rows, @{$self->_retrieve_queryMore($ql, $limit)};
    }

    return \@rows;
}

#**************************************************************************
# _retrieve_queryMore
#  -- returns the next block of a running query set. Supports do_query
#     and do_queryAll
#
#**************************************************************************

sub _retrieve_queryMore {
    my ( $self, $ql, $limit ) = @_;

    my $done = 'false';
    my @results;

    while ($done eq 'false') {
        my $res = $self->queryMore(
            queryLocator => $ql,
            limit        => $limit
        );
        unless ($res) {
            die "could not execute queryMore $ql, limit $limit";
        }
        if ( $res->fault() ) {
            die( $res->faultstring() );
        }
        $done = $res->valueof('//queryMoreResponse/result/done');
        $ql   = $res->valueof('//queryMoreResponse/result/queryLocator');

        if ( $res->valueof('//queryMoreResponse/result/size') ) {
            push @results, $res->valueof('//queryMoreResponse/result/records');
        }
    }

    return \@results;

}

=head2 get_field_list

    my $fields = $sf->get_field_list();

Returns a reference to an array of hash references for each field name.
Field name keyed as C<name>

=cut

sub get_field_list {
    my ( $self, $table_name ) = @_;

    if ( !defined $table_name || !length $table_name ) {
        die('Param1 of get_field_list() should be a string');
    }

    my $res = $self->describeSObject( 'type' => $table_name );
    unless ($res) {
        die "could not describeSObject for table $table_name";
    }
    if ( $res->fault() ) {
        die( $res->faultstring() );
    }

    my @fields = $res->valueof('//describeSObjectResponse/result/fields');
    return \@fields;
}


=head2 get_tables

    my $tables = $sf->get_tables();

Returns a reference to an array of hash references.
Each hash gives the properties for each Salesforce object

=cut

sub get_tables {
    my ($self) = @_;

    my $res = $self->describeGlobal();
    unless ($res) {
        die "could not describeGlobal()";
    }
    if ( $res->fault() ) {
        die( $res->faultstring() );
    }

    my @globals = $res->valueof('//describeGlobalResponse/result/sobjects');
    return \@globals;
}


1;
__END__

=head1 AUTHORS

Byrne Reese - <byrne at majordojo dot com>

Chase Whitener <F<capoeirab@cpan.org>>

Fred Moyer <fred at redhotpenguin dot com>

=head1 CONTRIBUTORS

Michael Blanco

Garth Webb

Jun Shimizu

Ron Hess

Tony Stubblebine

=head1 COPYRIGHT & LICENSE

Copyright 2003 Byrne Reese, Chase Whitener, Fred Moyer. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
