use strict;
use Test::More;
use Test::Requires qw(IO::Handle::Util);
use IO::Handle::Util qw(:io_from);
use HTTP::Request::Common;
use Plack::Builder;
use Plack::Test;
use Plack::Middleware::Deflater;
$Plack::Test::Impl = "Server";


my $app = builder {
    enable 'Deflater', content_type => 'text/*';
    sub { [200, [ 'Content-Type' => 'text/plain' ], [ "Hello World" ]] }
};
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        $req->accept_decodable;
        my $res = $cb->($req);
        is $res->decoded_content, 'Hello World';
        is $res->content_encoding, 'gzip';
    };

my $app2 = builder {
    enable 'Deflater', content_type => 'text/*';
    sub { [200, [ 'Content-Type' => 'text/html; charset=UTF-8' ], [ "Hello World" ]] }
};
test_psgi
    app => $app2,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        $req->accept_decodable;
        my $res = $cb->($req);
        is $res->decoded_content, 'Hello World';
        is $res->content_encoding, 'gzip';
    };

my $app3 = builder {
    enable 'Deflater', content_type => 'text/*';
    sub { [200, [ 'Content-Type' => 'image/jpeg' ], [ "Hello World" ]] }
};
test_psgi
    app => $app3,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        $req->accept_decodable;
        my $res = $cb->($req);
        is $res->decoded_content, 'Hello World';
        isnt $res->content_encoding, 'gzip';
    };

my $app4 = builder {
    enable 'Deflater', content_type => ['text/*','application/javascript'];
    sub { [200, [ 'Content-Type' => 'application/javascript' ], [ "Hello World" ]] }
};
test_psgi
    app => $app4,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        $req->accept_decodable;
        my $res = $cb->($req);
        is $res->decoded_content, 'Hello World';
        is $res->content_encoding, 'gzip';
    };

my $app5 = builder {
    enable 'Deflater', content_type => ['text/*','application/javascript'];
    sub { [200, [ 'Content-Type' => 'image/gif' ], [ "Hello World" ]] }
};
test_psgi
    app => $app5,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => "http://localhost/");
        $req->accept_decodable;
        my $res = $cb->($req);
        is $res->decoded_content, 'Hello World';
        isnt $res->content_encoding, 'gzip';
    };



done_testing;
