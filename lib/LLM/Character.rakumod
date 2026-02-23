unit class LLM::Character;

use Base64::Native;
use Image::PNG::Portable;

use LLM::Character::IO::Import;
use LLM::Character::IO::Export;

method import-character(Str:D $file --> LLM::Character::Card) {
	fail "Character file does not exist: $file" unless $file.IO.e;
	my $format = self!detect-file-type-from-ext($file);
	fail "Character file must be one of: .json/.png/.charx" if $format eq 'unknown';

	given $format {
		when 'json' { 
			return import-character-json(slurp $file);
		}
		when 'png' {
			my $img = Image::PNG::Portable.new;
			$img.read($file, True);
			my $data = $img.get-text-meta('ccv3') // $img.get-text-meta('chara');
			fail "Image $file does not appear to contain character metadata" unless $data.defined;

			my $decoded = base64-decode($data).decode;
			return import-character-json($decoded);
		}
		default {
			fail "Import mechanism for $format not implemented yet.";
		}
	}
}

method import-lorebook(Str:D $file --> LLM::Character::Lorebook) {
	fail "Lorebook file does not exist: $file" unless $file.IO.e;

	import-lorebook-json(slurp $file);
}

method export-character(LLM::Character::Card:D $card, Str:D $file) {
	my $format = self!detect-file-type-from-ext($file);
	given $format {
		when 'json' {
			spurt $file, export-character-json($card);
		}
		when 'png' {
			fail "PNG export requires export-character-to-png with a source image";
		}
		default {
			fail "Export to $format not supported";
		}
	}
}

method export-character-to-png(LLM::Character::Card:D $card, Str:D $source-png, Str:D $output-png) {
	export-character-png($card, $source-png, $output-png);
}

method export-lorebook(LLM::Character::Lorebook:D $lorebook, Str:D $file, Str :$format = 'ccv3') {
	my $json = $format eq 'st'
		?? export-lorebook-st-json($lorebook)
		!! export-lorebook-json($lorebook);
	spurt $file, $json;
}

method !detect-file-type-from-ext(Str:D $file --> Str) {
	given $file.lc {
		when /\.png$/   { 'png' }
		when /\.json$/  { 'json' }
		when /\.charx$/ { 'charx' }
		default         { 'unknown' }
	}
}
