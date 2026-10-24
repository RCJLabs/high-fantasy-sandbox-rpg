# Corruption

**Decided 24 October 2026:** option A (Stain), harshness up to 4 of 5, cleansable, and
swallowing Wisp Essence corrupts. Corruption changes the ending. No Draw spell (option D)
for now. Built in `systems/corruption.gd` (autoload `Corruption`).

## How it works

A value from 0 to 100 that only corrupt acts raise and only cleansing lowers. It shows at
the bottom centre of the HUD ("Corruption: Stained") once you're Touched.

| Tier | From | Gain | Cost | Who notices |
|---|---|---|---|---|
| **Touched** | 20 | Spells +10% | Health regen ×0.75 | Zora |
| **Stained** | 50 | Spells +20%, +20 max Magicka | Health regen ×0.5; the roadside shrine won't bless you | Aurel; **The First recognises you** ("…you smell like us") |
| **Hollowing** | 80 | Spells +30%, +40 max Magicka | Health regen ×0.5, −20 max Health; −20 with the Thornwood Free (once) | Mirela turns cold; **the ending changes** |

**Sources:**
- Swallowing **Wisp Essence**: +10 each (it still gives +40 Magicka). Offering it at the
  shrine isn't swallowing it, so the Silent Shrine quest is unaffected.
- Taking the **caged wisp's light** in the barrow: +35 (Touched on its own).

So the caged wisp alone makes you Touched; it plus two essences, Stained; it plus five,
Hollowing.

**Cleansing:** once the roadside shrine is rekindled (Silent Shrine), keep a **vigil** there
at night: the night passes to dawn, and you drop one tier (Hollowing → Stained → Touched →
clean). One tier per night, so a long way down takes three nights. The tier's gains go with it.

**The ending at Hollowing:** Maren, Brannoc and Mirela each have a different last scene (they
keep their distance), the closing card adds "the light you took is still in you; it pulls
north too", and the journal's outcome for What They Made says The First knew you.

**Harshness, as built (about 4 of 5):** the costs are real (slower healing from Touched on,
less Health at Hollowing) and people react, but nothing blocks a quest: Mirela is cold at
Hollowing but still gives you everything the story needs. "Outlaws hostile on sight" from
the draft became a one-time −20 with the Thornwood Free and a cold welcome, because the
outlaws are talking NPCs, not fighters, in the demo.

**Saves:** version 11 stores it. An older save that had taken the caged wisp's light starts
at 35 (Touched).

**Not built:** the Draw spell (option D), drinking from the cult's jars, visible changes to
your hands (the first-person view has no hands yet), animals reacting.

---

# The original options (24 October 2026)

**From LORE.md (decided):** magic corrupts the user if practised corruptly, physically
(exhaustion, corruption, madness). *(Suggested, approved with the lore:)* "corrupt" means
taking what isn't yours: drawing power from another living thing instead of from yourself and
the world. That's exactly what the cult does, at scale.

**What's in the game now:** one corrupt act, taking the caged wisp's essence in the barrow
(+25 max Magicka, −15 with the outlaws, and lines from Mirela). Nothing else follows from it.

---

## First, two inconsistencies (whatever you pick)

1. **Wisp Essence is already a corrupt act we hand out freely.** Kill a wisp, swallow its
   essence, +40 Magicka. By the lore that's drawing another living thing's light. Options:
   - **(a)** A *dead* wisp's light is a remnant, free to take; only draining a *living* one is
     corrupt. Cheapest, and keeps the item as it is. *(My pick.)*
   - **(b)** Swallowing it counts as a small corrupt act.
   - **(c)** Rename it and change the description so it's clearly "what's left behind".
2. **Silent Shrine asks for "light given freely"**, and the player brings essence from a wisp
   they killed. With (a) that holds: the dead give freely. With (b) the shrine should refuse it,
   or the quest needs another source (a freed wisp giving some of its light?).

---

## The options

### A. Stain: a value with tiers (Fallout radiation / Skyrim vampirism)
A hidden number, 0–100, raised by corrupt acts, shown as three tiers with a name in the
Character menu and on the HUD's effects row.

| Tier | Gain | Cost | You notice |
|---|---|---|---|
| **Touched** (20+) | Spells +10% | Health regen −25% | A faint glow in your hands (first person) |
| **Stained** (50+) | Spells +20%, Magicka +20 | Health regen −50%; the shrine won't bless you | Animals uneasy; Aurel, Zora and Mirela comment |
| **Hollowing** (80+) | Spells +30%, Magicka +40 | Max Health −20%; outlaws hostile on sight | Your hands look like Dunya's; the ending changes (below) |

- **Sources:** taking the wisp's essence (+35), the Draw spell (D below; +2 per second of use),
  drinking from the cult's jars (+15 each, if we make them drinkable).
- **Cleansing:** at the rekindled shrine, one tier per visit, costing an offering and the
  tier's gains. Or never: it's permanent, and that's the point.
- **Cost to build:** one PR. Tiers are permanent status effects (the effect system already
  does modifiers); a small Corruption autoload holds the number and saves it.

### B. Marks: a few permanent scars, no meter
Each corrupt act leaves a **mark** (max 3), listed by name in the Character menu ("The
Wisp's Light"). Each mark: +15 max Magicka, −10 max Health, permanently. People react to
the number of marks. No cleansing.
- **Pros:** very legible, fits "choices echo", tiny to build (flags and a modifier).
- **Cons:** only 3–4 corrupt acts in the demo, so it's mostly a story device, not a system.

### C. Hunger: power that wears off (a dependency loop)
Corrupt power gives a strong buff (Magicka regen ×2, spells +25%) that fades over a day,
then flips into **Withdrawal** (Magicka regen stops) until you draw again or wait it out
(two days, or the shrine).
- **Pros:** real temptation every day; the strongest "madness" flavour.
- **Cons:** can feel like a nag; punishes players who tried it once. Needs Draw (D) to have
  anything to feed on.

### D. Draw: the corrupt spell (combines with A or C)
A spell you can learn from the cult's notes or by taking the essence: a short-range
stream like Flames that **drains a living target**: damage to them, Health and Magicka to
you. Strong (the cult's whole method), and each second of use feeds A or C.
- **Pros:** makes corruption a *gameplay* temptation in every fight, not a one-off choice;
  uses the existing spell styles (a DAMAGE_STREAM that heals you).
- **Cons:** needs balancing against Flames and Healing; one more spell to teach.

### The ending, for any of them
At the highest tier (or 2+ marks), The First **recognises you**: it pauses before the fight
("…you smell like us"), and Maren/Brannoc/Mirela's ending lines change. Small to write.

---

## My recommendation

**A + D, with Wisp Essence treated as (a).** Stain gives the full game a system that will
matter again (other cult sites, other temptations), Draw makes it a choice you face in
fights rather than once in a cellar, and the tiers turn the lore's "exhaustion, corruption,
madness" into things you feel. Keep cleansing possible but costly (the shrine), so trying it
once isn't a save-ruining mistake.

Speculation, not tested: whether players actually feel tempted depends on Draw being
genuinely good. That's a playtest question, which is another reason to build it after the
playtest rather than before.

## Questions for you

1. Which option, or which mix? (A+D, B, C+D, or something else.)
2. How harsh, 1 (a flavour cost) to 5 (it changes how you play for the rest of the game)?
3. Can it be cleansed? If so, where and at what price?
4. Wisp Essence: (a) dead wisps are fair game, (b) swallowing it is corrupt, or (c) rename it?
5. Should a heavily corrupted player get a different ending line, or The First recognising them?
6. Build it before or after your playtest? (I'd say after.)
