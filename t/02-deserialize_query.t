#!perl

use strict;
use warnings;
use Test::More 0.88; # done_testing
use WWW::Salesforce::Deserializer ();

my $xml = q{<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="urn:partner.soap.sforce.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:sf="urn:sobject.partner.soap.sforce.com"><soapenv:Header><LimitInfoHeader><limitInfo><current>22092</current><limit>64000</limit><type>API REQUESTS</type></limitInfo></LimitInfoHeader></soapenv:Header><soapenv:Body><queryResponse><result xsi:type="QueryResult"><done>true</done><queryLocator xsi:nil="true"/><records xsi:type="sf:sObject"><sf:type>Contact</sf:type><sf:Id>0BXBXBXBXBXcvhDAAR</sf:Id><sf:Id>0BXBXBXBXBXcvhDAAR</sf:Id><sf:Name>FooBar Homer</sf:Name></records><records xsi:type="sf:sObject"><sf:type>Contact</sf:type><sf:Id>00ACACACACACAC0AAO</sf:Id><sf:Id>00ACACACACACAC0AAO</sf:Id><sf:Name>BazQux Simpson</sf:Name></records><size>2</size></result></queryResponse></soapenv:Body></soapenv:Envelope>};
my $href = {queryResponse => {
    result => {done => 1, queryLocator => undef, size => 2,
      records => [
        {Id => "0BXBXBXBXBXcvhDAAR",Name => "FooBar Homer",type => "Contact"},
        {Id => "00ACACACACACAC0AAO",Name => "BazQux Simpson",type => "Contact"}
      ],
    }
  }
};
my $som = WWW::Salesforce::Deserializer->deserialize($xml);
isa_ok($som, 'SOAP::SOM', 'deserialize: got a proper SOM object');
is_deeply($som->body, $href, 'deserialized content matches');

$xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:sf=\"urn:fault.partner.soap.sforce.com\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soapenv:Body><soapenv:Fault><faultcode>sf:INVALID_FIELD</faultcode><faultstring>INVALID_FIELD: \nselect adfId, Name, Account.Name from Contact\n       ^\nERROR at Row:1:Column:8\nNo such column &apos;adfId&apos; on entity &apos;Contact&apos;. If you are attempting to use a custom field, be sure to append the &apos;__c&apos; after the custom field name. Please reference your WSDL or the describe call for the appropriate names.</faultstring><detail><sf:InvalidFieldFault xsi:type=\"sf:InvalidFieldFault\"><sf:exceptionCode>INVALID_FIELD</sf:exceptionCode><sf:exceptionMessage>\nselect adfId, Name, Account.Name from Contact\n       ^\nERROR at Row:1:Column:8\nNo such column &apos;adfId&apos; on entity &apos;Contact&apos;. If you are attempting to use a custom field, be sure to append the &apos;__c&apos; after the custom field name. Please reference your WSDL or the describe call for the appropriate names.</sf:exceptionMessage><sf:row>1</sf:row><sf:column>8</sf:column></sf:InvalidFieldFault></detail></soapenv:Fault></soapenv:Body></soapenv:Envelope>";
$href = {
  Fault => {
    detail => {
      InvalidFieldFault => bless( {
        column => 8,
        exceptionCode => "INVALID_FIELD",
        exceptionMessage => "\nselect adfId, Name, Account.Name from Contact\n       ^\nERROR at Row:1:Column:8\nNo such column 'adfId' on entity 'Contact'. If you are attempting to use a custom field, be sure to append the '__c' after the custom field name. Please reference your WSDL or the describe call for the appropriate names.",
        row => 1
      }, 'InvalidFieldFault' )
    },
    faultcode => "sf:INVALID_FIELD",
    faultstring => "INVALID_FIELD: \nselect adfId, Name, Account.Name from Contact\n       ^\nERROR at Row:1:Column:8\nNo such column 'adfId' on entity 'Contact'. If you are attempting to use a custom field, be sure to append the '__c' after the custom field name. Please reference your WSDL or the describe call for the appropriate names."
  }
};
$som = WWW::Salesforce::Deserializer->deserialize($xml);
isa_ok($som, 'SOAP::SOM', 'deserialize: got a proper error SOM object');
is_deeply($som->body, $href, 'deserialized error content matches');

done_testing();
