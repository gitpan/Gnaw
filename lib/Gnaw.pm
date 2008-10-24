#package Gnaw;

use warnings;
use strict;

=head1 NAME

Gnaw - Define parse grammars using perl subroutine calls. No intermediate grammar languages.

=head1 VERSION

Version 0.09

=cut

{ 
package Gnaw;
our $VERSION = '0.09';

# all the subroutines in Gnaw go into users namespace
# however, cpan likes to see a package declaration.
# putting one here inside a lexical block so that 
# the package declaration is active only inside the
# block, and then the namespace returns to the user's
# namespace.
# declare $VERSION here because it is tied to the Gnaw
# namespace.
}

=head1 SYNOPSIS

Gnaw is a perl module which implements full regular expressions and full text parsing grammars using nothing but pure perl code limited to subroutine closures, exception trapping via eval, and basic perl variables such as scalars, hashes, and arrays.

You write your grammar in pure perl. There is no intermediate "parser language" that then gets interpreted into something executable.

When you do a "use Gnaw", the Gnaw module will import a number of functions directly into your namespace. Yes, this is completely bad form for normal modules. But this is not a normal module. The imported subroutines include regular expression and parsing equivalents for matching, quantifiers, literals, alternations, character classes, and so on. You build up your grammar by calling these functions. The final call will return a code reference. This code reference is your grammar.

