use 5.012;

package Polywall 1.0;
use parent qw(Continuity::RequestHolder);
use self 0.32;
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

{
    my $tx = Text::Xslate->new(path => ['views']);
    sub render {
        my ($template, $var) = @args;

        $var->{content} = $tx->render($template, $var);
        $self->print( $tx->render("layout.tx", $var) );
    }
}

sub dispatch {
    my $uri = URI->new($self->request->uri);

    $self = bless $self, 'Polywall';

    given ($uri->path) {
        when ('/') {
            $self->show;
        }
        when ('/posts/new') {
            $self->to_create_posts;
        }

        when ('/stickies/new') {
            $self->to_create_stickies;
        }
    }
}

sub show {
    my @posts    = Post->find->sort({   created_at => -1 })->limit(10)->all;
    my @stickies = Sticky->find->sort({ created_at => -1 })->all;

    @posts = map {
        $_->{content} = encode_utf8($_->{content});
        $_;
    } grep { $_->{content} }@posts;

    @stickies = map {
        $_->{content} = encode_utf8($_->{content});
        $_;
    } grep { $_->{content} }@stickies;

    $self->render(
        "show.tx",
        {
            posts => \@posts,
            stickies => \@stickies
        }
    );
}

sub to_create_posts {
    my $content = $self->param('post.content');

    while(!$content) {
        $self->render("posts/new.tx");
        $self->next;
        $content = $self->param('post.content');
    }

    Post->insert({ content => $content, created_at => DateTime->now });

    $self->render("posts/created.tx");
}

sub to_create_stickies {
    my $content = $self->param('sticky.content');

    while(!$content) {
        $self->render("stickies/new.tx");
        $self->next;
        $content = $self->param('sticky.content');
    }

    Sticky->insert({ content => $content, created_at => DateTime->now });

    $self->render("stickies/created.tx");
}

1;
