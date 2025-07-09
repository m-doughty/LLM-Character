unit class LLM::Character::Card;

use LLM::Character::Asset;
use LLM::Character::Lorebook;

has Str  $.uuid;
has Str  $.name;
has Str  $.description;
has Str  $.personality;
has Str  $.scenario;
has Str  $.first_mes;
has Str  $.mes_example;
has Str  $.creator_notes;
has Str  $.system_prompt;
has Str  $.post_history_instructions;
has Array $.tags;
has Str  $.creator;
has Str  $.character_version;
has Array $.alternate_greetings;
has Array $.group_only_greetings;
has Hash $.extensions = {};
has Str  $.nickname;
has Array $.creator_notes_multilingual;
has Array $.source;
has Int  $.creation_date;
has Int  $.modification_date;

has LLM::Character::Asset    @.assets;
has LLM::Character::Lorebook $.character_book is rw;