When you dereference that grammar, if it is a "match" grammar (i.e. $string =~ m//) then you pass in the string you want to parse.

	use Gnaw;

	# create the grammar
	my $grammar = match(lit('hello'));

	# apply the grammar to a string
	if($grammar->('hello world')) {
		print "match\n";
	} else {
		print "no match";
	}

Please note that this is a beta release. This is more of a proof of concept than something ready for production code or for massive grammars. The interfaces may change completely in the future. When the interfaces have settled, I will release this as a version 1.0+ module. Until then, please do not use this to develop some gigantic parser when the grammar may have to completely change.


=head1 EXPORT

Currently, EVERYTHING is exported into the callers namespace. Yes, I know, bad programmer. No biscuit. 

The problem is I did not want grammars to be weighed down with a bunch of package prefixes at every step.

	my $grammar = Gnaw::match(Gnaw::alternation(Gnaw::lit('hello'),Gnaw::lit('howdy'));

Gets rather tedious.

Hopefully, no one will have collisions with subroutine names. If they do, then it might make sense to create a new package, declare the grammar in there, then simply pull out the code reference and use that in the rest of your code.

Again, everything may change tomorrow as I sort this out.

=head1 FUNCTIONS

=cut

use warnings;
use strict;
use Data::Dumper; 

# declare this now so we can use it in the "parse fail" sub
our %__gnaw__quantifier_callbacks_by_type;

our $GNAWDEBUG=0;

sub GNAWMONITOR {}

sub GNAWMONITOR_0  {
	print "MONITOR: "; 

	# if user passes in a message, print it
	if(scalar(@_)){
		my $str=shift(@_);
		chomp($str);
		print $str." ";
	} 

	# print the name of the subroutine that called MONITOR
	my $subname = (caller(1))[3];
	print $subname." ";
	my $linenum = (caller(1))[2];

	# print the name of the subroutine that called this subroutine
	print " called from ";
	my $calledfrom = (caller(2))[3];
	unless(defined($calledfrom)) {
		$calledfrom = '(no one?) ';
	}
	print $calledfrom." ";

	print "line ".$linenum."\n";
}



sub __gnaw__where_in_code {
	GNAWMONITOR;


	my $location = '';

	my $cnt=2;
	my @caller=caller($cnt-1);
	while(scalar(@caller)) {
		my $package  = $caller[0];
		my $filename = $caller[1];
		my $linenumb = $caller[2];
		my $subrname = $caller[3];


		$location .= "file='$filename', line=$linenumb, sub='$subrname', pkg='$package'\n";
		@caller = caller($cnt++);
	}
	return $location;
}

sub __gnaw__die {
	GNAWMONITOR;
	my($string) = @_;

	#__gnaw__dump_current_call_tree();

	my $location = __gnaw__where_in_code();
	$location .= __gnaw__string_showing_user_current_location_in_text();

	my $message = $string . "\n" . $location;

	die $message ;
}


our $__gnaw__current_calltree_location;
our $__gnaw__call_tree 	;

sub __gnaw__initialize_call_tree {
	GNAWMONITOR;

	if(scalar(@_)) {
		__gnaw__die("called __gnaw__initialize_call_tree with status hash which is no longer used.");
	}

	$__gnaw__call_tree = {
		location => "__gnaw__initialize_call_tree",
		descriptor => "__gnaw__initialize_call_tree",
	};

	$__gnaw__current_calltree_location = $__gnaw__call_tree;
}

__gnaw__initialize_call_tree();


our $__gnaw__parse_failed;

sub __gnaw__parse_failed {
	GNAWMONITOR( "__gnaw__parse_failed BEGINNING\n" );
	GNAWMONITOR( __gnaw__dump_current_call_tree () );

	# from current position in call tree, work our way back.
	# if we run into a quantifier, calculate next try value.
	# if that calculation causes an overflow, go back to 
	# next quantifier and calculate new try value.
	# if that causes overflow, go back to next quantifer...
	# and so on.
	#
	# if we hit first call in list, then we cant do any more
	# quantifiers and we really did fail.
	
	my $looking_for_quantifier_to_calculate_new_try=1;
	my $command = $__gnaw__current_calltree_location;

	my @list_of_owners_who_have_been_told_to_retry;

	GNAWMONITOR( "__gnaw__parse_failed internal: just before while loop");
	while(defined($command) and $looking_for_quantifier_to_calculate_new_try) {
		GNAWMONITOR( "__gnaw__parse_failed internal: just inside while loop");

		if(exists($command->{quantifier})) {
			GNAWMONITOR( "__gnaw__parse_failed internal: command is quantifier");
			my $quantifier_type = $command->{quantifier_type};
			my $quantifier_callbacks = $__gnaw__quantifier_callbacks_by_type{$quantifier_type};
			my $rolled_over = $quantifier_callbacks->{calculate_try}->($command);

			GNAWMONITOR( "__gnaw__parse_failed internal: rolled_over = $rolled_over");

			# if it didnt roll over, we can stop looking
			if($rolled_over==0) {
				$looking_for_quantifier_to_calculate_new_try=0;
				GNAWMONITOR( "__gnaw__parse_failed internal: didn't rollover, stop looking");

				# tell the call that owns this quantifier to try another quantifier run
				my $quantifier_owner = $command->{quantifier_owner};
				unless(defined($quantifier_owner)) {
					__gnaw__die("no quantifier_owner defined for this quantifier");
				}
				$quantifier_owner->{try_another_quantifier_run}=1;

				push(@list_of_owners_who_have_been_told_to_retry, $quantifier_owner);
			}
		} else {
			GNAWMONITOR( "__gnaw__parse_failed internal: command is not quantifier");
		}

		if(exists($command->{previous})){
			$command = $command->{previous};
		} else {
			$command = undef;
		}
	}

	# if command is not defined (hit end of call tree) but still "looking" for quantifier
	# then all the quantifiers rolled over, which means we shouldn't actually try another run
	if( (not(defined($command))) and ($looking_for_quantifier_to_calculate_new_try==1)) {
		GNAWMONITOR ("__gnaw__parse_failed internal: ALL QUANTIFIERS ROLLED OVER, DONT TRY");
		foreach my $owner (@list_of_owners_who_have_been_told_to_retry) {
			$owner->{try_another_quantifier_run}=0;
		}
	}

	$__gnaw__parse_failed=1;

	GNAWMONITOR (  "__gnaw__parse_failed ENDING\n" );
	GNAWMONITOR (  "\n\n\n__gnaw__parse_failed START DUMP\n" );
	GNAWMONITOR (  __gnaw__where_in_code() );
	GNAWMONITOR (  __gnaw__string_showing_user_current_location_in_text() );
	GNAWMONITOR (  __gnaw__dump_current_call_tree() );
	GNAWMONITOR (  "\n__gnaw__parse_failed END DUMP\n\n\n" );

	my $message = "__gnaw__parse_failed ";

	die $message;
}

####################################################################
####################################################################
####################################################################
# text is linked list to allow adding new and removing old
####################################################################
####################################################################
####################################################################




# text to parse is a linked list.

sub __GNAW__PREV {0;}

sub __GNAW__NEXT {1;}

sub __GNAW__LETTER {2;}

sub __GNAW__LOCATION_MARKERS {3;}


# these two elements never get deleted
our $__gnaw__head_element    ;
our $__gnaw__tail_element    ;
our $__gnaw__current_linkedtext_element ;  

# __gnaw__current_linkedtext_element is a plain pointer into the linked list.
# any subroutine dealing directly with linked list can
# reference the current_element variable.
# all other blocks must user sub calls to 
# __gnaw__get_current_text_marker
# __gnaw__restore_old_text_marker
# to get and restore the current pointer.
# Those subroutines will create hash refs that
# will contain a pointer to the current element
# Those subs will also put a pointer to that hash
# into the __GNAW__LOCATION_MARKERS part of the linked list.
# this allows us to keep track of who is pointing to
# a particular piece of text.
# When we "commit" and delete some text, we need to 
# move all the pointers forward, and let the subroutine
# that's using the pointer know that the pointer was moved.


sub __gnaw__initialize_linked_list_to_empty {
	GNAWMONITOR;
	$__gnaw__head_element = [];
	$__gnaw__tail_element = [];

	$__gnaw__head_element->[__GNAW__PREV]	= $__gnaw__tail_element;
	$__gnaw__head_element->[__GNAW__NEXT]	= $__gnaw__tail_element;
	$__gnaw__head_element->[__GNAW__LETTER]	= '';
	$__gnaw__head_element->[__GNAW__LOCATION_MARKERS] = 
		{debug=>"THIS IS THE HEAD ELEMENT!!!! NO MARKERS HERE"};



	$__gnaw__tail_element->[__GNAW__PREV]	= $__gnaw__head_element;
	$__gnaw__tail_element->[__GNAW__NEXT]	= $__gnaw__head_element;
	$__gnaw__tail_element->[__GNAW__LETTER]	= '';
	$__gnaw__tail_element->[__GNAW__LOCATION_MARKERS] = 
		{debug=>"THIS IS THE TAIL ELEMENT!!!! NO MARKERS HERE"};

	$__gnaw__current_linkedtext_element  = $__gnaw__head_element;
}



__gnaw__initialize_linked_list_to_empty();

sub __gnaw__insert_element_in_linked_list_after_this {
	GNAWMONITOR;
	my ($ptr_to_this_element, $letter_to_insert)=@_;

	my $newelement = [];

	$newelement->[__GNAW__LETTER]=$letter_to_insert;
	$newelement->[__GNAW__LOCATION_MARKERS]={};

	my $third_element = $ptr_to_this_element->[__GNAW__NEXT];

	$ptr_to_this_element->[__GNAW__NEXT] = $newelement;
	$newelement->[__GNAW__PREV] = $ptr_to_this_element;

	$newelement->[__GNAW__NEXT] = $third_element;
	$third_element->[__GNAW__PREV] = $newelement;
}



sub __gnaw__insert_element_in_linked_list_at_end {
	GNAWMONITOR;
	my ($letter)=@_;

	my $last = $__gnaw__tail_element->[__GNAW__PREV];

	__gnaw__insert_element_in_linked_list_after_this($last, $letter);
}


# text markers, an explanation.
#
# the text is stored in a linked list.
# the __gnaw__current_linkedtext_element variable points to whatever is
# the current element in the linked list that we are working on now.
#
# However, parsing commands need more intelligent markers than
# a simple reference to an element in the linked list.
# The problem is to deal with what happens when a command gets
# a marker to some element, and then at some later time, that
# element is deleted before the parsing command could deal with
# the marker.
#
# worst case example, the "capture" command gets a marker at the
# start of capture. It then executes any sub-grammar. On successful
# completion, the "capture" command will then get the current marker,
# and then get the text in between the two markers.
#
# if the sub-grammar does a "commit", then the elements of text in
# the linked list will be deleted, and the first capture pointer will
# point to some unknown value in the heap.
#
# Therefore, we need to implement smart location markers.
# Any grammar command that needs a marker will call a subroutine
# to get the marker. The subroutine willl create a marker and return
# it to the caller. It will also put a reference to that marker into
# the linked list element that it points to. If the grammar performs
# a commit, the element can be deleted, and all markers can be updated
# to point to the next element in the linked list which still exists.
#
# this will prevent markers pointing to unknown data in the heap.
#
# a marker is a hash. currently two keys are defined:
# pointer_to_text => a pointer to the linked list element
# original_characters_deleted => a boolean flag set when the text it was pointing to is deleted
# MARKER_DELETED => this key exists only once the marker has been restored.
#
# When the marker has been restored, all the pointers to it are deleted to
# allow automatic garbage collection. If the user wants to restore the same location,
# they will need to restore the first marker, then immediately get a new marker of that location.
#
# the hash is created on the fly lexically, and no one gets the
# hash, instead everyone uses references to the hash.
#
# The linked list of text contains one index [__GNAW__LOCATION_MARKERS]
# which contains a hash of markers. The key is the address of the marker
# stringified to give a unique key. The data is an actual reference to 
# the hash marker.
#
# We use the address of the hash marker as the key so that we can
# delete individual markers when they are no longer used.
#
# The __gnaw__get_current_text_marker subroutines creates
# this hashref and sets the pointer_to_text to the current location.
# it then needs to add a pointer to the href into the 
# linked list of text. This will allow the pointer to move
# if text is deleted.
#
# The restore linkedtext location subroutine takes the hash
# sets the current pointer to the linked list element indicated
# in teh hash, and deletes the pointer to the href from the
# linked list location. Deleting the pointer from the linked
# list will allow garbage collection and should avoid memory leaks.

sub __gnaw__get_current_text_marker {
	# create the text marker and initialize it
	my $markerref = {};
	$markerref->{pointer_to_text} = $__gnaw__current_linkedtext_element;
	$markerref->{original_characters_deleted}=0;
	GNAWMONITOR($markerref);
	GNAWMONITOR($__gnaw__current_linkedtext_element);

	# make sure the current element in linked list of text knows
	# that the marker we just created is pointing to this element.

	# a. get the hashref for this element that contains the location markers for this element
	my $pointers_for_this_element = $__gnaw__current_linkedtext_element->[__GNAW__LOCATION_MARKERS];

	# the address of our new marker is the key into the element's hash of location markers
	my $markeraddress = $markerref.'';


	$pointers_for_this_element->{$markeraddress} = $markerref;

	# return the marker
	$_[0] = $markerref;	
} 

sub __gnaw__restore_old_text_marker {
	my($markerref) = @_;
	GNAWMONITOR($markerref);

	if(exists($markerref->{MARKER_DELETED})) {
		__gnaw__die("tried to __gnaw__restore_old_text_marker with a marker that had already been restored. Need to __gnaw__get_current_text_marker after every restore.");
	}

	# the marker points to some element in linked list.
	# set the current_element to whatever the marker points to.
	$__gnaw__current_linkedtext_element = $markerref->{pointer_to_text};
	GNAWMONITOR($__gnaw__current_linkedtext_element);

	__gnaw__unlink_old_text_marker($markerref);
}


# this deletes the element in the linked list of text that points to the marker.
# this means that the only thing left pointing to the marker after this call
# should be the grammar command that got the marker in the first place.
# once they're done with it, perl should garbage collect the hash.
sub __gnaw__unlink_old_text_marker {
	my($markerref) = @_;
	GNAWMONITOR($markerref);

	# the element in the linked list contains a hash of location markers.
	# we want to go into that hash and delete this marker.
	# this will allow garbage collection to kick in if needed.
	# this is also why the user can only restore a marker once,
	# because once we restore it, we remove it from the text linked list.

	my $element_in_list = $markerref->{pointer_to_text};
	GNAWMONITOR($element_in_list);

	# get a reference to the markers for this element
	my $markers_for_this_element = $element_in_list->[__GNAW__LOCATION_MARKERS];

	# get the address, which we will use as the hash key
	my $markeraddress = $markerref.'';

	# if it doesn't exist, then something went really wrong somewhere.
	# either the user munged the href before they tried to do a restore
	# or I didn't move a pointer in the linked list somewhere.
	# The location href should always point to an element in the linked list of text,
	# and that element should always point to the href that points to it.
	unless(exists($markers_for_this_element->{$markeraddress})) {
		__gnaw__die("tried to __gnaw__restore_old_text_marker, but somehow the element in the linked list doesn't point to this marker. Marker should point to element, and element should point to marker. Are you experience a memory leak? ");
	}

	delete($markers_for_this_element->{$markeraddress});

	# now tag the user's href so we can catch if they 
	# use it again without getting a new marker
	%{$_[0]} = (MARKER_DELETED=>1);
} 

sub __gnaw__at_end_of_string {
	GNAWMONITOR;
	if($__gnaw__current_linkedtext_element eq $__gnaw__tail_element) {
		return 1;
	} else { 
		return 0;
	}
}

sub __gnaw__move_pointer_forward {
	GNAWMONITOR;
	if(__gnaw__at_end_of_string()) {
		__gnaw__parse_failed();
	}
	$__gnaw__current_linkedtext_element = $__gnaw__current_linkedtext_element->[__GNAW__NEXT];
}	

####################################################################
# skip is called by low level routine that handles linked list of text
####################################################################

our $__gnaw__skip_whitespace = sub{
	GNAWMONITOR('skipwhitespace');
	if(__gnaw__at_end_of_string()) {
			return;
	}

	my $letter =  $__gnaw__current_linkedtext_element->[__GNAW__LETTER];

	# \t\n\r\f
	while(
		($letter eq ' ' ) or
		($letter eq "\t") or
		($letter eq "\n") or
		($letter eq "\f")
	) {
		__gnaw__move_pointer_forward();
		$letter =  $__gnaw__current_linkedtext_element->[__GNAW__LETTER];
	}
};


our $__gnaw__skip_nothing = sub{};

####################################################################
# change the coderef assigned to this to change what we skip.
# probably want to do it with a "local" command.
####################################################################
our $__gnaw__skip = $__gnaw__skip_whitespace;
####################################################################



sub __gnaw__curr_character {
	GNAWMONITOR;
	if(__gnaw__at_end_of_string()) {
		return 0;
	}

	$__gnaw__skip->();

	my $letter =  $__gnaw__current_linkedtext_element->[__GNAW__LETTER];
	return $letter;
}

sub __gnaw__next_character {
	GNAWMONITOR;
	my $curr_char = __gnaw__curr_character();
	__gnaw__move_pointer_forward();
	return $curr_char;
}


sub __gnaw__initialize_string_to_parse {
	GNAWMONITOR;
	my ($string) = @_;

	my @letters = split(//, $string);

	__gnaw__initialize_linked_list_to_empty();

	foreach my $letter (@letters) {
		__gnaw__insert_element_in_linked_list_at_end($letter);
	}

	#current pointer will be pointing to HEAD marker. move it up one.
	$__gnaw__current_linkedtext_element = 
	$__gnaw__current_linkedtext_element->[__GNAW__NEXT];
}





sub __gnaw__get_string_between_two_pointers {
	GNAWMONITOR;
	my ($start,$stop) = @_;

	unless(defined($start)) {
		__gnaw__die("Get string requires two defined references, first one was undefined");
	}

	unless(defined($stop)) {
		__gnaw__die("Get string requires two defined references, second one was undefined");
	}

	unless(ref($start) eq 'ARRAY') {
		__gnaw__die("Get string requires two defined references, first one was not a reference ($start)");
	}
	
	unless(ref($stop) eq 'ARRAY') {
		__gnaw__die("Get string requires two defined references, second one was not a reference ($stop)");
	}
	

	my $this = $start;

	my $string = '';


	while( ($this ne $stop) and  ($this ne $__gnaw__tail_element) ){
		my $letter = $this->[__GNAW__LETTER];
		$string .= $letter;
		$this = $this->[__GNAW__NEXT];
	}

	return $string;
}

sub __gnaw__string_showing_user_current_location_in_text {
	GNAWMONITOR;
	my $count;

	# starting from current location,
	# back up to the beginning of the line.
	# don't go past 100 characters
	# and don't go past the beginning marker.
	my $start = $__gnaw__current_linkedtext_element;
	$count = 100;
	while( 	($count--) and  
		($start ne $__gnaw__head_element) and 
		($start->[__GNAW__LETTER] ne "\n") 
	){
		$start = $start->[__GNAW__PREV];
	}


	# starting from current 
	# move to the end of the line.
	# don't go past 100 characters
	# and don't go past the end marker.
	my $stop = $__gnaw__current_linkedtext_element;
	$count = 100;
	while( 	($count--) and  
		($stop ne $__gnaw__tail_element) and 
		($stop->[__GNAW__LETTER] ne "\n") 
	){
		$stop = $stop->[__GNAW__NEXT];
	}


	# now, go from start to stop marker and print out the elements
	my $curr = $start;
	my $final_string='';

	$final_string .= "START\n";
	$final_string .= "This is the contents of the text linked list for the current line\n";
	$final_string.= "current element points to ".$__gnaw__current_linkedtext_element."\n";

	my $keepgoing=1;

	while ($keepgoing) {
		if($curr eq $__gnaw__current_linkedtext_element) {
			$final_string.= ">";
		} else {
			$final_string.= " ";
		}

		$final_string .= $curr." ";

		if($curr eq $__gnaw__head_element) {
			$final_string.= "HEAD";
		} elsif ($curr eq $__gnaw__tail_element){
			$final_string.= "TAIL";
		} else {
			my $letter = $curr->[__GNAW__LETTER];
			$final_string.= $letter;
		}

		$final_string.= " : ";

		my $marker_hash_ref = $curr->[__GNAW__LOCATION_MARKERS];
		my @markers = keys(%$marker_hash_ref);
		foreach my $marker (@markers) {
			$final_string.= "$marker ";
		}

		$final_string.= "\n";

		if($curr eq $stop) {
			$keepgoing=0;
		}

		$curr = $curr->[__GNAW__NEXT];
	}

	$final_string .= "END\n";
	return $final_string;
}



# what if element being deleted is __gnaw__current_linkedtext_element or 
# is a location that some marker is pointing to?
# need to move all the pointers and markers to the next element in list.
sub __gnaw__delete_this_element_from_linked_list {
	GNAWMONITOR;
	my ($element)=@_;


	my $prev_ele = $element->[__GNAW__PREV];
	my $next_ele = $element->[__GNAW__NEXT];


	# if we are deleting the element that the 
	# $__gnaw__current_linkedtext_element variable is pointing to
	# then we need to move the $__gnaw__current_linkedtext_element 
	# variable forward.
	if($element eq $__gnaw__current_linkedtext_element) {
		$__gnaw__current_linkedtext_element = $next_ele;
	}

	# if this element has any location markers pointing to it,
	# then we need to move all those markers to the next element.
	my $this_elements_location_markers =  $element->[__GNAW__LOCATION_MARKERS];
	my $next_elements_location_markers = $next_ele->[__GNAW__LOCATION_MARKERS];

	# take all the markers that point to this element in linked list
	# and have them point to next element instead.
	while(my($key, $marker)=each(%$this_elements_location_markers)) {
		next if($key eq 'debug'); # debug flag. just ignore it.

		$marker->{pointer_to_text}=$next_ele;
		$marker->{original_characters_deleted}=1; # that's gotta hurt

		# take these markers and add them to the next element's marker hash.
		# note, next element in list may already have some markers,
		# so we have to add these one at a time to existing hash.
		$next_elements_location_markers->{$key}=$marker;
	}

	$prev_ele->[__GNAW__NEXT] = $next_ele;
	$next_ele->[__GNAW__PREV] = $prev_ele;

	# empty out the contents of this element in linked list.
	@$element=undef;
}

sub __gnaw__delete_linked_list_between_two_pointers {
	GNAWMONITOR;
	my($start,$stop)=@_;

	my $this = $start;

	if($this eq $__gnaw__head_element) {
		$this = $this->[__GNAW__NEXT];
	}

	if($this eq $__gnaw__tail_element) {
		return;
	}

	while( defined($this) and ($this ne $stop) and  ($this ne $__gnaw__tail_element) ){
		__gnaw__delete_this_element_from_linked_list($this);
		$this = $this->[__GNAW__NEXT];
	}
}

sub __gnaw__delete_linked_list_from_start_to_current_pointer {
	GNAWMONITOR;
	__gnaw__delete_linked_list_between_two_pointers
		($__gnaw__head_element,$__gnaw__current_linkedtext_element);
}



####################################################################
####################################################################
####################################################################
# call tree is used to keep track of what we've tried in the grammar.
####################################################################
####################################################################
####################################################################


sub __gnaw__get_current_calltree_marker {
	GNAWMONITOR;
	# create the marker and initialize it
	my $markerref = {};
	$markerref->{pointer_to_tree} = $__gnaw__current_calltree_location;
	$markerref->{original_calls_deleted}=0;

	# 2) make sure the current call in calltree knows
	# that the marker we just created is pointing to this call.

	# 2.a) get the hashref of location markers inside current call
	my $pointers_for_this_call = 
		$__gnaw__current_calltree_location->{LOCATION_MARKERS};

	# 2.b) the address of our new marker is the hash key 
	my $markeraddress = $markerref.'';

	# 2.c) put this marker into the current call's hash of markers
	$pointers_for_this_call->{$markeraddress} = $markerref;

	# return the marker
	$_[0] = $markerref;	
}

sub __gnaw__restore_old_calltree_marker {
	GNAWMONITOR;
	my($markerref) = @_;

	# if already deleted, something really bad happened.
	if(exists($markerref->{MARKER_DELETED})) {
		__gnaw__die("tried to __gnaw__restore_old_calltree_marker with a marker " .
				"that had already been restored. Need to " . 
				"__gnaw__get_current_calltree_marker after every restore.");
	}

	# the marker points to some element in linked list.
	# set the current_element to whatever the marker points to.
	$__gnaw__current_calltree_location = $markerref->{pointer_to_tree};

	__gnaw__unlink_old_calltree_marker($markerref);
}

sub __gnaw__unlink_old_calltree_marker {
	GNAWMONITOR;
	my($markerref) = @_;

	# if already deleted, something really bad happened.
	if(exists($markerref->{MARKER_DELETED})) {
		__gnaw__die("tried to __gnaw__unlink_old_calltree_marker with a marker " .
				"that had already been deleted. Need to " . 
				"__gnaw__get_current_calltree_marker after every restore.");
	}

	# the marker points to one hash in the call tree.
	# each hash in calltree contains a hash of location markers.
	# we want to take the marker, get the hash in call tree, 
	# then get the location markers for that hash, and delete this marker.
	# this will allow garbage collection to kick in if needed.
	# this is also why the user can only restore a marker once,
	# because once we restore it, we remove it from the calltree.

	my $call_in_calltree = $markerref->{pointer_to_tree};

	# get a reference to the markers for this element
	my $markers_for_this_call = $call_in_calltree->{LOCATION_MARKERS};

	# get the address, which we will use as the hash key
	my $markeraddress = $markerref.'';

	# if it doesn't exist, then something went really wrong somewhere.
	unless(exists($markers_for_this_call->{$markeraddress})) {
		my $call_address = $call_in_calltree.'';

		__gnaw__die("tried to __gnaw__unlink_old_calltree_marker, but somehow ".
			"the call in calltree doesn't point to this marker. ".
			"Marker should point to call, and call should point to marker. ".
			"Are you experience a memory leak? ".
			"(markeraddress is '$markeraddress') ".
			"(call_address is '$call_address')"
		);
	}

	delete($markers_for_this_call->{$markeraddress});

	# now tag the user's href so we can catch if they 
	# use it again without getting a new marker
	%{$_[0]} = (MARKER_DELETED=>1);
} 



sub __gnaw__try_to_parse {
	GNAWMONITOR;
	my($subref)=@_;

	my $call_at_start_of_try = $__gnaw__current_calltree_location;

	# we will try to parse command from current location
	# if it fails, but there is another quantifier combination to try,
	# then go back to start location and try again.
	# need to keep track of location at start of try.
	my $location_on_call_tree_at_start_of_try;
	my $location_on_text_list_at_start_of_try;

	$__gnaw__parse_failed=0; 
	my $keeplooking=1;

	if(exists($call_at_start_of_try->{try_another_quantifier_run})) {
		  $call_at_start_of_try->{try_another_quantifier_run}=0;
	}

	while( $keeplooking ) {
		GNAWMONITOR ("TRYTOPARSE:__gnaw__try_to_parse while loop ");
		__gnaw__get_current_text_marker    ($location_on_text_list_at_start_of_try);
		__gnaw__get_current_calltree_marker($location_on_call_tree_at_start_of_try);

		eval { 
			$subref->(); 
		};

		if($@) {
			if($__gnaw__parse_failed) {
				GNAWMONITOR("TRYTOPARSE:failed ");
				__gnaw__restore_old_text_marker		($location_on_text_list_at_start_of_try);
				__gnaw__restore_old_calltree_marker	($location_on_call_tree_at_start_of_try);

				$__gnaw__parse_failed=0; # reset flag before returning

				if(exists($call_at_start_of_try->{try_another_quantifier_run}) and
					 ($call_at_start_of_try->{try_another_quantifier_run}==1)
				) {
					# then want to drop through to while loop again
					GNAWMONITOR("TRYTOPARSE:try_another_quantifier_run=1 ");
				} else {
					# else last eval failed and there are no quantifier runs to attempt. 
					# overall result is fail.
					GNAWMONITOR("TRYTOPARSE:try_another_quantifier_run=0 ");
					return 0;
				}
			} else {
				# died, but gnaw didn't fail. something else went wrong
				GNAWMONITOR("TRYTOPARSE:plain die ");
				__gnaw__die $@;
			}
		} else {
			# didn't die, must have succeeded.
			GNAWMONITOR("TRYTOPARSE:success ");
			__gnaw__unlink_old_text_marker		($location_on_text_list_at_start_of_try);
			__gnaw__unlink_old_calltree_marker	($location_on_call_tree_at_start_of_try);
			return 1;
		}
	}

	if(exists($call_at_start_of_try->{try_another_quantifier_run})) {
		$keeplooking = $call_at_start_of_try->{try_another_quantifier_run};
	}

}


sub __gnaw__find_location_of_this_subroutine_in_grammar {
	GNAWMONITOR;
	my $cnt=0;
	my @caller=caller($cnt++);

	while(scalar(@caller)) {

		my $package  = $caller[0];
		my $filename = $caller[1];
		my $linenumb = $caller[2];
		my $subrname = $caller[3];
	
		if($filename ne 'Gnaw.pm') {
			my $location = "file='$filename', line=$linenumb, sub='$subrname', pkg='$package'\n";

			#print "location is $location\n";

			return $location;
		}
		@caller=caller($cnt++);
	}

	return "__gnaw__find_location_of_this_subroutine_in_grammar epic fail";
}


# use "local" to always point to the current "series" command.
# "series" will localize this variable then assign it to the call element of the series.
# if  __gnaw__handle_call_tree  gets called to handle a quantifier,
# and that quantifier is not in the call tree, then that quantifier
# needs to be assigned to the series element. This will then allow the series element
# to decide if it needs to alter the quantifier "try" values and try the series again
# or if the quantifiers within the series have been exhausted, and the series fails.
our $__gnaw__current_quantifier_owner;


sub __gnaw__handle_call_tree {
	GNAWMONITOR;
	my($ptrtocoderef,$statushash)=@_;
	my $coderef = $$ptrtocoderef;

	my $this_stringified_address = $coderef.'';
	my $next_stringified_address = '';

	if(exists($__gnaw__current_calltree_location->{try_another_quantifier_run})) {
		  $__gnaw__current_calltree_location->{try_another_quantifier_run}=0;
	}
 
	if(exists($__gnaw__current_calltree_location->{next})) {
		$next_stringified_address = $__gnaw__current_calltree_location->{next}->{coderef};
	}

	# if we've already been down this path
	if($this_stringified_address eq $next_stringified_address) {
		# reuse existing hash pointing to next operation.
		$__gnaw__current_calltree_location = $__gnaw__current_calltree_location->{next};
	} else {
		# either never gone this far before or this is a new path
		# see if an old path exists, if so, it must be an old path
		# that we won't be using anymore, delete it.
		if(exists($__gnaw__current_calltree_location->{next})) {
			my $oldpath = $__gnaw__current_calltree_location->{next};
			__gnaw__delete_call_tree_from_here_to_end($oldpath);
		}

		my $href={};
		%$href=%$statushash;
		$href->{previous} = $__gnaw__current_calltree_location;
		$__gnaw__current_calltree_location->{next} = $href;
		$__gnaw__current_calltree_location = $href;
		$href->{LOCATION_MARKERS}={};
		$href->{coderef}=$this_stringified_address;
	}

	if(exists($__gnaw__current_calltree_location->{quantifier})) {
		$__gnaw__current_calltree_location->{quantifier_owner} = $__gnaw__current_quantifier_owner;
	}

	if(exists($__gnaw__current_calltree_location->{try_another_quantifier_run})) {
		  $__gnaw__current_calltree_location->{try_another_quantifier_run}=0;
	}

	GNAWMONITOR (   "DUMPING STATUS EVERY TIME WE CALL __gnaw__handle_call_tree \n" );
	GNAWMONITOR (  __gnaw__dump_current_call_tree() );
	GNAWMONITOR (  __gnaw__string_showing_user_current_location_in_text() );
	GNAWMONITOR (   "\n\n\n" );
}

sub __gnaw__delete_call_tree_from_here_to_end {
	my($startelement)=@_;

	my $this = $startelement;
	my $next;

	while(defined($this)) {

		# delete any call tree markers stored in this element
		my $markers = $this->{LOCATION_MARKERS};
		while(my($markeraddr,$markerref)=each(%$markers)) {
			__gnaw__unlink_old_calltree_marker($markerref);
		}

		# get the next hash, if there is one
		$next = undef;
		if(exists($this->{next})) {
			$next=$this->{next};
		}

		# delete everything in this hash
		%$this=();		

		# get ready for next iteration
		$this=$next;
	}

}


# this will dump the call tree from the current pointer back to the beginning.
sub __gnaw__dump_current_call_tree {
	GNAWMONITOR;
	
	my $string = "\n\n\n";
	$string.= "DUMPING CALL TREE, starting from current location, working back\n";
	my $command = $__gnaw__current_calltree_location;

	my $counter = 0;

	while(defined($command)) {
		my $stringified_address = $command.'';
		my $location = $command->{location};
		my $descriptor = $command->{descriptor};
		my $coderefstr = $command->{coderef};

		unless(defined($location)) {
			$string.= "no definition for location\n";
			$location = '';
		}
		$location = chomp($location);

		unless(defined($descriptor)) {
			$string.= "no definition for descriptor\n";
			$descriptor = '';
		}

		unless(defined($coderefstr)) {
			$coderefstr='coderef?';
		}

		my $qrun='';
		if(exists($command->{try_another_quantifier_run})) {
			$qrun = " try_another_quantifier_run = ". $command->{try_another_quantifier_run};
		}

		my $call_markers = '';
		if(exists($command->{LOCATION_MARKERS})) {
			my @marker_names = keys(%{$command->{LOCATION_MARKERS}});
			$call_markers = join (' ', @marker_names);
			
		}

		$string.= "$counter $stringified_address : $coderefstr : $descriptor at $location :: $qrun :: call_markers($call_markers)\n";

		if(exists($command->{quantifier})) {
			my $min = $command->{min};
			my $max = $command->{max};
			unless(defined($max)) { $max='undef'; }
			my $try = $command->{try};
			unless(defined($try)) { $try='undef'; }
			my $successes = $command->{successes};
			unless(defined($successes)) { $successes='undef'; }
			my $rollover= $command->{rollover};
			unless(defined($rollover)){$rollover='undef';}
			my $owner = $command->{quantifier_owner};
			$string.= " quantifier dump {min=$min, max=$max, try=$try, successes=$successes, rollover=$rollover } [owner=$owner] \n";

		}

		$command = $command->{previous};

		$counter++;
	}
	$string.= "end of __gnaw__dump_current_call_tree\n";
	$string.= "\n\n\n";

	return $string;
}




####################################################################
####################################################################
####################################################################
# now define the subroutines that users will call to define their grammars.
####################################################################
####################################################################
####################################################################




sub __gnaw__check_all_coderefs {
	GNAWMONITOR;
	my @elements=@_;
	unless(scalar(@_)>0) {
		__gnaw__die("no elements to process");
	}

	# make sure they're all code refs.
	# otherwise, user might have dropped a paren somewhere
	foreach my $element (@elements) {
		unless(ref($element) eq 'CODE') {
			__gnaw__die("non-code-ref element '$element'");
		}
	}
}

=head2 match

This is equivalent to the "m" part of a perl regexp of $string\=~m//.  The match function takes a grammar and attempts to find the first match within the string. If a match is found, the function returns true (1), else it returns false (0). The match function takes a series() of grammar components such as lit, set, quantifier, etc. The match function returns a coderef to the grammar. The "match" function should have no other grammar components outside of it. When calling the grammar, dereference the coderef returned by "match" and pass it the string you want to apply to the grammar.

	# create the grammar
	my $grammar = match(lit('hello'));
	
	# apply the grammar to a string
	if($grammar->('hello world')) {
		print "match\n";
	} else {
		print "no match";
	}

=cut

sub match {
	GNAWMONITOR;
	__gnaw__check_all_coderefs(@_);
	my (@coderefs)=@_;

	my $status = {};
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();
	$status->{location} = $location;
	$status->{descriptor} = 'match';

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('match');
		my $string_to_match = shift(@_);
		__gnaw__initialize_string_to_parse($string_to_match);

		my $position;

		# start at beginning of string and try to match
		# if match fails, keep moving forward until we're
		# at the end of the string.
		until( __gnaw__at_end_of_string() ) {

			__gnaw__initialize_call_tree();
			__gnaw__handle_call_tree($ptrtocoderef, $status);

			__gnaw__get_current_text_marker($position);

			if(__gnaw__try_to_parse(series(@coderefs))) {
				# DONE!
				__gnaw__done();
				return 1;
			} else {
				__gnaw__restore_old_text_marker($position);
				__gnaw__move_pointer_forward();
			}
		}

		return 0;
	};
	return $coderef;
}


=head2 series

The "series" function is a gnaw grammar component which takes a series of other grammar components. This is the only way to define a grammar with one component occurring after another. The "series" function takes a series of other grammar components and returns a coderef to that portion of the grammar. 

The "series" function returns a coderef that is used in part of a larger grammar.

	# look for a series of two literals, "hello" followed by "world"
	my $grammar = match( series(lit('hello'), lit('world')) );
	
	# apply the grammar to a string
	if($grammar->('hello world')) {
		print "match\n";
	} else {
		print "no match";	
	}	

=cut

sub series {
	GNAWMONITOR;
	__gnaw__check_all_coderefs(@_);
	my (@coderefs)=@_;

	my $status = {};
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();
	$status->{location} = $location;
	$status->{descriptor} = 'series';

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('series');
		__gnaw__handle_call_tree($ptrtocoderef, $status);
		__gnaw__series(@coderefs);
	};
	return $coderef;
}


sub __gnaw__series {
	GNAWMONITOR;
	my $series_location = $__gnaw__current_calltree_location;
	local($__gnaw__current_quantifier_owner) = $series_location;

	my @elements = @_;

	my $sub = sub{ 
		GNAWMONITOR('__gnaw__series closure');
		foreach my $coderef (@elements) {
			$coderef->();
		}
	};
	# __gnaw__try_to_parse will handle any quantifier reruns.
	# check return value for pass or fail of this whole series.
	if(__gnaw__try_to_parse($sub)) {
		return;
	} else {
		__gnaw__parse_failed();
	}
}


=head2 lit

The "lit" function is a gnaw grammar component which applies a literal string value to the string being parsed. The literal value may be a single character or more than one character. 

The "lit" function returns a coderef that is used in part of a larger grammar.

	# look for the literal string "hello" in the string being parsed
	my $grammar = match(lit('hello'));
	
	# apply the grammar to a string
	if($grammar->('hello world')) {
		print "match\n";
	} else {
		print "no match";
	}

=cut

sub lit {
	GNAWMONITOR;
	my ($literal)=shift(@_);

	my $status = {};
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();
	$status->{location} = $location;
	$status->{descriptor} = "lit '$literal'";

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('litoperation');
		__gnaw__handle_call_tree($ptrtocoderef, $status);
		__gnaw__lit($literal);
	};
	return $coderef;
}

