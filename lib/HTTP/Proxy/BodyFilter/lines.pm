package HTTP::Proxy::BodyFilter::lines;

use strict;
use Carp;
use base qw( HTTP::Proxy::BodyFilter );

=head1 NAME

HTTP::Proxy::BodyFilter::lines - A filter that outputs only complete lines

=head1 SYNOPSIS

    use HTTP::Proxy::BodyFilter::lines;
    use MyFilter;    # this filter only works on complete lines

    my $filter = MyFilter->new();

    # note that both filters will be run on the same messages
    # (those with a MIME type of text/*)
    $proxy->push_filter(
        mime     => 'text/*',
        response => HTTP::Proxy::BodyFilter::lines->new
    );
    $proxy->push_filter( mime => 'text/*', response => $filter );

    # I want my lines to end with '!'
    # This is equivalent to $/ = '!' in a normal Perl program
    my $lines = HTTP::Proxy::BodyFilter::lines->new('!');

=head1 DESCRIPTION

The HTTP::Proxy::BodyFilter::lines filter makes sure that the next filter
in the filter chain will only receive complete lines. The "chunks"
of data received by the following filters with either end with C<\n>
or will be the last piece of data for the current HTTP message body.

You can change the idea the filter has of what is a line by passing to
its constructor the string it should understand as line ending. C<\n>
is the default value.

    my $filter = HTTP::Proxy::BodyFilter::lines->new( $sep );

This is similar to modifying $/ in a Perl program. In fact, this
filter has a behaviour so similar to modifying $/ that it also knows
about "paragraph mode" and "record mode".

Note that the "slurp" mode is not supported. Please use
HTTP::Proxy::BodyFilter::store to enable the generic store and forward
filter mechanism.

=cut

sub init {
    my $self = shift;

    croak "slurp mode is not supported. Use HTTP::Proxy::BodyFilter::store."
      if @_ && not defined $_[0];

    my $eol = @_ ? $_[0] : "\n";
    if ( ref $eol eq 'SCALAR' ) {
        local $^W;
        croak qq'"$$eol" is not numeric' if $$eol ne ( 0 + $$eol );
        croak "Records of size 0 are not supported" if $$eol == 0;
    }
    $self->{eol} = $eol;
}

sub filter {
    my ( $self, $dataref, $message, $protocol, $buffer ) = @_;
    return if not defined $buffer;    # last "lines"

    my $eol = $self->{eol};
    if ( $eol eq "" ) {               # paragraph mode
        # if $$dataref ends with \n\n, we cannot know if there are
        # more white lines at the beginning of the next chunk of data
        $$dataref =~ /^(.*\n\n)([^\n].*)/sg;
        ( $$dataref, $$buffer) = defined $1 ? ($1, $2) : ("", $$dataref);
    }
    elsif ( ref $eol eq 'SCALAR' ) {    # record mode
        my $idx = length($$dataref) - length($$dataref) % $$eol;
        $$buffer = substr( $$dataref, $idx );
        $$dataref = substr( $$dataref, 0, $idx );
    }
    else {
        my $idx = rindex( $$dataref, $eol );
        if ( $idx == -1 ) {
            $$buffer  = $$dataref;      # keep everything for later
            $$dataref = '';
        }
        else {
            $idx += length($eol);
            $$buffer = substr( $$dataref, $idx );
            $$dataref = substr( $$dataref, 0, $idx );
        }
    }
}

=head1 AUTHOR

Philippe "BooK" Bruhat, E<lt>book@cpan.orgE<gt>.

=head1 COPYRIGHT

This module is free software; you can redistribute it or modify it under
the same terms as Perl itself.

=cut

1;