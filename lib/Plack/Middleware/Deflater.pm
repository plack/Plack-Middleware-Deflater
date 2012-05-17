package Plack::Middleware::Deflater;
use strict;
use 5.008001;
our $VERSION = '0.06';
use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw( content_type vary_user_agent);

use IO::Compress::Deflate;
use IO::Compress::Gzip;
use Plack::Util;

sub prepare_app {
    my $self = shift;
    if ( my $match_cts = $self->content_type ) {
        $match_cts = [$match_cts] if ! ref $match_cts; 
        $self->content_type($match_cts);
    }
}

sub call {
    my($self, $env) = @_;

    my $res = $self->app->($env);

    $self->response_cb($res, sub {
        my $res = shift;

        # can't operate on Content-Ranges
        return if $env->{HTTP_CONTENT_RANGE};

        my $h = Plack::Util::headers($res->[1]);
        my $content_type = $h->get('Content-Type') || '';
        $content_type =~ s/(;.*)$//;
        if ( my $match_cts = $self->content_type ) {
            my $match=0;
            for my $match_ct ( @{$match_cts} ) {
                if ( $content_type eq $match_ct ) {
                    $match++;
                    last;
                }
            }
            return unless $match;
        }

        if (Plack::Util::status_with_no_entity_body($res->[0]) or
            $h->exists('Cache-Control') && $h->get('Cache-Control') =~ /\bno-transform\b/) {
            return;
        }

        my @vary = split /\s*,\s*/, ($h->get('Vary') || '');
        push @vary, 'Accept-Encoding';
        push @vary, 'User-Agent' if $self->vary_user_agent;
        $h->set('Vary' => join(",", @vary));

        # some browsers might have problems, so set no-compress
        return if $env->{"psgix.no-compress"};

        # Some browsers might have problems with content types
        # other than text/html, so set compress-only-text/html
        if ( $env->{"psgix.compress-only-text/html"} ) {
            return if $content_type ne 'text/html';
        }

        # TODO check quality
        my $encoding = 'identity';
        if ( defined $env->{HTTP_ACCEPT_ENCODING} ) {
            for my $enc (qw(gzip deflate identity)) {
                if ( $env->{HTTP_ACCEPT_ENCODING} =~ /\b$enc\b/ ) {
                    $encoding = $enc;
                    last;
                }
            }
        }

        my $encoder;
        if ($encoding eq 'gzip') {
            $encoder = sub { IO::Compress::Gzip->new($_[0]) };
        } elsif ($encoding eq 'deflate') {
            $encoder = sub { IO::Compress::Deflate->new($_[0]) };
        } elsif ($encoding ne 'identity') {
            my $msg = "An acceptable encoding for the requested resource is not found.";
            @$res = (406, ['Content-Type' => 'text/plain'], [ $msg ]);
            return;
        }

        if ($encoder) {
            $h->set('Content-Encoding' => $encoding);
            $h->remove('Content-Length');
            my($done, $buf);
            my $compress = $encoder->(\$buf);
            return sub {
                my $chunk = shift;
                return if $done;
                unless (defined $chunk) {
                    $done = 1;
                    $compress->flush;
                    return $buf;
                }
                $compress->print($chunk);
                if (defined $buf) {
                    my $body = $buf;
                    $buf = undef;
                    return $body;
                } else {
                    return '';
                }
            };
        }
    });
}

1;

__END__

=head1 NAME

Plack::Middleware::Deflater - Compress response body with Gzip or Deflate

=head1 SYNOPSIS

  use Plack::Builder;

  builder {
    enable sub {
        my $app = shift;
        sub {
            my $env = shift;
            my $ua = $env->{HTTP_USER_AGENT} || '';
            # Netscape has some problem
            $env->{"psgix.compress-only-text/html"} = 1 if $ua =~ m!^Mozilla/4!;
            # Netscape 4.06-4.08 have some more problems
             $env->{"psgix.no-compress"} = 1 if $ua =~ m!^Mozilla/4\.0[678]!;
            # MSIE (7|8) masquerades as Netscape, but it is fine
            if ( $ua =~ m!\bMSIE (?:7|8)! ) {
                $env->{"psgix.no-compress"} = 0;
                $env->{"psgix.compress-only-text/html"} = 0;
            }
            $app->($env);
        }
    };
    enable "Deflater",
        content_type => ['text/css','text/html','text/javascript','application/javascript'],
        vary_user_agent => 1;
    sub { [200,['Content-Type','text/html'],["OK"]] }
  };

=head1 DESCRIPTION

Plack::Middleware::Deflater is a middleware to encode your response
body in gzip or deflate, based on C<Accept-Encoding> HTTP request
header. It would save the bandwidth a little bit but should increase
the Plack server load, so ideally you should handle this on the
frontend reverse proxy servers.

This middleware removes C<Content-Length> and streams encoded content,
which means the server should support HTTP/1.1 chunked response or
downgrade to HTTP/1.0 and closes the connection.

=head1 CONFIGURATIONS

=over 4

=item content_type

  content_type => 'text/html',
  content_type => [ 'text/html', 'text/css', 'text/javascript', 'application/javascript', 'application/x-javascript' ]

Content-Type header to apply deflater. if content-type is not defined, Deflater will try to deflate all contents.

=item vary_user_agent

  vary_user_agent => 1

Add "User-Agent" to Vary header.

=back

=head1 ENVIRONMENT VALUE

=over 4

=item psgix.no-compress

Do not apply deflater

=item psgix.compress-only-text/html

Apply deflater only if content_type is "text/html"

=back

=head1 LICENSE

This software is licensed under the same terms as Perl itself.

=head1 AUTHOR 

Tatsuhiko Miyagawa

=head1 SEE ALSO

L<Plack>, L<http://httpd.apache.org/docs/2.2/en/mod/mod_deflate.html>

=cut
