use strict;
use warnings;

use Feature::Compat::Try;
use WWW::Salesforce ();
use WWW::Salesforce::Serializer ();
use Test::More;

plan skip_all => 'Skip live tests under $ENV{AUTOMATED_TESTING}'
    if ($ENV{AUTOMATED_TESTING});
plan skip_all =>
    'Set $ENV{SFDC_HOST} $ENV{SFDC_USER}, $ENV{SFDC_PASS}, $ENV{SFDC_TOKEN}'
    unless ($ENV{SFDC_HOST}
    && $ENV{SFDC_USER}
    && $ENV{SFDC_PASS}
    && $ENV{SFDC_TOKEN});

my $sforce;
try {
    $sforce = WWW::Salesforce->new(
        username  => $ENV{SFDC_USER},
        password  => $ENV{SFDC_PASS} . $ENV{SFDC_TOKEN},
        serverurl => $ENV{SFDC_HOST},
    );
    ok($sforce, 'Got a connection');
}
catch ($error) {
    BAIL_OUT('Unable to login for testing: ' . ($error // ''));
}

# given that these can be serialized in various orders, let's have fun finding all the ways this fails
my %header = (
    AllOrNoneHeader => {
        header => {allOrNone => 'true'},
        response => ['<sforce:AllOrNoneHeader><sforce:allOrNone xsi:type="xsd:boolean">true</sforce:allOrNone></sforce:AllOrNoneHeader>'],
    },
    AllowFieldTruncationHeader => {
        header => {allowFieldTruncation => 'true'},
        response => ['<sforce:AllowFieldTruncationHeader><sforce:allowFieldTruncation xsi:type="xsd:boolean">true</sforce:allowFieldTruncation></sforce:AllowFieldTruncationHeader>'],
    },
    AssignmentRuleHeader => {
        header => {assignmentRuleId => '123RuleID', useDefaultRule => 'true'},
        response => [
            '<sforce:AssignmentRuleHeader><sforce:useDefaultRule xsi:type="xsd:boolean">true</sforce:useDefaultRule><sforce:assignmentRuleId xsi:type="xsd:string">123RuleID</sforce:assignmentRuleId></sforce:AssignmentRuleHeader>',
            '<sforce:AssignmentRuleHeader><sforce:assignmentRuleId xsi:type="xsd:string">123RuleID</sforce:assignmentRuleId><sforce:useDefaultRule xsi:type="xsd:boolean">true</sforce:useDefaultRule></sforce:AssignmentRuleHeader>',
        ],
    },
    CallOptions => {
        header => {client => 'battle', defaultNamespace => 'battle'},
        response => [
            '<sforce:CallOptions><sforce:defaultNamespace xsi:type="xsd:string">battle</sforce:defaultNamespace><sforce:client xsi:type="xsd:string">battle</sforce:client></sforce:CallOptions>',
            '<sforce:CallOptions><sforce:client xsi:type="xsd:string">battle</sforce:client><sforce:defaultNamespace xsi:type="xsd:string">battle</sforce:defaultNamespace></sforce:CallOptions>',
        ],
    },
    DebuggingHeader => {
        header => {
            categories => [
                {LogInfo => {category => 'All', level => 'DEBUG'}},
                {LogInfo => {category => 'System', level => 'INFO'}},
            ],
            debugLevel => 'none'
        },
        response => [
            '<sforce:DebuggingHeader><sforce:categories><sforce:LogInfo><sforce:category xsi:type="xsd:string">All</sforce:category><sforce:level xsi:type="xsd:string">DEBUG</sforce:level></sforce:LogInfo><sforce:LogInfo><sforce:category xsi:type="xsd:string">System</sforce:category><sforce:level xsi:type="xsd:string">INFO</sforce:level></sforce:LogInfo></sforce:categories><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel></sforce:DebuggingHeader>',
            '<sforce:DebuggingHeader><sforce:categories><sforce:LogInfo><sforce:category xsi:type="xsd:string">All</sforce:category><sforce:level xsi:type="xsd:string">DEBUG</sforce:level></sforce:LogInfo><sforce:LogInfo><sforce:level xsi:type="xsd:string">INFO</sforce:level><sforce:category xsi:type="xsd:string">System</sforce:category></sforce:LogInfo></sforce:categories><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel></sforce:DebuggingHeader>',
            '<sforce:DebuggingHeader><sforce:categories><sforce:LogInfo><sforce:level xsi:type="xsd:string">DEBUG</sforce:level><sforce:category xsi:type="xsd:string">All</sforce:category></sforce:LogInfo><sforce:LogInfo><sforce:category xsi:type="xsd:string">System</sforce:category><sforce:level xsi:type="xsd:string">INFO</sforce:level></sforce:LogInfo></sforce:categories><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel></sforce:DebuggingHeader>',
            '<sforce:DebuggingHeader><sforce:categories><sforce:LogInfo><sforce:level xsi:type="xsd:string">DEBUG</sforce:level><sforce:category xsi:type="xsd:string">All</sforce:category></sforce:LogInfo><sforce:LogInfo><sforce:level xsi:type="xsd:string">INFO</sforce:level><sforce:category xsi:type="xsd:string">System</sforce:category></sforce:LogInfo></sforce:categories><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel></sforce:DebuggingHeader>',
            '<sforce:DebuggingHeader><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel><sforce:categories><sforce:LogInfo><sforce:category xsi:type="xsd:string">All</sforce:category><sforce:level xsi:type="xsd:string">DEBUG</sforce:level></sforce:LogInfo><sforce:LogInfo><sforce:category xsi:type="xsd:string">System</sforce:category><sforce:level xsi:type="xsd:string">INFO</sforce:level></sforce:LogInfo></sforce:categories></sforce:DebuggingHeader>',
            '<sforce:DebuggingHeader><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel><sforce:categories><sforce:LogInfo><sforce:category xsi:type="xsd:string">All</sforce:category><sforce:level xsi:type="xsd:string">DEBUG</sforce:level></sforce:LogInfo><sforce:LogInfo><sforce:level xsi:type="xsd:string">INFO</sforce:level><sforce:category xsi:type="xsd:string">System</sforce:category></sforce:LogInfo></sforce:categories></sforce:DebuggingHeader>',
            '<sforce:DebuggingHeader><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel><sforce:categories><sforce:LogInfo><sforce:level xsi:type="xsd:string">DEBUG</sforce:level><sforce:category xsi:type="xsd:string">All</sforce:category></sforce:LogInfo><sforce:LogInfo><sforce:category xsi:type="xsd:string">System</sforce:category><sforce:level xsi:type="xsd:string">INFO</sforce:level></sforce:LogInfo></sforce:categories></sforce:DebuggingHeader>',
            '<sforce:DebuggingHeader><sforce:debugLevel xsi:type="xsd:string">none</sforce:debugLevel><sforce:categories><sforce:LogInfo><sforce:level xsi:type="xsd:string">DEBUG</sforce:level><sforce:category xsi:type="xsd:string">All</sforce:category></sforce:LogInfo><sforce:LogInfo><sforce:level xsi:type="xsd:string">INFO</sforce:level><sforce:category xsi:type="xsd:string">System</sforce:category></sforce:LogInfo></sforce:categories></sforce:DebuggingHeader>',
        ],
    },
    DisableFeedTrackingHeader => {
        header => {disableFeedTracking => 'true'},
        response => ['<sforce:DisableFeedTrackingHeader><sforce:disableFeedTracking xsi:type="xsd:boolean">true</sforce:disableFeedTracking></sforce:DisableFeedTrackingHeader>',],
    },
    DuplicateRuleHeader => {
        header => {allowSave => 'true', includeRecordDetails => 'true', runAsCurrentUser => 'true'},
        response => [
            '<sforce:DuplicateRuleHeader><sforce:allowSave xsi:type="xsd:boolean">true</sforce:allowSave><sforce:includeRecordDetails xsi:type="xsd:boolean">true</sforce:includeRecordDetails><sforce:runAsCurrentUser xsi:type="xsd:boolean">true</sforce:runAsCurrentUser></sforce:DuplicateRuleHeader>',
            '<sforce:DuplicateRuleHeader><sforce:allowSave xsi:type="xsd:boolean">true</sforce:allowSave><sforce:runAsCurrentUser xsi:type="xsd:boolean">true</sforce:runAsCurrentUser><sforce:includeRecordDetails xsi:type="xsd:boolean">true</sforce:includeRecordDetails></sforce:DuplicateRuleHeader>',
            '<sforce:DuplicateRuleHeader><sforce:includeRecordDetails xsi:type="xsd:boolean">true</sforce:includeRecordDetails><sforce:allowSave xsi:type="xsd:boolean">true</sforce:allowSave><sforce:runAsCurrentUser xsi:type="xsd:boolean">true</sforce:runAsCurrentUser></sforce:DuplicateRuleHeader>',
            '<sforce:DuplicateRuleHeader><sforce:includeRecordDetails xsi:type="xsd:boolean">true</sforce:includeRecordDetails><sforce:runAsCurrentUser xsi:type="xsd:boolean">true</sforce:runAsCurrentUser><sforce:allowSave xsi:type="xsd:boolean">true</sforce:allowSave></sforce:DuplicateRuleHeader>',
            '<sforce:DuplicateRuleHeader><sforce:runAsCurrentUser xsi:type="xsd:boolean">true</sforce:runAsCurrentUser><sforce:includeRecordDetails xsi:type="xsd:boolean">true</sforce:includeRecordDetails><sforce:allowSave xsi:type="xsd:boolean">true</sforce:allowSave></sforce:DuplicateRuleHeader>',
            '<sforce:DuplicateRuleHeader><sforce:runAsCurrentUser xsi:type="xsd:boolean">true</sforce:runAsCurrentUser><sforce:allowSave xsi:type="xsd:boolean">true</sforce:allowSave><sforce:includeRecordDetails xsi:type="xsd:boolean">true</sforce:includeRecordDetails></sforce:DuplicateRuleHeader>',
        ],
    },
    EmailHeader => {
        header => {triggerAutoResponseEmail => 'true', triggerOtherEmail => 'true', triggerUserEmail => 'true'},
        response => [
            '<sforce:EmailHeader><sforce:triggerAutoResponseEmail xsi:type="xsd:boolean">true</sforce:triggerAutoResponseEmail><sforce:triggerOtherEmail xsi:type="xsd:boolean">true</sforce:triggerOtherEmail><sforce:triggerUserEmail xsi:type="xsd:boolean">true</sforce:triggerUserEmail></sforce:EmailHeader>',
            '<sforce:EmailHeader><sforce:triggerAutoResponseEmail xsi:type="xsd:boolean">true</sforce:triggerAutoResponseEmail><sforce:triggerUserEmail xsi:type="xsd:boolean">true</sforce:triggerUserEmail><sforce:triggerOtherEmail xsi:type="xsd:boolean">true</sforce:triggerOtherEmail></sforce:EmailHeader>',
            '<sforce:EmailHeader><sforce:triggerOtherEmail xsi:type="xsd:boolean">true</sforce:triggerOtherEmail><sforce:triggerAutoResponseEmail xsi:type="xsd:boolean">true</sforce:triggerAutoResponseEmail><sforce:triggerUserEmail xsi:type="xsd:boolean">true</sforce:triggerUserEmail></sforce:EmailHeader>',
            '<sforce:EmailHeader><sforce:triggerOtherEmail xsi:type="xsd:boolean">true</sforce:triggerOtherEmail><sforce:triggerUserEmail xsi:type="xsd:boolean">true</sforce:triggerUserEmail><sforce:triggerAutoResponseEmail xsi:type="xsd:boolean">true</sforce:triggerAutoResponseEmail></sforce:EmailHeader>',
            '<sforce:EmailHeader><sforce:triggerUserEmail xsi:type="xsd:boolean">true</sforce:triggerUserEmail><sforce:triggerOtherEmail xsi:type="xsd:boolean">true</sforce:triggerOtherEmail><sforce:triggerAutoResponseEmail xsi:type="xsd:boolean">true</sforce:triggerAutoResponseEmail></sforce:EmailHeader>',
            '<sforce:EmailHeader><sforce:triggerUserEmail xsi:type="xsd:boolean">true</sforce:triggerUserEmail><sforce:triggerAutoResponseEmail xsi:type="xsd:boolean">true</sforce:triggerAutoResponseEmail><sforce:triggerOtherEmail xsi:type="xsd:boolean">true</sforce:triggerOtherEmail></sforce:EmailHeader>',
        ],
    },
    LimitInfoHeader => {
        header => {current => '5', limit => '100000', type => 'API REQUESTS'},
        response => [
            '<sforce:LimitInfoHeader><sforce:current xsi:type="xsd:int">5</sforce:current><sforce:limit xsi:type="xsd:int">100000</sforce:limit><sforce:type xsi:type="xsd:string">API REQUESTS</sforce:type></sforce:LimitInfoHeader>',
            '<sforce:LimitInfoHeader><sforce:current xsi:type="xsd:int">5</sforce:current><sforce:type xsi:type="xsd:string">API REQUESTS</sforce:type><sforce:limit xsi:type="xsd:int">100000</sforce:limit></sforce:LimitInfoHeader>',
            '<sforce:LimitInfoHeader><sforce:limit xsi:type="xsd:int">100000</sforce:limit><sforce:type xsi:type="xsd:string">API REQUESTS</sforce:type><sforce:current xsi:type="xsd:int">5</sforce:current></sforce:LimitInfoHeader>',
            '<sforce:LimitInfoHeader><sforce:limit xsi:type="xsd:int">100000</sforce:limit><sforce:current xsi:type="xsd:int">5</sforce:current><sforce:type xsi:type="xsd:string">API REQUESTS</sforce:type></sforce:LimitInfoHeader>',
            '<sforce:LimitInfoHeader><sforce:type xsi:type="xsd:string">API REQUESTS</sforce:type><sforce:current xsi:type="xsd:int">5</sforce:current><sforce:limit xsi:type="xsd:int">100000</sforce:limit></sforce:LimitInfoHeader>',
            '<sforce:LimitInfoHeader><sforce:type xsi:type="xsd:string">API REQUESTS</sforce:type><sforce:limit xsi:type="xsd:int">100000</sforce:limit><sforce:current xsi:type="xsd:int">5</sforce:current></sforce:LimitInfoHeader>',
        ],
    },
    LocaleOptions => {
        header => {language => 'en_US'},
        response => ['<sforce:LocaleOptions><sforce:language xsi:type="xsd:string">en_US</sforce:language></sforce:LocaleOptions>',],
    },
    LoginScopeHeader => {
        header => {organizationId => '123OrgID', portalId => '123PortalID'},
        response => [
            '<sforce:LoginScopeHeader><sforce:organizationId xsi:type="xsd:string">123OrgID</sforce:organizationId><sforce:portalId xsi:type="xsd:string">123PortalID</sforce:portalId></sforce:LoginScopeHeader>',
            '<sforce:LoginScopeHeader><sforce:portalId xsi:type="xsd:string">123PortalID</sforce:portalId><sforce:organizationId xsi:type="xsd:string">123OrgID</sforce:organizationId></sforce:LoginScopeHeader>',
        ],
    },
    MruHeader => {
        header => {updateMru => 'true'},
        response => ['<sforce:MruHeader><sforce:updateMru xsi:type="xsd:boolean">true</sforce:updateMru></sforce:MruHeader>',],
    },
    OwnerChangeOptions => {
        header => {
            options => [
                {OwnerChangeOption => {execute =>'true', type =>'SendEmail'}},
                {OwnerChangeOption => {execute =>'true', type =>'EnforceNewOwnerHasReadAccess'}},
            ],
        },
        response => [
            '<sforce:OwnerChangeOptions><sforce:options><sforce:OwnerChangeOption><sforce:execute xsi:type="xsd:boolean">true</sforce:execute><sforce:type xsi:type="xsd:string">SendEmail</sforce:type></sforce:OwnerChangeOption><sforce:OwnerChangeOption><sforce:type xsi:type="xsd:string">EnforceNewOwnerHasReadAccess</sforce:type><sforce:execute xsi:type="xsd:boolean">true</sforce:execute></sforce:OwnerChangeOption></sforce:options></sforce:OwnerChangeOptions>',
            '<sforce:OwnerChangeOptions><sforce:options><sforce:OwnerChangeOption><sforce:execute xsi:type="xsd:boolean">true</sforce:execute><sforce:type xsi:type="xsd:string">SendEmail</sforce:type></sforce:OwnerChangeOption><sforce:OwnerChangeOption><sforce:execute xsi:type="xsd:boolean">true</sforce:execute><sforce:type xsi:type="xsd:string">EnforceNewOwnerHasReadAccess</sforce:type></sforce:OwnerChangeOption></sforce:options></sforce:OwnerChangeOptions>',
            '<sforce:OwnerChangeOptions><sforce:options><sforce:OwnerChangeOption><sforce:type xsi:type="xsd:string">SendEmail</sforce:type><sforce:execute xsi:type="xsd:boolean">true</sforce:execute></sforce:OwnerChangeOption><sforce:OwnerChangeOption><sforce:type xsi:type="xsd:string">EnforceNewOwnerHasReadAccess</sforce:type><sforce:execute xsi:type="xsd:boolean">true</sforce:execute></sforce:OwnerChangeOption></sforce:options></sforce:OwnerChangeOptions>',
            '<sforce:OwnerChangeOptions><sforce:options><sforce:OwnerChangeOption><sforce:type xsi:type="xsd:string">SendEmail</sforce:type><sforce:execute xsi:type="xsd:boolean">true</sforce:execute></sforce:OwnerChangeOption><sforce:OwnerChangeOption><sforce:execute xsi:type="xsd:boolean">true</sforce:execute><sforce:type xsi:type="xsd:string">EnforceNewOwnerHasReadAccess</sforce:type></sforce:OwnerChangeOption></sforce:options></sforce:OwnerChangeOptions>',
        ],
    },
    PackageVersionHeader => {
        header => {packageVersions => [{majorNumber => 1, minorNumber => 0, namespace => 'battle'}]},
        response => [
            '<sforce:PackageVersionHeader><sforce:packageVersions><sforce:majorNumber xsi:type="xsd:int">1</sforce:majorNumber><sforce:minorNumber xsi:type="xsd:int">0</sforce:minorNumber><sforce:namespace xsi:type="xsd:string">battle</sforce:namespace></sforce:packageVersions></sforce:PackageVersionHeader>',
            '<sforce:PackageVersionHeader><sforce:packageVersions><sforce:majorNumber xsi:type="xsd:int">1</sforce:majorNumber><sforce:namespace xsi:type="xsd:string">battle</sforce:namespace><sforce:minorNumber xsi:type="xsd:int">0</sforce:minorNumber></sforce:packageVersions></sforce:PackageVersionHeader>',
            '<sforce:PackageVersionHeader><sforce:packageVersions><sforce:minorNumber xsi:type="xsd:int">0</sforce:minorNumber><sforce:majorNumber xsi:type="xsd:int">1</sforce:majorNumber><sforce:namespace xsi:type="xsd:string">battle</sforce:namespace></sforce:packageVersions></sforce:PackageVersionHeader>',
            '<sforce:PackageVersionHeader><sforce:packageVersions><sforce:minorNumber xsi:type="xsd:int">0</sforce:minorNumber><sforce:namespace xsi:type="xsd:string">battle</sforce:namespace><sforce:majorNumber xsi:type="xsd:int">1</sforce:majorNumber></sforce:packageVersions></sforce:PackageVersionHeader>',
            '<sforce:PackageVersionHeader><sforce:packageVersions><sforce:namespace xsi:type="xsd:string">battle</sforce:namespace><sforce:majorNumber xsi:type="xsd:int">1</sforce:majorNumber><sforce:minorNumber xsi:type="xsd:int">0</sforce:minorNumber></sforce:packageVersions></sforce:PackageVersionHeader>',
            '<sforce:PackageVersionHeader><sforce:packageVersions><sforce:namespace xsi:type="xsd:string">battle</sforce:namespace><sforce:minorNumber xsi:type="xsd:int">0</sforce:minorNumber><sforce:majorNumber xsi:type="xsd:int">1</sforce:majorNumber></sforce:packageVersions></sforce:PackageVersionHeader>',
        ],
    },
    QueryOptions => {
        header => {batchSize => '100'},
        response => ['<sforce:QueryOptions><sforce:batchSize xsi:type="xsd:int">100</sforce:batchSize></sforce:QueryOptions>',],
    },
    SessionHeader => {
        header => {sessionId => '123SessionID'},
        response => ['<sforce:SessionHeader><sforce:sessionId xsi:type="xsd:string">123SessionID</sforce:sessionId></sforce:SessionHeader>',],
    },
    UseTerritoryDeleteHeader => {
        header => {transferToUserId => '123UserID'},
        response => ['<sforce:UseTerritoryDeleteHeader><sforce:transferToUserId xsi:type="xsd:string">123UserID</sforce:transferToUserId></sforce:UseTerritoryDeleteHeader>',],
    },

);

foreach my $key (sort keys %header) {
    my $head = $sforce->soap_header($key, $header{$key}->{header});
    my $res = $sforce->_get_client(1)->serializer->serialize($head);
    ok($res, "$key => Got a serialized header");

    # just clean some crap out of it so our responses can be easier to read. sigh
    $res =~ s{\Q<?xml version="1.0" encoding="UTF-8"?>\E}{}g;
    $res =~ s{\s+\Qxmlns:sforce="urn:partner.soap.sforce.com"\E}{}g;
    $res =~ s{\s+\Qxmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"\E}{}g;
    $res =~ s{\s+\Qxmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/\E"}{}g;
    $res =~ s{\s+\Qxmlns:xsd="http://www.w3.org/2001/XMLSchema"\E}{}g;
    $res =~ s{\s+\Qxmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\E}{}g;
    $res =~ s{\s\s+}{ }g;

    # check our sanitized XML against expected responses
    # we have to do it this way as it doesn't get serialized in the same way each time
    my $in_result_array = grep {$_ && $_ eq $res} @{$header{$key}->{response}};
    ok($in_result_array, "$key => got the right header");
    unless($in_result_array) {
        diag($res);
    }
}

done_testing();
