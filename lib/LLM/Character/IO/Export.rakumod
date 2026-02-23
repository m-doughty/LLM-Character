unit module LLM::Character::IO::Export;

use Base64::Native;
use Image::PNG::Portable;
use JSON::Fast;
use LLM::Character::Asset;
use LLM::Character::Card;
use LLM::Character::Lorebook;
use LLM::Character::Lorebook::Entry;

sub export-character-json(LLM::Character::Card:D $card --> Str) is export {
	my %data = _export-character-hash($card);
	my %envelope = (
		spec         => 'chara_card_v3',
		spec_version => '3.0',
		data         => %data,
	);
	to-json(%envelope, :sorted-keys);
}

sub export-character-png(LLM::Character::Card:D $card, Str:D $source-png, Str:D $output-png) is export {
	my $json = export-character-json($card);
	my $encoded = base64-encode($json.encode, :str);

	my $img = Image::PNG::Portable.new;
	$img.read($source-png);
	$img.set-text-meta('ccv3', $encoded);
	$img.set-text-meta('chara', $encoded);
	$img.write($output-png);
}

sub export-lorebook-json(LLM::Character::Lorebook:D $lorebook --> Str) is export {
	my %data = _export-lorebook-hash($lorebook);
	to-json(%data, :sorted-keys);
}

sub export-lorebook-st-json(LLM::Character::Lorebook:D $lorebook --> Str) is export {
	my %data = _export-st-lorebook-hash($lorebook);
	to-json(%data, :sorted-keys);
}

sub _export-character-hash(LLM::Character::Card:D $card --> Hash) {
	my %h = (
		name                       => $card.name,
		description                => $card.description,
		personality                => $card.personality,
		scenario                   => $card.scenario,
		first_mes                  => $card.first_mes,
		mes_example                => $card.mes_example,
		creator_notes              => $card.creator_notes,
		system_prompt              => $card.system_prompt,
		post_history_instructions  => $card.post_history_instructions,
		tags                       => $card.tags,
		creator                    => $card.creator,
		character_version          => $card.character_version,
		alternate_greetings        => $card.alternate_greetings,
		group_only_greetings       => $card.group_only_greetings,
		extensions                 => $card.extensions,
		nickname                   => $card.nickname,
		creator_notes_multilingual => $card.creator_notes_multilingual,
		source                     => $card.source,
		creation_date              => $card.creation_date,
		modification_date          => $card.modification_date,
		assets                     => $card.assets.map({ _export-asset($_) }).Array,
	);

	if $card.character_book.defined {
		%h<character_book> = _export-lorebook-hash($card.character_book);
	}

	%h;
}

sub _export-lorebook-hash(LLM::Character::Lorebook:D $lb --> Hash) is export {
	my %h = (
		name               => $lb.name,
		description        => $lb.description,
		scan_depth         => $lb.scan_depth,
		token_budget       => $lb.token_budget,
		recursive_scanning => $lb.recursive_scanning,
		extensions         => $lb.extensions,
		entries            => $lb.entries.map({ _export-entry($_) }).Array,
	);
	%h;
}

sub _export-entry(LLM::Character::Lorebook::Entry:D $e --> Hash) {
	my $content = $e.decorators.elems > 0
		?? $e.decorators.join("\n") ~ "\n" ~ $e.content
		!! $e.content;

	my %h = (
		keys            => $e.keys,
		content         => $content,
		extensions      => $e.extensions,
		enabled         => $e.enabled,
		insertion_order => $e.insertion_order,
		case_sensitive  => $e.case_sensitive,
		use_regex       => $e.use_regex,
		constant        => $e.constant,
		name            => $e.name,
		priority        => $e.priority,
		id              => $e.id,
		comment         => $e.comment,
		selective       => $e.selective,
		secondary_keys  => $e.secondary_keys,
		position        => $e.position,
	);
	%h;
}

sub _export-st-entry(LLM::Character::Lorebook::Entry:D $e --> Hash) {
	my $content = $e.decorators.elems > 0
		?? $e.decorators.join("\n") ~ "\n" ~ $e.content
		!! $e.content;

	my %h = (
		uid          => $e.id,
		key          => $e.keys,
		keysecondary => $e.secondary_keys,
		comment      => $e.comment,
		content      => $content,
		constant     => $e.constant,
		selective    => $e.selective,
		order        => $e.insertion_order,
		position     => _convert-position-to-st($e.position),
		disable      => !$e.enabled,
		use_regex    => $e.use_regex,
		name         => $e.name,
		priority     => $e.priority,
	);

	my %ext = $e.extensions;
	if %ext<prevent_recursion>.defined {
		%h<preventRecursion> = %ext<prevent_recursion>;
	}
	if %ext<delay_until_recursion>.defined {
		%h<delayUntilRecursion> = %ext<delay_until_recursion>;
	}
	if %ext<exclude_recursion>.defined {
		%h<excludeRecursion> = %ext<exclude_recursion>;
	}

	for %ext.kv -> $k, $v {
		next if $k eq 'prevent_recursion' | 'delay_until_recursion' | 'exclude_recursion';
		%h{$k} = $v;
	}

	%h;
}

sub _convert-position-to-st(Str $pos --> Int) {
	given $pos {
		when 'before_char' { 0 }
		when 'after_char'  { 1 }
		when 'before_name' { 2 }
		default            { 0 }
	}
}

sub _export-st-lorebook-hash(LLM::Character::Lorebook:D $lb --> Hash) {
	my %entries;
	for $lb.entries.kv -> $i, $entry {
		%entries{~$i} = _export-st-entry($entry);
	}

	my %h = (
		entries => %entries,
	);

	%h<name>               = $lb.name if $lb.name;
	%h<description>        = $lb.description if $lb.description;
	%h<scan_depth>         = $lb.scan_depth if $lb.scan_depth;
	%h<token_budget>       = $lb.token_budget if $lb.token_budget;
	%h<recursive_scanning> = $lb.recursive_scanning if $lb.recursive_scanning;
	%h<extensions>         = $lb.extensions if $lb.extensions.elems > 0;

	%h;
}

sub _export-asset(LLM::Character::Asset:D $a --> Hash) {
	my %h = (
		type => $a.type,
		uri  => $a.uri,
		name => $a.name,
		ext  => $a.ext,
	);
	%h;
}
