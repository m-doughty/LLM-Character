unit module LLM::Character::IO::Import;

use JSON::Fast;
use UUID::V4;
use LLM::Character::Asset;
use LLM::Character::Card;
use LLM::Character::Lorebook;
use LLM::Character::Lorebook::Entry;

sub import-character-json(Str:D $json --> LLM::Character::Card) is export {
	my %data = from-json $json;

	_import-character(%data);
}

sub import-lorebook-json(Str:D $json --> LLM::Character::Lorebook) is export {
	my %data = from-json $json;

	_import-lorebook(%data);
}

sub _import-character(%character --> LLM::Character::Card) {
	my $format = _detect-character-format %character;

	given $format {
		when 'enclosed' {
			return _coerce-character(%character<data>);
		}
		when 'flat' {
			return _coerce-character(%character);
		}
		default {
			fail "Unknown character format";
		}
	}
}

sub _coerce-character(%character --> LLM::Character::Card) {
	my $lorebook = _import-lorebook(%character<character_book>)
		if %character<character_book>.defined;
	my @assets = (%character<assets> // []).map: -> %a {
		_coerce-asset(%a);
	};
	my $now = DateTime.new(now).posix;

	my $character = LLM::Character::Card.new(
		uuid          => uuid-v4,
		name          => %character<name> // '',
		description   => %character<description> // '',
		personality   => %character<personality> // '',
		scenario      => %character<scenario> // '',
		first_mes     => %character<first_mes> // '',
		mes_example   => %character<mes_example> // '',
		creator_notes => %character<creator_notes> // '',
		system_prompt => %character<system_prompt> // '',
		post_history_instructions => %character<post_history_instructions> // '',
		tags          => %character<tags> // [],
		creator       => %character<creator> // '',
		character_version    => %character<character_version> // '',
		alternate_greetings  => %character<alternate_greetings> // [],
		group_only_greetings => %character<group_only_greetings> // [],
		extensions    => %character<extensions> // {},
		nickname      => %character<nickname> // '',
		creator_notes_multilingual => %character<creator_notes_multilingual> // [],
		source        => %character<source> // [],
		creation_date => %character<creation_date> // $now,
		modification_date => %character<modification_date> // $now,
		assets        => @assets,
	);
	$character.character_book = $lorebook if $lorebook.defined;

	return $character
}

sub _coerce-asset(%asset --> LLM::Character::Asset) {
	LLM::Character::Asset.new(
		type => %asset<type> // '',
		uri  => %asset<uri> // '',
		name => %asset<name> // '',
		ext  => %asset<ext> // '',
	);
}

