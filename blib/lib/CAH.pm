package CAH;
use warnings;
use strict;
use Data::Dumper;
use JSON -support_by_pp;
use feature 'say';
use feature ':5.10';
use threads ('yield',
'stack_size' => 64*4096,
'exit' => 'threads_only',
'stringify');
#valid states idle, joining, dealing, turn.
my $gamestate = "idle";
my @whitecards;
my @blackcards;
my %players = ();
loadcards();
sub spec {
        return {
        nick => 'jdcah',
                altnick => 'jdcah_',
        server => 'irc.freenode.org',
        port => 6667,
        handlers => {
	    public => [ sub { CAH::choice(@_)},sub { CAH::join(@_)}],
            addressed => [ sub {CAH::choice(@_)},sub { CAH::join(@_)},sub { CAH::state(@_)}],                        
            msg =>       [ sub {CAH::choice(@_)},sub { CAH::join(@_)}],
        }
    }
}
sub multichoice {
    say "Execute multichoice";
    my ($robit,$args) = @_;
    if ($args->{what} =~ /^(\d+) (\d+)$/) {
        my ($choice,$second) = ($1,$2);
	say $choice;
	if ($second) {say $second};
        return 1;
    }
    return 0;
}
sub choice {
    say "Execute choice";
    my ($robit,$args) = @_;
    if ($args->{what} =~ /^(\d+)$/) {
        my ($choice) = ($1);
	say $choice;
        return 1;
    }
    return 0;
}
sub join {
    say "Execute join";
    my ($robit,$args) = @_;
    if ($args->{what} =~ /^(join)$/) {
	if ($gamestate eq "idle") {
		say $args->{who};
		my $player = $args->{who};
		if (exists $players{$player}) {
			$robit->cb->reply($args->{where}, $args->{who} . ": You are already in the game.");
			$players{$args->{who}} = 0;	
		}		
		else {
			$robit->cb->reply($args->{where}, $args->{who} . ": You have joined the game.");
		}
		return 1;
	}
	$robit->cb->reply($args->{where}, $args->{who} . ": Game is in wrong state.");
	return 1;
    }
    return 0;
}
sub state {
    say "Execute state";
    my ($robit,$args) = @_;
    if ($args->{what} =~ /^(state)$/) {
	$robit->cb->reply($args->{where}, $args->{who} . ": Current state is $gamestate");
	#$robit->cb->reply($args->{where}, $args->{who} . ": ".scalar(@whitecards)." white cards.");
	$robit->cb->reply($args->{where}, $args->{who} . ": ".scalar(@blackcards)." black cards.");
	$robit->{heap}->{whois_cb}->{$args->{who}} = sub {
                my $account = $_[0]->{identified}; 
		if (!$account) {$account = $args->{who};} 
		say $account;
		$robit->cb->reply($args->{where}, $args->{who} . ": You are $account");
	}
    }
    return 0;
}
sub loadcards {	
	@blackcards = do {
	    open my $fh, "<", "black.txt"
		or die "could not open black.txt: $!";
	    <$fh>;
	};
	@whitecards = do {
	    open my $fh, "<", "white.txt"
		or die "could not open white.txt: $!";
	    <$fh>;
	};
	return 1;
}
1
