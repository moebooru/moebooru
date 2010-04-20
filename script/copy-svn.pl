#!/usr/bin/perl
use strict;
use warnings;

sub cwd
{
	my $pwd = `pwd`;
	chomp $pwd;
	return $pwd;
}

my $src = $ARGV[0];
my $dst = $ARGV[1];
if(! -d $src) { die "bad src: $src"; }
if(! -d $dst) { die "bad dst: $dst"; }

# get file lists
my $olddir = cwd();
chdir $src || die "bad src: $src: $!";
my @src_files = split /\n/, `find . ! -wholename '*/.svn*' `;

chdir $olddir || die "$!";
chdir $dst || die "bad dst: $dst: $!";
my @dst_files = split /\n/, `find . ! -wholename '*/.svn*' `;
chdir $olddir || die "$!";

# hash files
my %src_files_hash;
my %dst_files_hash;
foreach my $x (@src_files) { $src_files_hash{$x}=1; }
foreach my $x (@dst_files) { $dst_files_hash{$x}=1; }

# merge file lists
my @all_files;
foreach my $x (@src_files) { push @all_files, $x; }
foreach my $x (@dst_files) { push @all_files, $x if(!$src_files_hash{$x}); }

# figure out which files are added and removed
my %new_files;
foreach my $x (@src_files) { $new_files{$x}=1 if(!$dst_files_hash{$x}); }
my %removed_files;
foreach my $x (@dst_files) { $removed_files{$x}=1 if(!$src_files_hash{$x}); }

#foreach my $x (@all_files) { print $x."\n" if($new_files{$x}); }
#foreach my $x (@all_files) { print $x."\n" if($removed_files{$x}); }

# copy all files except .svn
system("svn export '$src' '$dst' --force");

chdir $dst || die "bad dst: $dst: $!";

print "adding " . keys(%new_files) . " files\n";
foreach my $x (@all_files)
{
	next if(!$new_files{$x});
	next if(! -d $x);
	system("svn add -N '$x'");
}

foreach my $x (@all_files)
{
	next if(!$new_files{$x});
	next if(-d $x);
	system("svn add -N '$x'");
}

print "removing " . keys(%new_files) . " files\n";
foreach my $x (@all_files)
{
	next if(!$removed_files{$x});
	next if(-d $x);
	system("svn rm --non-interactive '$x'");
}

foreach my $x (@all_files)
{
	next if(!$removed_files{$x});
	next if(! -d $x);
	system("svn rm --non-interactive '$x'");
}

