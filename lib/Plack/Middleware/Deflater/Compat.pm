package Plack::Middleware::Deflater::Compat;
use strict;
use parent qw(Plack::Middleware);
use Plack::Util;

sub call {
    my($self, $env) = @_;

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
    return $self->app->($env);
}

1;
