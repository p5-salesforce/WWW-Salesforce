# NAME

WWW::Salesforce - This class provides a simple abstraction layer between SOAP::Lite and Salesforce.com.

# SYNOPSIS

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

# DESCRIPTION

This class provides a simple abstraction layer between [SOAP::Lite](https://metacpan.org/pod/SOAP::Lite) and
[Salesforce](http://www.Salesforce.com).

# ATTRIBUTES

[WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce) makes the following attributes available.

## password

    $sf = $sf->password('my super secret password'); # method chaining
    my $password = $sf->password();

The password is the password you set for your user account in
[Salesforce](http://www.salesforce.com).

Note, this attribute is only used to generate the access token during
["login" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#login). You may want to ["logout" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#logout) before
changing this attribute.

## username

    $sf = $sf->username('foo@bar.com'); # method chaining
    my $username = $sf->username;

The username is the email address you set for your user account in
[Salesforce](http://www.salesforce.com).

Note, this attribute is only used to generate the access token during
["login" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#login). You may want to ["logout" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#logout) before
changing this attribute.

# CONSTRUCTORS

[WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce) makes the following constructors available.

## new

    my $sf = WWW::Salesforce->new(
        username => 'foo@bar.com',
        password => 'super secrety goodness',
    );

Creates a new [WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce) object and then calls the
["login" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#login) method.

Any of the ["ATTRIBUTES" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#ATTRIBUTES) above can be passed in as a
parameter via either a hash reference or a hash.

# METHODS

[WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce) makes the following methods available.

## login

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

The `login` method makes use of the soap login method:
[Salesforce SOAP-based username and password login flow](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_login.htm).

Upon success, it will return your [WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce) object. On failure, it will
die with some useful error string.

On a successful login, the `session id` is saved and the `server URL` is set
properly and used as the endpoint for API communication from here on out.

## convertLead

    $sf->convertLead(
        leadId => ['01t500000016RuaAAE', '01t500000016RuaAAF']
        contactId => ['01t500000016RuaAAC'],
    );

The [convertLead](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_convertlead.htm)
method converts a [Lead](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_lead.htm#topic-title)
into an [Account](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_account.htm#topic-title)
and [Contact](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_contact.htm#topic-title),
as well as (optionally) an [Opportunity](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_objects_opportunity.htm#topic-title).

To convert a Lead, your account must have the `Convert Leads` permission and
the `Edit` permission on leads, as well as `Create` and `Edit` on the
Account, Contact, and Opportunity objects.

Returns an object of type [SOAP::SOM](https://metacpan.org/pod/SOAP::SOM) if the attempt was successful and
dies otherwise.

## create

    my $res = $sf->create(
        'type'      => 'Lead',
        'FirstName' => 'conversion test',
        'LastName'  => 'lead',
        'Company'   => 'Acme Inc.',
    );
    if ($res->valueof('//success') eq 'true') {
        say "Yay! New Lead with ID: ", $res->valueof('//id');
    }

The [create](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_create.htm)
method adds one record, such as an `Account` or `Contact` record, to
your organization's information. The `create` call is analogous to the
`INSERT` statement in SQL.

A hash or hash-reference is accepted, but must contain a `type` key to tell us
what we're inserting.

Returns a [SOAP::SOM](https://metacpan.org/pod/SOAP::SOM) object or dies.

## delete

    # delete just one item
    my $res = $sf->delete('01t500000016RuaAAE');
    # delete many items
    $res = $sf->delete('01t500000016RuaAAE', '01t500000016RuaAAF');

The [delete](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_delete.htm)
method will delete one or more individual objects from your organization's data.

## describeGlobal

    my $res = $sf->describeGlobal();

The [describeGlobal](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describeglobal.htm)
method is used to obtain a list of available objects for your organization. You
can then iterate through this list and use ["describeSObject" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#describeSObject)
to obtain metadata about individual objects.

## describeLayout

    # must provide a type to lookup
    my $res = $sf->describeLayout(type => 'Contact');

The [describeLayout](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describelayout.htm)
method returns metadata about a given page layout, including layouts for edit
and display-only views and record type mappings.

## describeSObject

    # must provide a type to lookup
    my $res = $sf->describeLayout(type => 'Contact');

The [describeSObject](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describesobject.htm)
method is used to get metadata (field list and object properties) for the
specified object.

## describeSObjects

    # must provide an array of types to lookup
    my $res = $sf->describeLayout(type => ['Contact', 'Account', 'Custom__c']);

The [describeSObjects](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describesobjects.htm)
method is used to obtain metadata for a given object or array of objects.

## describeTabs

    my $res = $sf->describeTabs();

The [describeTabs](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_describetabs.htm)
method obtains information about the standard and custom apps to which the
logged-in user has access. It returns the minimum required metadata that can be
used to render apps in another user interface. Typically this call is used by
partner applications to render Salesforce data in another user interface.

## get\_session\_id

    my $id = $sf->get_session_id();

Gets the Salesforce SID captured during login.

## get\_user\_id

    my $id = $sf->get_user_id();

Gets the Salesforce UID captured during login.

## getDeleted

    # get a list of deleted records within a given timespan
    # times are in GMT
    my $res = $sf->getDeleted(
        type => 'Account',
        start => '2017-09-21T08:42:42',
        end   => '2017-09-21T08:43:42',
    );

The [getDeleted](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getdeleted.htm)
method retrieves the list of individual objects that have been deleted within
the given time span for the specified object.

## getServerTimestamp

    my $res = $sf->getServerTimestamp();

The [getServerTimestamp](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getservertimestamp.htm)
method retrieves the current system timestamp (GMT) from the Salesforce web service.

## getUpdated

    # get a list of updated records within a given timespan
    # times are in GMT
    my $res = $sf->getUpdated(
        type => 'Account',
        start => '2017-09-21T08:42:42',
        end   => '2017-09-21T08:43:42',
    );

The [getUpdated](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getupdated.htm)
method retrieves the list of individual objects that have been updated (added
or changed) within the given time span for the specified object.

## getUserInfo

    my $res = $sf->getUserInfo();

The [getUserInfo](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_getuserinfo.htm)
method retrieves personal information for the user associated with the current
session.

## logout

    $sf->logout();

Ends the session for the logged-in user issuing the call. No arguments are needed.
Useful to avoid hitting the limit of ten open sessions per login.
[Logout API Call](http://www.salesforce.com/us/developer/docs/api/Content/sforce_api_calls_logout.htm)

## query

    my $soql = "SELECT Id, Name FROM Account";
    my $limit = 25;

    my $res = $sf->query(query => $soql);
    # or limit our result set
    $res = $sf->query(query => $soql, limit => $limit);

The [query](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_query.htm)
method executes the given
[SOQL Statement](https://developer.salesforce.com/docs/atlas.en-us.208.0.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_sosl_intro.htm)
and returns the result set. This query will not include deleted records.

## queryAll

    my $soql = "SELECT Id, Name FROM Account";
    my $limit = 25;

    my $res = $sf->queryAll(query => $soql);
    # or limit our result set
    $res = $sf->queryAll(query => $soql, limit => $limit);

The [queryAll](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_queryall.htm)
method is exactly like the ["query" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#query) method with the exception
that it has read-only access to deleted records as well.

## queryMore

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

The [queryMore](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_querymore.htm)
method retrieves the next batch of objects from a ["query" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#query) or
["queryAll" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#queryAll) method call.

## resetPassword

    my $res = $sf->resetPassword(userId => '01t500000016RuaAAE');

The [resetPassword](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_resetpassword.htm)
method will change a user's password to a server-generated value.

## retrieve

    # all parameters are strings and are required
    my $res = $sf->retrieve(
        type => 'Contact',
        fields => 'FirstName,LastName,Id', # comma separated list in a string
        ids => '01t500000016RuaAAE,01t500000016RuaAAF',
        # however, limit is optional and is an integer
        limit => 500,
    );

The [retrieve](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_retrieve.htm)
method retrieves individual records from a given object type.

## search

    my $res = $sf->search(
        searchString => 'FIND {4159017000} IN Phone FIELDS RETURNING Account(Id, Phone, Name)',
    );

The [search](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_search.htm)
method searches for records based on a search string
([SOSL String](https://developer.salesforce.com/docs/atlas.en-us.208.0.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_sosl_intro.htm)).

## setPassword

    my $res = $sf->setPassword(
        userId => '01t500000016RuaAAE',
        password => 'Some new password!',
    );

The [setPassword](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_setpassword.htm)
method sets the specified user's password to the specified value.

## sf\_date

    my $date = $sf->sf_date(time);
    # Or, as a class method
    $date = WWW::Salesforce->sf_date(time);
    say $date; # 2017-09-21T08:42:42.000-0400

Converts a time in Epoch seconds to the date format that Salesforce likes.

## update

    # an array of hash-refs representing SObjects is expected
    my $res = $sf->update({
        Id => '01t500000016RuaAAE',
        Type => 'Account',
        Name => "Bender's Shiny Metal Co.", # Update our Account name
    });

The [update](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_update.htm)
method is analogous to a SQL `UPDATE` statement.

The only requirement is that each object represented by a hash reference must
contain one key called `id` or `Id` and a `type` or `Type` key. The other
keys in the hash reference are the fields we'll be updating for the given object.

**\* Note:** As of version `20.0` of the Salesforce API, you can now update
objects of differing types. This makes passing the object `type` as the first
argument no longer necessary. Just pass an array of hash references.

## upsert

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

The [upsert](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_upsert.htm)
method creates new records and updates existing records; uses a custom field to
determine the presence of existing records. In most cases, we recommend that
you use `upsert` instead of ["create" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#create) to avoid creating
unwanted duplicate records (idempotent).

## describeMetadata

Get some metadata info about your instance.

## retrieveMetadata

## checkAsyncStatus

## checkRetrieveStatus

## getErrorDetails

Returns a hash with information about errors from API calls - only useful if ($res->valueof('//success') ne 'true')

    {
        'statusCode' => 'INVALID_FIELD_FOR_INSERT_UPDATE',
        'message' => 'Account: bad field names on insert/update call: type'
        ...
    }

## bye

Synonym for ["logout" in WWW::Salesforce](https://metacpan.org/pod/WWW::Salesforce#logout).

## do\_query

Returns a reference to an array of hash refs

## do\_queryAll

    my $soql_query = "Select Name from Contact";
    my $limit = 10;

    # get all contacts
    my $res = $sf->do_queryAll($soql_query);
    # only get 10 contacts
    $res = $sf->do_queryAll($soql_query, $limit)

Returns a reference to an array of hash refs

## get\_field\_list

    my $fields = $sf->get_field_list();

Returns a reference to an array of hash references for each field name.
Field name keyed as `name`

## get\_tables

    my $tables = $sf->get_tables();

Returns a reference to an array of hash references.
Each hash gives the properties for each Salesforce object

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

Copyright 2003 Byrne Reese, Chase Whitener, Fred Moyer. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
