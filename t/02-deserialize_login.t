#!perl

use strict;
use warnings;
use Test::More 0.88; # done_testing
use WWW::Salesforce::Deserializer ();

my $xml = q{<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="urn:partner.soap.sforce.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Body><loginResponse><result><metadataServerUrl>https://foobar.my.salesforce.com/services/Soap/m/37.0/00D30ACACA00RnR</metadataServerUrl><passwordExpired>false</passwordExpired><sandbox>false</sandbox><serverUrl>https://foobar.my.salesforce.com/services/Soap/u/37.0/00D30ACACA00RnR</serverUrl><sessionId>00D30ACACA00RnR!AQQAQHLrBFDFGFDFDFDFDFDFQ4PretFUYUYUYI1jPG94DyEr.Kk3J6909090909HaF76RTuxpZ.lU6Wl121212121lKDR8Ig</sessionId><userId>000606060606WH5AAO</userId><userInfo><accessibilityMode>false</accessibilityMode><currencySymbol>$</currencySymbol><orgAttachmentFileSizeLimit>5242880</orgAttachmentFileSizeLimit><orgDefaultCurrencyIsoCode>USD</orgDefaultCurrencyIsoCode><orgDisallowHtmlAttachments>false</orgDisallowHtmlAttachments><orgHasPersonAccounts>false</orgHasPersonAccounts><organizationId>0090909ACA00RnREAU</organizationId><organizationMultiCurrency>false</organizationMultiCurrency><organizationName>Foo Bar, Inc.</organizationName><profileId>0fdfdfdfdfdfdwfAAC</profileId><roleId>00E84884800njJZEAY</roleId><sessionSecondsValid>14400</sessionSecondsValid><userDefaultCurrencyIsoCode xsi:nil="true"/><userEmail>foobar.homer@foobar.com</userEmail><userFullName>FooBar Homer</userFullName><userLanguage>en_US</userLanguage><userId>000606060606WH5AAO</userId><userLocale>en_US</userLocale><userName>foobar.homer@foobar.com</userName><userTimeZone>America/New_York</userTimeZone><userType>Standard</userType><userUiSkin>Theme3</userUiSkin></userInfo></result></loginResponse></soapenv:Body></soapenv:Envelope>};
my $href = {
  loginResponse => {
    result => {
      metadataServerUrl => "https://foobar.my.salesforce.com/services/Soap/m/37.0/00D30ACACA00RnR",
      passwordExpired => "false",
      sandbox => "false",
      serverUrl => "https://foobar.my.salesforce.com/services/Soap/u/37.0/00D30ACACA00RnR",
      sessionId => "00D30ACACA00RnR!AQQAQHLrBFDFGFDFDFDFDFDFQ4PretFUYUYUYI1jPG94DyEr.Kk3J6909090909HaF76RTuxpZ.lU6Wl121212121lKDR8Ig",
      userId => "000606060606WH5AAO",
      userInfo => {
        accessibilityMode => "false",
        currencySymbol => "\$",
        orgAttachmentFileSizeLimit => 5242880,
        orgDefaultCurrencyIsoCode => "USD",
        orgDisallowHtmlAttachments => "false",
        orgHasPersonAccounts => "false",
        organizationId => "0090909ACA00RnREAU",
        organizationMultiCurrency => "false",
        organizationName => "Foo Bar, Inc.",
        profileId => "0fdfdfdfdfdfdwfAAC",
        roleId => "00E84884800njJZEAY",
        sessionSecondsValid => 14400,
        userDefaultCurrencyIsoCode => undef,
        userEmail => "foobar.homer\@foobar.com",
        userFullName => "FooBar Homer",
        userId => "000606060606WH5AAO",
        userLanguage => "en_US",
        userLocale => "en_US",
        userName => "foobar.homer\@foobar.com",
        userTimeZone => "America/New_York",
        userType => "Standard",
        userUiSkin => "Theme3"
      }
    }
  }
};
my $som = WWW::Salesforce::Deserializer->deserialize($xml);
isa_ok($som, 'SOAP::SOM', 'deserialize: got a proper SOM object');
is_deeply($som->body, $href, 'deserialized content matches');

$xml = q{<?xml version="1.0" encoding="UTF-8"?><soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sf="urn:fault.partner.soap.sforce.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soapenv:Body><soapenv:Fault><faultcode>INVALID_LOGIN</faultcode><faultstring>INVALID_LOGIN: Invalid username, password, security token; or user locked out.</faultstring><detail><sf:LoginFault xsi:type="sf:LoginFault"><sf:exceptionCode>INVALID_LOGIN</sf:exceptionCode><sf:exceptionMessage>Invalid username, password, security token; or user locked out.</sf:exceptionMessage></sf:LoginFault></detail></soapenv:Fault></soapenv:Body></soapenv:Envelope>};
$href = {
  Fault => {
    detail => {
      LoginFault => bless( {
        exceptionCode => "INVALID_LOGIN",
        exceptionMessage => "Invalid username, password, security token; or user locked out."
      }, 'LoginFault' )
    },
    faultcode => "INVALID_LOGIN",
    faultstring => "INVALID_LOGIN: Invalid username, password, security token; or user locked out."
  }
};
$som = WWW::Salesforce::Deserializer->deserialize($xml);
isa_ok($som, 'SOAP::SOM', 'deserialize: got a proper error SOM object');
is_deeply($som->body, $href, 'deserialized error content matches');

done_testing();
