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
autosea          do the Sea Monkee quest; once Mom is rescued, carry on farming (autosea_farmAfterQuest)
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
| `autosea_skatePark` / `autosea_sushiMat` / `autosea_helmet` | `true` | Do these optional steps |
| `autosea_abyssPace` | `true` | With the legendary seal-clubbing club, stop the Abyss for the day once its 10 daily kills are spent (see below) |
| `autosea_debug` | `false` | Print every decision |

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

- **Zone:** the best-paying sea zone that passes the survival check, re-checked every 10 adventures so it moves deeper as you level. For meat (the default) that's the Briniest Deepests from level 16, otherwise the Briny Deeps. With `autosea_farmGoal = stats` it's the Coral Corral or Mer-Kin Outpost from level 16, otherwise the Briny Deeps. The Brinier Deepers (trophyfish) and the Wreck (mine crabs) are never farmed.
- **Fishy:** kept up before every adventure. By default it stops rather than pay 2 adventures a turn.
- **Gear:** `sea` plus `autosea_farmMaximize` (default `meat, 1.5 mainstat, 0.5 hp, 2 dr`), and the aquamariner's necklace and ring if you own them, for Better Diver.
- **Familiar:** `autosea_farmFamiliar` (default Grouper Groupie, if you have it).
- **Mom's food:** once Mom is rescued, it takes her daily food first (`autosea_farmMomFood`, default `stats`, which gives Cereal Killer: +200 Experience for 50 turns).
- **Combat:** your own combat settings. Something that picks club or spells by cost, like SimpleSmack, works well.
- **Stops:** at the turn count, your adventure reserve, being Beaten Up, or running out of Fishy. It then reports meat and stats per turn.

| Setting | Default | Meaning |
| --- | --- | --- |
| `autosea_farmGoal` | `meat` | `meat` or `stats` |
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


If a task claims to act three times in a row but neither your turn count nor your quest progress changes, autosea stops with a message instead of looping.

## License

[CC BY-NC-SA 4.0](LICENSE), the same as autoscend.
