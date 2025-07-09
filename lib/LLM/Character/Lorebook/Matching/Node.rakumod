unit class LLM::Character::Lorebook::Matching::Node;

use LLM::Character::Lorebook::Entry;

has LLM::Character::Lorebook::Matching::Node %.children  is rw;
has LLM::Character::Lorebook::Matching::Node $.fail-node is rw;
has LLM::Character::Lorebook::Entry          @.outputs   is rw;
