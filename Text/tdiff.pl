#!/usr/bin/perl -w
use strict;
use Diff::Text;

print text_diff($ARGV[0],$ARGV[1],{plain=>1});
