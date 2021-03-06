package Polywall;
use strict;
use feature qw(switch);


use parent qw(Continuity::RequestHolder);
use Encode qw(encode_utf8 decode_utf8);
use DateTime;
use MongoDB;
use URI;
use Text::Xslate;
use String::Truncate ();

sub __mongodb {
    MongoDB::Connection->new->polywall;
}

sub Post()   { __mongodb->posts }
sub Sticky() { __mongodb->stickies }

sub __xslate {
    Text::Xslate->new(path => ['views'], cache => 1, cache_dir => "/tmp/polywall_xslate_cache");
}


use self::implicit;

sub render {
    my ($template, $var) = @args;

    $var->{content} = __xslate->render($template, $var);

    $self->print( Encode::encode_utf8(__xslate->render("layout.tx", $var) ));
}

sub show() {
    my @posts    = map {
        $_->{summerized_content} = String::Truncate::elide( $_->{content}, 280 );
        $_;
    } Post->find->sort({   created_at => -1 })->limit(25)->all;

    my @stickies = Sticky->find({
        "created_at" => { '$gte' => DateTime->now->subtract(hours => 24) }
    })->sort({ created_at => -1 })->all;

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

sub to_show_post($) {
    my ($post_id) = @args;
    my $post = Post->find_one({ _id => MongoDB::OID->new(value => $post_id) });

    render("posts/show.tx", { post => $post });
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

        when ( /^\/posts\/([0-9a-z]{24})$/ ) {
            to_show_post($1);
        }
    }
}

1;
