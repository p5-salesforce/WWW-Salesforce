package WWW::Salesforce::Deserializer;

use strict;
use warnings;
use SOAP::Lite;

use base qw( SOAP::Deserializer );
use strict 'refs';

our $XSD_NSPREFIX     = "xsd";
our $XSI_NSPREFIX     = "xsi";
our $SOAPENV_NSPREFIX = "SOAP-ENV";
our $SOAPENC_NSPREFIX = "SOAP-ENC";
our $NSPREFIX         = "wsisup";

sub as_Array {
    my $self = shift;
    my $f    = shift;
    my @Array;
    foreach my $elem (@_) {
        my ($name, $attr, $value, $ns) = splice(@$elem, 0, 4);
        my $attrv = ${attr}->{$XSI_NSPREFIX . ":type"};
        my ($pre, $type) = ($attrv =~ /([^:]*):(.*)/);
        my $result;
        if ($pre eq $XSD_NSPREFIX) {
            $result = $value;
        }
        else {
            my $cmd
                = '$self->as_' . $type . '(1, $name, $attr, @$value, $ns );';

            #        print STDERR $cmd . "\n";
            $result = eval $cmd;
        }
        push(@Array, $result);
    }
    return \@Array;
}

sub as_QueryResult {
    my ($self, $f, $name, $attr, $elements, $ns) = @_;
    my $obj = {done => undef, size => 0, queryLocator => undef, records => [],};
    for my $el (@{$elements}) {
        my ($el_name, $el_attr, $el_val, $el_ns) = @{$el};
        $el_name =~ s/^sf:// if $el_name;
        if (my $nil = $el_attr->{"$XSI_NSPREFIX:nil"}) {
            $el_val = undef if $nil eq 'true';
        }
        if (defined($el_val)) {
            if (my $type = $el_attr->{"$XSI_NSPREFIX:type"}) {
                my ($prefix, $type_name) = split(/:/, $type, 2);
                if (my $func = $self->can("as_$type_name")) {
                    $el_val = $self->$func(undef, @{$el});
                }
            }
            if (ref($obj->{$el_name}) eq 'ARRAY') {
                push @{$obj->{$el_name}}, $el_val;
            }
            elsif ($el_name eq 'done') {
                $obj->{$el_name} = $el_val ? 1 : 0;
            }
            else {
                $obj->{$el_name} = $el_val;
            }
        }
    }
    return $obj;
}

sub as_sObject {
    my ($self, $f, $name, $attr, $elements, $ns) = @_;
    my $obj = {};
    for my $el (@{$elements}) {
        my ($el_name, $el_attr, $el_val, $el_ns) = @{$el};
        $el_name =~ s/^sf:// if $el_name;
        if (my $nil = $el_attr->{"$XSI_NSPREFIX:nil"}) {
            $el_val = undef if $nil eq 'true';
        }
        if (my $type = $el_attr->{"$XSI_NSPREFIX:type"}) {
            my ($prefix, $type_name) = split(/:/, $type, 2);
            if (my $func = $self->can("as_$type_name")) {
                $obj->{$el_name} = $self->$func(undef, @{$el});
            }
            else {
                $obj->{$el_name} = $el_val;
            }
        }
        else {
            $obj->{$el_name} = $el_val;
        }
    }
    return $obj;
}

1;

__END__

=encoding utf8

=head1 NAME

WWW::Salesforce::Deserializer - Parse response SOAP objects from L<Salesforce.com|http://www.salesforce.com>.

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use strict;
    use warnings;
    use WWW::Salesforce::Deserializer ();

    my $xml = q{<?xml version="1.0" encoding="UTF-8"?><foo>bar</foo>};
    my $som = WWW::Salesforce::Deserializer->deserialize($xml);
    # now we have a SOAP::SOM object, let's get a hash ref
    my $href = $som->body();

=head1 DESCRIPTION

This class provides a common way to parse the XML responses we get from our
communication with L<Salesforce.com|http://www.salesforce.com>. You shouldn't
need to interact with this module directly.

=head1 METHODS

L<WWW::Salesforce::Deserializer> inherits all methods from L<SOAP::Deserializer> and
implements the following new ones.

=head2 as_Array

Takes an array of XML tags and turns them into a Perl array.

=head2 as_QueryResult

Parses the query result into the proper hash reference of data to match the
Salesforce
L<QueryResult|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_query_queryresult.htm>
object.

=head2 as_sObject

Parses the XML into the proper hash reference of data to match the
Salesforce
L<sObject|https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_concepts_core_data_objects.htm#i1421095>.

=head1 SEE ALSO

L<WWW::Salesforce>

=cut