sub __gnaw__lit {
	GNAWMONITOR;
	my ($lit)=@_;
	my @literal_characters = split(//, $lit);

	foreach my $litchar (@literal_characters) {
		my $userchar = __gnaw__next_character();
		if($litchar ne $userchar) {
			__gnaw__parse_failed();
		}
	}
}


sub __gnaw__convert_character_class_string_into_hash_ref {
	GNAWMONITOR;
	my ($characterset)=@_;

	my @chars = split(//, $characterset);

	my $char_set_hash_ref={};

	if($chars[0] eq '-') {
		$char_set_hash_ref->{'-'} = 1;
		shift(@chars);
	}



	 while(@chars) {
		my $first = shift(@chars);

		if( (scalar(@chars)>=2) and ($chars[0] eq '-') ){

			my $hyphen = shift(@chars);

			my $last = shift(@chars);

			for my $letter ($first .. $last) {
				$char_set_hash_ref->{$letter} = 1;
			}
		} else {
			$char_set_hash_ref->{$first} = 1;
		}
	}


	#print "\ncharacterset is '$characterset'\n"; print Dumper $char_set_hash_ref;

	return $char_set_hash_ref;
}

=head2 set

The "set" function is a gnaw grammar component which applies a character class or character set to the string being parsed. Since "class" is a perl reserved word, gnaw uses the word "set" for character set. The "set" function takes a string which describes the character class. The "set" function parses one metacharacter within the string and that is a '-' character. This is used to define a range of charcters. All digits can be described as "0-9". All letters can be described as "a-zA-Z". If you want the "-" character to be part of the set itself, make it the first character in the string you pass into set.

The "set" function returns a coderef that is used in part of a larger grammar.

	# look for an x, y, or z within the string being parsed
	my $grammar = match(set("xyz"));
	
	# apply the grammar to a string
	if($grammar->('hello world')) {
		print "match\n";
	} else {
		print "no match";
	}

=cut

# character classes: anything in the specified class of characters.
# I'd use the subroutine name "class" for character classes,
# but "class" is already a perl keyword. I hope "set" isn't.
sub set { 
	GNAWMONITOR;
	my ($characterset)=@_;

	my $char_set_hash_ref = 
		__gnaw__convert_character_class_string_into_hash_ref
			($characterset);

	my $status = {};
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();
	$status->{location} = $location;
	$status->{descriptor} = "character set '$characterset'";

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('setoperation');
		__gnaw__handle_call_tree($ptrtocoderef, $status);
		__gnaw__set($char_set_hash_ref);
	};
	return $coderef;

}


sub __gnaw__set {
	GNAWMONITOR;
	my ($char_set_hash_ref)=@_;

	my $curr_char = __gnaw__next_character();

	unless(exists($char_set_hash_ref->{$curr_char})) {
		__gnaw__parse_failed();
	}
}


# character classes NOT: anything BUT what's in the specified class of characters.

=head2 SET

The "SET" function is a gnaw grammar component which applies a NEGATIVE character class or NEGATIVE character set to the string being parsed. The "SET" function takes a string which describes the character class. The "SET" function parses one metacharacter within the string and that is a '-' character. This is used to define a range of charcters. All digits can be described as "0-9". All letters can be described as "a-zA-Z". If you want the "-" character to be part of the set itself, make it the first character in the string you pass into set.

The "SET" function returns a coderef that is used in part of a larger grammar.

	# look for anything other than an x, y, or z in the string being parsed.
	my $grammar = match(SET("xyz"));
	
	# apply the grammar to a string
	if($grammar->('hello world')) {
		print "match\n";
	} else {
		print "no match";
	}

=cut

sub SET {
	GNAWMONITOR;
	my ($characterset)=@_;

	my $char_set_hash_ref = 
		__gnaw__convert_character_class_string_into_hash_ref
			($characterset);

	# at the end of the string, code may return a null string
	$char_set_hash_ref->{''} = 1;

	my $status = {};
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();
	$status->{location} = $location;
	$status->{descriptor} = "character SET '$characterset'";

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('SEToperation');
		__gnaw__handle_call_tree($ptrtocoderef, $status);
		__gnaw__SET($char_set_hash_ref);
	};
	return $coderef;

}


sub __gnaw__SET {
	GNAWMONITOR;
	my ($char_set_hash_ref)=@_;

	my $curr_char = __gnaw__next_character();

	if(exists($char_set_hash_ref->{$curr_char})) {
		__gnaw__parse_failed();
	}
}

=head2 set_digit

The "set_digit" is a shortcut equivalent to set('0-9'). 

=cut

sub set_digit {
	return set('0-9');
}


=head2 SET_DIGIT

The "SET_DIGIT" is a shortcut equivalent to SET('0-9').  i.e. [^0-9]

=cut

sub SET_DIGIT {
	return SET('0-9');
}

=head2 set_whitespace

The "set_whitespace" is a shortcut equivalent to set("\t\n\r\f"). 

=cut
sub set_whitespace {
	return set("\t\n\r\f");
}

=head2 SET_WHITESPACE

The "SET_WHITESPACE" is a shortcut equivalent to SET("\t\n\r\f"). i.e. [^\t\n\r\f]

=cut
sub SET_WHITESPACE {
	return SET("\t\n\r\f");
}

=head2 set_identifier

The "set_identifier" is a shortcut equivalent to set('a-zA-Z0-9_'). 

=cut

sub set_identifier {
	return set('a-zA-Z0-9_');
}

=head2 SET_IDENTIFIER

