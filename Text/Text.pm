package Diff::Text;

use strict;
use warnings 'all';
use Algorithm::Diff qw(diff);
use HTML::Entities ();
use POSIX qw(strftime);
use vars qw(
	$output $start $total_offset
	%highlight @EXPORT @ISA
);
require Exporter;
@EXPORT = qw(text_diff);
@ISA = qw(Exporter);

sub text_diff {
	my($old,$new,) = (shift,shift);
	my $opt=shift if (@_);

	if ($opt->{plain}) {
		$highlight{minus} = qq(b><font color="#FF0000" size="+1" );
		$highlight{plus}  = qq(b><font color="#005500" size="+1" );
		$highlight{end} = "font></b";
	}
	else {
		$highlight{minus} = qq(span class="minus" );
		$highlight{plus}  = qq(span class="plus" );
		$highlight{end}   = qq(span);
	}

	$start = 1;
	$total_offset = 0;
	$output = "";

	my @old;
	my @new_count;
	my @space;
	my @old_orig;
	if (!ref $old) {
		$opt->{file_old} = 1;
		open (FILE, "$old") or die $!;
		@old_orig = <FILE>;
		close(FILE);
	}
	else {
		@old_orig = @$old;
	}

	my %old_count;
	my $char_count=0;
	foreach (@old_orig)
	{
		$_ = HTML::Entities::encode($_);
	    my @words = (/\S+/g);
		$char_count += scalar(@words);
	    push @old, @words;
	    #my $key = $char_count - 1;
	    #print $key, "\n";
	    $old_count{$char_count} = 1;

	}

	my @new_orig;
	if (!ref $new) {
		$opt->{file_new} = 1;
		open (FILE, "$new") or die $!;
		@new_orig = <FILE>;
		close(FILE);
	}
	else {
		@new_orig = @$new;
	}

	my @new;
	foreach (@new_orig)
	{
	    my ($leading_white) = /^( *)/;
	    push @space, $leading_white;

		$_ = HTML::Entities::encode($_);
	    my @words = (/\S+/g);

	    push @new, @words;
	    push @new_count, scalar(@words);
	}


	my @diffs = diff(\@old, \@new);

	my @starts = get_starts(\@diffs,\%old_count);

	my $line_diff = 0;
	my $last = 0;


	foreach my $hunk (@diffs) {
	    foreach my $line (@$hunk) {
			my $minus=0;
	        my $start_index;
	        if ($line->[0] eq '+') {
	            $start_index = $line->[1];
	            ($start_index,$line_diff) = ($start_index-$line_diff,$start_index);
	            $start = 0;
	            ($last) = print_para($last, \@new_count,\@space,@new[0..$start_index-1]);
	        }
	        elsif ($line->[0] eq '-') {
	            my $start_from = shift @starts;
	            $start_index = $start_from->[0];
	            ($start_index,$line_diff) = ($start_index-$line_diff,$start_index);
	            ($last) = print_para($last, \@new_count,\@space,@new[0..$start_index-1]);
	            $start = $start_from->[1];
	        }

	        @new = @new[$start_index..$#new];

	        if ($line->[0] eq '+') {

	            while (!$new_count[0])
	            {
	                shift @new_count;
	                $output .= "<br>\n";
	                $space[0] =~ s/\s/&nbsp;/g;
	                $output .= (shift @space);
	            }

	            $new_count[0]--;
	            $last = output_item($last,1,"plus",$line->[2]); #if $line->[2];
			}
			else {
				$last = output_item($last,2,"minus",$line->[2]);
			}

	    }
	}

	print_para($last, \@new_count,\@space,@new);
	$output .= "</p></body></html>";
	my $header = output_html_header($old,$new,$opt);
	$output =~ s/<\/\Q$highlight{end}\E>//;

	my $h1 = $highlight{minus};
	my $h2 = $highlight{end};
	$output =~
		s/(<\Q$h1\E>\n[^<]+<\/\Q$h2\E>)/fix_tag($1)/eg;

	return $header.$output;
}

sub fix_tag {
	my $item = shift;
	$item =~ s/\n/<br>/g;
	return $item;
}

sub print_para {
	my($last,$countref,$spaceref,@words) = @_;

    ($start) ? $start = 0 : shift @words;
    $start=0;

    if (@words) {
        $output .= "</$highlight{end}> ";
        $last=0;
    }

    foreach my $word (@words) {
        if ($countref->[0]) {
            $countref->[0]--;
            $output .= ($word . " ");
        }
        else {
            while (!$countref->[0])
            {
                shift @$countref;
                $output .=  "<br>\n";
            	$spaceref->[0] =~ s/\s/&nbsp;/g;
            	$output .= (shift @$spaceref);
            }
            $countref->[0]--;
            $output .= ($word . " ");
        }
    }
    return ($last);
}

sub get_starts {
    my ($diffs,$para) = @_;
    my @starts;
    my $start_index = 0;
    my $minus_count = 0;
    foreach my $hunk (@$diffs) {
	    my $pos = 0;

		foreach my $line (@$hunk) {
			if ($line->[0] eq '+') {
				$pos++;
				last
			}
        }
        if ($pos) {
	        foreach my $line (@$hunk) {

	            if ($line->[0] eq '+') {
	                $start_index = $line->[1];
	                while ($minus_count) {
	                    push @starts, [$start_index,0];
	                    $minus_count--;
	                }
	            }
	            else {
		            $line->[2] = "\n".$line->[2] if ($para->{$line->[1]});
		            #print $line->[2], "\n" if ($para->{$line->[1]});
	                $minus_count++;
	            }
	        }
    	}
    	else {
	    	foreach my $line (@$hunk) {
		    	$line->[2] = "\n".$line->[2] if ($para->{$line->[1]});
		        #print $line->[2], "\n" if ($para->{$line->[1]});

	    		push @starts, [$line->[1]-$total_offset,1];
	    		$total_offset++
    		}
    	}
    }
    return @starts;
}

sub output_item {

	my ($last,$value,$type,$item) = @_;
	if ($last) {
		if ($last == $value) {
			$output .=  (" " . $item);
		}
		else {
			$output .= qq(</$highlight{end}>&nbsp;<$highlight{$type}>$item);
			$last=$value;
		}
	}
	else {
		$output .= qq(<$highlight{$type}>$item);
		$last=$value;
	}
	return $last;
}

sub find_para {

	my $dataref = shift;
	my $data = join ("\n",@$dataref);
	my $para;
	while ($data =~ /^$/gm) {
		$para->{+pos($data)} = 1
	}
	return $para;
}


sub output_html_header {
	my ($old,$new,$opt) = @_;

    my $old_time = strftime( "%A, %B %d, %Y @ %H:%M:%S",
    						$opt->{old_file} ? (stat $old)[9] : time
    						, 0, 0, 0, 0, 70, 0 );
    my $new_time = strftime( "%A, %B %d, %Y @ %H:%M:%S",
    						$opt->{new_file} ? (stat $new)[9] : time
    						, 0, 0, 0, 0, 70, 0 );

    $old = (!ref $old) ? $old : "old";
    $new = (!ref $new) ? $new : "new";

	if ($opt->{plain}) {
		return "<html><head><title>Difference of $old, $new</title></head><body>"
	}

    my $header = $opt->{header} || qq(
	    <p>
	    <font size="+2"><b>Difference of:</b></font>
	    <table border="0" cellspacing="5">
	    <tr><td class="minus">---</td><td class="minus"><b>$old</b></td><td>$old_time</td></tr>
	    <tr><td class="plus" >+++</td><td class="plus" ><b>$new</b></td><td>$new_time</td></tr>
	    </table></p>
    );

    my $script = (!$opt->{functionality}) ? "" : qq(
	    <script>
	    toggle_plus_status = 1;
	    toggle_minus_status = 1;
	    function dis_plus() {
	        for(i=0; (a = document.getElementsByTagName("span")[i]); i++) {
	            if(a.className == "plus") {
	                a.style.display="none";
	            }
	        }
	    }
	    function dis_minus() {
	        for(i=0; (a = document.getElementsByTagName("span")[i]); i++) {
	            if(a.className == "minus") {
	                a.style.display="none";
	            }
	        }
	    }
	    function view_plus() {
	        for(i=0; (a = document.getElementsByTagName("span")[i]); i++) {
	            if(a.className == "plus") {
	                a.style.display="inline";
	            }
	        }
	    }
	    function view_minus() {
	        for(i=0; (a = document.getElementsByTagName("span")[i]); i++) {
	            if(a.className == "minus") {
	                a.style.display="inline";
	            }
	        }
		}

	    function toggle_plus() {
		    if (toggle_plus_status == 1) {
			    dis_plus();
			    toggle_plus_status = 0;
			}
			else {
				view_plus();
				toggle_plus_status = 1;
			}
	    }

	    function toggle_minus() {
		    if (toggle_minus_status == 1) {
			    dis_minus();
			    toggle_minus_status = 0;
			}
			else {
				view_minus();
				toggle_minus_status = 1;
			}
	    }
	    </script>
	);

    my $style = $opt->{style} || qq(
	    <style>
	        .plus{background-color:#00BBBB; visibility="visible"}
	        .minus{background-color:#FF9999; visibility="visible"}
	        P{ margin:50; border:solid; background-color:#F2F2F2; padding:5; }
	        BODY{line-height:1.7; background-color:#888888}
	        B{font-size:bigger;}
	        .togglep {
	            font-size : 12px;
	            font-family : geneva, arial, sans-serif;
	            color : #ffc;
	            background-color : #00BBBB;
	        }
	        .togglem {
	            font-size : 12px;
	            font-family : geneva, arial, sans-serif;
	            color : #ffc;
	            background-color : #ff9999;
	        }
	    </style>
	);

    my $functionality = $opt->{functionality} || qq(
	    <form>
	    <p>
	    <table border="0" cellspacing="5">
	    <td><input type="button" class="togglep" value="Toggle Plus" onclick="toggle_plus(); return false;" /></td><td width="10">&nbsp;</td>
	    <td><input type="button" class="togglem" value="Toggle Minus" onclick="toggle_minus(); return false;" /></td><td width="10">&nbsp;</td>
	    </table>
	    </p>
	    </form>
    );

    return qq(
	    <html><head>
	    <title>Difference of $old, $new</title>
	    $script
	    $style
	    </head><body>
	    $header
	    $functionality
	    <p>
    );
}

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Diff::Text - Perl extension for blah blah blah

=head1 SYNOPSIS

	use Diff::Text;
	print text_diff($ARGV[0],$ARGV[1]);

=head1 DESCRIPTION

Stub documentation for Diff::Text, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut
