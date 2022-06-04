# NAME

WWW::Salesforce - This class provides a simple SOAP client for Salesforce.com.

# SYNOPSIS

```perl
use Try::Tiny;
use WWW::Salesforce ();
try {
    my $sforce = WWW::Salesforce->login(
        username => 'foo',
        password => 'password' . 'pass_token',
        serverurl => 'https://test.salesforce.com',
        version => '52.0' # must be a string
    );
    my $res = $sforce->query(query => 'select Id, Name from Account');
    say "Found this many: ", $res->valueof('//queryResponse/result/size');
    my @records = $res->valueof('//queryResponse/result/records');
    say $records[0];
}
catch {
    # log or whatever. we'll just die for example
    die "Could not perform an action: $_";
}
```

# DESCRIPTION

This class provides a simple abstraction layer between [SOAP::Lite](https://metacpan.org/pod/SOAP%3A%3ALite) and
[Salesforce](https://www.salesforce.com). Because [SOAP::Lite](https://metacpan.org/pod/SOAP%3A%3ALite) does not
support `complexTypes`, and document/literal encoding is limited, this module
works around those limitations and provides a more intuitive interface a
developer can interact with.

# CONSTRUCTOR ARGUMENTS

Given that [WWW::Salesforce](https://metacpan.org/pod/WWW%3A%3ASalesforce) doesn't have attributes in the traditional
sense, the following arguments, rather than attributes, can be passed
into the constructor.

## password

```perl
my $sforce = WWW::Salesforce->new(password => 'foobar1232131');
```

The password is a combination of your Salesforce password and your user's
[Security Token](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_concepts_security.htm).

## serverurl

```perl
my $sforce = WWW::Salesforce->new(serverurl => 'https://login.salesforce.com');
# or maybe one of your developer instances
$sforce = WWW::Salesforce->new(serverurl => 'https://test.salesforce.com');
```

When you login to Salesforce, it's sometimes useful to login to one of your sandbox or
other instances. All you need is the base URL here.

## username

```perl
my $sforce = WWW::Salesforce->new(username => 'foo@bar.com');
```

When you login to Salesforce, your username is necessary.

## version

```perl
my $sforce = WWW::Salesforce->new(version => '52.0');
```

Salesforce makes changes to their API and luckily for us, they version those changes.
You can choose which API version you want to use by passing this argument. However, it
**must** be a string.

# CONSTRUCTORS

[WWW::Salesforce](https://metacpan.org/pod/WWW%3A%3ASalesforce) constructs its instance and immediately logs you into the
[Salesforce](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_login.htm)
API. So that there's less confusion, we have the traditional constructor as well as a
second constructor named login.

## new

```perl
my $sforce = WWW::Salesforce->new(
  username => 'foo@bar.com',
  password => 'password' . 'security_token',
  serverurl => 'https://login.salesforce.com',
  version => '52.0'
);
```

When you create a new instance, the ["username" in WWW::Salesforce](https://metacpan.org/pod/WWW%3A%3ASalesforce#username) and ["password" in WWW::Salesforce](https://metacpan.org/pod/WWW%3A%3ASalesforce#password)
arguments are required. The others are not required. After construction, these items are
not mutable.

## login

```perl
my $sforce = WWW::Salesforce->login(
  username => 'foo@bar.com',
  password => 'password' . 'security_token',
  serverurl => 'https://login.salesforce.com',
  version => '52.0'
);
```

When you create a new instance, the ["username" in WWW::Salesforce](https://metacpan.org/pod/WWW%3A%3ASalesforce#username) and ["password" in WWW::Salesforce](https://metacpan.org/pod/WWW%3A%3ASalesforce#password)
arguments are required. The others are not required. After construction, these items are
not mutable.

# METHODS

## convertLead( HASH )

The `convertLead` method returns an object of type SOAP::SOM if the login attempt was successful, and 0 otherwise.

Converts a Lead into an Account, Contact, or (optionally) an Opportunity

The following are the accepted input parameters:

- %hash\_of\_array\_references

    ```perl
    leadId => [ 2345, 5678, ],
    contactId => [ 9876, ],
    ```

## create

```perl
# create a new account with a hash
my $res = $sforce->create(type => 'Account', name => 'Foo');
say $res->envelope->{Body}->{createResponse}->{result}->{success};

# create a new account with a hashref
my $res = $sforce->create({type => 'Account', name => 'Foo'});
say $res->envelope->{Body}->{createResponse}->{result}->{success};

# create a new account with an extra header and a hash
my $header = {
    AssignmentRuleHeader => {assignmentRuleId => '123RuleID', useDefaultRule => 'true'},
};
my $res = $sforce->create(-headers => $header, type => 'Account', name => 'Foo');
say $res->envelope->{Body}->{createResponse}->{result}->{success};

# create a new account with an extra header and a hashref
my $res = $sforce->create({-headers => $header, type => 'Account', name => 'Foo'});
say $res->envelope->{Body}->{createResponse}->{result}->{success};
```

Adds one new individual object to your organization's data. This takes as
input an optional extra [SOAP::Header](https://metacpan.org/pod/SOAP%3A%3AHeader) object followed by a `hash` or
`hashref` representing the object you wish to add to your organization.
The hash must contain the `type` key in order to identify the type of the
record to add.

Returns a [SOAP::Lite](https://metacpan.org/pod/SOAP%3A%3ALite) object. Success of this operation can be gleaned from
the envelope result as shown in the examples above.

## delete( ARRAY )

Deletes one or more individual objects from your organization's data.
This subroutine takes as input an array of SCALAR values, where each SCALAR is an `sObjectId`.

## describeGlobal()

Retrieves a list of available objects for your organization's data.
You can then iterate through this list and use `describeSObject()` to obtain metadata about individual objects.
This method calls the Salesforce [describeGlobal method](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describeglobal.htm).

## describeLayout( HASH )

Describes metadata about a given page layout, including layouts for edit and display-only views and record type mappings.

- type

    The type of the object you wish to have described.

## describeSObject( HASH )

Describes metadata (field list and object properties) for the specified object.

- type

    The type of the object you wish to have described.

## describeSObjects( type => \['Account','Contact','CustomObject\_\_c'\] )

An array based version of describeSObject; describes metadata (field list and object properties) for the specified object or array of objects.

## describeTabs()

Use the `describeTabs` call to obtain information about the standard and custom apps to which the logged-in user has access. The `describeTabs` call returns the minimum required metadata that can be used to render apps in another user interface. Typically this call is used by partner applications to render Salesforce data in another user interface.

## get\_session\_id()

Gets the Salesforce SID

## get\_user\_id()

Gets the Salesforce UID

## get\_username()

Gets the Salesforce Username

## getDeleted( HASH )

Retrieves the list of individual objects that have been deleted within the given time span for the specified object.

- type

    Identifies the type of the object you wish to find deletions for.

- start

    A string identifying the start date/time for the query

- end

    A string identifying the end date/time for the query

## getServerTimestamp()

Retrieves the current system timestamp (GMT) from the Salesforce web service.

## getUpdated( HASH )

Retrieves the list of individual objects that have been updated (added or changed) within the given time span for the specified object.

- type

    Identifies the type of the object you wish to find updates for.

- start

    A string identifying the start date/time for the query

- end

    A string identifying the end date/time for the query

## getUserInfo( HASH )

Retrieves personal information for the user associated with the current session.

- user

    A user ID

## logout()

Ends the session for the logged-in user issuing the call. No arguments are needed.
Useful to avoid hitting the limit of ten open sessions per login.
[Logout API Call](http://www.salesforce.com/us/developer/docs/api/Content/sforce_api_calls_logout.htm)

## query

```perl
my $res = $sf->query(query => 'SELECT Id, Name FROM Account');
$res = $sf->query(query => 'SELECT Id, Name FROM Account', limit => 20);
# records as an array
my @records = $res->valueof('//queryResponse/result/records');
# number of records returned (int)
my $number = $res->valueof('//queryResponse/result/size');
# When our query has more results than our limit, we get paged results
my $done = $res->valueof('//queryResponse/result/done');
while (!$done) {
  my $locator = $res->valueof('//queryResponse/result/queryLocator');
  # use that locator for the queryMore method
}
```

Executes a [query](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_query.htm)
against the specified object and returns data that matches the specified
criteria.

The method takes in a hash with two potential keys, `query` and `limit`.

The `query` key is required and should contain an
[SOQL](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql.htm)
query string.

The `limit` key sets the batch size, or size of the result returned.
This is helpful in producing paginated results, or fetching small sets
of data at a time.

## queryAll( HASH )

Executes a query against the specified object and returns data that matches the
specified criteria including archived and deleted objects.

- query

    The query string to use for the query. The query string takes the form of a _basic_ SQL statement. For example, "SELECT Id,Name FROM Account".

- limit

    This sets the batch size, or size of the result returned. This is helpful in producing paginated results, or fetch small sets of data at a time.

## queryMore( HASH )

Retrieves the next batch of objects from a `query` or `queryAll`.

- queryLocator

    The handle or string returned by `query`. This identifies the result set and cursor for fetching the next set of rows from a result set.

- limit

    This sets the batch size, or size of the result returned. This is helpful in producing paginated results, or fetch small sets of data at a time.

## resetPassword( HASH )

Changes a user's password to a server-generated value.

- userId

    A user Id.

## retrieve( HASH )

- fields

    A comma delimited list of field name you want retrieved.

- type

    The type of the object being queried.

- ids

    The ids (LIST) of the object you want returned.

## search( HASH )

- searchString

    The search string to be used in the query. For example,
    `find {4159017000} in phone fields returning contact(id, phone, firstname, lastname), lead(id, phone, firstname, lastname), account(id, phone, name)`

## setPassword( HASH )

Sets the specified user's password to the specified value.

- userId

    A user Id.

- password

    The new password to assign to the user identified by `userId`.

## soap\_header

```perl
my $headers = [
    $sforce->soap_header(AllOrNoneHeader => {allOrNone => 'true'}),
    $sforce->soap_header(PackageVersionHeader => {packageVersions => [{majorNumber => 1, minorNumber => 0, namespace => 'battle'}]}),
];
my $res = $sforce->some_method(-headers: $headers);
```

This method is merely a convenience for you, the user, to create one of
the various
[SOAP headers](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/soap_headers.htm)
in a [SOAP::Header](https://metacpan.org/pod/SOAP%3A%3AHeader) format to send along with a method call. Any header
created using this method is _not_ saved in any way. You must pass any
header you created to the method itself via the special `-headers` parameter.
The `-headers` parameter always takes an array ref of [SOAP::Header](https://metacpan.org/pod/SOAP%3A%3AHeader)
objects.

## sf\_date

Converts a time in Epoch seconds to the date format that Salesforce likes

## update(type => $type, HASHREF \[, HASHREF ...\])

Updates one or more existing objects in your organization's data. This subroutine takes as input a **type** value which names the type of object to update (e.g. Account, User) and one or more perl HASH references containing the fields (the keys of the hash) and the values of the record that will be updated.

The hash must contain the 'Id' key in order to identify the record to update.

## upsert(type => $type, key => $key, HASHREF \[, HASHREF ...\])

Updates or inserts one or more objects in your organization's data.  If the data doesn't exist on Salesforce, it will be inserted.  If it already exists it will be updated.

This subroutine takes as input a **type** value which names the type of object to update (e.g. Account, User).  It also takes a **key** value which specifies the unique key Salesforce should use to determine if it needs to update or insert.  If **key** is not given it will default to 'Id' which is Salesforce's own internal unique ID.  This key can be any of Salesforce's default fields or an custom field marked as an external key.

Finally, this method takes one or more perl HASH references containing the fields (the keys of the hash) and the values of the record that will be updated.

## describeMetadata()

Get some metadata info about your instance.

## retrieveMetadata

## checkAsyncStatus( $pid )

## checkRetrieveStatus( $pid )

## getErrorDetails( RESULT )

Returns a hash with information about errors from API calls - only useful if ($res->valueof('//success') ne 'true')

```perl
{
    'statusCode' => 'INVALID_FIELD_FOR_INSERT_UPDATE',
    'message' => 'Account: bad field names on insert/update call: type'
    ...
}
```

## bye()

Synonym for `logout`.

Ends the session for the logged-in user issuing the call. No arguments are needed.
Returns a reference to an array of hash refs

## do\_query( $query, \[$limit\] )

Returns a reference to an array of hash refs

## do\_queryAll( $query, \[$limit\] )

Returns a reference to an array of hash refs

## get\_field\_list( $table\_name )

Returns a ref to an array of hash refs for each field name
Field name keyed as 'name'

## get\_tables()

Returns a reference to an array of hash references
Each hash gives the properties for each Salesforce object

# EXAMPLES

## login()

```perl
use WWW::Salesforce;
my $sf = WWW::Salesforce->login( 'username' => $user,'password' => $pass )
    or die $@;
```

## search()

```perl
my $query = 'find {4159017000} in phone fields returning contact(id, phone, ';
$query .= 'firstname, lastname), lead(id, phone, firstname, lastname), ';
$query .= 'account(id, phone, name)';
my $result = $sforce->search( 'searchString' => $query );
```

# SUPPORT

Please visit Salesforce.com's user/developer forums online for assistance with
this module. You are free to contact the author directly if you are unable to
resolve your issue online.

# CAVEATS

The `describeSObjects` and `describeTabs` API calls are not yet complete. These will be
completed in future releases.

Not enough test cases built into the install yet.  More to be added.

# SEE ALSO

```
L<DBD::Salesforce> by Jun Shimizu
L<SOAP::Lite> by Byrne Reese

Examples on Salesforce website:
L<http://www.sforce.com/us/docs/sforce70/wwhelp/wwhimpl/js/html/wwhelp.htm>
```

# HISTORY

This Perl module was originally provided and presented as part of
the first Salesforce.com dreamForce conference on Nov. 11, 2003 in
San Francisco.

# AUTHORS

Byrne Reese - &lt;byrne at majordojo dot com>

Chase Whitener <`capoeirab@cpan.org`>

Fred Moyer &lt;fred at redhotpenguin dot com>

# CONTRIBUTORS

Michael Blanco

Garth Webb

Jun Shimizu

Ron Hess

Tony Stubblebine

# COPYRIGHT & LICENSE

Copyright 2003-2004 Byrne Reese, Chase Whitener, Fred Moyer. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
