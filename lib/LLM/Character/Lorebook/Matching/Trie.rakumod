unit class LLM::Character::Lorebook::Matching::Trie;
use LLM::Character::Lorebook::Matching::Node;

has LLM::Character::Lorebook::Matching::Node $.root;

method has-entries {
	self.root && self.root.children.elems > 0
}

method insert-pattern(Str $pattern, LLM::Character::Lorebook::Entry $entry) {
	my $node = self.root;
	for $pattern.comb -> $ch {
		$node = $node.children{$ch} //= LLM::Character::Lorebook::Matching::Node.new;
	}
	unless $node.outputs.grep(* === $entry) {
		$node.outputs.push: $entry;
	}
}

method build-failures {
	my $root = self.root;
	my @queue = $root.children.values;
	for @queue -> $child {
		$child.fail-node = $root;
	}

	my $i = 0;
	while $i < @queue.elems {
		my $node = @queue[$i++];
		for $node.children.kv -> $ch, $child {
			my $fail_node = $node.fail-node;
			while $fail_node && !$fail_node.children{$ch}.defined && !($fail_node === $root) {
				$fail_node = $fail_node.fail-node;
			}
			$child.fail-node = $fail_node.children{$ch}.defined ?? $fail_node.children{$ch} !! $root;

			for $child.fail-node.outputs -> $out {
				unless $child.outputs.grep(* === $out) {
					$child.outputs.push: $out;
				}
			}
			@queue.push: $child;
		}
	}
}
