package Diff::Text;

use strict;
use warnings 'all';
use Algorithm::Diff qw(diff);
use HTML::Entities ();
use POSIX qw(strftime);
use vars qw(
    $output $start $total_offset %highlight
    @EXPORT @EXPORT_OK @ISA $VERSION
);
require Exporter;
@EXPORT = qw(text_diff);
@EXPORT_OK = qw(create_diff html_header html_footer);
@ISA = qw(Exporter);
$VERSION = "1.00";

sub text_diff {
	return ((html_header(@_)).(create_diff(@_)).(html_footer()));
}

sub create_diff {
    my($old,$new,) = (shift,shift);
    my $opt=shift if (@_);

    if ($opt->{plain}) {
        $highlight{minus} = qq(b><font color="#FF0000" size="+1" );
        $highlight{plus}  = qq(b><font color="#005500" size="+1" );
        $highlight{end} = "/font></b";
    }
    else {
        $highlight{minus} = qq(span class="minus" );
        $highlight{plus}  = qq(span class="plus" );
        $highlight{end}   = qq(/span);
    }

    $start = 1;
    $total_offset = 0;
    $output = "";

    my @old_orig;
    if (!ref $old) {
        open (FILE, "$old") or die $!;
        @old_orig = <FILE>;
        close(FILE);
    }
    else {
        @old_orig = @$old;
    }

    my @old;
    my %old_count;
    my $char_count=0;
    foreach (@old_orig)
    {
        $_ = HTML::Entities::encode($_);
        my @words = (/\S+/g);
        $char_count += scalar(@words);
        push @old, @words;
        $old_count{$char_count} = 1;

    }

    my @new_orig;
    if (!ref $new) {
        open (FILE, "$new") or die $!;
        @new_orig = <FILE>;
        close(FILE);
    }
    else {
        @new_orig = @$new;
    }

    my @new;
    my @new_count;
    my @space;
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
                $last = output_item($last,1,"plus",$line->[2]);
            }
            else {
                $last = output_item($last,2,"minus",$line->[2]);
            }

        }
    }

    print_para($last, \@new_count,\@space,@new);

    $output =~ s/^\Q<$highlight{end}>\E//i;
    return $output;
}

sub print_para {
    my($last,$countref,$spaceref,@words) = @_;

    ($start) ? $start = 0 : shift @words;
    $start=0;

    if (@words) {
        $output .= "<$highlight{end}> ";
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
                    $line->[2] = $line->[2] if ($para->{$line->[1]});
                    $minus_count++;
                }
            }
        }
        else {
	        if (@$hunk) {
	        	$hunk->[0][2] = "<br>".$hunk->[0][2] if ($para->{$hunk->[0][1]});
        	}
            foreach my $line (@$hunk) {
                $line->[2] = "<br>".$line->[2] if ($para->{$line->[1]});
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
            $output .= qq(<$highlight{end}>&nbsp;<$highlight{$type}>$item);
            $last=$value;
        }
    }
    else {
        $output .= qq(<$highlight{$type}>$item);
        $last=$value;
    }
    return $last;
}

sub html_header {
    my ($old,$new,$opt) = @_;

    my $old_time = strftime( "%A, %B %d, %Y @ %H:%M:%S",
                            (ref $old) ? time : (stat $old)[9]
                            , 0, 0, 0, 0, 70, 0 );
    my $new_time = strftime( "%A, %B %d, %Y @ %H:%M:%S",
                            (ref $new) ? time : (stat $new)[9]
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

    my $script = ($opt->{functionality}) ? "" : qq(
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
            P{ margin:50px; border:solid; background-color:#F2F2F2; padding:5px; }
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

    my $functionality = ($opt->{functionality}) ? "" : qq(
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

        <?xml version="1.0" encoding="iso-8859-1"?>
        <!DOCTYPE html
            PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
            "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml" lang="en-US"><head>
        <title>Difference of $old, $new</title>
        $script
        $style
        </head><body>
        $header
        $functionality
        <p>
    );
}

sub html_footer { return "</p></body></html>" }

1;
__END__

=head1 NAME

Diff::Text - Visual Difference for paragraphed text.

=head1 ABSTRACT

C<Diff::Text> finds the difference between two paragraphed text files by word
rather than by line, reflows the text together, and then outputs result as xhtml.

=head1 SYNOPSIS

    use Diff::Text;
    print text_diff($old,$new);            # $old and $new are filenames
    print text_diff(\@old,\@new);          # Or pass array references
    print text_diff($old,$new,{plain=>1}); # Pass options (see below)

    # or use the premade script:
    # ./tdiff.pl oldfile newfile

=head1 DESCRIPTION

C<Diff::Text> is a reimplementation of C<diff> that is meant for paragraphed
text rather than for code.  Instead of "diffing" a document by line,
C<Diff:Text> expands a document to one word per line, uses C<Algorithm::Diff>
to find the difference, and then reflows the text back together, highlighting
the "add" and "subtract" sections.  Writers and editors might find this useful
for sending revisions to each other across the internet; a single user might
use it to keep track of personal work.  For example output, please see
diff.html in the distribution, as well as the sources for the difference,
old.txt and new.txt.

The output is in xhtml, for ease of generation, ease of access, and ease of
viewing.  C<Diff::Text> also takes advantage of two advanced features of the
median: CSS and JavaScript.

CSS is used to cut down on output size and to make the output very pleasing to
the eye.  JavaScript is used to implement additional functionality: two buttons
that can toggle the display of the difference.  CSS and JavaScript can be
turned off; see the C<plain> option below. (Note: CSS & Javascript tested with
Mozilla 1.0 and IE 5.x)

=head1 OPTIONS

Options are stored in a hashref, C<$opt>.  C<$opt> is an optional last argument
to C<text_diff>, passed like this:

    text_diff($old, $new, {plain => 1,
                           functionality => 1,
                           style => 'stylesheet_code_here',
                           header => 'header_markup_here'});

Options are:

=over 3

=item B<plain>

When set to a true value, C<plain> will cause a document to be rendered
plainly, with very sparse html that should be valid even through Netscape
Navigator 2.0.

=item B<functionality>

When set to a true value, C<functionality> will cause the JavaScript toggle
buttons to not be shown.

=item B<style>

When C<style> is set, its value will override the default stylesheet.  Please
see C<output_html_header> above for the default stylesheet specifications.


=item B<header>

When C<header> is set, its value will override the default difference header.
Please see C<output_html_header> above for more details.

=back

=head1 EXPORT

C<text_diff> is exported by default.
Additionally, C<create_diff>, C<html_header>, and C<html_footer> are optionally
exported by request (e.g. use Diff::Text qw(create_diff)).  C<create_diff> is
the actual diff itself; C<html_header> and C<html_footer> should be obvious.

=head1 BUGS

In some situations, deletion of entire paragraphs in special places might make
the surrounding line-breaks become whacky.  If you can isolate the case, please
send me a bug report, I might be able to fix it.  In the mean time, if this
happens to you, just fix the output's markup by hand, it shouldn't be too
complicated.

=head1 AUTHOR

Joseph F. Ryan (ryan.311@osu.edu)

=head1 SEE ALSO

C<Algorithm::Diff>.

=cut