The "SET_IDENTIFIER" is a shortcut equivalent to SET('a-zA-Z0-9_').  i.e. [^a-zA-Z0-9_]

=cut

sub SET_IDENTIFIER {
	return SET('a-zA-Z0-9_');
}



=head2 thing

The "thing" function is a gnaw grammar component which matches any single character in the string being parsed. It is equivalent to the '.' operator in normal regular expression format. I would have called it "character" but that is a bit long and "char" is usually a reserved word. 

	my $grammar = match(lit('b'), thing, lit('b'));

	# these will all match.
	$grammar->("bob");
	$grammar->("bib");
	$grammar->("bub");

	# this will fail to match.
	$grammar->("bb");

The "thing" function returns a coderef that is used in part of a larger grammar.

=cut


sub thing { 
	GNAWMONITOR;

	my $status = {};
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();
	$status->{location} = $location;
	$status->{descriptor} = "a single 'thing' operation";

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('thing operation');
		__gnaw__handle_call_tree($ptrtocoderef, $status);

		if(__gnaw__at_end_of_string()) {
			__gnaw__parse_failed();
		} else {
			__gnaw__move_pointer_forward();
		}

	};
	return $coderef;

}

=head2 alternation

The "alternation" function is a gnaw grammar component which applies one of several possible alternatives to the string being parsed. The "alternation" function will attempt each possible alternative in the order it is passed into the function as a parameter. Each alternative must be a single command. 

	# look for people we know
	my $grammar = match(alternation(lit('alice'), lit('bob')));
	
	# apply the grammar to a string
	if($grammar->('hello alice')) {
		print "match\n";
	} else {
		print "no match";
	}

If an alternative needs to be made of more than one grammar command, either bundle them together using a "series" function, or create a named subroutine that will act as a named rule for your grammar, and call that subroutine as one of your alternates.

	# one alternative will be a series of two literals, 'hello' followed by 'world'.
	# create a subroutine that will contain this rule.
	sub greet_all { series(lit('hello'), lit('world'));}
	
	# another alternative will be a series of two literals, "howdy" followed by "partner"
	sub greet_one { series(lit('howdy'), lit('partner'));}
	
	# look for either greeting	
	my $grammar = match(alternation(greet_all, greet_one));

	# apply the grammar to a string
	if($grammar->('hello world')) {
		print "match\n";
	} else {
		print "no match";
	}

The "alternation" function returns a coderef that is used in part of a larger grammar.

=cut

sub alternation {
	GNAWMONITOR;
	__gnaw__check_all_coderefs(@_);

	my @alternates = @_;

	my $status = {};
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();
	$status->{location} = $location;
	$status->{descriptor} = "alternation";

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('alternationcommand');
		__gnaw__handle_call_tree($ptrtocoderef, $status);
		__gnaw__alternation(@alternates);
	};
	return $coderef;
}


sub __gnaw__alternation {
	GNAWMONITOR;
	my $text_marker_at_start_of_alternation;

	my $location_of_alternation_on_call_tree;


	# try each alternate
	foreach my $alternate (@_) {

		__gnaw__get_current_calltree_marker($location_of_alternation_on_call_tree);
		__gnaw__get_current_text_marker($text_marker_at_start_of_alternation);

		# if it works, then return
		if(__gnaw__try_to_parse($alternate) == 1) {
			# need to garbage collect the marker
			__gnaw__unlink_old_text_marker($text_marker_at_start_of_alternation);
			__gnaw__unlink_old_calltree_marker($location_of_alternation_on_call_tree);

			return;
		}

		# else go back to where alternation started and try next alternation
		__gnaw__restore_old_text_marker($text_marker_at_start_of_alternation);
		__gnaw__restore_old_calltree_marker( $location_of_alternation_on_call_tree );
	}

	# if no alternate worked, then alternation failed.
	__gnaw__parse_failed(); # throws an exception

}


#####################################################################
#####################################################################
#####################################################################
# defining some "callbacks" for quantifier functionality.
# we will define thrifty and greedy processes, 
# and then put them into global hash.
# user can then easily create their own behaviour for new quantifier types
# or modify the existing behaviour.
#####################################################################
#####################################################################
#####################################################################


sub __gnaw__thrifty_preprocess {
	GNAWMONITOR;

	my $href = shift(@_);
	__gnaw__quantifier_min_max_default_handler($href , @_);

	my $min=$href->{min};
	my $max=$href->{max};

	my $descriptor = "quantifier (thrifty, $min,";
	if(defined($href->{max})) {
		$descriptor .= $href->{max};
	}
	$descriptor .= ')';
	$href->{descriptor}=$descriptor;

	# parser will ask to calculate number of times to try a command
	$href->{try}=$min;

	# parser will ask if calculation appears to have caused a rollover
	$href->{rollover}=0;

	# after trying command N times, parser will tell callback how many times it succeeded
	$href->{success}=undef;
}

sub __gnaw__greedy_preprocess {
	GNAWMONITOR;
	my $href = shift(@_);
	__gnaw__quantifier_min_max_default_handler($href , @_);

	my $min=$href->{min};
	my $max=$href->{max};

	my $descriptor = "quantifier (greedy, $min,";
	if(defined($href->{max})) {
		$descriptor .= $href->{max};
	}
	$descriptor .= ')';
	$href->{descriptor}=$descriptor;


	# parser will ask to calculate number of times to try a command
	$href->{try}=$max;

	# parser will ask if calculation appears to have caused a rollover
	$href->{rollover}=0;

	# after trying command N times, parser will tell callback how many times it succeeded
	$href->{successes}=undef;
}

	

sub __gnaw__thrifty_calculate_next_try_value { 
	GNAWMONITOR;
	my ($href)=@_;

	my $min = $href->{min};
	my $max = $href->{max};
	my $try = $href->{try};
	my $successes = $href->{successes};
	my $nexttry;
	my $rollover=0;

	GNAWMONITOR("NEXTTRYVALUE: min=$min");
	GNAWMONITOR("NEXTTRYVALUE: max=".(defined($max)?$max:'undef') );
	GNAWMONITOR("NEXTTRYVALUE: try=".(defined($try)?$try:'undef') );
	GNAWMONITOR("NEXTTRYVALUE: successes=".(defined($successes)?$successes:'undef') );


	if(defined($try) and defined($successes)) {
		if(0) {
		# start small and work our way up.
		# if we tried 8 and got 8,
		# then we should try 9 this time.
		} elsif($try == $successes) {
			GNAWMONITOR("NEXTTRYVALUE: try==successes");
			$nexttry = $try+1;

			# if at defined max, then make sure we dont' exceed it.
			if(defined($max)) {
				if($nexttry>$max) {
					$nexttry=$min;
					$rollover=1;
				}
			}

		# if we tried 8 and got 5,
		# then we should rollover and try the min value again
		} elsif ($try > $successes) {
			GNAWMONITOR("NEXTTRYVALUE: try>successes");
			$nexttry = $min;
			$rollover=1;

		# else we tried 5 and got 8.
		# something went wrong. die.
		} else {
			__gnaw__die("__gnaw__thrifty_calculate_next_try_value, try less than success. no idea what to do ($try < $successes)");
		}
	
	# else haven't tried anything yet, go with min
	} else {
		$nexttry = $href->{min};
		$rollover=0; # starting out, so no rollover
	}

	#set the values into hash
	$href->{try}=$nexttry;
	$href->{rollover}=$rollover;

	GNAWMONITOR("NEXTTRYVALUE: rollover=$rollover");


	return $rollover; 
}



sub __gnaw__greedy_calculate_next_try_value { 
	GNAWMONITOR;
	my ($href)=@_;

	my $min = $href->{min};
	my $max = $href->{max};
	my $try = $href->{try};
	my $successes = $href->{successes};
	my $nexttry;
	my $rollover=0;

	GNAWMONITOR("NEXTTRYVALUE: min=$min");
	GNAWMONITOR("NEXTTRYVALUE: max=".(defined($max)?$max:'undef') );
	GNAWMONITOR("NEXTTRYVALUE: try=".(defined($try)?$try:'undef') );
	GNAWMONITOR("NEXTTRYVALUE: successes=".(defined($successes)?$successes:'undef') );

	if(defined($try) and defined($successes)) {
		if(0) {

		} elsif($successes<$min) {
			$nexttry = $min;
			$rollover=1;

		# start big and work our way down.
		# if we tried 8 and got 8,
		# then we should try 7 this time.
		# if we tried 8 and got 5
		# then we should try 4 next time
		} elsif($try >= $successes) {
			$nexttry = $successes-1;

			# if below min, then try max and set rollover
			if($nexttry<$min) {
				$nexttry=$max;
				$rollover=1;
			}

		# else we tried 5 and got 8.
		# something went wrong. die.
		} else {
			__gnaw__die("__gnaw__greedy_calculate_next_try_value, try less than success. no idea what to do ($try < $successes)");
		}

	# else haven't tried anything yet, go with max
	} else {
		$nexttry = $href->{max}; #may be undefined, but deal with it as infinite
		$rollover=0; # starting out, so no rollover
	}

	#set the values into hash
	$href->{try}=$nexttry;
	$href->{rollover}=$rollover;

	return $rollover; 
}


sub __gnaw__thrifty_report_successes {
	GNAWMONITOR;
	my ($href, $successes)=@_;

	$href->{successes} = $successes;
	my $try = $href->{try};

	unless(defined($try)) {
		$try = $successes;
		$href->{try} = $try;
	}

	# if we tried 5 and got 8.
	# something went wrong. die.
	if($try<$successes) {
		__gnaw__die("__gnaw__thrifty_report_successes, try less than success. no idea what to do ($try < $successes)");
	}
	
	return;
}

sub __gnaw__greedy_report_successes {
	GNAWMONITOR;
	my ($href, $successes)=@_;

	$href->{successes} = $successes;
	my $try = $href->{try};

	unless(defined($try)) {
		$try = $successes;
		$href->{try} = $try;
	}

	# if we tried 5 and got 8.
	# something went wrong. die.
	if($try<$successes) {
		__gnaw__die("__gnaw__greedy_report_successes, try less than success. no idea what to do ($try < $successes)");
	}
	
	return;
}


sub __gnaw__thrifty_and_greedy_successes_in_range {
	GNAWMONITOR;
	my ($href)=@_;

	# if successes_in_range, 
	if( 
		($href->{successes} < $href->{min})
		or
		(	defined($href->{max}) and 
			($href->{successes} > $href->{max}) 
		) 
	) { 
		return 0;
	} else {
		return 1;
	}
}


#####################################################################
#####################################################################
#####################################################################
# first parameter to "quantifier" function is the type of quantifier.
# behaviour for different quantifiers are defined in this hash.
# existing types can be changed by assigning new callbacks.
# and new types can be added by adding a key that is the "type"
# and a value that is a hash of code refs with the defined names.
#####################################################################
#####################################################################
#####################################################################

%__gnaw__quantifier_callbacks_by_type = (

	t => {	# t for thrifty
		preprocess => 		\&__gnaw__thrifty_preprocess,
		calculate_try => 	\&__gnaw__thrifty_calculate_next_try_value,
		report_successes => 	\&__gnaw__thrifty_report_successes,
		successes_in_range =>	\&__gnaw__thrifty_and_greedy_successes_in_range,
	},

	g => {	# g for greedy
		preprocess => 		\&__gnaw__greedy_preprocess,
		calculate_try => 	\&__gnaw__greedy_calculate_next_try_value,
		report_successes =>	\&__gnaw__greedy_report_successes,
		successes_in_range =>	\&__gnaw__thrifty_and_greedy_successes_in_range,
	},
);
#####################################################################
#####################################################################
#####################################################################


sub __gnaw__numeric_check {
	GNAWMONITOR;
	my ($ptrtonumtocheck)=@_;

	my $numtocheck = $$ptrtonumtocheck;

	# convert to numeric.

	eval { my $numify = $numtocheck + 0; };

	if($@) {
		__gnaw__die("quantifier value is not numeric ($numtocheck) ($@) " );
	}

	my $numify = $numtocheck + 0;

	# make sure it's an integer
	my $intify = int($numify);

	unless($numify == $intify){
		__gnaw__die("quantifier value is not an integer ($numtocheck) ");
	}

	# assign back to the references
	$$ptrtonumtocheck = $intify;
}



# pass in an href and the min/max values (including (min,) and '+' and 's' and '*') and 
# this subroutine will initialize the hash
sub __gnaw__quantifier_min_max_default_handler {
	my $hashref = shift(@_);

	# always specify some kind of min value or a '+' or '*' or something
	my $min = shift(@_);
	my $max;

	unless(defined($min)){
		__gnaw__die("Quantifier min-value must be defined");
	}

	if(($min eq 's')or($min eq '+')) {
		$min = 1;
		$max = undef;
		if( scalar(@_) and (not(defined($_[0]))) ) {
			shift(@_);
		}

	} elsif ($min eq '*') {
		$min = 0;
		$max = undef;
		if( scalar(@_) and (not(defined($_[0]))) ) {
			shift(@_);
		}
	} else {
		__gnaw__numeric_check(\$min);

		$max = shift(@_);

		if(defined($max)) {
			__gnaw__numeric_check(\$max);
		}
	}

	$hashref->{min} = $min;
	$hashref->{max} = $max;

	if(scalar(@_)) {
		__gnaw__die("quantifier called with unknown parameters (".$_[0].")");
	}
}

#####################################################################
#####################################################################
#####################################################################
# quantifier
#####################################################################
#####################################################################
#####################################################################


=head2 quantifier

The "quantifier" function is a gnaw grammar component which receives a single grammar component and attempts to apply that command repeatedly to the string being parsed. The parameters passed into the "quantifier" function are defined as follows:

quantifier( thrifty_or_greedy , single_grammar_component , minimum , maximum );

The thrifty_or_greedy parameter is a 't' or a 'g' to indicate whether the single command is applied as a thrifty or greedy quantifier. It is an optional parameter and may be skipped. If no thrifty_or_greedy parameter is provided, the quantifier will assume greedy.

The single_grammar_component is a single gnaw grammar component. If the quantifier is to be applied to more than one command in a series, either bundle those commands up in a series() function or bundle them up in a named subroutine that can act as a separate rule.

The minimum parameter is the minimum number of times the component must successfully apply to the string being parsed for the grammar to be considered successful. The smallest legal value for "minimum" is zero. You must provide a minimum value of some kind.

The maximum parameter is the maximum number of times the component must successfully apply to the string being parsed for the grammar to be considered successful. The maximum value is optional. if no maximum value is provided, the parser will try as many as possible.

The "quantifier" function also allows some shortcuts instead of the numeric "minimum" and "maximum" parameters. 

'*' means "0 or more"

's' and '+' means "1 or more"


	# look for 3 to 7 letter 'a'. Use a thrifty search.
	my $grammar = match(quantifier('t', lit('a'), 3,7));

	# look for 3 or more letter 'a'. still thrifty.
	my $grammar = match(quantifier('t', lit('a'), 3));

	# look for 3 or more letter 'a'. greedy search.
	my $grammar = match(quantifier('g', lit('a'), 3));

	# look for 3 or more letter 'a'. greedy search.
	my $grammar = match(quantifier(lit('a'), 3));

	# look for 1 or more letter 'a'. greedy search.
	my $grammar = match(quantifier(lit('a'), 's'));

	# look for 1 or more letter 'a'. greedy search.
	my $grammar = match(quantifier(lit('a'), '+'));

	# look for 0 or more letter 'a'. greedy search.
	my $grammar = match(quantifier(lit('a'), '*'));

The "quantifier" function returns a coderef that is used in part of a larger grammar.

=cut

sub quantifier{
	GNAWMONITOR;

	# my($quantifier_type, $operation, $min, $max)=@_;
	#
	# quantifier_type currently supports a 't' or a 'g' for thrifty or greedy type quantifiers.
	# the type is optional and defaults to "g" for greedy.
	#
	# operation is a code ref
	#
	# The existing quantifier types support 2 additional parameters to define min and max.
	# min/max could be two integers 3,7 (at least 3, up to 7)
	# it could also be a single integer 3 (at least 3, but up to infinity)
	# it could also be a nonnumeric symbol such as '+' (1 or more)
	
	# print Dumper \@_;


	my $quantifier_type = 'g';

	unless(ref($_[0]) eq 'CODE') {
		$quantifier_type = shift(@_);
	}

	unless(exists( $__gnaw__quantifier_callbacks_by_type{$quantifier_type} )) {
		__gnaw__die("quantifier called with unknown quantifier_type marker '$quantifier_type'");
	}

	my $operation = shift(@_);
	unless(ref($operation) eq 'CODE') {
		__gnaw__die("Expecting a code reference to be passed to quantifier, received '$operation'");
	}	

	# call the handler that takes the rest of parameters and initializes hash
	my $quantifier_callbacks = $__gnaw__quantifier_callbacks_by_type{$quantifier_type};

	my $preprocess_callback = $quantifier_callbacks->{preprocess};

	my $preprocess_hash = {
		quantifier_type => $quantifier_type
	};

	$preprocess_callback->($preprocess_hash, @_);
	
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('quantifieroperation');

		# whenever we start a regexp, set "try" to "try_init".
		# whenever a regexp fails, see if try==done, if not,
	 	# then add incrementor to "try" and retry.
		my $status = {
			quantifier => 1,
			operation => $operation, # just for record keeping
		};

		$status->{location} = $location;

		while(my($key,$data)=each(%$preprocess_hash)) {
			$status->{$key}=$data;
		}

		__gnaw__handle_call_tree($ptrtocoderef, $status);

		__gnaw__quantifier ($operation);
	};

	return $coderef;
}



=head2 thrifty

The "thrifty" function is a shortcut to the "quantifier" function with the thrifty/greedy parameter forced to thrifty.

=cut

sub thrifty{
	my($operation, $min, $max)=@_;
	return quantifier('t', $operation, $min, $max);
}

=head2 greedy

The "greedy" function is a shortcut to the "quantifier" function with the thrifty/greedy parameter forced to greedy.

=cut

sub greedy{
	my($operation, $min, $max)=@_;
	return quantifier('g', $operation, $min, $max);
}

=head2 some

The "some" function is a shortcut to a "quantifier" function set to greedy, and the quantity set to "1 or more".

=cut 

sub some {
	my($operation)=@_;
	return quantifier('g', $operation, 1);
}

=head2 any

The "any" function is a shortcut to a "quantifier" function set to greedy, and the quantity set to "0 or more".

=cut 

sub any {
	my($operation)=@_;
	return quantifier('g', $operation, 0);
}



=head2 something

The "something" function is a shortcut to a "quantifier" function set to greedy, the quantity set to "1 or more", and the command set to "thing". This is equivalent to the '.+' operator in the usual regular expression syntax.

=cut 

sub something {
	my($operation)=@_;
	return quantifier('g', thing(), 1);
}


=head2 anything

The "anything" function is a shortcut to a "quantifier" function set to greedy, the quantity set to "0 or more", and the command set to "thing". This is equivalent to the '.+' operator in the usual regular expression syntax.

=cut 

sub anything {
	my($operation)=@_;
	return quantifier('g', thing(), 0);
}




sub __gnaw__quantifier {
	GNAWMONITOR;
	my($operation)=@_;

	my $quantifier_hash = $__gnaw__current_calltree_location;

	my $quantifier_type = $quantifier_hash->{quantifier_type};

	my $quantifier_callbacks = $__gnaw__quantifier_callbacks_by_type{$quantifier_type};

	my $try = $quantifier_hash->{try};

	my $openended = defined($try) ? 0 : 1;

	# get markers for start of entire quantifier command
	my $text_marker_at_start_of_quantifier_command;
	my $call_marker_at_start_of_quantifier_command;
	__gnaw__get_current_text_marker($text_marker_at_start_of_quantifier_command);
	__gnaw__get_current_calltree_marker($call_marker_at_start_of_quantifier_command);

	my $cnt;
	my $number_of_successes=0;
	my $successful_so_far=1;

	# try the sub as many times as hashinfo says to try.
	# if we try it 7 times and it works, then it fails on the 8th try,
	# then set the marker to the end of the 7th try and set the 
	# hashinfo to 8 so we know how many times to try next time.
	# (use short circuit OR to prevent evaluation of an undefined 'try' value)
	for($cnt=1; ( ($openended or ($cnt<=$try)) and $successful_so_far ); $cnt++) {
		# if we try this iteration, keep going.
		GNAWMONITOR("__gnaw__quantifier in loop to try command (cnt=$cnt)");
		if(__gnaw__try_to_parse($operation)) {
			GNAWMONITOR("__gnaw__quantifier tried command and worked");
			$number_of_successes++;
		} else {
			GNAWMONITOR("__gnaw__quantifier tried command and failed");
			$successful_so_far=0;
		}
	}

	GNAWMONITOR("__gnaw__quantifier number_of_successes=$number_of_successes");

	# report how many successes we actually had
	$quantifier_callbacks->{report_successes}->($quantifier_hash, $number_of_successes);

	# if successes_in_range, 
	if( $quantifier_callbacks->{successes_in_range}->($quantifier_hash) ) { 

		GNAWMONITOR("__gnaw__quantifier successes_in_range=TRUE");

		# this quantifier passed, get rid of the start markers
		__gnaw__unlink_old_text_marker($text_marker_at_start_of_quantifier_command);
		__gnaw__unlink_old_calltree_marker($call_marker_at_start_of_quantifier_command);

	} else {
		# we're either too many or not enough.
		# quantifier failed, go back to very beginning
		GNAWMONITOR("__gnaw__quantifier successes_in_range=FALSE");

		__gnaw__restore_old_text_marker( $text_marker_at_start_of_quantifier_command );
		__gnaw__restore_old_calltree_marker( $call_marker_at_start_of_quantifier_command );

		__gnaw__parse_failed(); # throws an exception
	}
}


