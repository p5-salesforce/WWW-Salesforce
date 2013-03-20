package WWW::Salesforce::Simple;

use 5.008001;
use strict;
use warnings;

use base 'WWW::Salesforce';

#handle versioning and exporting
use vars qw( $VERSION );
$VERSION = $WWW::Salesforce::VERSION;

#**************************************************************************
# new( %params ) ------CONSTRUCTOR
#   -- make a connection to salesforce using the API
#**************************************************************************
sub new {
    my ($class) = shift;
    my $self = $class->SUPER::login(@_) or die 'could not login';
    return $self;
}

#**************************************************************************
# bye () 
#   --  Ends the session for the logged-in user issuing the call. No arguments are needed.
#**************************************************************************
sub bye {
    my ( $self ) = @_; 
    $self->logout() or die 'could not logout';
}

#**************************************************************************
# do_query( $query, [$limit] )
#   -- returns a reference to an array of hash refs
#**************************************************************************
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

#**************************************************************************
# do_queryAll( $query, [$limit] )
#   -- returns a reference to an array of hash refs
#**************************************************************************
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

#**************************************************************************
# get_field_list( $table_name )
#   -- returns a ref to an array of hash refs for each field name...
#       --field name keyed as 'name'
#**************************************************************************
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

#**************************************************************************
# get_tables()
#   -- returns a reference to an array of hash references
#   -- each hash gives the properties for each salesforce object
#**************************************************************************
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

1;    #magically delicious
__END__

=pod

=head1 NAME

WWW::Salesforce::Simple.pm - this class provides a simpler abstraction layer between WWW::Salesforce and Salesforce.com.

=head1 DESCRIPTION

Because the Salesforce API is somewhat cumbersome to deal with, this class
was created to make it a little simpler to get information.

=head1 METHODS

This class inherits all the methods from L<WWW::Salesforce> and adds the following new ones.

=head2 new( %parameters )

Handles creating new Salesforce objects as well as the login process
to use the salesforce objects. 

=head2 do_query( $sql_query_string )

Executes a query against the information in Salesforce.  Returns a reference
to an array of hash references keyed by the column names. Strict attention
should be paid to the case of the field names.

=head2 do_queryAll( $sql_query_string )

Executes a query against the information in Salesforce.  Returns a reference
to an array of hash references keyed by the column names that includes deleted
and archived objects. Strict attention should be paid to the case of the field
names.

=head2 get_field_list( $table_name )

Gathers a list of fields contained in a given table.  Returns a reference
to an array of hash references.  The hash references have several keys
which provide information about the field's type, etc.  The key 'name'
will provide the name of the field itself.

=head2 get_tables( )

Gathers a list of tables available for use from salesforce.  Returns a
reference to an array of strings representing each table name.


=head1 EXAMPLES

=head2 new()

    use WWW::Salesforce::Simple;

    my $sforce = WWW::Salesforce::Simple->new(
        'username' => $user,
        'password' => $pass
    );

=head2 do_query( $query )

    my $query = 'select Id from Account';

    my $res = $sforce->do_query( $query );

    foreach my $field ( @{ $res } ) {
        print $field->{'Id'} . "\n";
    }
    print "Found " . scalar @{$res} . " results\n";    

=head2 do_queryAll( $query )

    my $query = 'select Id from Account';

    my $res = $sforce->do_queryAll( $query );

    foreach my $field ( @{ $res } ) {
        print $field->{'Id'} . "\n";
    }
    print "Found " . scalar @{$res} . " results\n";    

=head2 get_field_list( $table_name )

    my $fields_ref = $sforce->get_field_list( 'Account' );

    foreach my $field( @{$fields_ref} ) {
        print $field->{'name'} . "\n";
        foreach my $key ( keys %{$field} ) {
            print "\t $key --> ";
            print $field->{$key} if ( $field->{$key} );
            print "\n";
        }
        print "\n";
    }

=head2 get_tables()

    my $tables_ref = $sforce->get_tables();

    foreach my $table ( @{$tables_ref} ) {
        print "$table\n";
    }
    print "\n";

=head1 SUPPORT

Please visit Salesforce.com's user/developer forums online for assistance with
this module. You are free to contact the author directly if you are unable to
resolve your issue online.

=head1 AUTHORS

Fred Moyer <fred at redhotpenguin dot com>

Chase Whitener <cwhitener at gmail dot com>

=head1 COPYRIGHT

No Copyright
