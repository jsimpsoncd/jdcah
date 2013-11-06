package QQ;
use strict;
use warnings;

use Data::Dumper;
use LWP::UserAgent::POE;
use Finance::NASDAQ::Quote;
use feature ':5.10';
use feature 'say';

sub spec {
    return {
        nick => 'rr',
        server => 'irc.freenode.org',
        port => 6667,
        handlers => {
            addressed => sub { QQ::quote(@_), QQ::profit(@_)  },
            msg => sub { QQ::quote(@_), QQ::profit(@_)  },
        }
    };
}

sub quote {
    my ($robit,$args) = @_;
    if ($args->{what} =~ /^([-.\w]+)\s*$/) {
        my $symbol = $1;
        my $quote = Finance::NASDAQ::Quote::getquote($symbol, LWP::UserAgent::POE->new());
        $robit->cb->reply($args->{where}, $args->{who} . ": $quote");
        return 1;
    }
    return 0;
}
sub profit {
    my ($robit,$args) = @_;
    if ($args->{what} =~ /profit\s+([-.\w]+)\s+(\$?[.\d]+)\s+(\d+)\s*$/) {
        my $symbol = $1;
        my %quote = Finance::NASDAQ::Quote::getquote($symbol, LWP::UserAgent::POE->new());
	my $profit = ($quote{prc} - $2) * $3;
        $robit->cb->reply($args->{where}, $args->{who} . ": Symbol $symbol Shares $3 Paid $2 Profit formatcurrency($profit)");
        return 1;
    }
    return 0;
}
sub formatCurrency {
my $number = sprintf "%.2f", shift @_;
# Add one comma each time through the do-nothing loop
1 while $number =~ s/^(-?\d+)(\d\d\d)/$1,$2/;
# Put the dollar sign in the right place
$number =~ s/^(-?)/$1\$/;
return $number;
}
1
