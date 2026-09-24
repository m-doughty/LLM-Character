unit class LLM::Character::Lorebook::Matching;

use ECMA262Regex;

use LLM::Character::Lorebook::Entry;
use LLM::Character::Lorebook::Matching::Trie;
use LLM::Character::Lorebook::Matching::Regex;

has LLM::Character::Lorebook::Matching::Trie  $.case_sensitive;
has LLM::Character::Lorebook::Matching::Trie  $.case_insensitive;
has LLM::Character::Lorebook::Matching::Trie  $.case_sensitive_selective;
has LLM::Character::Lorebook::Matching::Trie  $.case_insensitive_selective;
has LLM::Character::Lorebook::Matching::Regex @.regex_entries;
has LLM::Character::Lorebook::Entry           @.constant_entries;

# ECMA262Regex writes each literal as a \x escape, which :i does not fold,
# so emit quoted literals instead.
my class KeyRegexActions is ECMA262Regex::ToRakuRegex {
	method pattern-character($/) {
		make "'" ~ $/.Str.trans(["\\", "'"] => ["\\\\", "\\'"]) ~ "'";
	}
}

# Lorebook regex keys are JavaScript regex literals such as /^bar/i.
# A key without the slashes is taken as the bare pattern.
sub compile-key-regex(Str $key --> Regex) {
	my ($pattern, $flags) = $key ~~ /^ '/' (.+) '/' (<[a..z]>*) $/
		?? (~$0, ~$1)
		!! ($key, '');
	my $match   = ECMA262Regex::Parser.parse($pattern, :actions(KeyRegexActions));
	return Regex without $match;
	my $adverb = $flags.contains('i') ?? ':i' !! '';
	use MONKEY-SEE-NO-EVAL;
	return (try EVAL "rx$adverb/{$match.made}/") // Regex;
}

method build-matcher(@entries, Bool :$default_cs = False) {
	my $cs_trie  = LLM::Character::Lorebook::Matching::Trie.new(
		:root(LLM::Character::Lorebook::Matching::Node.new)
	);
	my $ci_trie  = LLM::Character::Lorebook::Matching::Trie.new(
		:root(LLM::Character::Lorebook::Matching::Node.new)
	);
	my $css_trie = LLM::Character::Lorebook::Matching::Trie.new(
		:root(LLM::Character::Lorebook::Matching::Node.new)
	);
	my $cis_trie = LLM::Character::Lorebook::Matching::Trie.new(
		:root(LLM::Character::Lorebook::Matching::Node.new)
	);
	my @regex_entries;
	my @constant_entries;

	for @entries -> $e {
		next unless $e.enabled;

		if $e.constant {
			@constant_entries.push: $e;
			next;
		}

		if $e.use_regex {
			for $e.keys -> $key {
				my $rx = compile-key-regex($key);
				if $rx.defined {
					@regex_entries.push: LLM::Character::Lorebook::Matching::Regex.new(
						:regex($rx), :output($e)
					);
				}
			}
			next;
		}

		my $cs = $e.case_sensitive // $default_cs;
		for $e.keys -> $key {
			if $cs {
				$cs_trie.insert-pattern($key, $e);
			} else {
				$ci_trie.insert-pattern($key.lc, $e);
			}
		}
		if $e.selective && $e.secondary_keys.elems {
			for $e.secondary_keys -> $key {
				if $cs {
					$css_trie.insert-pattern($key, $e);
				} else {
					$cis_trie.insert-pattern($key.lc, $e);
				}
			}
		}
	}

	$cs_trie.build-failures  if $cs_trie.has-entries;
	$ci_trie.build-failures  if $ci_trie.has-entries;
	$css_trie.build-failures if $css_trie.has-entries;
	$cis_trie.build-failures if $cis_trie.has-entries;

	return LLM::Character::Lorebook::Matching.new(
		:case_sensitive($cs_trie),
		:case_insensitive($ci_trie),
		:case_sensitive_selective($css_trie),
		:case_insensitive_selective($cis_trie),
		:regex_entries(@regex_entries),
		:constant_entries(@constant_entries)
	);
}

method match(Str $haystack, Int $recursion_depth = 99, Bool :$recursive_scanning = False) {
	my %matched;
	my $to_match = $haystack;
	my $pass = 0;
	my $max_passes = $recursive_scanning ?? $recursion_depth !! 1;

	while $pass < $max_passes && $to_match.chars {
		my %this_pass;
		my %this_pass_selective;

		self!trie-match($pass, $to_match, %this_pass, self.case_sensitive.root);
		self!trie-match($pass, $to_match.lc, %this_pass, self.case_insensitive.root);
		self!trie-match($pass, $to_match, %this_pass_selective, self.case_sensitive_selective.root);
		self!trie-match($pass, $to_match.lc, %this_pass_selective, self.case_insensitive_selective.root);

		for self.regex_entries -> $rx {
			my $entry = $rx.output;
			next if $entry.extensions<delay_until_recursion> && $pass == 0;
			next if $entry.extensions<exclude_recursion> && $pass != 0;
			if $to_match ~~ $rx.regex {
				%this_pass{self!entry-key($entry)} = $entry;
			}
		}

		for self.constant_entries -> $entry {
			%this_pass{self!entry-key($entry)} = $entry;
		}

		my @new_matches = %this_pass.keys
			.grep({ %this_pass{$_}.defined })
			.grep({ %this_pass{$_}.selective ?? %this_pass_selective{$_}.defined !! True })
			.map({ %this_pass{$_} });

		last unless @new_matches.elems;

		%matched{self!entry-key($_)} = $_ for @new_matches;

		$to_match = @new_matches.grep({ !$_.extensions<prevent_recursion> })
			.map({ $_.content }).join("\n\n");

		$pass++;
	}

	return %matched.values;
}

#|( Dedup key for an entry inside the matched-hash accumulators.
	C<uuid> is normally always populated (every import path assigns
	one), but entries built directly — e.g. a consumer editing one
	in memory before persisting — may omit it. Falling back to
	object identity keeps entries lacking a C<uuid> from colliding
	with one another under the same key, while still deduping a
	single such entry against itself across recursion passes. )
method !entry-key(LLM::Character::Lorebook::Entry $entry) {
	$entry.uuid // $entry.WHICH.Str;
}

method !trie-match(Int $pass, Str $to_match, %matched, LLM::Character::Lorebook::Matching::Node $root) {
	my $node = $root;
	for $to_match.comb -> $ch {
		while $node && !$node.children{$ch}.defined && !($node === $root) {
			$node = $node.fail-node;
		}
		$node = $node.children{$ch}.defined ?? $node.children{$ch} !! $root;
		for $node.outputs -> $entry {
			next if $entry.extensions<delay_until_recursion> && $pass == 0;
			next if $entry.extensions<exclude_recursion> && $pass != 0;

			%matched{self!entry-key($entry)} = $entry;
		}
	}
}
