#!/usr/bin/env perl

use strict;
use warnings;

use 5.008001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'WWW::Salesforce',
    VERSION_FROM      => 'lib/WWW/Salesforce.pm',
    PREREQ_PM         => {
        'Crypt::SSLeay' => 0.56,
        'SOAP::Lite'    => 0.68,
    },
    ABSTRACT_FROM => 'lib/WWW/Salesforce.pm',
    AUTHOR => 'Chase Whitener <cwhitener@gmail.com>',
    LICENSE => 'perl',
);
