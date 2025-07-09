[![Actions Status](https://github.com/m-doughty/LLM-Character/actions/workflows/linux.yml/badge.svg)](https://github.com/m-doughty/LLM-Character/actions) [![Actions Status](https://github.com/m-doughty/LLM-Character/actions/workflows/windows.yml/badge.svg)](https://github.com/m-doughty/LLM-Character/actions) [![Actions Status](https://github.com/m-doughty/LLM-Character/actions/workflows/macos.yml/badge.svg)](https://github.com/m-doughty/LLM-Character/actions)

NAME
====

LLM::Character - Implementation of Character Card v3 characters & lorebooks in Raku

SYNOPSIS
========

```raku
use LLM::Character;
use LLM::Character::Lorebook::Matching;

# Import lorebook & characters
my $c         = LLM::Character.new;
my $lorebook  = $c.import-lorebook('t/fixtures/lorebook_minimal.json');
my $character = $c.import-character('t/fixtures/character.json');
my $pngchar   = $c.import-character('t/fixtures/Assistant.png');

# Get lorebook entries which match an input
my $m       = LLM::Character::Lorebook::Matching.build-matcher($lorebook.entries);
my $input   = "foo bar baz";
my @matches = $m.match($input);
```

STATUS
------

This module aims to implement the most common functionality of the Character Card V2/V3 spec, including importing SillyTavern character cards and their embedded lorebooks.

Fast aho-corasick based lorebook matching is implemented for the following:

  * Case sensitive & case insensitive matches

  * Selective matches with secondary keys

  * Constant matches

  * Regex matches with or without valid pcre flags

  * ST-style prevent recursion, delay until recursion, and exclude recursion

Not yet implemented are decorator-based matches.

EXTERNAL API
============

LLM::Character
--------------

### .new()

Create a new instance of LLM::Character

### .import-character(Str:D $file)

Imports a character from JSON or PNG at $file (the file extension must be correct)

### .import-lorebook(Str:D $file)

Imports a stand-alone JSON lorebook in ST or CCv3 format from $file

LLM::Character::Lorebook::Matching
----------------------------------

### .build-matcher(@entries, Bool :default-cs = False)

Creates a matcher based on the entries provided.

If default-cs is True, defaults to case-sensitive matching where not specified.

### .match(Str:D $input, Int:D $recursion_depth = 99, Bool:D :$recursive_scanning = False)

Matches input against the specified entries.

If $recursive_scanning is True, will continue to match against newly matched entries up to $recursion_depth times, or until there are no more matches.

AUTHOR
======

  * Matt Doughty

COPYRIGHT AND LICENSE
=====================

Copyright 2025 Matt Doughty

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

