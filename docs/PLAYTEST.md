# Playtest checklist (about 30 minutes)

Everything here works in automated tests. What the tests can't tell us is whether it **feels**
right, **looks** right in the full renderer, or **sounds** right. These are the numbers and
choices that were guessed and need your verdict. Go in order; skip anything you run out of
time for.

**Setup:** open `godot/` in Godot 4.3, press **F5** (starts at the title screen). Or download
a build from the latest CI run on `main` (Actions → CI → Artifacts). Turn on **Settings →
Graphics → Show FPS** first. If you have a gamepad, keep it nearby for section 7.

At the end, copy the **feedback block** at the bottom into a message, fill in what you
noticed, and send it back. Short answers are fine ("too easy", "parry window feels tight").

---

## 1. Title, creation, first look (3 min)

- [ ] Title screen: does the slow orbit over the stone circle look OK? Any stutter?
- [ ] New Game → make any character (try **Soldier** for the shield, or **Scholar** for spells).
      Each background now starts in its own spot with a short intro card. Is the card readable,
      and up long enough? Do you know where to go (talk to Maren)?
- [ ] Main quest 1, **Wrong Things** (5 min): Maren → the hollow wolf east of Greyfang Hollow
      (press E on it) → Brannoc. Does the hollow wolf feel eerie or just broken?
- [ ] Main quest 2, **The Waking Stones**: after you deal with the shards, touch the crystal
      again. Can you see the thread of light running north? At night, stay near the stones
      (but not too near) for a minute: one wisp should drift into the crystal and streak away.
- [ ] Main quest 3, **Ask the Forest**: follow the line north to the trees and the outlaw camp.
      Is the camp easy to find? Is Mirela's choice (bandits or a garrison crate) clear?
- [ ] Main quest 4, **The Barrow**: after the Guardian, can you find the way on from the vault
      without help (look at the floor)? Free the wisp or take its essence: does either feel
      like a real choice?
- [ ] **Corruption**: take the caged wisp's light, or swallow a few Wisp Essences (each says
      "Corruption +10"). Do you notice the HUD line and the messages? Is the trade (stronger
      spells, slower healing) worth taking? Once the shrine is rekindled, keep a vigil there at
      night: is one tier a night too slow? At Hollowing, the ending changes.
- [ ] Side quests (pick one or two): **Silent Shrine** (the roadside shrine south of spawn),
      **The Lost Wagon** (a yellow wagon north-east of the bandit camp), **Licence to Burn**
      (ask Brannoc for work), **Readings Under the Wanderer** (Magister Aurel at the
      waystation). Were they easy to find? Too long, too short?
- [ ] Main quest 5, **What They Made**: go to the Hollow Oak by day first (it should tell you to
      come back at night), then at night. The First: are the leaking rings readable? How many
      tries did it take (the bot tuning aims for "hard but fair": a careful player wins with
      a third or more of their Health left)? After it
      dies, can you see its light streaming north? Does the ending land?
- [ ] First view of the level: note the **FPS** in the corner, on **High**.
- [ ] The compass at the top: can you tell where the wolves quest points once Maren gives it?
      Press **M**: is the map readable?
- [ ] Is it too dark / too bright / washed out? (Screenshots so far were all from the simpler
      renderer; this is the first look in the real one.)

## 2. Sound (2 min, with headphones if you can)

Every sound is a synthesised placeholder, and nobody has listened to them yet.

- [ ] Walk on grass, then onto the stone block (a few metres north-east of spawn): do steps sound like steps?
- [ ] Stand still for 20 s: is the wind/bird bed pleasant, annoying, or too loud?
- [ ] Walk up to the campfire at the waystation: crackle OK?
- [ ] Rate the worst sound you hear today, so it gets replaced first.

## 3. Melee feel (5 min) — the wolves, north-east of spawn

- [ ] Light attacks: do swings feel weighty or floaty? Is the windup too slow?
- [ ] Hold for a heavy: is the charge time OK?
- [ ] **Parry** (right-click just as a bite lands, when its eyes flare): too easy, about right,
      or too tight? (Window: 0.2 s.)
- [ ] Dodge (Alt): does it get you out of a bite? Too long / too short?
- [ ] The pack of three: fair, too easy, or overwhelming at the start?

## 4. The bandit camp (4 min) — south-west of the stone circle

- [ ] One bandit at a time attacks: does it feel like a duel or like they're waiting their turn?
- [ ] Do you notice them blocking and parrying you? Readable or frustrating?

## 5. Magic (3 min)

- [ ] Flames on a wolf, then a **Firebolt** (hold to charge, release): satisfying?
- [ ] Dual-cast (both buttons with nothing in the right hand): does it feel worth the Magicka?
- [ ] Night (rest at a fire until 21:00, or wait): **wisps** at the stone circle. Can you read
      their charge-up and parry a bolt back at them?

## 6. The dungeon (8 min) — the wooden door in a stone mound, about 35 m south-west of spawn

- [ ] Corridor 1: did you **spot the pressure plates** before stepping on one? Try disarming one (E).
- [ ] Corridor 2: the swinging blades — fun to time, or annoying? Too fast?
- [ ] Lever room: the riddle on the east wall — solvable without reading DUNGEONS.md?
- [ ] **Stone Guardian:** can you read the slam (arms up) vs the sweep (arm out)?
  - [ ] How many tries did it take? (Target: a first-time player should usually win in 1–3.)
  - [ ] Did the 1.5x hit after a slam feel like a reward you noticed?
  - [ ] Phase 2 shockwaves: did you realise you had to jump?
  - [ ] Is the arena **lit well enough** to see its arms?
- [ ] Vault chest and the way out work?

## 7. Gamepad (3 min, if you have one)

- [ ] Stick look speed: too slow / OK / too fast?
- [ ] Menus with the D-pad (pause, Tab menu, a conversation): anything you couldn't reach?
- [ ] Try **Settings → Accessibility → Toggle sprint / Toggle block**: better or worse than holding?
- [ ] Any button that felt wrong where it is? (Rebind it in Settings → Controls, then tell me
      the new layout.)

## 8. Performance (4 min)

- [ ] Back on the title screen: **Settings → Graphics → Run benchmark** (about 3 minutes, hands
      off). It copies a results table to the clipboard: paste it into the feedback block.
- [ ] While you played: did anything stutter? Where?
- [ ] Switch to **Low** for a minute: does it still look acceptable?

---

## Feedback block (copy, fill in, send back)

```
Benchmark results: (paste the table)
Stutter anywhere?:

Look (dark/bright/OK):
Opening card / Wrong Things (clear? eerie? too short?):
Main quests 2-5 (which was best? which dragged?):
Side quests tried (and how they felt):
Compass / map (useful? cluttered?):
Worst sound:
Melee feel (floaty/weighty, windup, heavy charge):
Parry window (easy / right / tight):
Dodge:
Wolf pack (easy / fair / too hard):
Bandits:
Magic:
Wisps:
Plates spotted? Blades fun? Riddle solved without help?
Guardian tries to win: ___   The First tries to win: ___   Slam/sweep readable? ___   Noticed shockwaves needed jumping? ___
Gamepad (look speed, menus, layout):
Anything broken:
Anything that made you smile:
```
