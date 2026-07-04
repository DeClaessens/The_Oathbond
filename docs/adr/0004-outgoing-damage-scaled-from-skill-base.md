# A skill's own base damage is scaled by the caster, not looked up from a caster stat

`scale_outgoing(base, type)` takes the skill's base damage as its seed value and multiplies in the caster's offensive modifiers for that damage type — there is no character-level "attack power" stat a skill reads from. A fresh character needs no offensive stat declared to deal correct damage, and "increased fire damage" is purely a bag of modifiers stacked on top of whatever skill is cast.

## Consequences

Any richer offensive pipeline (crits, damage packets) has to replace the body of this one function — the seam is deliberate — rather than adding a new character stat that every skill would need to read.
