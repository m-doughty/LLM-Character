#!/usr/bin/env raku

my constant $root = $?FILE.IO.cleanup.parent.parent;
use lib $root.child('lib');

use LLM::Character;

sub MAIN(Str:D $file-path) {
    my $c = LLM::Character.new;
    my $lorebook = $c.import-lorebook($file-path);

    say $lorebook;
}
