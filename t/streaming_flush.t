use strict;
use warnings;
use FindBin;
use Test::More tests => 4;
use HTTP::Request::Common;
use Plack::Test;
use Plack::Builder;
use Test::Requires {
    'AnyEvent' => 5.34,
    'Plack::Test::AnyEvent' => 0.03
};

my $app = builder {
    enable 'Chunked';
    enable 'Deflater';

    # Non streaming
    # sub { [200, [ 'Content-Type' => 'text/plain' ], [ "Hello World" ]] }

    # streaming
    sub {
        my $env = shift;
        return sub {
            my $r = shift;
            my $w = $r->([ '200', [ 'Content-Type' => 'text/plain' ]]);
            my $timer;
            my $i = 0;
            my @message = qw/Hello World/;
            $timer = AnyEvent->timer(
                after => 1,
                interval => 1,
                cb => sub {
                    use Compress::Zlib ();
                    local $env->{'psgix.deflater_flush_type'} = Compress::Zlib::Z_SYNC_FLUSH();
                    $w->write($message[$i]. "x" x 1024 . "\n");
                    $i++;
                    if ( $i == 2 ) {
                        $w->close;
                        undef $timer;
                    }
                }
            );
        };
    };
};

local $Plack::Test::Impl = 'AnyEvent';

test_psgi
    app    => $app,
    client => sub {
        my $cb = shift;
        
        my $req = HTTP::Request->new( GET => "http://localhost/" );
        $req->accept_decodable;
        my $res = $cb->($req);

        # The first is by Plack::Middleware::Chunked.
        # The second is by Plack::Test::AnyEvent. (Is it reasonable?)
        # is $res->header('Transfer-Encoding'), 'chunked'; # chunked, chunked
        like $res->header('Transfer-Encoding'), qr/chunked/;

        my @chunk;
        $res->on_content_received(sub {
            my ($content) = @_;
            push @chunk, [ $content, time ];
        });
        $res->recv;
        is $res->content_encoding, 'gzip';
        is @chunk, 2;
        ok abs $chunk[0][1] - $chunk[1][1] >= 1;
    };


done_testing;
