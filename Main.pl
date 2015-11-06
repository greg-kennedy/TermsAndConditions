#!/usr/bin/perl -w
use v5.10;
use strict;

# Copyright (c) 2015 Greg Kennedy <kennedy.greg@gmail.com>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING file for more details.
use Data::Dumper;
use File::Basename;

# Constants / rule params
my $intro = "## INTRODUCTION\nBefore using this product, please read carefully the following Terms and Conditions:\n";
my $outro = "## SIGNATURE\nBy signing below, you indicate that you have read and understood the Terms and Conditions outlined above.\n\n\n    Name: _____________________________________  Date: _____________";
my $company = "Cyberdyne Systems";

my $chain_prefix_length = 3;

# How many sentences per paragraph?
my $min_paragraph_size = 3;
my $max_paragraph_size = 10;
# How many paragraphs per section?
my $min_section_size = 5;
my $max_section_size = 8;
my $max_sentence_length = 50; # Hard cap on sentence length

# Reject section headers shorter than this
my $min_header_length=5;

# Likelihood of "special" paragraphs, higher = less common (more normaltext)
my $probability=9;

# Globals
my $total_word_count = 0;
# Internal
my %section_headers;
my %sentence_beginnings;
my %chains;

#################### HELPER FUNCTIONS
# Count words in a line
sub word_count { return scalar split(/\s+/,+shift); }

# Trim whitespace
sub trim { my $str = shift; $str =~ s/^\s+//; $str =~ s/\s+$//; return $str; }

# Tokenize a sentence and add it to the Markov chain hash
sub add_to_chains
{
  my $sentence = shift;
  my @words = split(/\s+/, $sentence);

  if (@words < $chain_prefix_length)
  {
    # Maybe it has enough characters to be aSection Header?
    if (length($sentence) < $min_header_length) { print STDERR "Cannot use sentence $sentence: too short!\n"; }
    else { $section_headers{$sentence} = 1; }
  } else {
    for (my $i = 0; $i < @words - $chain_prefix_length; $i ++)
    {
      # construct three-word prefix
      my $prefix = join(' ', @words[$i .. $i+$chain_prefix_length-1]);
      if ($i == 0) { $sentence_beginnings{$prefix} = 1; }

      # Filter silly chars from $prefix.
      $prefix =~ s/[,"-]//g;

      # last_word may contain silly chars, though.
      my $last_word = $words[$i + $chain_prefix_length];

      if (!defined $chains{$prefix}) { $chains{$prefix} = {$last_word => 1}; }
      else { $chains{$prefix}->{$last_word} = 1; }
    }
  }
}

# Return the next link in a Markovchain
sub chain_link
{
  my $prefix = shift;
  my $depth = shift;

  # Filter silly chars from $prefix.
  $prefix =~ s/[,"-]//g;

  if (defined $chains{$prefix} && $depth < $max_sentence_length)
  {
    # More are available!  Let's pick one at random.
    my @available_words = keys %{$chains{$prefix}};
    my $next_word = $available_words[int(rand(@available_words))];

    # Advance prefix
    my @next_prefix_list = ((split(/\s+/, $prefix))[1 .. $chain_prefix_length-1], $next_word);
    my $next_prefix = join(' ',@next_prefix_list);

    # Recurse
    return ' ' . $next_word . chain_link($next_prefix,$depth+1);
  } else {
    # This ends a chain, sadly
    return '.';
  }
}

################# Code begins here
# Seed RNG
say STDERR "Seed in use: " . srand();

# Seed Markov Chain from corpus folder.
{
  my %sentences;

  while (my $filename = <corpus/*.txt>) {
    # Filename is generally COMPANY_NAME, so get basename.
    my ($name,$path,$suffix) = fileparse($filename,('.txt'));
    $name = lc($name);

    # Open txt file, parse it
    open (FP, '<', $filename) or die "Cannot open file $filename: $!\n";
    while (my $line = <FP>)
    {
      # All whitespace to one space
      $line =~ s/\s+/ /g;

      # lowercase and trim
      $line = lc(trim($line));

      # Remove characters that tend to screw things up
      $line =~ s/[()]//g;
      $line =~ s/( \-)//g;
      $line =~ s/(\- )//g;

      # Try to take out letters and other one-char junk
      $line =~ s/( [^ai](?:\.)? ) //g;
      $line =~ s/(^[^ai](?:\.)? ) //g;
      $line =~ s/( [^ai](?:\.)?$) //g;

      #GPL and others like to end lists with '; and' or '; or'
      $line =~ s/(; and)$/$1;/g;
      $line =~ s/(; or)$/$1;/g;

      # Try to normalize company names to COMPANY_NAME
      $line=~ s/$name/company_name/g;

      next if ($line eq '');
      if ($line =~ m/^(.+)[.;:]$/ && word_count($line) > 1) {
        # Probably a paragraph or something else useful.
        foreach my $sentence (split/[.;:]\s+/,$1)
        {
          add_to_chains($sentence);
        }
      } else {
        # Looks like a Section header.
        if (length($line) < $min_header_length) { print STDERR "Cannot use sentence $line: too short!\n"; }
        else { $section_headers{$line} = 1; }
      }
    }
    close(FP);
  }
}

# Count available sentence beginnings.
my @headers = keys %section_headers;
my @beginnings = keys %sentence_beginnings;

# DEBUG
print STDERR Dumper(%chains);

################## READY TO PRINT NOVEL
# Title and subtitle
say '# Terms and Conditions';
say "*A Legal Thriller*\n";

# Put intro line into novel
say $intro;

# Print 50000 words
while ($total_word_count < 50000)
{
  # Add section
  my $header = $headers[int(rand(@headers))];
  $header =~ s/company_name/$company/g;

  say "## " . uc($header);
  my $section_size = $min_section_size + int(rand($max_section_size-$min_section_size));
  for my $paragraph (0 .. $section_size)
  {
    # Add paragraph
    my $paragraph_size = $min_paragraph_size + int(rand($max_paragraph_size-$min_paragraph_size));

    # Paragraph type: 0=ALLCAPS, 1=* list * type, 2+=normal
    my $paragraph_type = int(rand($probability));

    for my $sentence (0 .. $paragraph_size)
    {
      # Pick a random beginning.
      my $prefix = $beginnings[int(rand(@beginnings))];
      # Compose a sentence.
      my $output = $prefix . chain_link($prefix,0);

      # Replace company_name.
      $output =~ s/company_name/$company/g;

      # Add words
      $total_word_count += word_count($output);

      # Print sentence.  Use paragraph filter.
      if ($paragraph_type == 0) { print uc($output) , ' '; }
      elsif ($paragraph_type == 1) { if ($sentence > 0 ) { say ' * ', ucfirst($output); } else { say ucfirst($output); } }
      elsif ($paragraph_type == 2) { if ($sentence > 0 ) { say " $sentence. ", ucfirst($output); } else { say ucfirst($output); } }
      else { print ucfirst($output), ' '; }
    }
    say "\n";
  }
  say "\n";
}

# Put outro line into novel
say $outro;

# Done!
