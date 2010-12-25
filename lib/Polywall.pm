use 5.012;

package Polywall 1.0;
use parent qw(Continuity::RequestHolder);
use Encode qw(encode_utf8);
use DateTime;
use MongoDB;
use URI;
use Text::Xslate;

{
    my $mdb;
    sub __mongodb {
        return $mdb if $mdb;
        $mdb = MongoDB::Connection->new->polywall;
    }

    sub Post()   { __mongodb->posts }
    sub Sticky() { __mongodb->stickies }
}

use self::implicit;

sub render {
    my ($template, $var) = @args;
    my $tx = Text::Xslate->new(path => ['views'], cache => 1, cache_dir => "/tmp/polywall_xslate_cache");

    $var->{content} = $tx->render($template, $var);
    $self->print( $tx->render("layout.tx", $var) );
}

sub show() {
    my @posts    = Post->find->sort({   created_at => -1 })->limit(25)->all;
    my @stickies = Sticky->find({
        "created_at" => { '$gte' => DateTime->now->subtract(hours => 24) }
    })->sort({ created_at => -1 })->all;

    @posts = map {
        $_->{content} = encode_utf8($_->{content});
        $_;
    } grep { $_->{content} }@posts;

    @stickies = map {
        $_->{content} = encode_utf8($_->{content});
        $_;
    } grep { $_->{content} }@stickies;

    render("show.tx", {
        posts => \@posts,
        stickies => \@stickies
    });
}

sub to_create_posts() {
    my $content = $self->param('post.content');

    while(!$content) {
        render("posts/new.tx");

        $self->next;
        $content = $self->param('post.content');
    }

    Post->insert({ content => $content, created_at => DateTime->now });

    render("posts/created.tx");
}

sub to_create_stickies() {
    my $content = $self->param('sticky.content');

    while(!$content) {
        render("stickies/new.tx");
        $self->next;
        $content = $self->param('sticky.content');
    }

    Sticky->insert({ content => $content, created_at => DateTime->now });

    render("stickies/created.tx");
}

no self::implicit;

sub dispatch {
    my $self = shift;
    my $uri = URI->new($self->request->uri);

    $self = bless $self, 'Polywall';

    given ($uri->path) {
        when ('/') {
            show;
        }
        when ('/posts/new') {
            to_create_posts;
        }

        when ('/stickies/new') {
            to_create_stickies;
        }
    }
}

1;
