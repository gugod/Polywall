#!/usr/bin/env perl
use 5.012;

package Polywall 1.0;
use self 0.32;
use Encode qw(encode_utf8);
use DateTime;
use MongoDB;
use URI;

{
    my $mdb;
    sub __mongodb {
        return $mdb if $mdb;
        $mdb = MongoDB::Connection->new->polywall;
    }

    sub Post()   { __mongodb->posts }
    sub Sticky() { __mongodb->stickies }
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
    my @posts = Post->find->sort({ created_at => -1 })->limit(10)->all;
    my @stickies = Sticky->find->sort({ created_at => -1 })->all;

    $self->print(q{<p><a href="/posts/new">Create New Post</a></p>});
    $self->print(qq{<div id="posts">});
    for (@posts) {
        next unless $_->{content};
        my $c = encode_utf8( $_->{content} );
        $self->print(qq{<article><p>$c</p></article>});
    }
    $self->print(qq{</div>});

    $self->print(qq{<hr>});
    $self->print(q{<p><a href="/stickies/new">Create New Sticky</a></p>});
    $self->print(qq{<div id="stickies">});
    for (@stickies) {
        next unless $_->{content};
        my $c = encode_utf8( $_->{content} );
        $self->print(qq{<article><p>$c</p></article>});
    }
    $self->print(qq{</div>});
}

sub to_create_posts {
    my $content = $self->param('post.content');

    while(!$content) {
        $self->print(q{<form><input type="text" name="post.content"><input type="submit"></form>});
        $self->next;
        $content = $self->param('post.content');
    }

    Post->insert({ content => $content, created_at => DateTime->now });
    $self->print(q{<p>Done !</p><p><a href="/">Back to homepage.</a></p>});
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

package main;
use Continuity;
use Continuity::Adapt::PSGI;

Continuity->new(
    adapter => Continuity::Adapt::PSGI->new,
    cookie_session => 'polywall_session',
    callback => \&Polywall::dispatch
)->loop;
