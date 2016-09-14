use strict;
use warnings;

use Test::More tests => 6;
use POSIX qw(strftime);
use Time::Piece;

use WWW::Salesforce;

my $test_time = time;
my @local_time = localtime($test_time);

my $sf_now;

if ($^O !~ /win/i) {
    $sf_now = strftime('%Y-%m-%dT%H:%M:%S%z', @local_time);
    $sf_now =~ s/(\d\d)$/:$1/;

    is(WWW::Salesforce->sf_date($test_time), $sf_now,
        'Checking right here, right now');
} else {
    pass("%z doesn't work properly on Windows");
}

# Timezones from http://science.ksc.nasa.gov/software/winvn/userguide/3_1_4.htm
my @places = ({ name => 'Sydney', tz => 'EAS-10EAD', off => '+10:00' },
              { name => 'Chicago', tz => 'CST6CDT', off => '-06:00' },
              { name => 'Newfoundland', tz => 'NST3:30NDT', off => '-03:30' },
              { name => 'Adelaide', tz => 'CAS-9:30CAD', off => '+09:30' },
              { name => 'Chatham Island',tz => 'CDT-13:45CDT',off => '+13:45' }
             );

foreach my $place (@places) {
    $ENV{TZ} = $place->{tz};
    Time::Piece::_tzset();
    @local_time = localtime($test_time);

    $sf_now = strftime('%Y-%m-%dT%H:%M:%S', @local_time) . $place->{off};
    is(WWW::Salesforce->sf_date($test_time), $sf_now,
      'Checking ' . $place->{name} . ' time');
}
