unit class LLM::Character::Lorebook::Entry;

has Str   $.uuid;
has Array $.keys;
has Str   $.content;
has Bool  $.case_sensitive;
has Hash  $.extensions = {};
has Bool  $.enabled;
has Int   $.insertion_order;
has Bool  $.use_regex;
has Bool  $.constant;
has Str   $.name;
has       $.id;
has Str   $.comment;
has Int   $.priority;
has Bool  $.selective;
has Array $.secondary_keys;
has Str   $.position;
has Str   @.decorators;
