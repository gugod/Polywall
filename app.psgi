#!/usr/bin/env perl
use 5.012;
use lib 'lib';
use Polywall;

use Continuity;
use Continuity::Adapt::PSGI;

Continuity->new(
    adapter => Continuity::Adapt::PSGI->new,
    cookie_session => 'polywall_session',
    callback => \&Polywall::dispatch
)->loop;

# plackup -s Twiggy
