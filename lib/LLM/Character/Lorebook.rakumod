unit class LLM::Character::Lorebook;
use LLM::Character::Lorebook::Entry;

has Str  $.uuid;
has Str  $.name;
has Str  $.description;
has Int  $.scan_depth;
has Int  $.token_budget;
has Bool $.recursive_scanning;
has Hash $.extensions = {};

has LLM::Character::Lorebook::Entry @.entries;
