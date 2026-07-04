# Cooldowns and modifier durations never live on Skill or SkillEffect

`Skill` and `SkillEffect` are Godot `Resource`s, which are shared instances — every character equipping the same `Skill.tres` holds a reference to the same object. Runtime state therefore lives elsewhere instead: a slot's cooldown on `AbilitySlot` (per-equip, `RefCounted`), and a modifier's remaining duration on `StatModifier` (per-application, `RefCounted`). Putting either on the Resource would make two characters sharing a skill secretly share its cooldown, or share an active buff's remaining time.
