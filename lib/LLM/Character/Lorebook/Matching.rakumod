unit class LLM::Character::Lorebook::Matching;

use RegexUtils;

use LLM::Character::Lorebook::Entry;
use LLM::Character::Lorebook::Matching::Trie;
use LLM::Character::Lorebook::Matching::Regex;

has LLM::Character::Lorebook::Matching::Trie  $.case_sensitive;
has LLM::Character::Lorebook::Matching::Trie  $.case_insensitive;
has LLM::Character::Lorebook::Matching::Trie  $.case_sensitive_selective;
has LLM::Character::Lorebook::Matching::Trie  $.case_insensitive_selective;
has LLM::Character::Lorebook::Matching::Regex @.regex_entries;
has LLM::Character::Lorebook::Entry		   @.constant_entries;

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
				my @parts = $key.split("/", :skip-empty);
				my $regex = @parts[0];
				my $flags = @parts[1];
				my $rx;
				try {
					$flags = RegexUtils.get-old-perl5-flags($flags) if $flags.defined;

					$rx = $flags ?? 
						RegexUtils.CreatePerlRegex($regex, $flags) !! 
						RegexUtils.CreatePerlRegex($regex, "");
				}
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
				%this_pass{$entry.uuid} = $entry;
			}
		}

		for self.constant_entries -> $entry {
			%this_pass{$entry.uuid} = $entry;
		}

		my @new_matches = %this_pass.keys
			.grep({ %this_pass{$_}.defined })
			.grep({ %this_pass{$_}.selective ?? %this_pass_selective{$_}.defined !! True })
			.map({ %this_pass{$_} });
		last unless @new_matches.elems;

		%matched{$_.uuid} = $_ for @new_matches;

		$to_match = @new_matches.grep({ !$_.extensions<prevent_recursion> })
			.map({ $_.content }).join("\n\n");

		$pass++;
	}

	return %matched.values;
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

			%matched{$entry.uuid} = $entry;
		}
	}
}
