#!/usr/local/bin/perl 
use warnings;

use lib '/ws/jadew-rtp/perllib';
use WWW::Mechanize;
use XML::Simple;
use Data::Dumper;
use Switch;

my $username = $ENV{'USER'};
my $url = "http://wwwin.cisco.com/cgi-bin/support/tools/iceberg6/iceberg6_buildxml.cgi?agentid=$username";
my $tempfile = "/tmp/iceberg-$username.xml";

print "CEC password for $username: ";
system("stty -echo");
my $password = <STDIN>;
print "\n";
chomp($password);
system("stty echo");

# main loop
while ( "forever" ) {
	get_page();
	system('clear');
	parse_and_display();
	sleep(15);
}

#===  FUNCTION  ================================================================
#         NAME: get_page
#   PARAMETERS: none
#      RETURNS: none
#  DESCRIPTION: retrieves XML from iceberg
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub get_page {
	my $mech = WWW::Mechanize->new();
	$mech->credentials( $username => $password );
	eval { $mech->get($url); };

	#if tempfile exists, delete it first
	if (-e $tempfile) {
		unlink ($tempfile);
	}

	open (OUT, ">$tempfile");
	print OUT $mech->content;
	close(OUT);
} ## --- end sub get_page


#===  FUNCTION  ================================================================
#         NAME: parse_and_display
#   PARAMETERS: none
#      RETURNS: none
#  DESCRIPTION: Parses the XML from iceberg and displays the information
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub parse_and_display {
	#Create XML object and pull in the file
	my $simple = XML::Simple->new();
	my $tree = $simple->XMLin("$tempfile",ForceArray => 1);

	#undefine variables to reset for each loop
	undef %staffedskills;
	undef %talkingskills;
	undef %toasskills; #talking on another skill
	undef %idleskills;
	undef %readyskills;
	undef %grouped_staffed;
	undef %grouped_talking;
	undef %grouped_toas; #talkig on another skill
	undef %grouped_idle;
	undef %grouped_ready;
	undef %analyst_state;
	undef %analyst_time_min;
	undef %analyst_time_sec;
	undef %analyst_time_total;
	undef %analyst_toas;

	#get staffing count for talking agents
	foreach my $analyst (@{$tree->{agentstatus}->[0]->{talking}->[0]->{talkinganalyst}}) {
		my @skills = split /,/, $analyst->{callskills};
		foreach my $skill (@skills) {
			if ($staffedskills{$skill}) {
				$staffedskills{$skill} += 1;
			} else {
				$staffedskills{$skill} = 1;
			}
			if ($skill =~ m/GTRC_ENG/) {
				$analyst_state{$analyst->{userid}} = "talking";
				($analyst_time_min{$analyst->{userid}},$analyst_time_sec{$analyst->{userid}})=split(/:/,$analyst->{statedate});
				$analyst_time_total{$analyst->{userid}} = ($analyst_time_min{$analyst->{userid}} * 60) + $analyst_time_sec{$analyst->{userid}};
			}
			# increment count if talking on another skill
			if ($skill ne $analyst->{talkingon}) {
				if ($toasskills{$skill}) {
					$toasskills{$skill} += 1;
				} else {
					$toasskills{$skill} = 1;
				}
				if ($skill =~ m/GTRC_ENG/) {
					$analyst_toas{$analyst->{userid}} = "true";
				}
			}
		}
		if ($talkingskills{$analyst->{talkingon}}) {
			$talkingskills{$analyst->{talkingon}} += 1;
		} else {
			$talkingskills{$analyst->{talkingon}} = 1;
		}
	}

	#get staffing count for idle agents
	foreach my $analyst (@{$tree->{agentstatus}->[0]->{notready}->[0]->{notreadyanalyst}}) {
		my @skills = split /,/, $analyst->{callskills};
		foreach my $skill (@skills) {
			if ($staffedskills{$skill}) {
				$staffedskills{$skill} += 1;
			} else {
				$staffedskills{$skill} = 1;
			}
			if ($idleskills{$skill}) {
				$idleskills{$skill} += 1;
			} else {
				$idleskills{$skill} = 1;
			}
			if ($skill =~ m/GTRC_ENG/) {
				$analyst_state{$analyst->{userid}} = "idle";
				($analyst_time_min{$analyst->{userid}},$analyst_time_sec{$analyst->{userid}})=split(/:/,$analyst->{statedate});
				$analyst_time_total{$analyst->{userid}} = ($analyst_time_min{$analyst->{userid}} * 60) + $analyst_time_sec{$analyst->{userid}};
			}
		}
	}

	#get staffing count for ready agents
	foreach my $analyst (@{$tree->{agentstatus}->[0]->{ready}->[0]->{readyanalyst}}) {
		my @skills = split /,/, $analyst->{callskills};
		foreach my $skill (@skills) {
			if ($staffedskills{$skill}) {
				$staffedskills{$skill} += 1;
			} else {
				$staffedskills{$skill} = 1;
			}
			if ($readyskills{$skill}) {
				$readyskills{$skill} += 1;
			} else {
				$readyskills{$skill} = 1;
			}
			if ($skill =~ m/GTRC_ENG/) {
				$analyst_state{$analyst->{userid}} = "ready";
				($analyst_time_min{$analyst->{userid}},$analyst_time_sec{$analyst->{userid}})=split(/:/,$analyst->{statedate});
				$analyst_time_total{$analyst->{userid}} = ($analyst_time_min{$analyst->{userid}} * 60) + $analyst_time_sec{$analyst->{userid}};
			}
		}
	}

	#combine 1/2/3 skills into groups
	foreach my $skill (sort keys %staffedskills) {
		#set $group based on $skill
		switch ($skill) {
			case /GTRC_DESKTOP/ { $group=" DESKTOP"; }
			case /GTRC_ENG/ { $group=" ENG"; }
			case /GTRC_MAIN/ { $group=" MAIN"; }
			case /GTRC_MOBILITY/ { $group=" MOBILITY"; }
			case /GTRC_T2D_SPA/ { $group=" T2D_SPANISH"; }
			case /GTRC_T2D/ { $group=" T2D"; }
			case /GTRC_VIP/ { $group=" VIP"; }
			case /GTRC_WEBEX/ { $group=" WEBEX"; }
			case /GTRC_PORTUGUESE/ { $group=" PORTUGUESE"; }
			case /GTRC_SPANISH/ { $group=" SPANISH"; }
			case /GTRC_LWR/ { $group=" LWR"; }
			case /GTRC_DR_DESKTOP/ { $group=" DR_DESKTOP"; }
			case /GTRC_MAND_ENG/ { $group=" MANDARIN_ENG"; }
			case /GTRC_MAND/ { $group=" MANDARIN"; }
			case /GTRC_WARROOM/ { $group=" WARROOM"; }
			case /GTRC_CiscoTV/ { $group=" CiscoTV"; }
			else	{ $group=$skill; }
		}

		#initialize $grouped_*{$group} hashes to zero if needed
		if (!defined($grouped_staffed{$group})) { $grouped_staffed{$group}=0; }
		if (!defined($grouped_talking{$group})) { $grouped_talking{$group}=0; }
		if (!defined($grouped_idle{$group})) { $grouped_idle{$group}=0; }
		if (!defined($grouped_ready{$group})) { $grouped_ready{$group}=0; }
		if (!defined($grouped_toas{$group})) { $grouped_toas{$group}=0; }

		#add to running total for $group
		$grouped_staffed{$group} += $staffedskills{$skill}; #staffedskills should never be null (famous last words)
		if ($talkingskills{$skill}) { $grouped_talking{$group} += $talkingskills{$skill}; }
		if ($idleskills{$skill}) { $grouped_idle{$group} += $idleskills{$skill}; }
		if ($readyskills{$skill}) { $grouped_ready{$group} += $readyskills{$skill}; }
		if ($toasskills{$skill}) { $grouped_toas{$group} += $toasskills{$skill}; }
	}

	#print out the grouped staffing numbers
	print "        Staff Avail  Idle  Talk (TOAS)\n";
	print "        ===== ===== ===== =============\n";
	foreach my $group (sort keys %grouped_staffed) {
		if (!($group eq " ENG" || $group eq " T2D")) { next; }  #skip if not ENG or T2D
		printf ("%-6s %5d %5d %5d %5d",$group,$grouped_staffed{$group},$grouped_ready{$group},$grouped_idle{$group},$grouped_talking{$group});
		#only print TOAS if TOAS not zero
		if ($grouped_toas{$group} > 0) {
			printf ("  (%2d)\n",$grouped_toas{$group});
		} else {
			print "\n";
		}
	}

	#print holding calls
	print "\n";
	print "Queue            Calls  Time\n";
	print "=====            =====  =====\n";
	$num_calls = 0;
	foreach my $queue (@{$tree->{queuestatus}->[0]->{queues}}) {
		printf("%-15s %5s %7s\n",$queue->{queuename},$queue->{queuenumber},$queue->{queuetime});
		$num_calls++;
	}
	if ($num_calls == 0) { print "No calls holding\n"; }

	#Eng Staffing section
	#testing: print all eng analysts
	print "\n\n";

	#Eng Talking
	print "Eng: Talking\n";
	foreach my $analyst ( sort { $analyst_time_total{$b} <=> $analyst_time_total{$a} } keys %analyst_time_total ) {
		if ( $analyst_state{$analyst} eq "talking" ) {
			if ($analyst_toas{analyst} eq "true" ) { print "*"; }
			printf ("%-10s %2i:%02i\n",$analyst,$analyst_time_min{$analyst},$analyst_time_sec{$analyst});
		}
	}

	#Eng Idle
	print "\nEng: Idle\n";
	foreach my $analyst ( sort { $analyst_time_total{$b} <=> $analyst_time_total{$a} } keys %analyst_time_total ) {
		if ( $analyst_state{$analyst} eq "idle" ) {
			printf ("%-10s %2i:%02i\n",$analyst,$analyst_time_min{$analyst},$analyst_time_sec{$analyst});
		}
	}

	#Eng Available
	print "\nEng: Available\n";
	foreach my $analyst ( sort { $analyst_time_total{$b} <=> $analyst_time_total{$a} } keys %analyst_time_total ) {
		if ( $analyst_state{$analyst} eq "ready" ) {
			printf ("%-10s %2i:%02i\n",$analyst,$analyst_time_min{$analyst},$analyst_time_sec{$analyst});
		}
	}

	#print Dumper(%analyst_time_total);  #DEBUG
} ## --- end sub parse_and_display
