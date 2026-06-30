#!/usr/bin/env perl
use strict;
use warnings;

# resolve-go-versions.pl
# Fetch latest Go patch versions from go.dev for given major.minor versions.
# Usage: resolve-go-versions.pl 1.24 1.25 1.26
# Output: 1.24.13 1.25.11 1.26.4 (one per line)

my @wanted = @ARGV;
die "Usage: $0 <major.minor> [major.minor ...]\n" unless @wanted;

my @html = `curl -sL "https://go.dev/dl/"`;
my %latest;

for my $line (@html) {
    while ($line =~ /go(\d+\.\d+)\.(\d+)\.linux-amd64\.tar\.gz/g) {
        my $minor = $1;
        my $patch = $2;
        $latest{$minor} = $patch if !defined $latest{$minor} || $patch > $latest{$minor};
    }
}

for my $v (@wanted) {
    if (defined $latest{$v}) {
        print "$v.$latest{$v}\n";
    } else {
        warn "WARNING: Go $v not found on go.dev, using as-is\n";
        print "$v\n";
    }
}