sub _detect-character-format(%data --> Str) {
	(%data<spec> // '') eq 'chara_card_v3'
		?? 'enclosed'
		!! (%data<spec> // '') eq 'chara_card_v2'
			?? 'enclosed'
			!! 'flat';
}

sub _import-lorebook(%lorebook --> LLM::Character::Lorebook) {
	my $format = _detect-lorebook-format %lorebook;

	given $format {
		when 'enclosed' {
			return _coerce-lorebook(%lorebook<data>);
		}
		when 'flat' {
			return _coerce-lorebook(%lorebook);
		}
		when 'sillytavern' {
			return _coerce-sillytavern(%lorebook);
		}
		default {
			fail "Unknown lorebook format";
		}
	}
}

sub _detect-lorebook-format(%data --> Str) {
	(%data<spec> // '') eq 'lorebook_v3'
		?? 'enclosed'
		!! (%data<entries>.WHAT ~~ Hash)
			?? 'sillytavern'
			!! 'flat';
}

sub _coerce-lorebook(%data --> LLM::Character::Lorebook) {
	my @entries = (%data<entries> // []).map: -> %e {
		_coerce-entry(%e);
	};
	LLM::Character::Lorebook.new(
		uuid               => uuid-v4,
		name               => %data<name> // '',
		description        => %data<description> // '',
		scan_depth         => %data<scan_depth> // 0,
		token_budget       => %data<token_budget> // 0,
		recursive_scanning => %data<recursive_scanning> // False,
		extensions         => %data<extensions> // {},
		entries            => @entries,
	);
}

sub _coerce-entry(%e --> LLM::Character::Lorebook::Entry) {
	my @decorators;
	my @lines = (%e<content> // '').lines;
	my @clean = @lines.grep({ !/^'@@'/ && !/^'@@@'/ });
	@decorators = @lines.grep({ /^'@@'/ || /^'@@@'/ });

	LLM::Character::Lorebook::Entry.new(
		uuid           => uuid-v4,
		keys           => %e<keys> // [],
		secondary_keys => %e<secondary_keys> // %e<keysecondary> // [],
		case_sensitive => %e<case_sensitive> // False,
		content        => @clean.join("\n"),
		decorators     => @decorators,
		extensions     => %e<extensions> // {},
		enabled        => %e<enabled> // (!(%e<disable> // False)),
		insertion_order=> %e<insertion_order> // %e<order> // 0,
		use_regex      => %e<use_regex> // False,
		constant       => %e<constant> // False,
		name           => %e<name> // '',
		id             => %e<id> // '',
		comment        => %e<comment> // '',
		priority       => %e<priority> // 0,
		selective      => %e<selective> // False,
		position       => %e<position> // 'after_char',
	);
}

sub _coerce-st-entry(%e --> LLM::Character::Lorebook::Entry) {
	my @decorators;
	my @lines = (%e<content> // '').lines;
	my @clean = @lines.grep({ !/^'@@'/ && !/^'@@@'/ });
	@decorators = @lines.grep({ /^'@@'/ || /^'@@@'/ });

	my %known = <key keysecondary content disable order use_regex constant name id comment priority selective position preventRecursion delayUntilRecursion excludeRecursion>.
		map({ $_ => 1 }).Hash;

	my %ext = %e.grep({ !(%known{.key}:exists) }).Hash;
	%ext<prevent_recursion>     = %ext<preventRecursion>    if %ext<preventRecursion>.defined;
	%ext<delay_until_recursion> = %ext<delayUntilRecursion> if %ext<delayUntilRecursion>.defined;
	%ext<exclude_recursion>     = %ext<excludeRecursion>    if %ext<excludeRecursion>.defined;

	my $selective = %e<selective> && %e<selectiveLogic>.defined && %e<selectiveLogic> > 0;

	LLM::Character::Lorebook::Entry.new(
		uuid            => uuid-v4,
		keys            => %e<key> // [],
		secondary_keys  => %e<keysecondary> // [],
		content         => @clean.join("\n"),
		decorators      => @decorators,
		extensions      => %ext,
		enabled         => !(%e<disable> // False),
		insertion_order => %e<order> // 0,
		use_regex       => %e<use_regex> // False,
		constant        => %e<constant> // False,
		name            => %e<name> // '',
		id              => %e<uid> // %e<id>,
		comment         => %e<comment> // '',
		priority        => %e<priority> // 0,
		selective       => $selective,
		position        => _convert-st-position(%e<position>),
	);
}

sub _convert-st-position($val) {
	given $val {
		when 0 { 'before_char' }
		when 1 { 'after_char'  }
		when 2 { 'before_name' }
		default { 'before_char' }
	}
}

sub _coerce-sillytavern(%st --> LLM::Character::Lorebook) {
	my @entries = %st<entries>.keys.sort.map: -> $k {
		_coerce-st-entry(%st<entries>{$k});
	};
	LLM::Character::Lorebook.new(
		uuid               => uuid-v4,
		name               => %st<name> // '',
		description        => %st<description> // '',
		scan_depth         => %st<scan_depth> // 0,
		token_budget       => %st<token_budget> // 0,
		recursive_scanning => %st<recursive_scanning> // False,
		extensions         => %st<extensions> // {},
		entries            => @entries,
	);
}

