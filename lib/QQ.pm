package QQ;
use warnings;
use strict;
use LWP::UserAgent::POE;
use Data::Dumper;
use DBI;
use Finance::NASDAQ::Quote;
use LWP::Simple;
use XML::Simple;
use XML::Parser;
use URI::Escape;
use JSON -support_by_pp;
use feature 'say';
use feature ':5.10';
use threads ('yield',
'stack_size' => 64*4096,
'exit' => 'threads_only',
'stringify');
# ariens :(  who are you
#added to git
sub spec {
	return {
        nick => 'rr',
		altnick => 'qq',
        server => 'irc.freenode.org',
        port => 6667,
        handlers => {
            addressed => [ sub {QQ::help(@_)}, sub { QQ::status(@_) }, sub { QQ::buy(@_) }, sub { QQ::sell(@_) }, sub { QQ::reset(@_)}, sub { QQ::quote(@_)}, sub { QQ::math(@_)}],			
            msg =>       [ sub {QQ::help(@_)}, sub { QQ::status(@_) }, sub { QQ::buy(@_) }, sub { QQ::sell(@_) }, sub {QQ::account(@_)}, sub { QQ::reset(@_)}, sub { QQ::quote(@_)},sub { QQ::math(@_)}],
        }
    };
}
sub buy {
        
		my ($robit,$args) = @_;
		$robit->cb->log("Check Buy");
		if ($args->{what} =~ /buy\s+([-.\w]+)\s+(\d+|all)(?:\s+(\$?(?:\d+\.\d*\d*\.?\d+)))?$/)  {
        #if ($args->{what} =~ /buy\s+([-.\w]+)\s+(\$?(?:\d+\.\d*|\d*.?\d+))$/)  {
                if (MarketStatus() == 0) {
                        $robit->cb->reply($args->{where}, $args->{who} . ": The market is not currently open, try again later.");
                return 1;
                }
		$robit->whois($args->{who});
		my $a_dork = "";
		my $symbol = $1;
		my $shares = $2;
		my $strike = $3;
		$strike = 0;
		my $dec;
		$robit->{heap}->{whois_cb}->{$args->{who}} = sub {
		$a_dork = $_[0]->{identified};		
		if (!$a_dork) {$a_dork = $args->{who};}
		#$shares= int($shares);
		if ($shares < 0 ) {
			$robit->cb->reply($args->{where}, $args->{who} . ": lol.");
			return 1;
		}
		# get account ID
		if ($symbol eq "CrissiD") {$robit->cb->reply($args->{where}, $args->{who} . ": You cannot afford her.");return 1;}
		if ($symbol eq "Toes") {$robit->cb->reply($args->{where}, $args->{who} . ": Buy? We'll pay you to take him. Please.");return 1;}
		if ($symbol eq "JonathanD") {$robit->cb->reply($args->{where}, $args->{who} . ": Just so you know, we don't accept any returns.");return 1;}
		if ($symbol eq "joeyk") {$robit->cb->reply($args->{where}, $args->{who} . ": If you call now, we'll throw in a free sofa.");return 1;}
		if ($symbol eq "joeyk") {$robit->cb->reply($args->{where}, $args->{who} . ": If you call now, we'll throw in a free sofa.");return 1;}
		if ($symbol eq "nkk") {$robit->cb->reply($args->{where}, $args->{who} . ": Thank you, come again.");return 1;}
		if ($symbol eq "peltkore") {$robit->cb->reply($args->{where}, $args->{who} . ": Why?");return 1;}
		if ($symbol eq "ik") {$robit->cb->reply($args->{where}, "LOUDBOT: BE IK");return 1;}
		if ($symbol eq "linode") {$robit->cb->reply($args->{where}, "Go to fosscon.");return 1;}
                if ($symbol eq "Alipha") {$robit->cb->reply($args->{where}, $args->{who} . ": Please confirm. He enjoys playing with balls.");return 1;}
		my @data;
		my @curdata;
		my $sth2;
		my $dbh = DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
		my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
		#$sth->execute($args->{who});	
		$sth->execute($a_dork);	
		if ($sth->rows == 0) {
			$robit->cb->reply($args->{where}, $args->{who} . ": You do not have an account. Create one with the account command first.");
			return 1;
		}
		while (@data = $sth->fetchrow_array()) {
			#my %quote = Finance::NASDAQ::Quote::getquote($symbol, LWP::UserAgent::POE->new());
			my %quote = getquoteg($symbol);
			print $quote{cur}."\n";
			my $exchange = $quote{exc};
				if (($exchange eq "") || ($quote{prc} == 0)) {
				$robit->cb->reply($args->{where}, $args->{who} . ": that doesn't exist. Neither do you. (buy)");
				return 1;
			}			
			if ($quote{cur} ne "USD") {
				$robit->cb->reply($args->{where}, $args->{who} .": I can't do that general.  Buy something sold in USD.");
				return 1;
			}
			my $price = $quote{prc};
			if (($strike < $price)&&($strike > 0)) {
				$robit->cb->reply($args->{where}, $args->{who} .": Current price of $price is above your stated limit.");
				return 1;
			}
			my $id = $data[0];
			my $balance = $data[2];
			my $max = int(($balance-5)/$price);
			print $max."\n";
			if ($shares eq 'all')
			{
				$shares = $max;
			}
			$shares= int($shares);
			if (($balance - 5 > $price * $shares)) {
				#See if you already have shares.
				$sth = $dbh->prepare("SELECT * FROM Positions WHERE accountid = ? AND symbol = ?");
				$sth->execute($id, uc $symbol);
				#insert or update
				if ($sth->rows == 0){
					$sth = $dbh->prepare("INSERT INTO Positions (accountid, symbol, shares, price, lastprice, updatetime) VALUES (?, ?, ?, ?, ?, 1)");
					$sth->execute($id, uc $symbol, $shares, $price, $price);
					$sth = $dbh->prepare("INSERT INTO Trades (accountid, symbol, shares, price) VALUES (?, ?, ?, ?)");
					$sth->execute($id, uc $symbol, $shares, $price);
					$sth = $dbh->prepare("UPDATE Positions SET lastprice=?, yprice=? WHERE symbol = ?");
					$sth->execute($quote{prc}, $quote{ypc}, $symbol);
				}else{
					#calculate new average price, update timestamp, add (or remove) shares.										
					@curdata = $sth->fetchrow_array();
					my $curvalue = $curdata[4] * $curdata[5];
					my $newvalue = $shares * $price;
					my $totalshares = $shares + $curdata[4];
					print $totalshares,  $curdata[4], $shares;
					#average price 
					my $avgprice = ($curvalue + $newvalue) / $totalshares;
					$sth2 = $dbh->prepare("UPDATE Positions SET shares = ?, price = ? WHERE AccountID = ? and symbol = ?");
					$sth2->execute($totalshares, $avgprice, $id, uc $symbol);
					$sth = $dbh->prepare("INSERT INTO Trades (accountid, symbol, shares, price, updatetime) VALUES (?, ?, ?, ?, 1)");
					$sth->execute($id, uc $symbol, $shares, $price);
					$sth = $dbh->prepare("UPDATE Positions SET lastprice=?, yprice=? WHERE symbol = ?");
					$sth->execute($quote{prc}, $quote{ypc}, $symbol);
				}
				$balance = $balance - (($price * $shares) + 5);
				$sth = $dbh->prepare("UPDATE Users SET CashBalance = CashBalance + 5 WHERE AccountID = 2");
				$sth->execute();
				$sth = $dbh->prepare("UPDATE Users SET CashBalance=? WHERE AccountID = ?");
				$sth->execute($balance, $id);
				$balance = formatCurrency($balance);
				$robit->cb->reply($args->{where}, $args->{who} . ": Bought $shares at $price. Balance: $balance");
			}else{
				 $max = int($balance/$price);
				 $robit->cb->reply($args->{where}, $args->{who} .": You do not have enough dollars, and can afford $max at most.");
			}
		}		
		};
		return 1;
	}
	return 0;
}
sub sell {
		
        my ($robit,$args) = @_;
		$robit->cb->log("Check Sell");		
        if ($args->{what} =~ /sell\s+([-.\w]+)\s+(\d+|all)(?:\s+(\$?(?:\d+\.\d*\d*\.?\d+)))?$/)  {
		$robit->whois($args->{who});
		my $a_dork = "";
		my $symbol = $1;
		my $shares = $2;
		my $strike = $3;
        $robit->{heap}->{whois_cb}->{$args->{who}} = sub {
		$a_dork = $_[0]->{identified};		
		if (!$a_dork) {$a_dork = $args->{who};}
		#if ($args->{what} =~ /sell\s+([-.\w]+)\s+(\$?(?:\d+\.\d*|\d*.?\d+))$/)  {
                if (MarketStatus() == 0) {
                        $robit->cb->reply($args->{where}, $args->{who} . ": The market is not currently open, try again later.");
                return 1;
		}

		print "sym:$symbol shares:$shares strike:$strike";
		$strike = 0;
		
		# get account ID
		my @data;
		my @curdata;
		my $sth2;
		my $dbh = DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
		my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
		$sth->execute($a_dork);	
		if ($sth->rows == 0) {
			$robit->cb->reply($args->{where}, $args->{who} . ": You do not have an account. Create one with the account command first.");
			return 1;
		}
		while (@data = $sth->fetchrow_array()) {
			#my %quote = Finance::NASDAQ::Quote::getquote($symbol, LWP::UserAgent::POE->new());
			my %quote = getquoteg($symbol);
			print $quote{cur}."\n";
			my $price = $quote{prc};
			if (($price eq undef) || ($price eq "")) {
				$robit->cb->reply($args->{where}, $args->{who} .": There is no such symbol.");
				return 1;
			}
			if (($strike > $price) && ($strike > 0)) {
				$robit->cb->reply($args->{where}, $args->{who} .": Current price of $price is below your stated limit.");
				return 1;
			}
			my $id = $data[0];
			my $balance = $data[2];
			if (1) {
				#See if you already have shares.
				$sth = $dbh->prepare("SELECT * FROM Positions WHERE accountid = ? AND symbol = ?");
				$sth->execute($id, uc $symbol);
				#insert or update
				if ($sth->rows == 0){
					$robit->cb->reply($args->{where}, $args->{who} . ": I'm sorry $args->{who}, I'm afraid I can't do that.");
					return 1;
					$sth = $dbh->prepare("INSERT INTO Positions (accountid, symbol, shares, price) VALUES (?, ?, ?, ?)");
					$sth->execute($id, uc $symbol, $shares, $price);
					$sth = $dbh->prepare("INSERT INTO Trades (accountid, symbol, shares, price) VALUES (?, ?, ?, ?)");
					$shares = 0 - $shares;
					$sth->execute($id, uc $symbol, $shares, $price);
				}else{
					#calculate new average price, update timestamp, add (or remove) shares.										
					@curdata = $sth->fetchrow_array();					
					if ($curdata[4] < $shares) {
						$robit->cb->reply($args->{where}, $args->{who} . ": You do not have enough shares. Buzz off.");
						return 1;
					}
					if ($shares eq "all") { $shares = $curdata[4];}
					if ($shares < 1 ) {
						$robit->cb->reply($args->{where}, $args->{who} . ": lol.");
						return 1;
					}
					$shares= int($shares);				
					my $curvalue = $curdata[4] * $curdata[5];
					my $newvalue = $shares * $price;
					my $totalshares = $curdata[4] - $shares;							
					$sth2 = $dbh->prepare("UPDATE Positions SET shares = ? WHERE AccountID = ? and symbol = ?");
					$sth2->execute($totalshares, $id, uc $symbol);
					$sth = $dbh->prepare("INSERT INTO Trades (accountid, symbol, shares, price) VALUES (?, ?, ?, ?)");
					$shares = 0 - $shares;
					$sth->execute($id, uc $symbol, $shares, $price);
				}
				$balance = $balance + (($price * -$shares)-5);
				$sth = $dbh->prepare("UPDATE Users SET CashBalance = CashBalance + 5 WHERE AccountID = 2");
				$sth->execute();
				$sth = $dbh->prepare("UPDATE Users SET CashBalance=? WHERE AccountID = ?");
				
				$sth->execute($balance, $id);
				$balance = formatCurrency($balance);
				$robit->cb->reply($args->{where}, $args->{who} . ": Sold $shares at $price. Balance: $balance");
			}else{
				 $robit->cb->reply($args->{where}, $args->{who} .": You do not have enough dollars.");
			}
		}
		};
		return 1;
	}
	return 0;
}
sub reset {
	
	my ($robit,$args) = @_;
	$robit->cb->log("Check Reset");
	if ($args->{what} =~ /reset$/) {
		my $dbh = DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
		my @data;
		my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
		$sth->execute($args->{who});
		@data = $sth->fetchrow_array();
		my $id = $data[0];
		$sth = $dbh->prepare("UPDATE Users SET CashBalance=10000 WHERE AccountName = ?");
		$sth->execute($args->{who});
		$sth = $dbh->prepare("DELETE From Positions WHERE AccountID = ?");
		$sth->execute($id);
		$robit->cb->reply($args->{where}, $args->{who} . ": Account reset.");
		return 1;
	}
	return 0;
	}
