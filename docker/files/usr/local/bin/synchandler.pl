#!/usr/bin/perl -w
use strict;
use warnings;
my $DEBUG = 0;
my $CONFIG = $ENV{"SYNCH_RCLONE_CONF"}||"/root/.config/rclone/rclone.conf";
my $TMPFILE = "/tmp/synch.$$";
my $DTMPFILE = "/tmp/synch-del.$$";
# my $ADD_DEST = "s3:nowhere/at/the/moment"; # s3:mandala-ingest-${CLASS}-inbound/${KMTYPE}-inbound/2022/$app
# my $DEL_DEST = "s3:nowhere/at/the/moment"; # s3:mandala-ingest-${CLASS}-inbound/${KMTYPE}-delete/2022/$app
my $DRYRUN = ($ENV{"SYNCH_RCLONE_DRY_RUN"} eq "false" )?"":"--dry-run"; # default is true
my $CHECKSUM = ($ENV{"SYNCH_RCLONE_USE_CHECKSUM"} eq "false" )? "":"--checksum"; # default is true
my $FLAGS = $ENV{"SYNCH_RCLONE_EXTRA_FLAGS"}||"--log-level INFO";
my @args=@ARGV;

# print STDERR `cat /root/.config/rclone/rclone.conf` if ($debug);

if ($DEBUG) {
	print STDERR "ARGS=",join(" ", @args),"\n";
}

my $DEL_DEST=pop @args;
my $ADD_DEST=pop @args;
my $WATCHDIR=pop @args;

if ($DRYRUN) {
	print STDERR "$0: Warn: DRYRUN is set to true.\n";
}

if (!$CONFIG) {
	die "Error: CONFIG environment must be set to point to an rclone.conf\n";
}

if (! -r $CONFIG) {
	die "Error: Can't read CONFIG file $CONFIG: $!\n";
}

# normal files with actual contents ending with .json
my @adds=map {  ( $_=~/\.json$/ && -f "$WATCHDIR/$_" && -s "$WATCHDIR/$_")?$_:() } @args;

# delete files that end in .ids
my @deletes=map {  ( $_=~/\.ids$/ && -f "$WATCHDIR/$_" && -s "$WATCHDIR/$_")?$_:() } @args;

my $adds=join("\n",@adds);
my $deletes=join("\n",@deletes);

print STDERR "watchdir = $WATCHDIR\n";
print STDERR "add_dest = $ADD_DEST\n";
print STDERR "del_dest = $DEL_DEST\n";

if ($DEBUG) {
	print STDERR "adds=",$adds,"\n";
	print STDERR "deletes=",$deletes,"\n";
}

if ($adds) {
	open (TMPH, ">", $TMPFILE) or die "Error: Can't open tempfile $TMPFILE: $!\n";
	print TMPH $adds,"\n";
	close TMPH or die "Error closing tempfile $TMPFILE: $!\n";

	my $ret=`rclone --config $CONFIG $DRYRUN copy $CHECKSUM --files-from $TMPFILE $FLAGS $WATCHDIR $ADD_DEST 2>&1`;
	if ($ret) {
		print "$TMPFILE:\n$ret\n";
	} else {
		print "$TMPFILE: success\n"; unlink $TMPFILE;
	};
}

# $del_dest="s3:mandala-ingest-${CLASS}-inbound/kmassets-delete/2022/$app";
if ($deletes) {
	open (DTMP, ">", $DTMPFILE) or die "Error: Can't open tempfile $DTMPFILE: $!\n";
	print DTMP $deletes,"\n";
	close DTMP or die "Error closing tempfile $DTMPFILE: $!\n";

	my $dret=`rclone --config $CONFIG $DRYRUN copy $CHECKSUM --files-from $DTMPFILE $FLAGS $WATCHDIR $DEL_DEST 2>&1`;
	if ($dret) {
		print "$DTMPFILE:\n$dret\n";
	} else {
		print "$DTMPFILE: success\n"; unlink $DTMPFILE
	};
}
