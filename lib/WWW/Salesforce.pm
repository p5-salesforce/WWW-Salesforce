package WWW::Salesforce;

use 5.008001;

use strict;
use warnings;

use SOAP::Lite;    # ( +trace => 'all', readable => 1, );#, outputxml => 1, );
                   #use Data::Dumper;
use WWW::Salesforce::Constants;
use WWW::Salesforce::Deserializer;
use WWW::Salesforce::Serializer;

use vars qw(
  $VERSION $SF_URI $SF_PREFIX $SF_PROXY $SF_SOBJECT_URI $SF_URIM $SF_APIVERSION
);

$VERSION = '0.17';

$SF_PROXY       = 'https://www.salesforce.com/services/Soap/u/8.0';
$SF_URI         = 'urn:partner.soap.sforce.com';
$SF_PREFIX      = 'sforce';
$SF_SOBJECT_URI = 'urn:sobject.partner.soap.sforce.com';
$SF_URIM        = 'http://soap.sforce.com/2006/04/metadata';
$SF_APIVERSION  = '23.0';

#
#**************************************************************************
# new( %params )
#   -- DEPRECATED
#**************************************************************************
sub new {
    warn("WWW::Salesforce->new() is deprecated. use login()");
    return login(@_);
}

#**************************************************************************
# convertLead()     -- API
#   -- Converts a Lead into an Account, Contact, or (optionally)
#       an Opportunity
#**************************************************************************
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

#**************************************************************************
# create()     -- API
#   -- Adds one or more new individual objects to your organization's data
#**************************************************************************
sub create {
    my $self = shift;
    my (%in) = @_;

    if ( !keys %in ) {
        die("Expected a hash of arrays.");
    }
    my $client = $self->get_client(1);
    my $method =
      SOAP::Data->name("create")->prefix($SF_PREFIX)->uri($SF_URI)
      ->attr( { 'xmlns:sfons' => $SF_SOBJECT_URI } );

    my $type = $in{'type'};
    delete( $in{'type'} );

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

#**************************************************************************
# delete()     -- API
#   -- Deletes one or more individual objects from your org's data
#**************************************************************************
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

#**************************************************************************
# describeGlobal()     -- API
#   -- Retrieves a list of available objects for your organization's data
#**************************************************************************
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

#**************************************************************************
# describeLayout()     -- API
#   -- retrieve information about the layout (presentation of data to
#       users) for a given object type.
#**************************************************************************
sub describeLayout {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# describeSObject()     -- API
#   -- Describes metadata (field list and object properties) for the
#       specified object.
#**************************************************************************
sub describeSObject {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# describeSObjects()        --API
#   -- An array-based version of describeSObject; describes metadata
#       (field list and object properties) for the specified object
#       or array of objects.
#**************************************************************************
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

#**************************************************************************
# describeTabs()        --API
#   -- returns information about the standard apps and custom apps, if
#       any, available for the user who sends the call, including the list
#       of tabs defined for each app.
#**************************************************************************
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

#**************************************************************************
# get_client( $readable )
#   -- get a client
#**************************************************************************
sub get_client {
    my $self = shift;
    my ($readable) = @_;
    $readable = ($readable) ? 1 : 0;

    my $client =
      SOAP::Lite->readable($readable)
      ->deserializer( WWW::Salesforce::Deserializer->new )
      ->serializer( WWW::Salesforce::Serializer->new )
      ->on_action( sub { return '""' } )->uri($SF_URI)->multirefinplace(1)
      ->proxy( $self->{'sf_serverurl'} );
    return $client;
}

#**************************************************************************
# get_session_header( $mustunderstand )
#   -- gets the session header
#**************************************************************************
sub get_session_header {
    my ($self) = @_;
    return SOAP::Header->name( 'SessionHeader' =>
          \SOAP::Header->name( 'sessionId' => $self->{'sf_sid'} ) )
      ->uri($SF_URI)->prefix($SF_PREFIX);
}

#**************************************************************************
# getDeleted() -- API
#   -- Retrieves the list of individual objects that have been deleted
#       within the given timespan for the specified object.
#**************************************************************************
sub getDeleted {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# getServerTimestamp() -- API
#   -- Retrieves the current system timestamp (GMT) from the Web service.
#**************************************************************************
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

#**************************************************************************
# getUpdated()  --API
#   -- Retrieves the list of individual objects that have been updated
#       (added or changed) within the given timespan for the specified
#       object.
#**************************************************************************
sub getUpdated {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# getUserInfo()  --API
#   -- Retrieves personal information for the user associated with the
#       current session.
#**************************************************************************
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

#**************************************************************************
# login( %params ) --API
#   -- logs a user into Sforce and returns a WWW::Salesforce object or 0
#**************************************************************************
sub login {
    my $class = shift;
    my (%params) = @_;

    unless ( defined $params{'username'} and length $params{'username'} ) {
        die("WWW::Salesforce::login() requires a username");
    }
    unless ( defined $params{'password'} and length $params{'password'} ) {
        die("WWW::Salesforce::login() requires a password");
    }
    my $self = {
        sf_user      => $params{'username'},
        sf_pass      => $params{'password'},
        sf_serverurl => $SF_PROXY,
        sf_sid       => undef,                 #session ID
    };
    $self->{'sf_serverurl'} = $params{'serverurl'}
      if ( $params{'serverurl'} && length( $params{'serverurl'} ) );
    bless $self, $class;

    my $client = $self->get_client();
    my $r      = $client->login(
        SOAP::Data->name( 'username' => $self->{'sf_user'} ),
        SOAP::Data->name( 'password' => $self->{'sf_pass'} )
    );
    unless ($r) {
        die sprintf( "could not login, user %s, pass %s",
            $self->{'sf_user'}, $self->{'sf_pass'} );
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }

    $self->{'sf_sid'}       = $r->valueof('//loginResponse/result/sessionId');
    $self->{'sf_uid'}       = $r->valueof('//loginResponse/result/userId');
    $self->{'sf_serverurl'} = $r->valueof('//loginResponse/result/serverUrl');
    $self->{'sf_metadataServerUrl'} = $r->valueof('//loginResponse/result/metadataServerUrl');
    return $self;
}

#**************************************************************************
# query( %in )  --API
#   -- runs a query against salesforce
#**************************************************************************
sub query {
    my $self = shift;
    my (%in) = @_;
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
    my $r = $client->query( SOAP::Data->name( 'queryString' => $in{'query'} ),
        $limit, $self->get_session_header() );

    unless ($r) {
        die "could not query " . $in{'query'};
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r;
}

#**************************************************************************
# queryAll( %in )  --API
#   -- runs a query against salesforce including archived and deleted 
#      objects in its return
#**************************************************************************
sub queryAll {
    my $self = shift;
    my (%in) = @_;
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

#**************************************************************************
# queryMore()  --API
#   -- query from where you last left off
#**************************************************************************
sub queryMore {
    my $self = shift;
    my (%in) = @_;
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

#**************************************************************************
# resetPassword()  --API
#   -- reset your password
#**************************************************************************
sub resetPassword {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# retrieve()  --API
#   -- Retrieves one or more objects based on the specified object IDs.
#**************************************************************************
sub retrieve {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# search()  --API
#   -- Executes a text search in your organization's data.
#**************************************************************************
sub search {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# setPassword()  --API
#   -- Sets the specified user's password to the specified value.
#**************************************************************************
sub setPassword {
    my $self = shift;
    my (%in) = @_;

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

#**************************************************************************
# update()  --API
#   -- Updates one or more existing objects in your organization's data.
#**************************************************************************
sub update {
    my $self = shift;

    my ( $spec, $type ) = splice @_, 0, 2;
    if ( $spec ne 'type' || !$type ) {
        die("Expected a hash with key 'type' as first argument");
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

        my $id = $in{'id'};
        delete( $in{'id'} );
        if ( !$id ) {
            die("Expected a hash with key 'id'");
        }

        my @elems;
        push @elems,
          SOAP::Data->prefix($SF_PREFIX)->name( 'Id' => $id )
          ->type('sforce:ID');
        foreach my $key ( keys %in ) {
            push @elems,
              SOAP::Data->prefix($SF_PREFIX)->name( $key => $in{$key} )
              ->type( WWW::Salesforce::Constants->type( $type, $key ) );
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

#**************************************************************************
# upsert()  --API
#   -- Creates new objects and updates existing objects;
#      uses a custom field to determine the presence of existing objects.
#**************************************************************************
sub upsert {
    my $self = shift;
    my ( $spec, $type, $extern, $name, @sobjects ) = @_;

    if ( $spec ne 'type' || !$type ) {
        die("Expected a hash with key 'type' as first argument");
    }

    # Default to the 'id' field
    $name ||= 'id';

    my %tmp = ();
    if ( ref $sobjects[0] ne 'HASH' ) {
        %tmp      = @_;
        @sobjects = ( \%tmp );    # create an array of one
    }

    my @updates =
      ( SOAP::Data->prefix($SF_PREFIX)->name( 'externalIDFieldName' => $name )
          ->attr( { 'xsi:type' => 'xsd:string' } ) );

    foreach (@sobjects) {         # arg list is now an array of hash refs
        my %in = %{$_};

        my @elems;
        foreach my $key ( keys %in ) {
            push @elems,
              SOAP::Data->prefix($SF_PREFIX)->name( $key => $in{$key} )
              ->type( WWW::Salesforce::Constants->type( $type, $key ) );
        }
        push @updates,
          SOAP::Data->name( 'sObjects' => \SOAP::Data->value(@elems) )
          ->attr( { 'xsi:type' => 'sforce:' . $type } );
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

#
# NEW Methods
#
###########################

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

sub describeMetadata {
    my $self = shift;
    my $client = $self->get_clientM(1);
    my $method =
      SOAP::Data->name("describeMetadata")->prefix($SF_PREFIX)->uri($SF_URIM);

    my $r = $client->call(
          $method =>
          SOAP::Data->prefix($SF_PREFIX)->name( 'asOfVersion' )->value( $SF_APIVERSION ), $self->get_session_headerM() );
    unless ($r) {
        die "could not call method $method";
    }
    if ( $r->fault() ) {
        die( $r->faultstring() );
    }
    return $r->valueof('//describeMetadataResponse/result');
}

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



#magically delicious
1;
__END__

=head1 NAME

WWW::Salesforce - this class provides a simple abstraction layer between SOAP::Lite and Salesforce.com.

=head1 SYNOPSIS

    use WWW::Salesforce;
    my $sforce = eval { WWW::Salesforce->login( username => 'foo',
                                                password => 'bar' ); };
    die "Could not login to SFDC: $@" if $@;

    # eval, eval, eval.  WWW::Salesforce uses a SOAP connection to
    # salesforce.com, so things can go wrong unexpectedly.  Be prepared
    # by eval'ing and handling any exceptions that occur.

=head1 DESCRIPTION

This class provides a simple abstraction layer between SOAP::Lite and Salesforce.com. Because SOAP::Lite does not support complexTypes, and document/literal encoding is limited, this module works around those limitations and provides a more intuitive interface a developer can interact with.

=head2 METHODS

=over 

=item login( HASH )

The C<login> method returns an object of type WWW::Salesforce if the login attempt was successful, and 0 otherwise. Upon a successful login, the sessionId is saved and the serverUrl set properly so that developers need not worry about setting these values manually. Upon failure, the method dies with an error string.

The following are the accepted input parameters:

=over

=item username

A Salesforce.com username.

=item password

The password for the user indicated by C<username>.

=back

=item convertLead( HASH )

The C<convertLead> method returns an object of type SOAP::SOM if the login attempt was successful, and 0 otherwise.

The following are the accepted input parameters:

=over

=item %hash_of_array_references

    leadId => [ 2345, 5678, ],
    contactId => [ 9876, ],

=back

=item create( HASH )

Adds one new individual objects to your organization's data. This takes as input a HASH containing the fields (the keys of the hash) and the values of the record you wish to add to your arganization.
The hash must contain the 'type' key in order to identify the type of the record to add.

Returns a SOAP::Lite object.  Success of this operation can be gleaned from
the envelope result.

    $r->envelope->{Body}->{createResponse}->{result}->{success};

=over

=back

=item delete( ARRAY )

Deletes one or more individual objects from your organization's data. This subroutine takes as input an array of SCALAR values, where each SCALAR is an sObjectId.

=over

=back

=item query( HASH )

Executes a query against the specified object and returns data that matches the specified criteria.

=over 

=item query

The query string to use for the query. The query string takes the form of a I<basic> SQL statement. For example, "SELECT Id,Name FROM Account".

=item limit

This sets the batch size, or size of the result returned. This is helpful in producing paginated results, or fetch small sets of data at a time.

=back

=item queryAll( HASH )

Executes a query against the specified object and returns data that matches the
specified criteria including archived and deleted objects.

=over 

=item query

The query string to use for the query. The query string takes the form of a I<basic> SQL statement. For example, "SELECT Id,Name FROM Account".

=item limit

This sets the batch size, or size of the result returned. This is helpful in producing paginated results, or fetch small sets of data at a time.

=back

=item queryMore( HASH )

Retrieves the next batch of objects from a C<query> or C<queryAll>.

=over 

=item queryLocator

The handle or string returned by C<query>. This identifies the result set and cursor for fetching the next set of rows from a result set.

=item limit

This sets the batch size, or size of the result returned. This is helpful in producing paginated results, or fetch small sets of data at a time.

=back

=item update(type => $type, HASHREF [, HASHREF ...])

Updates one or more existing objects in your organization's data. This subroutine takes as input a B<type> value which names the type of object to update (e.g. Account, User) and one or more perl HASH references containing the fields (the keys of the hash) and the values of the record that will be updated.

The hash must contain the 'Id' key in order to identify the record to update.

=item upsert(type => $type, key => $key, HASHREF [, HASHREF ...])

Updates or inserts one or more objects in your organization's data.  If the data doesn't exist on Salesforce, it will be inserted.  If it already exists it will be updated.

This subroutine takes as input a B<type> value which names the type of object to update (e.g. Account, User).  It also takes a B<key> value which specificies the unique key Salesforce should use to determine if it needs to update or insert.  If B<key> is not given it will default to 'Id' which is Salesforces own internal unique ID.  This key can be any of Salesforces default fields or an custom field marked as an external key.

Finally, this method takes one or more perl HASH references containing the fields (the keys of the hash) and the values of the record that will be updated.

=item getServerTimestamp()

Retrieves the current system timestamp (GMT) from the sforce Web service.

=item getUserInfo( HASH )

Retrieves personal information for the user associated with the current session.

=over

=item user

A user ID

=back

=item getUpdated( HASH )

Retrieves the list of individual objects that have been updated (added or changed) within the given timespan for the specified object.

=over

=item type

Identifies the type of the object you wish to find updates for.

=item start

A string identifying the start date/time for the query

=item end

A string identifying the end date/time for the query

=back

=item getDeleted( HASH )

Retrieves the list of individual objects that have been deleted within the given timespan for the specified object.

=over

=item type

Identifies the type of the object you wish to find deletions for.

=item start

A string identifying the start date/time for the query

=item end

A string identifying the end date/time for the query

=back

=item describeSObject( HASH )

Describes metadata (field list and object properties) for the specified object.

=over

=item type

The type of the object you wish to have described.

=back

=item describeLayout( HASH )

Describes metadata about a given page layout, including layouts for edit and display-only views and record type mappings.

=over

=item type

The type of the object you wish to have described.

=back

=item describeGlobal()

Retrieves a list of available objects for your organization's data.

=item setPassword( HASH )

Sets the specified user's password to the specified value.

=over

=item userId

A user Id.

=item password

The new password to assign to the user identified by C<userId>.

=back

=item resetPassword( HASH )

Changes a user's password to a server-generated value.

=over

=item userId

A user Id.

=back

=item retrieve( HASH )

=over

=item fields

A comma delimitted list of field name you want retrieved.

=item type

The type of the object being queried.

=item ids

The ids (LIST) of the object you want returned.

=back

=item search( HASH )

=over

=item searchString

The search string to be used in the query. For example, "find {4159017000} in phone fields returning contact(id, phone, firstname, lastname), lead(id, phone, firstname, lastname), account(id, phone, name)"

=back

=back


=head1 EXAMPLES

=head2 login()

    use WWW::Salesforce;
    my $sf = WWW::Salesforce->login( 'username' => $user,'password' => $pass )
        or die $@;

=head2 search()

    my $query = 'find {4159017000} in phone fields returning contact(id, phone, ';
    $query .= 'firstname, lastname), lead(id, phone, firstname, lastname), ';
    $query .= 'account(id, phone, name)';
    my $result = $sforce->search( 'searchString' => $query );

=head1 SUPPORT

Please visit Salesforce.com's user/developer forums online for assistance with
this module. You are free to contact the author directly if you are unable to
resolve your issue online.

=head1 CAVEATS

The C<describeSObjects> and C<describeTabs> API calls are not yet complete. These will be 
completed in future releases.

Not enough test cases built into the install yet.  More to be added.

=head1 SEE ALSO

    L<DBD::Salesforce> by Jun Shimizu
    L<SOAP::Lite> by Byrne Reese

    Examples on Salesforce website:
    L<http://www.sforce.com/us/docs/sforce70/wwhelp/wwhimpl/js/html/wwhelp.htm>

=head1 HISTORY

This Perl module was originally provided and presented as part of
the first Salesforce.com dreamForce conference on Nov. 11, 2003 in
San Francisco.

=head1 AUTHORS

Fred Moyer <fred at redhotpenguin dot com>

Thanks to:

Chase Whitener <cwhitener at gmail dot com> -
Maintaining this module and working on development version.

Michael Blanco -
Finding and fixing some bugs.

Garth Webb - 
Finding and fixing bugs. Adding some additional features and more constant types.

Ron Hess -
Finding and fixing bugs. Adding some additional features. Adding more tests
to the build. Providing a lot of other help.

Tony Stubblebine -
Finding a bug and providing a fix.

Jun Shimizu - 
Providing more to the WWW::Salesforce::Constants module
and submitting fixes for various other bugs.

Byrne Reese - <byrne at majordojo dot com> -
Byrne Reese wrote the original Salesforce module.

=head1 COPYRIGHT

Copyright 2010 Fred Moyer, All rights reserved.

Copyright 2005-2007 Chase Whitener.

Copyright 2003-2004 Byrne Reese, Chase Whitener. All rights reserved.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut

