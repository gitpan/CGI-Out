
# Copyright (c) 1996, David Muir Sharnoff

package CGI::Out;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(out outf croak carp confess savequery);
@EXPORT_OK = qw(carpot);

use strict;

my $out;
my $error = 0;
my @saveA;
my $pwd;
my $zero;
my %e;
my $query;

use Cwd;

BEGIN	{
	require Carp;
	require CGI::Carp;

	*warn = \&{CGI::Carp::warn};
	*carpout = \&{CGI::Carp::carpout};
	$main::SIG{'__DIE__'}='CGI::Out::fakedie';

	$out = '';
	@saveA = @ARGV;
	$pwd = getcwd();
	$zero = $0;
	%e = %ENV;

	# idiom.com specific feature:
	$pwd = "$Chroot::has_chrooted$pwd" 
		if defined $Chroot::has_chrooted;
}

sub savequery
{
	($query) = (@_);
}

sub out	
{
	$out .= join('',@_);
}	

sub outf
{
	$out .= sprintf(@_);
}

sub error
{
	my (@bomb) = @_;
	$error = 1;
	my $pe = $@;
	my $se = $!;

	my $cout = $out;
	$cout =~ s/\</&lt;/g;
	$cout =~ s/\>/&gt;/g;

	print <<"";
Content-type: text/html
\n
		<html>
		<head>
		<title>Error!</title>
		</head>
		<body>
		The dynamic web page that you just tried to
		access has failed.  The exact error that it 
		failed with was:
		<xmp>
		@bomb
		</xmp>
		In addition the following may be of interest:
		<xmp>
		\$\@ = $pe
		\$! = $se
		</xmp>
		There is no need to report this error because 
		email has been sent about this problem already.
		<p>
		Had this CGI run completion, the following 
		would have been output (collected so far):
		<ul>
		<pre><tt>
$cout
		</tt></pre>
		</ul>


	require Net::SMTP;
	my $smtp = Net::SMTP->new('localhost');

	use vars qw($mailto);
	$mailto = getpwuid($<)
		unless $mailto;
	$smtp->mail($mailto);
	$smtp->to($mailto);
	$smtp->data();
	$smtp->datasend(<<"");
To: $mailto
From: $mailto
Subject: Perl script $0 bombed
\n
Perl script $0 bombed.
\n
Bomb code:
@bomb
\n
\$\@ = $pe
\$! = $se
\n

	my $qs = '';
	if (defined $query) {
		if ($e{'REQUEST_METHOD'} =~ /^P/) {
			$qs = $query->query_string();
		}
	}

	my $e ='';
	for (keys %e) {
		my $x = $_;
		my $y = $e{$x};
		$x =~ s/'/'"'"'/g;
		$y =~ s/'/'"'"'/g;
		$e .= "\\\n\t'$x'='$y'";
	}
	for ($qs, @saveA, $zero, $pwd) {
		s/'/'"'"'/g;
	}
	my $ne;

	my $x = <<"";
Repeat with:
\n
/bin/sh <<'END'
#!/bin/sh
cd '$pwd'
echo '$qs' | env - $e $zero @saveA 
exit $?
'END'
\n



	$smtp->datasend($x);
	$smtp->datasend("\n\noutput so far:\n$out\n");
	$smtp->dataend();
	$smtp->quit();
	print "<xmp>$x</xmp></body></html>\n";
}

sub croak
{
	error Carp::shortmess @_;
	CGI::Carp::die(Carp::shortmess @_);
}

sub confess
{	
	error Carp::longmess @_;
	CGI::Carp::die(Carp::longmess @_);
}

sub fakedie
{
	delete $main::SIG{'__DIE__'};
	exit(1) if $error;
	error Carp::shortmess @_;
	goto &CGI::Carp::die;
}

END	{
	print $out unless $error;
}

1;

__END__

=head1 NAME

CGI::Out - buffer output when building CGI programs

=head1 SYNOPSIS

	use CGI;
	use CGI::Out;

	$query = new CGI;
	savequery $query;		# to reconstruct input

	$CGI::Out::mailto = 'fred';	# override default of $<

	out $query->header();
	out $query->start_html(
		-title=>'A test',
		-author=>'muir@idiom.com');

	outf "%3d", 19;			# out sprintf

	croak "We're outta here!";
	confess "It was my fault: $!";
	carp "It was your fault!";
	warn "I'm confused";
	die  "I'm dying.\n";

	use CGI::Out qw(carpout);
	carpout(\*LOG);

=head1 DESCRIPTION

This is a helper routine for building CGI programs.  It buffers
stdout until you're completed building your output.  If you should
get an error before you are finished, then it will display a nice
error message (in HTML), log the error, and send email about the
problem.

It wraps all of the functions provided by CGI::Carp and Carp.  Do
not "use" them directly, instead just "use CGI::Out".

Instead of print, use C<out>.  Instead of printf, out C<outf>.

=head1 AUTHOR

David Muir Sharnoff <muir@idiom.com>

=head1 SEE ALSO

Carp, CGI::Carp, CGI

=head1 BUGS

No support for C<format>s is provided by CGI::Out.

