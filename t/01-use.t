#!perl

use strict;
use warnings;
use Test::More 0.88; # done_testing

BEGIN {
    use_ok('WWW::Salesforce') or BAIL_OUT("Can't use Salesforce module");
    use_ok('WWW::Salesforce::Deserializer') or BAIL_OUT("Can't use Deserializer");
}

can_ok('WWW::Salesforce', qw(new login));

done_testing();
