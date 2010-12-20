use 5.012;

package Polywall 1.0;
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

    given ($uri->path) {
        when ('/') {
            show($self);
        }
        when ('/posts/new') {
            to_create_posts($self);
        }

        when ('/stickies/new') {
            to_create_stickies($self);
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

    render(
        $self,
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
        render($self, "posts/new.tx");
        $self->next;
        $content = $self->param('post.content');
    }

    Post->insert({ content => $content, created_at => DateTime->now });

    render($self, "posts/created.tx");
}

sub to_create_stickies {
    my $content = $self->param('sticky.content');

    while(!$content) {
        $self->print(q{<form><input type="text" name="sticky.content"><input type="submit"></form>});
        $self->next;
        $content = $self->param('sticky.content');
    }

    Sticky->insert({ content => $content, created_at => DateTime->now });

    $self->print(q{<p>Done !</p><p><a href="/">Back to homepage.</a></p>});
}

1;
