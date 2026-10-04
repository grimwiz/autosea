# autosea

An autoscend-style KoLmafia script for The Sea. Before every adventure it re-reads your progress and does the next useful thing, so you can stop it and restart it at any point.

**Status:** in development. Version 1 targets the Sea Monkee rescues up to Mom, plus the side quests that make the trip cheaper: the Skate Park, the sushi-rolling mat and the aerated diving helmet.

## 11,037 Leagues Under the Sea

Autosea is for the Sea in aftercore. In the 11,037 Leagues Under the Sea challenge path, the Council's quests are different: both Elder Gods, five unblemished pearls, then the Nautical Seaceress. So autosea detects the path and won't run its quest route there. Use [UnderTheSea](https://github.com/tottington/UnderTheSea/tree/lowIOTM) (`git checkout https://github.com/tottington/UnderTheSea lowIOTM`), the Ascension Speed Society's script for the path. `autosea farm` still works in the path.

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

## Dreadscroll clues you can look up

Before guessing at the Mer-kin dreadscroll, autosea fills in the clues it can look up instead:
- **Clue 4 from a Mer-kin knucklebone.** It's used up. `autosea_keepKnucklebones` keeps that many back, for example 1 for an 11,037 Leagues Under the Sea run.
- **Clue 3 from Deep Dark Visions,** if you know the skill. The phrase comes even if its damage beats you up.

With Deep Dark Visions permed and a knucklebone for each run, plus the worktea clue, a dreadscroll needs no guesses at all.

## The Mer-kin Deepcity (stage 1)

Once the seahorse is tamed, autosea starts on the Deepcity. One Temple boss is allowed per ascension, and its reward depends on your class. So `autosea_deepcityPath = auto` (the default) takes the Scholar route to Yog-Urt when you don't yet own your class's "of Hatred" piece. Stage 1 covers:

- **Mer-kin Elementary School**, only if the Scholar route needs a Scholar's Vestments piece you don't have. The facecowl and waistrope are ingredients: Grandma makes the scholar mask from a crappy Mer-kin mask plus a facecowl, and the tailpiece from a crappy tailpiece plus a waistrope. Autosea unlocks the teacher's lounge and takes them from "Raising Cane", wearing another Mer-kin disguise, and olfacts the Mer-kin monitor (the only cheatsheet carrier) while it's there (`autosea_schoolGear`, `autosea_olfactMonitor`).
- **Vocabulary:** uses a wordquiz with each cheatsheet for +10% each, up to `autosea_vocabTarget` (100). It uses any cheatsheets you already hold, and buys the rest. The School is the only other source, and they rarely drop there.
- **Worktea clue:** eats a nigiri you rolled yourself with a Mer-kin worktea in inventory, for dreadscroll clue 7. It needs 2 free fullness.

**Stage 2, the Mer-kin Library** (wearing the Scholar's Vestments, once vocabulary is done):

- adventures until the 6th encounter gives the Mer-kin dreadscroll;
- with the dreadscroll in hand, uses a Mer-kin healscroll in a fight for clue 2, and a Mer-kin killscroll for clue 5;
- answers the Catalog Card (choice 704) by reading an unread book. At 100% vocabulary only the three clue books remain, for clues 1, 6 and 8.

It stops once the dreadscroll and clues 1, 2, 5, 6 and 8 are known. Clues 3 and 4 need a darkbook skill and a rare knucklebone, so they aren't farmed. `autosea status` lists the known clues.

**Stage 3, the High Priest and Yog-Urt:**

- **Reading the dreadscroll:** once the worktea clue (7) is known, autosea fills in the known clues and guesses the rest. Each wrong read is followed by Deep-Tainted Mind, and its length shows how many phrases were wrong. Every new guess must agree with all the earlier results, so the answer is found in a few reads. Autosea farms through each Deep-Tainted Mind wait. Set `autosea_readWithoutWorktea = true` to guess clue 7 as well.
- **Yog-Urt:** for the first rounds she casts More Like a Suckrament (5 rounds with 3 prayerbeads). During it your skills are disabled, you lose 80–90% of your HP every round, and **any damage to her kills you**. So before entering, autosea:
  - removes your familiar and every damage-dealing effect;
  - refuses to start if any gear has a damage aura or thorns;
  - wears the Scholar's Vestments and 3 prayerbeads;
  - makes sure it has a different healing item for every Suckrament round (each combat item works only once in the fight);
  - tops up MP.

  In the fight it heals each Suckrament round (healscroll, band-aid, red pixel potion, poultice and so on, never anything that deals damage), then kills her with your best spell. `autosea_yogUrt = dryrun` checks everything and stops before entering; `false` skips her. After a loss it won't try again that run.

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

- **Zone:** the best sea zone that passes the survival check, re-checked every 10 adventures so it moves deeper as you level. Pearls come first. After that, for `both` (the default) and `meat`:
  - the Briniest Deepests and the Coral Corral (from level 16) are ranked by what a turn has actually brought in there, meat plus the mall value of the drops;
  - until a zone has a record, an estimate from its monsters' meat and drop tables is used instead;
  - with the Corral's sea lassos counted, it often comes out on top.

  `stats` uses the Coral Corral or the Mer-Kin Outpost. The Briny Deeps is the fallback for all three. The Brinier Deepers (trophyfish) and the Wreck (mine crabs) are never farmed.
- **Fishy:** kept up before every adventure. By default it stops rather than pay 2 adventures a turn.
- **Gear, balanced against danger:** for each zone autosea tries three gear profiles, most profitable first, and uses the first that passes the survival check:
  1. greedy: meat drop and item drop, each weighted by what it's worth in that zone, plus experience. The Mer-kin begsign is added only where meat matters more than items;
  2. balanced: the same drop weights at half strength, plus experience, HP and damage reduction;
  3. defensive (`autosea_defensiveMaximize`, default `2 hp, 6 dr, 2 moxie`).

  The drop weights come from the zone's monsters: their base meat, and what each extra 1% of item drop adds in drop value at mall prices. Every sea zone has a pressure penalty on meat and item drop (−75% in the Briniest Deepests, −100% in the Corral). Autosea tells KoLmafia which zone it's dressing for, so the maximizer counts that penalty and the "better diver" gear that offsets it (such as the aquamariner's necklace and ring). Pearl zones add the zone's resistance (up to 18) to every profile. The choice is made again every 10 adventures, so it moves back to greedy gear as you get stronger. A saved `autosea_farmOutfit` replaces all of this.
- **Familiar:** `autosea_farmFamiliar` (default Grouper Groupie, if you have it).
- **Organs left open:** farm mode doesn't fill your stomach, liver or spleen up front, so later quest steps still have room. Sushi is eaten only when Fishy runs out, and 2 fullness is held back while the worktea clue is pending. `autosea_farmFillStomach = true` fills the stomach with sushi first. `autosea_farmPrep = veracity` runs Veracity's daily setup, but only once all organs are full.
- **Mad Tea Party:** once a day, buys a DRINK ME potion (about 2,000 meat) and takes the hat buff for `autosea_teaPartyHat` (default 22, Dances with Tweedles: +40% Meat from Monsters; 0 to skip). It uses no organ space.
- **Buffs:** before each adventure, recasts meat and experience buffs from your own skills that have run out. It never uses consumables for this.
- **Mom's food:** once Mom is rescued, it takes her daily food first (`autosea_farmMomFood`, default `stats`, which gives Cereal Killer: +200 Experience for 50 turns).
- **Combat:** your own combat settings. Something that picks club or spells by cost, like SimpleSmack, works well.
- **Tracking the valuable monster:** in each farm zone, autosea works out what each monster is worth with your gear on (meat plus drops at mall prices). When one is worth clearly more than an average fight there (`autosea_trackMargin`, 1.3 times, and at least 100 meat more), it tracks that monster. It uses Transcendent Olfaction (3 a day; the trail lasts until replaced, so a leftover from your last ascension gets replaced) and Gallapagosian Mating Call if you have it. In the Coral Corral that's the sea cowboy, for sea lassos. `autosea_track = false` turns this off.
- **Dolphins:** underwater, a dolphin can snatch a drop you just missed. Only the last stolen item can be recovered. Whenever the stolen item is worth more than a dolphin whistle plus a turn in that zone (a sea lasso is; a Mer-kin thingpouch isn't), autosea uses a whistle at once and fights the thief, an easy fight on the surface. It uses whistles you own, or gets one the cheapest way (see Make or buy). Owned whistles count at their mall price (about 320). `autosea_chaseDolphins = false` turns this off.
- **Fishbreath (off by default):** the Briniest Deepests' best drops (temporary teardrop tattoo, shark cartilage, eel battery) only drop while you have Fishbreath, from bazookafish bubble gum (about 100 meat for 5 turns). It also makes every monster there flip out, with double attack and defence, which the survival check can't see. `autosea_fishbreath = true` keeps it up in the Briniest Deepests while it pays for itself. It stops for the day after a fight lost with Fishbreath.
- **Stops:** at the turn count, your adventure reserve, being Beaten Up, or running out of Fishy. It then reports meat and stats per turn.

| Setting | Default | Meaning |
| --- | --- | --- |
| `autosea_farmGoal` | `both` | `both`, `meat` or `stats` |
| `autosea_dropWeight` | 1 | Scales the meat and item drop weights (one maximizer point is about one meat a turn) |
| `autosea_track` | `true` | Olfact (and Mating Call) the farm zone's most valuable monster |
| `autosea_trackMargin` | 1.3 | How much more than an average fight a monster must be worth to track it |
| `autosea_chaseDolphins` | `true` | Whistle back stolen items worth more than a whistle and a turn |
| `autosea_fishbreath` | `false` | Keep Fishbreath up in the Briniest Deepests for its extra drops (riskier fights) |
| `autosea_fishbreathMaxPrice` | 500 | Most to pay for a bazookafish bubble gum |
| `autosea_farmPrep` | `none` | `veracity` runs Veracity's daily setup first, but only once stomach, liver and spleen are full |
| `autosea_teaPartyHat` | 22 | Mad Tea Party hat length (22 = +40% Meat from Monsters; 0 to skip) |
| `autosea_farmMaximize` | `meat, 1.5 mainstat, 0.5 hp, 2 dr` | Maximizer terms added after `sea` |
| `autosea_farmOutfit` | (none) | A saved outfit to farm in instead of maximizing, e.g. one with breathing, HP regeneration and resistances for the tougher zones. Autosea still adds familiar breathing if the outfit lacks it |
| `autosea_farmFamiliar` | Grouper Groupie | Familiar to farm with |
| `autosea_farmRequireFishy` | `true` | Stop rather than adventure without Fishy |
| `autosea_farmMomFood` | `stats` | Mom's daily food (`none` to skip) |

## Make or buy

Before buying anything, autosea compares the mall price with the in-game ways to get it:
- **NPC stores**, when one sells it to you.
- **Big Brother**, for sand dollars. Sand dollars are themselves valued make-or-buy.
- **Collecting it from sea monsters.** That costs the turns it takes (from drop rates and your item drop after the pressure penalty), times what those turns lose against your best farm zone.

The collecting zone's own meat and drops count, so **farming and collecting happen together**:
- A drop from a zone you'd farm anyway, like sea cowbells in the Corral, costs next to nothing.
- Collecting is itself a short farm session in that zone.
- Drops you already hold are used before anything is bought.

When collecting is cheaper, autosea goes and gets the item, tracking the monster that drops it. It gives up after twice the expected turns (or `autosea_collectMaxTurns`, 60) and buys instead. At typical farm earnings most cheap items are quicker to buy. Sand dollars, for example, are about 20 turns each in An Octopus's Garden, against about 300 in the mall.

| Setting | Default | Meaning |
| --- | --- | --- |
| `autosea_collect` | `true` | Collect items in-game when that's cheaper than the mall |
| `autosea_selfSufficiency` | 1 | Above 1 favours in-game sources (1.5: collect even at up to 1.5 times the mall price) |
| `autosea_collectMaxTurns` | 60 | Most turns spent collecting one batch |

### Collecting things you want for themselves

`autosea collect <item> [turns]` goes and gets an item from the sea, however it compares with the mall. Use it for skill books and collection pieces. For example, `autosea collect Mer-kin darkbook 150` gets the book that teaches Deep Dark Visions.

What it does:
- Picks the zone and monster with the best chance, and tracks that monster.
- Dresses for item drop. Where a zone needs it, the right disguise goes on first (the Scholar's Vestments for the Mer-kin Library).
- Whistles back every copy a dolphin steals.
- Stops at the turn limit, or when you run out of adventures.
- Once it has a skill book, it learns the skill (`autosea_learnSkills = false` to keep the book instead).

Dolphins matter more than item drop for rare drops in deep zones. A dolphin steals a missed drop at its base rate times the zone's pressure (1.5 times in the Library), whatever your item drop is. So chasing them roughly doubles your chances there.

`autosea collect 5 Mer-kin knucklebone` collects until you hold that many, counting your closet and Hagnk's.

`autosea_wantItems` (comma-separated item names, each optionally with `:how many`, e.g. `Mer-kin knucklebone:5`) keeps items wanted during normal farming and questing too. They count as worth `autosea_wantValue` (1,000,000) until you have one, or know the skill it teaches. That means their dropper gets tracked where it's worth it, and any a dolphin steals get chased.

### Sea skills

The sea teaches seven permable skills:
- **Six class skills, one per class,** for rescuing Grandpa: Harpoon! (Seal Clubber), Summon Leviatuga (Turtle Tamer), Tempuramancy (Pastamancer), Deep Saucery (Sauceror), Salacious Cocktailcrafting (Disco Bandit) and Donho's Bubbly Ballad (Accordion Thief).
- **Deep Dark Visions,** for any class, from the Mer-kin darkbook.

`autosea status` lists each one with its state:
- **permed:** kept across ascensions;
- **known:** you have it this life only, so perm it at Valhalla for 100 Karma or lose it when you ascend;
- **missing:** with how to get it.

`autosea collect skills [turns]` goes after the ones this character can get now: it collects the darkbook in the Library, and points you to the quest route if your class's Grandpa skill is missing. The darkbook also stays wanted while you farm, so a dolphin that steals one is always chased (`autosea_wantSeaSkills = false` to turn that off).

## Paying for buffs

Autosea pays for a buff only while **all the paid buffs running, added together, cost less per turn than a turn earns in the zone you're about to adventure in**.

- **What a turn earns:** autosea records what each adventure brings in, per zone, as a running average (`autosea_zoneValue_<zone id>`): meat plus the mall value of the items dropped, including any recovered from a dolphin (less the whistle). While a pearl is in progress, the pearl's value divided by the fights still needed is added on top. A zone with no record yet counts as `autosea_defaultTurnValue` (400).
- **What a buff costs per turn:** (meat price + turns spent getting it × what a turn earns) ÷ the turns it actually helps. Items you already own count at their mall price, since you could sell them instead.
- **The turns a buff actually helps** can be fewer than its duration:
  - Without Fishy, each sea adventure uses 2 turns, so a buff lasts half as many adventures.
  - It's capped at the adventures you have left today.
  - A pearl resistance potion only helps until the pearl drops, so it's capped at the fights still needed.
  - Any turns spent getting the buff come off its useful turns.
- **The Mad Tea Party** takes no turn, and its buff lasts 30.
- **Covered:** the lustrous oyster egg, the Tea Party, the pearl resistance potions and bazookafish bubble gum.
- **Fishy:** sea jelly counts towards the total, but it's judged against a whole turn, since Fishy saves one on every sea adventure.
- **Spending adventures:** food, drink and spleen items are bought or used only if they cost less per adventure than your last farm zone earns a turn. That's why voodoo snuff (about 2,600 a turn at mall price) stays in your inventory.

## Diet

- **Spleen right away**, since nothing waits on it, but **keeping enough for sea jelly**. Without Fishy every sea adventure costs 2 turns, so 1 spleen of jelly (10 Fishy turns) is worth more than any spleen item's adventures. Autosea keeps 1 spleen per 10 of today's adventures that the other Fishy sources (Fishy already running, the Skate Park lutz, the fishy pipe, sushi while there's stomach room) won't cover. Autosea chews spleen items you own that give adventures, best adventures per spleen first. When farming for meat it adds a lustrous oyster egg (+50% Meat Drop). When nothing you own qualifies, it buys the cheapest 4-spleen paste or similar (ectoplasmic paste, grim fairy tale, powdered gold and so on), but only if its cost per adventure is below what your last farm zone earns a turn (`autosea_buySpleen = false` to stop that). It never chews Instant Karma, and never anything worth more than `autosea_spleenMaxValue` (5,000) in the mall.
- **Food and drink only when adventures run low** (at your reserve plus `autosea_dietAt`, default 6), so your stomach and liver stay open for quest steps:
  - **Drinks first, in a batch:** up to `autosea_boozeBatch` (5) of `autosea_booze` (elemental caipiroska), with The Ode to Booze cast first if you know it and have a free song slot.
  - **Then food:** `autosea_food` (autumn-spice donut), keeping 2 fullness free while the worktea clue is pending.
  - Items come from your inventory, closet or Hagnk's first, then the mall up to `autosea_dietMaxPrice` (1,000) each.
- `autosea_diet = false` turns all of this off.

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

The same goes for steps that must wait for something to wear off or roll over (Deep-Tainted Mind before a dreadscroll re-read, or free fullness for the worktea clue): autosea says what it's waiting for and farms the turns meanwhile (`autosea_farmWhileWaiting`).


If a task claims to act three times in a row but neither your turn count nor your quest progress changes, autosea stops with a message instead of looping.

## License

[CC BY-NC-SA 4.0](LICENSE), the same as autoscend.
