---
name: arpg-pivot
overview: >-
  Pivot OG English Learning from a standalone word puzzle into a top-down 2D
  ARPG where monsters are defeated by Orton-Gillingham word mini-games and loot
  builds the village.
createdAt: '2026-09-24T16:22:23.201Z'
todos:
  - id: m1-word-combat-loop
    content: >-
      Milestone 1: expand the world with a wild area, place wandering monsters,
      and add the Word Build mini-game that defeats a monster and pays gold plus
      a resource.
    status: pending
  - id: m2-minigame-arcade
    content: >-
      Milestone 2: add the rest of the OG mini-games (Elkonin boxes, word chain,
      syllable sort, which-spelling) and give each monster type one.
    status: pending
  - id: m3-resources-inventory
    content: >-
      Milestone 3: gatherable resource nodes in the wild, pickups, and an
      inventory panel.
    status: pending
  - id: m4-weapons-gear
    content: >-
      Milestone 4: weapons, armor, player hearts, and monster HP/damage so gear
      changes a fight.
    status: pending
  - id: m5-village-building
    content: >-
      Milestone 5: spend resources to build and upgrade village buildings, each
      unlocking a mini-game or word tier.
    status: pending
  - id: m6-campaign
    content: >-
      Milestone 6: OG scope-and-sequence progression, biomes by syllable type,
      XP and levels, and boss encounters.
    status: pending
---
# Pivot: OG ARPG (word-combat)

## Direction
Top-down 2D ARPG. Walk out of the village into the wild, meet monsters, and defeat each monster by completing an Orton-Gillingham word mini-game. Defeated monsters drop gold and resources. Spend those resources to build and upgrade the village.

Core rule: combat is assessment. You never kill a monster by clicking fast - each correctly completed word is one hit.

## OG foundation (researched)
Orton-Gillingham is explicit, systematic, cumulative and multisensory (visual + auditory + kinesthetic + tactile). Content follows a fixed scope and sequence and every new pattern builds on mastered ones. This is what makes the learning content defensible instead of generic.

Scope and sequence used to tier word difficulty:
1. CVC closed syllables, short vowels
2. Consonant digraphs (sh, ch, th, ck)
3. Blends (st, fl, cr, dr, fr, gr, tr, sw, ...)
4. VCe / magic e
5. Vowel teams
6. R-controlled
7. Consonant-le

Syllable types, taught in this order: Closed, Open, Magic e, Vowel Team, R-controlled, Consonant-le.

## Mini-game set (OG skill -> game)
- Encoding with letter tiles -> "Word Build": tap grapheme tiles in order to spell the word from its sounds. (Milestone 1)
- Phonemic awareness / segmenting -> "Elkonin Boxes": one chip per sound, dragged into boxes.
- Blending -> "Sound Slide": phonemes appear one at a time, blended into a word.
- Phoneme manipulation -> "Word Chain": change one sound at a time (cat -> hat -> hit).
- Syllable types -> "Syllable Sort": send each word into its syllable-type house.
- Spelling rule choice -> "Which Spelling?": choose c / k / ck for a final /k/.
- Decoding fluency -> "Real or Nonsense?": rapid real-word vs nonsense-word calls.

Each monster type gets a mini-game, so variety comes from the bestiary rather than from reskinning one puzzle.

## Architecture notes
- One world scene: res://scenes/village.tscn (Node2D). The village sits inside it; the wild is the land around and beyond the village, reached through a gate. Single scene means no scene-switch state loss.
- Word data lives in res://scripts/og_words.gd (word, sounds, grapheme tiles, hint, pattern, level). res://scripts/word_bank.gd is the legacy 4-letter list and stays untouched.
- The player, camera and HUD already exist and are reused.
- Encounter overlays freeze the world and must always be escapable.

## Milestones
1. Wild + monster + Word Build mini-game: the core loop, "explore, meet a monster, spell to defeat it, get loot."
2. Mini-game arcade: more OG mini-games (Elkonin boxes, word chain, syllable sort, which-spelling) and a monster bestiary that pairs each monster with one.
3. Resources: gatherable nodes in the wild, pickups, and an inventory panel.
4. Weapons and gear: equipped weapons change how many words a monster takes, player hearts, monster damage.
5. Village building: spend resources to upgrade buildings; each upgrade unlocks a mini-game or a word tier.
6. Campaign: OG scope-and-sequence progression, biomes by syllable type, XP and levels, boss encounters.

## Verification
Builds are graded on saved project state: files written, main scene set, input actions bound, signals connected, no parse or script errors. Movement, feel, layout and difficulty are confirmed by the user playing, not assumed.