=head2 callback

If you want to call a user-defined callback any time the parser hits a specific point of the grammar, simply insert a reference to a subroutine in that location in the grammar and it will be called every time the parser hits that location, whether the grammar ends up succeeding later or not.

	# want between 7 and 9 letter 'a'. and every time we try, print the letter "X".
	my $grammar = match(quantifier('t', series(lit('a'), sub{print"X\n";}) , 7,9));

	# this will not match, but it will print out an "X" for every time 
	# "quantifier" tried to match before the parser fails.
	$grammar->('aaaaa');

The "callback" function takes a single code reference to any user-defined subroutine and calls that coderef only if the parser succeeds. Success is defined as either (1) reaching the end of the grammar and successfully matching the string being parsed or (2) the grammar executes a "commit" function, which is defined later.

Note that "callback" is a scheduled call and only makes the actual call when grammar succeeds.

	# look for a series of two literals, "hello" followed by "world", 
	my $grammar = match(greedy( series(lit('a'), callback(sub{print"X\n";})), 7,9) );

	# this will fail to match and no callback will be called.
	$grammar->('aaaaa');

	# this will match and all the callbacks will be called at the end.
	$grammar->('aaaaaaaaaaaaaaaa');

=cut

sub callback {
	GNAWMONITOR;
	my ($callback_coderef)=@_;

	unless(ref($callback_coderef) eq 'CODE') {
		__gnaw__die("callback expecting first parameter to be a code reference to a callback, found ($callback_coderef)");
	}

	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('callbackoperation');
		my $status = {
			callback => $callback_coderef,
		};

		$status->{location} = $location;
		$status->{descriptor} = "callback";

		__gnaw__handle_call_tree($ptrtocoderef, $status);

	};

	return $coderef;

}

=head2 capture

The "capture" function is a specialized version of "callback". The user passes two parameters into "capture", (1) a grammar component and (2) a callback, a code reference to a user-defined subroutine which will be called when the grammar succeeds.

The callback will receive a copy of the string containing whatever was captured within the given grammar component. This will be passed via the @_ variable.

	my $capture_callback = sub{
		my ($string) = @_;
		print "captured string is '$string'\n";
	};


	# capture the first "a" we find.
	my $grammar = match(capture(lit('a'), $capture_callback)));

	# this will not match, the capture callback will not be called.
	$grammar->('xxxxx');

	# this will match and the capture callback will be called upon success.
	$grammar->('aaaaa');

Note that "capture" creates a scheduled call and only makes the actual call when the grammar succeeds.

=cut

sub capture {
	GNAWMONITOR;
	my ($gnaw_coderef, $callback_coderef)=@_;

	unless(ref($gnaw_coderef) eq 'CODE') {
		__gnaw__die("capture expecting first parameter to be a code reference to a gnaw function (series, lit, alt, quantifier, etc), found ($gnaw_coderef)");
	}

	unless(ref($callback_coderef) eq 'CODE') {
		__gnaw__die("capture expecting second parameter to be a code reference to a callback, found ($callback_coderef)");
	}

	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('captureoperation');
		my $status = {
			capture => 1,
			callback => $callback_coderef,
			start => undef,
			stop => undef,
			operation => $gnaw_coderef, # just for record keeping
		};

		$status->{location} = $location;
		$status->{descriptor} = "capture";

		__gnaw__handle_call_tree($ptrtocoderef, $status);
		__gnaw__capture($gnaw_coderef, $callback_coderef);

	};
	return $coderef;

}



sub __gnaw__capture {
	GNAWMONITOR;
	my ($gnaw_coderef, $callback_coderef)=@_;

	my $capture_hash = $__gnaw__current_calltree_location;

	# the next rule might skip some white space, if "skip" says to do that.
	# if "skip" says to skip anything, then we don't want to capture it.
	# so call skip first, then set the marker.
	# note if user wants to capture whitespace, they should have set skip to a null subroutine
	$__gnaw__skip->(); 

	my $start_capture_point;
	__gnaw__get_current_text_marker($start_capture_point);
	$capture_hash->{start} = $start_capture_point;

	$gnaw_coderef->();

	my $stop_capture_point;
	__gnaw__get_current_text_marker($stop_capture_point);
	$capture_hash->{stop} = $stop_capture_point;

}


# don't call this unless you've either (1) successfully parsed the whole input text or
# (2) the parser did a "commit" and the call tree must be correct
sub __gnaw__execute_callbacks_in_call_tree {
	GNAWMONITOR;
	#__gnaw__dump_current_call_tree();

	my $command = $__gnaw__current_calltree_location;

	my $callback;
	my $counter = 0;

	while(defined($command)) {
		$counter++;
		if(exists($command->{capture})) {
			print "found capture on call tree at counter '$counter'\n";
			my $start_marker = $command->{start};
			my $start_pointer = $start_marker->{pointer_to_text};

			my $stop_marker  = $command->{stop};
			my $stop_pointer = $stop_marker->{pointer_to_text};

			my $string = __gnaw__get_string_between_two_pointers
					($start_pointer, $stop_pointer);
			$callback = $command->{callback};
			$callback->($string, $start_pointer, $stop_pointer);

			# unlink the markers so they can be garbage collected.
			__gnaw__unlink_old_text_marker($start_marker);
			__gnaw__unlink_old_text_marker($stop_marker);

		} elsif (exists($command->{callback})) {
			print "found user callback on call tree at counter '$counter'\n";
			$callback = $command->{callback};
			$callback->();
		}

		$command = $command->{previous};
	}
}


sub __gnaw__done {
	GNAWMONITOR;
	#__gnaw__dump_current_call_tree();
	__gnaw__execute_callbacks_in_call_tree();
	__gnaw__initialize_call_tree( );
	__gnaw__delete_linked_list_from_start_to_current_pointer();
}




=head2 consumable

The "consumable" function is useful for parsing large portions of text. The "consumable" function receives a single grammar component and whenever that component successfully parses, even though the full grammar has not finished, then "consumable" will remove any internal data structures related to the command. If there are any callbacks scheduled inside of that command, they will be executed before being deleted. 

If you are parsing or matching a small block of text, then "consumable" might not be useful for your application.

If you have a hierarchical grammar and all the subrules from some level on down are wrapped as "consumable", then theoretically, that grammar could parse an infinite amount of text without running out of memory. As long as the consumable subrules match blocks of text that fit in memory, then the parser will operate on one consumable block, and then delete it from memory when that block matches.

Note that "consumable" acts as an immediately executed code reference rather than a scheduled callback in the sense that it gets called as soon as the single grammar command it contains succeeds.

If the grammar later fails and part of the reason was because that consumable portion did not actually match, then the parser will not be able to retry the grammar from prior to the consumable portion. That portion is gone.

When the single grammar command succeeds, the "consumable" function deletes the text currently matching that single grammar command and it deletes the portion of the call tree that corresponds to everything executed as part of that single grammar component.

The "consumable" function returns a coderef that is used in part of a larger grammar.

=cut

sub consumable {
	GNAWMONITOR;

	my($operation)=@_;
	my $location = __gnaw__find_location_of_this_subroutine_in_grammar();

	my $coderef;
	my $ptrtocoderef=\$coderef;
	$coderef = sub{
		GNAWMONITOR('consumableoperation');
		my $status = {
			consumable => 1,
		};

		$status->{location} = $location;
		$status->{descriptor} = "consumable";

		__gnaw__handle_call_tree($ptrtocoderef, $status);
		__gnaw__consumable($operation);

	};
	return $coderef;
}


sub __gnaw__consumable {
	GNAWMONITOR;

	my($operation)=@_;

	# get marker for current position. should be a "consumable" command.
	my $location_of_starting_consummable_command = $__gnaw__current_calltree_location;

	# try the operation. if it fails, let exception throw through
	$operation->();

	# if it passes, 
	# call any callbacks between the current location and the start location
	# delete commands in call tree from current to start
	# delete text in linked list from current to start.



}




=head1 AUTHOR

Greg London, C<< <email at greglondon.com> >>

=head1 BUGS

Please note this is a beta release. Do not use this for production code. This is a proof-of-concept piece of code, and the actual interface is still completely up in the air. Do not create any massively long grammars with this parser as the parser rules themselves may change completely.

If you do find bugs, please be kind.

Please report any bugs or feature requests to C<bug-gnaw at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Gnaw>.  I will be notified, and then you will automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Gnaw


You can also look for information at:

=over 4

=item * RT: CPANs request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Gnaw>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Gnaw>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Gnaw>

=item * Search CPAN

L<http://search.cpan.org/dist/Gnaw>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Greg London, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Gnaw
