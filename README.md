# autosea

An autoscend-style KoLmafia script for The Sea. Before every adventure it re-reads your progress and does the next useful thing, so you can stop it and restart it at any point.

**Status:** in development. Version 1 targets the Sea Monkee rescues up to Mom, plus the side quests that make the trip cheaper: the Skate Park, the sushi-rolling mat and the aerated diving helmet.

## Install

In KoLmafia's command line:

```
git checkout https://github.com/grimwiz/autosea.git
```

Update later with `git update`.

## Use

```
autosea          do the Sea Monkee quest; once Mom is rescued, stop (set autosea_farmAfterQuest = true to carry on farming)
autosea status   show progress without adventuring
autosea farm     farm meat and stats in the best safe sea zone (autosea farm 50 for 50 turns)
```

You need to be level 11 (the Old Man won't talk to you before then), and the deeper zones expect a strong level-13+ character. Autosea equips underwater breathing for you and your familiar using KoLmafia's maximizer (`maximize sea`), so you need at least one way to breathe underwater (for example a fishbowl or a diving helmet).

## Settings

Change these with `set autosea_<name> = <value>`.

| Setting | Default | Meaning |
| --- | --- | --- |
| `autosea_advReserve` | 2 | Adventures to leave unspent (never less than 2, since sea adventures can cost 2) |
| `autosea_maximize` | `mainstat, moxie, 0.5 hp, 3 dr` | Extra maximizer terms added after `sea`. Sea monsters hit hard, so the default values survival as well as your fighting stat |
| `autosea_hpThreshold` | 0.9 | Heal to full before a fight when HP is below this fraction of maximum |
| `autosea_keepRecoveryScript` | `false` | Keep your own `recoveryScript` during the run. By default autosea switches it off and uses KoLmafia's built-in recovery, then restores it when it finishes |
| `autosea_buy` | `true` | Buy from the mall what saves turns: sand dollars for Big Brother's shop, the rusty diving helmet, a skate blade, sea jelly for Fishy, and the Mom speed-up gear |
| `autosea_maxPrice` | 25000 | Most autosea will pay for any single item |
| `autosea_fishyMaxPrice` | 1000 | Most it will pay for a sea jelly (1 spleen, 10 turns of Fishy) |
| `autosea_eatSushi` | `true` | With the sushi-rolling mat installed and 3 fullness free, buy fish meat, white rice and seaweed (about 1,250 meat) and eat a beefy maki: 7–12 adventures and 45 turns of Fishy |
| `autosea_useSpleen` | `true` | Chew sea jelly for Fishy |
| `autosea_dangerRounds` | 4 | Skip a zone when its hardest monster's expected damage per round, times this many rounds, would take 90% of your maximum HP |
| `autosea_ignoreDanger` | `false` | Enter zones even when that check says you'd likely be beaten up |
| `autosea_skatePark` / `autosea_sushiMat` | `true` | Do these optional steps |
| `autosea_helmet` | `true` | Make an aerated diving helmet only if you have no other breathing hat (a Mer-kin mask is just as good). It crafts the rusty diving helmet if you hold all the parts, otherwise buys the cheaper of the helmet or the missing parts. `force` makes one anyway (for example to trade it to Grandma); `false` never does |
| `autosea_abyssPace` | `true` | With the legendary seal-clubbing club, stop the Abyss for the day once its 10 daily kills are spent (see below) |
| `autosea_debug` | `false` | Print every decision |

## The seahorse

After Mom, autosea tames the seahorse you need to reach the Mer-kin Deepcity (`autosea_seahorse`, default on):

1. Fights in the Mer-Kin Outpost until a Mer-kin lockkey drops (from a burglar, raider or healer).
2. Hunts the "Into the Outpost" noncombat with less-combat gear. It picks the tent that matches the lockkey, then tries the first three options in turn until the Mer-kin stashbox turns up.
3. Opens the stashbox, uses the Mer-kin trailmap (Intense Currents), and asks Grandpa about the currents to open the Coral Corral.
4. Throughout, throws a sea lasso once per underwater fight until you're an expert (20 points). Sea chaps add a point per throw. The sea cowboy hat adds another, but it takes the breathing hat slot, so autosea only wears it when breathing is already covered by an active effect or non-hat breathing gear. It never buys or uses anything just for that.
5. In the Coral Corral, rings 3 sea cowbells at the wild seahorse, then lassos it. Taming costs no adventure. If the lasso isn't expert yet, it runs from the seahorse, which damage can't touch.

## The Mer-kin Deepcity (stage 1)

Once the seahorse is tamed, autosea starts on the Deepcity. One Temple boss is allowed per ascension, and its reward depends on your class. So `autosea_deepcityPath = auto` (the default) takes the Scholar route to Yog-Urt when you don't yet own your class's "of Hatred" piece. Stage 1 covers:

- **Mer-kin Elementary School**, only if the Scholar route needs a Scholar's Vestments piece you don't have. The facecowl and waistrope are ingredients: Grandma makes the scholar mask from a crappy Mer-kin mask plus a facecowl, and the tailpiece from a crappy tailpiece plus a waistrope. Autosea unlocks the teacher's lounge and takes them from "Raising Cane", wearing another Mer-kin disguise, and olfacts the Mer-kin monitor (the only cheatsheet carrier) while it's there (`autosea_schoolGear`, `autosea_olfactMonitor`).
- **Vocabulary:** uses a wordquiz with each cheatsheet for +10% each, up to `autosea_vocabTarget` (100). It uses any cheatsheets you already hold, and buys the rest. The School is the only other source, and they rarely drop there.
- **Worktea clue:** eats a nigiri you rolled yourself with a Mer-kin worktea in inventory, for dreadscroll clue 7. It needs 2 free fullness.

**Stage 2, the Mer-kin Library** (wearing the Scholar's Vestments, once vocabulary is done):

- adventures until the 6th encounter gives the Mer-kin dreadscroll;
- with the dreadscroll in hand, uses a Mer-kin healscroll in a fight for clue 2, and a Mer-kin killscroll for clue 5;
- answers the Catalog Card (choice 704) by reading an unread book. At 100% vocabulary only the three clue books remain, for clues 1, 6 and 8.

It stops once the dreadscroll and clues 1, 2, 5, 6 and 8 are known. Clues 3 and 4 need a darkbook skill and a rare knucklebone, so they aren't farmed. `autosea status` lists the known clues. Reading the dreadscroll and the Yog-Urt fight come in a later stage.

## Unblemished pearls

Five sea zones each give one unblemished pearl a day. They sell for far more in the mall than they autosell for. Each won fight adds progress depending on your resistance to the zone's element:

| Zone | Element |
| --- | --- |
| The Briniest Deepests | cold |
| The Marinara Trench | hot |
| Anemone Mine | spooky |
| Madness Reef | stench |
| The Dive Bar | sleaze |

At 18 resistance a pearl takes 10 fights instead of 30–60. Whenever autosea adventures in one of these zones and today's pearl isn't found yet, it:

1. adds that element's resistance (capped at 18) to the gear it picks;
2. tops up with potions that use no stomach, liver or spleen: pec oil and programmable turtle if you own them, then scrolls of minor invulnerability and Ancient Protector Soda from the mall, up to `autosea_pearlBuffMaxPrice` (1,000) each.

`autosea farm` visits the pearl zones first (`autosea_farmPearls`, default on), then farms as normal. Progress is lost at rollover, so a half-finished pearl is worth nothing, and the fights already put into it make each remaining fight worth more. So it:

- works on one pearl at a time, starting with the zone with the most progress, and never walks away from a pearl in progress;
- only starts a pearl zone if the fights it needs, at your resistance after gear and potions, fit in the turns you have left;
- in a pearl zone, takes an item noncombat (batter, seaode) only if the item is worth more than the next fight's share of the pearl: the pearl's value (`autosea_pearlValue`, default the mall price) divided by the fights still needed. `autosea status` shows which pearls you've found today.

## Grandpa and the Midget Clownfish

Once Grandpa is found, autosea asks any of his stories you haven't heard yet (`autosea_grandpaTopics`). These unlock monster drops that otherwise never drop, and they stay unlocked across ascensions. It never asks about the trophyfish, which adds a very dangerous boss. It also buys and hatches a Midget Clownfish, an underwater familiar, if you don't have one (`autosea_clownfish`). The 1% drop isn't worth farming.

## Farming

`autosea farm` is for aftercore. Underwater, with the same buffs, monsters drop about as much meat as the Hidden Office Building and give 2–4 times the stats, provided Fishy keeps every adventure at 1 turn.

- **Zone:** the best sea zone that passes the survival check, re-checked every 10 adventures so it moves deeper as you level. `autosea_farmGoal` picks the order: `both` (the default: the Briniest Deepests, then the Coral Corral from level 16), `meat` (the Briniest Deepests from level 16) or `stats` (the Coral Corral or Mer-Kin Outpost from level 16). The Briny Deeps is the fallback for all three. The Brinier Deepers (trophyfish) and the Wreck (mine crabs) are never farmed.
- **Fishy:** kept up before every adventure. By default it stops rather than pay 2 adventures a turn.
- **Gear, balanced against danger:** for each zone autosea tries three gear profiles, most profitable first, and uses the first that passes the survival check:
  1. greedy: meat, experience and the Mer-kin begsign;
  2. balanced: meat, experience, HP and damage reduction;
  3. defensive (`autosea_defensiveMaximize`, default `2 hp, 6 dr, 2 moxie`).

  Pearl zones add the zone's resistance (up to 18) to every profile, and your aquamariner's necklace and ring are always worn, for Better Diver. The choice is made again every 10 adventures, so it moves back to greedy gear as you get stronger. A saved `autosea_farmOutfit` replaces all of this.
- **Familiar:** `autosea_farmFamiliar` (default Grouper Groupie, if you have it).
- **Diet:** first fills your stomach with sushi: beefy maki (3 fullness, 7–12 adventures, 45 turns of Fishy each), with nigiri for the last 2 fullness. Fishy stacks, so a full stomach covers a day of farming. Ingredients are bought (about 1,250 meat a maki, mostly white rice). Set `autosea_farmFillStomach = false` to skip.
- **Daily setup:** once a day, runs Veracity's meat farm in `nofarm` mode (its daily tasks, meat buffs and clan lounge raids, without its farming loop), but only when your stomach, liver and spleen are full. Its diet step would otherwise replace the sushi, and it can loop when it can't buy food. Fill your liver and spleen yourself. Set `autosea_farmPrep = none` to skip it.
- **Buffs:** before each adventure, recasts meat and experience buffs from your own skills that have run out. It never uses consumables for this.
- **Mom's food:** once Mom is rescued, it takes her daily food first (`autosea_farmMomFood`, default `stats`, which gives Cereal Killer: +200 Experience for 50 turns).
- **Combat:** your own combat settings. Something that picks club or spells by cost, like SimpleSmack, works well.
- **Stops:** at the turn count, your adventure reserve, being Beaten Up, or running out of Fishy. It then reports meat and stats per turn.

| Setting | Default | Meaning |
| --- | --- | --- |
| `autosea_farmGoal` | `both` | `both`, `meat` or `stats` |
| `autosea_farmPrep` | `veracity` | Run Veracity's daily setup first (`none` to skip) |
| `autosea_farmMaximize` | `meat, 1.5 mainstat, 0.5 hp, 2 dr` | Maximizer terms added after `sea` |
| `autosea_farmOutfit` | (none) | A saved outfit to farm in instead of maximizing, e.g. one with breathing, HP regeneration and resistances for the tougher zones. Autosea still adds familiar breathing if the outfit lacks it |
| `autosea_farmFamiliar` | Grouper Groupie | Familiar to farm with |
| `autosea_farmRequireFishy` | `true` | Stop rather than adventure without Fishy |
| `autosea_farmMomFood` | `stats` | Mom's daily food (`none` to skip) |

## Fishy

Every sea adventure costs 2 turns unless you have the Fishy effect. Before each adventure autosea tries, in order: Lutz at the Skate Park (30 turns a day, once the roller skates are driven out), the fishy pipe (10 turns a day), sushi, then a sea jelly. Fish meat is cheaper to buy (about 100 meat) than to farm underwater. Buying the sand dollars it needs (about 125, roughly 37,000 meat at current prices) avoids hours of farming.

## The Abyss and the legendary seal-clubbing club

The Caliginous Abyss sometimes throws a school of many at you: 20 monsters with 20,000 HP between them. If you own the legendary seal-clubbing club, autosea wields it in the Abyss and kills each school with the club's skills: first Club 'Em Back in Time (a free kill, 5 a day), then Club 'Em Across the Battlefield (an insta-kill, 5 a day). Both count towards Mom. Every other fight uses your own combat settings.

Once both skills are used up, autosea stops for the day instead of risking a school without them, so Mom takes a few days. Set `autosea_abyssPace = false` to keep going anyway.

## Sea noncombats

While it runs, autosea answers sea noncombats with its own choice script (the original choice script is put back afterwards). It takes the item when the item is worth more than the turn:

| Noncombat | Zone | What autosea does |
| --- | --- | --- |
| A Vent Horizon | Marinara Trench | Takes bubbling tempura batter (~6,000 meat) if you have 200 MP, up to 3 a day |
| Barback | Dive Bar | Takes a seaode (~4,000 meat), up to 3 a day |
| There is Sauce at the Bottom of the Ocean | Marinara Trench | Takes a globe of Deep Sauce only if you already hold a Mer-kin pressureglobe |
| Heavily Invested in Pun Futures | Madness Reef | Skips: the fish-scale trades lose value at mall prices |
| Down at the Hatch | The Wreck | Opens it only to free Big Brother |
| Picking Sides | Skate Park | Sides with the ice skates |

Set `autosea_takeSeaItems = false` to always skip, or `autosea_useChoiceScript = false` to keep your own choice script.

## Safety

Before entering a zone autosea asks KoLmafia how hard each monster there would hit you with your current gear and buffs. If a typical fight could beat you up, it skips the zone and tells you why.

Before giving up on a quest zone, it retries with defensive gear. If that still isn't enough, it farms for `autosea_farmBlockTurns` (20) turns to get stronger (pearls, then meat and stats, with Mom's Cereal Killer once she's rescued), then tries the quest again. It repeats until the zone opens up or your adventures run low. Set `autosea_farmWhenBlocked = false` to stop instead.


If a task claims to act three times in a row but neither your turn count nor your quest progress changes, autosea stops with a message instead of looping.

## License

[CC BY-NC-SA 4.0](LICENSE), the same as autoscend.
