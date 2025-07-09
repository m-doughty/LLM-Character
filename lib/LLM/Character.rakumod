unit class LLM::Character;

use Base64::Native;
use Image::PNG::Portable;

use LLM::Character::IO::Import;

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

method !detect-file-type-from-ext(Str:D $file --> Str) {
    given $file.lc {
        when /\.png$/    { 'png' }
        when /\.json$/   { 'json' }
        when /\.charx$/  { 'charx' }
        default          { 'unknown' }
    }
}