sub help{
	
	my ($robit,$args) = @_;
	$robit->cb->log("Check Help");
	if ($args->{what} =~ /help$/) {
		$robit->cb->reply($args->{where}, $args->{who} . ": Address me with 'rr' in channel or without in PM.  Commands are 'account' (only available in private message) for account info, 'buy <SYMBOL> <QUANTITY>' and 'sell <SYMBOL> <QUANTITY>' for trades, and 'reset' to reset your account to no stocks and default balance. Thank you and have a rotten day.");
		return 1;
	}
	return 0;
}
sub status {
	
	my ($robit,$args) = @_;
	$robit->cb->log("Check Status");
	if ($args->{what} =~ /status/) {
		print "getting status for ".$args->{who}."\n";
		$robit->whois($args->{who});
		my $a_dork = "";
        $robit->{heap}->{whois_cb}->{$args->{who}} = sub {
		use Data::Dumper; print Dumper(\@_);
		$a_dork = $_[0]->{identified};
		if (!$a_dork) {$a_dork = $args->{who};}
		if (!$a_dork) {$robit->cb->reply($args->{where}, $args->{who} . ": You need to identify to nickserv"); return 0;}
		#if (!$a_dork) {$a_dork = $args->{who};}
		#print "Getting status for  ".$a_dork."\n";
		if (MarketStatus() == 0) {
			$robit->cb->reply($args->{where}, $args->{who} . ": The market is not currently open, these amounts may be unrightly.");			
		}
		#$robit->whois('JonathanD');
		#check to see if an account exists
		my $dbh = DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
		my $sthinner;
		my @data;
		my @innerdata;
		my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
		$sth->execute($a_dork);
		#$sth->execute($args->{who});
		if ($sth->rows == 0) {
			$robit->cb->reply($args->{where}, $args->{who} . ": You do not have an account. I am making one for you. Enjoy your day.");
			$sth = $dbh->prepare("INSERT INTO Users (AccountName, CashBalance) VALUES (?, 10000)");
			$sth->execute($a_dork);			
		}else{
		my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
		$sth->execute($a_dork);
			while (@data = $sth->fetchrow_array()) {
				my $id = $data[0];
				my $balance = $data[2];
				my $tvalue = $balance;
				$sthinner = $dbh->prepare("SELECT * FROM Positions WHERE accountid = ?");
				$sthinner->execute($id);				
				while (@innerdata = $sthinner->fetchrow_array()) {
					#symbol shares price value					
					my %quote = getquoteg($innerdata[2]);
					if (MarketStatus() == 0) {				
						print '$innerdata[6]\n';
						%quote = ('prc',  $innerdata[6]);
					}
					my $value = $quote{prc} * $innerdata[4];
					$tvalue = $tvalue + $value;
					my $gain = (formatPercent(($quote{prc} / $innerdata[5])-1))*100;
					#if ($innerdata[4] != 0) {$robit->cb->reply($args->{where}, $args->{who} . ": Symbol:$innerdata[2] Shares:$innerdata[4] Paid:$innerdata[5] Current:$quote{prc} Value:$value Gain/Loss:$gain%");}
				}				
				my $ogain = (formatPercent(($tvalue/10000)-1)*100);	
				$tvalue = formatCurrency($tvalue);
				$balance = formatCurrency($balance);								
				$robit->cb->reply($args->{where}, $a_dork . ": Available Cash:$balance Total Value of Cash and Stocks:$tvalue Gain/Loss:$ogain%");
			}
		}	
		
	};
	$robit->cb->log("status returned 1");
	return 1;
	}
	$robit->cb->log("status returned 0");
	return 0;
}
sub account {
	
	my ($robit,$args) = @_;
	$robit->cb->log("Check Account");
	if ($args->{what} =~ /account$/) {		
		$robit->whois($args->{who});
		my $a_dork = "";
        $robit->{heap}->{whois_cb}->{$args->{who}} = sub {
		$a_dork = $_[0]->{identified};	
		if (!$a_dork) {$robit->cb->reply($args->{where}, $args->{who} . ": You need to identify to nickserv"); return 0;}
		#print "Getting status for  ".$a_dork."\n";
		if (MarketStatus() == 0) {
			$robit->cb->reply($args->{where}, $args->{who} . ": The market is not currently open, these amounts may be unrightly.");			
		}
			my $dbh = DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
			my $sthinner;
			my @data;
			my @innerdata;
			my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
			$sth->execute($a_dork);
			if ($sth->rows == 0) {
				$robit->cb->reply($args->{where}, $args->{who} . ": You do not have an account. I am making one for you. Enjoy your day.");
				$sth = $dbh->prepare("INSERT INTO Users (AccountName, CashBalance) VALUES (?, 10000)");
				$sth->execute($args->{who});
				return 1;
			}
			else
			{
			my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
			$sth->execute($a_dork);
				while (@data = $sth->fetchrow_array()) {
					my $id = $data[0];
					my $balance = $data[2];
					my $tvalue = $balance;
					$sthinner = $dbh->prepare("SELECT * FROM Positions WHERE accountid = ?");
					$sthinner->execute($id);				
					while (@innerdata = $sthinner->fetchrow_array()) {
						#symbol shares price value					
						my %quote = getquoteg($innerdata[2]);
						if (MarketStatus() == 0) {				
							print '$innerdata[6]\n';
							%quote = ('prc',  $innerdata[6]);
						}
						my $value = $quote{prc} * $innerdata[4];
						$tvalue = $tvalue + $value;
						my $gain = (formatPercent(($quote{prc} / $innerdata[5])-1))*100;
						if ($innerdata[4] != 0) {$robit->cb->reply($args->{where}, $a_dork . ": Symbol:$innerdata[2] Shares:$innerdata[4] Paid:$innerdata[5] Current:$quote{prc} Previous:$quote{ypc} Value:$value Gain/Loss:$gain%");}
					}				
					my $ogain = (formatPercent(($tvalue/10000)-1)*100);	
					$tvalue = formatCurrency($tvalue);
					$balance = formatCurrency($balance);								
					$robit->cb->reply($args->{where}, $args->{who} . ": Available Cash:$balance Total Value of Cash and Stocks:$tvalue Gain/Loss:$ogain%");				
			}
		}	
		
	};
	$robit->cb->log("status returned 1");
	return 1;
	}
	$robit->cb->log("status returned 0");
	return 0;
}
sub math {
    my ($robit,$args) = @_;
	my $json = new JSON;	
    if ($args->{what} =~ /math\s(.*)$/) {
		my $math = $1;		
		my $url = 'http://www.google.com/ig/calculator?q='.uri_escape($math);
		$robit->cb->log($url);
		my $result = get('http://www.google.com/ig/calculator?q='.uri_escape($math));
		#print =~ s/<sub><\/sub>//g;
		my $notjson = $json->allow_barekey->loose->decode($result);		
		my $rhs = $notjson->{'rhs'};
		my $lhs = $notjson->{'lhs'};
		my $error = $notjson->{'error'};
		$robit->cb->log("$rhs  $lhs  $error");
		if ($error eq "") {
			$robit->cb->reply($args->{where}, $args->{who} . ": $lhs = $rhs");
		}
		elsif ($error eq 4) {
			$robit->cb->reply($args->{where}, $args->{who} . ": $math ERROR LP0 ON FIRE.");
		}
		else {
			$robit->cb->reply($args->{where}, $args->{who} . ": Whooooooooooooooa Nelly! $math ERROR ERROR DOES NOT COMPUTE: $error.");
		}		
		return 1;
	}
	return 0;
}
sub quote {
	
    my ($robit,$args) = @_;
	$robit->cb->log("Check Quote");
    if ($args->{what} =~ /^([-.\w]+)\s*$/) {        
		my $symbol = $1;		
        my %quote = getquoteg($symbol);
		print "Getting quote for $symbol\n";
        #return 0 unless %quote;
		my @curdata;
		my @data;
		my $id;
		
		my $dbh = DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
		my $sth = $dbh->prepare("SELECT * FROM Users WHERE AccountName = ?");
		$sth->execute($args->{who});
		while (@data = $sth->fetchrow_array()) {
				my $id = $data[0];
				print "Account ID: ".$id."\n";
		}
		$sth = $dbh->prepare("SELECT * FROM Positions WHERE accountid = ? AND symbol = ?");
		print $sth->execute($id, uc $symbol);
		print "\n";
		while (@data = $sth->fetchrow_array()) {
					@curdata = $sth->fetchrow_array();
					my $totalshares = $curdata[4];
					print $totalshares."\n";
		}
		my $price = $quote{prc};
		my $name = $quote{nam};
		my $pct = $quote{pct};		
		my $change = formatCurrency($quote{net});
		my $exchange = $quote{exc};
		if ($exchange eq "") {
			$robit->cb->reply($args->{where}, $args->{who} . ": that doesn't exist. Neither do you. (quote)");
			return 1;
		}
		my $cur = $quote{cur};
		$robit->cb->reply($args->{where}, $args->{who} . ": $name($symbol) on $exchange: $price $cur $change($pct%)");
		$dbh = DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
		$sth = $dbh->prepare("UPDATE Positions SET lastprice=?, yprice=? WHERE symbol = ?");
		$sth->execute($quote{prc}, $quote{ypc}, $symbol);
	$robit->cb->log("quote returned 1");
        return 1;
    }
	$robit->cb->log("quote returned 0");
    return 0;
}
sub profit {
    my ($robit,$args) = @_;
    if ($args->{what} =~ /profit\s+([-.\w]+)\s+(\$?(?:\d+\.\d*|\d*.?\d+))\s+(\d+)\s*$/) {
        my ($symbol, $price, $shares) = ($1,$2,$3);
		$price =~ s/\$/0/g;
		my %quote = Finance::NASDAQ::Quote::getquote($symbol, LWP::UserAgent::POE->new());
		my $profit = ($quote{prc} - $price) * $shares;
		$profit = formatCurrency($profit);
		$price = formatCurrency($price);
        $robit->cb->reply($args->{where}, $args->{who} . ": Symbol $symbol Shares $shares Paid $price Profit $profit");
		print "profit returned 1\n";
        return 1;
    }
	print "profit returned 0\n";
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
sub formatPercent {
	my $number = sprintf "%.4f", shift @_;
	return $number;
}
sub updatePricesETC {
	my $dbh;
	my $sthinner;	
	my $sth;
	my @innerdata;
	my %quote;	
	while (1) {
		$dbh =  DBI->connect('dbi:mysql:rr','rr','rrsocks') or die "Connection Error: $DBI::errstr\n";
		$sthinner = $dbh->prepare("DELETE from Positions WHERE shares = 0");
		$sthinner->execute();	
		if (MarketStatus() == 1){
			#print "Checking stocks\n";
			$sthinner = $dbh->prepare("SELECT DISTINCT symbol FROM Positions");
			$sthinner->execute();				
			while (@innerdata = $sthinner->fetchrow_array()) {
				#print "Trying $innerdata[0]\n";
				#symbol shares price value
				#%quote = Finance::NASDAQ::Quote::getquote($innerdata[0], LWP::UserAgent::POE->new());
				#%quote = getquoteg($innerdata[0]);
				#print "$innerdata[0] $quote{prc}\n";				
				#$sth = $dbh->prepare("UPDATE Positions SET lastprice=?, yprice=? WHERE symbol = ?");
				#$sth->execute($quote{prc}, $quote{ypc}, $innerdata[0]);
				sleep 3;
			}			
			#print "Done updates.";
		}
		$dbh->disconnect;
	}
}
sub MarketStatus {
	my $url = 'http://www.nasdaq.com/dynamic_includes/marketstatus.js';
	my $content = get $url;
	if ($content =~ m/"C"/i){
		#print "Market closed\n";
		return 0;
	}
	my @timeData = localtime(time);
	#print join(' ', @timeData);
	my $minutes = $timeData[1] + ($timeData[2] * 60);	

	if ($minutes >= 870-60 && $minutes <= 1261-60 ){		
		if ($content =~ m/"P"/i){
			print "Pre market open\n";
			return 1;
		}
		if ($content =~ m/"O"/i){
			print "Market open\n";
			return 1;
		}
	}
	return 0;
}
sub getquoteg{
	my $symbol = $_[0];	
	my $parser= "";
	my $url = "http://www.google.co.in/ig/api?stock=$symbol&fish=".time; 
	my $content = get $url;
        my $content = get $url;
	my @data;	
	my $data = XMLin($content);
	my $prc = $data->{finance}->{last}->{data};
	my $net = $data->{finance}->{last}->{data} - $data->{finance}->{y_close}->{data};
	my $pct = $data->{finance}->{perc_change}->{data};
	my $vol = $data->{finance}->{volume}->{data};
	my $nam = $data->{finance}->{company}->{data};
	my $exc = $data->{finance}->{exchange}->{data};
	my $ypc = $data->{finance}->{y_close}->{data};
	my $cur = $data->{finance}->{currency}->{data};
	my %quote = (
		'prc' => $prc,
		'net' => $net, 
		'pct' => $pct, 
		'vol' => $vol,
		'exc' => $exc,
		'ypc' => $ypc,
		'cur' => $cur,
		'nam' => $nam		
	);
	#print '$quote{prc}/n';
return %quote;
}

1
