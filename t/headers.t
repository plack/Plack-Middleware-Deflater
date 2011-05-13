use strict;
use Test::More;
#use Test::Requires qw(IO::Handle::Util);
#use IO::Handle::Util qw(:io_from);
use HTTP::Request::Common;
use Plack::Builder;
use Plack::Test;
use Plack::Middleware::Deflater;
$Plack::Test::Impl = "Server";

# no compression on X-REPROXY-URL
my $app = builder {
    enable 'Deflater', content_type => 'text/html', vary_user_agent => 1;
    sub {
        [   200,
            [   'Content-Length' => '100',
                'Content-type'   => 'text/plain',
                'X-REPROXY-URL' =>
                    'http://10.0.0.1:7500/dev1/0/000/000/0000000001.fid',
            ],
            ['http://10.0.0.1:7500/dev1/0/000/000/0000000001.fid'],
        ];
        }
};

test_psgi
    app    => $app,
    client => sub {
    my $cb  = shift;
    my $req = HTTP::Request->new( GET => "http://localhost/" );
    my $res = $cb->($req);
    isnt $res->content_encoding, 'gzip', 'no content-encoding';
    };

done_testing;

