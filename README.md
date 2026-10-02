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
autosea          run until Mom is rescued, adventures run low, or something is missing
autosea status   show progress without adventuring
```

You need to be level 11 (the Old Man won't talk to you before then), and the deeper zones expect a strong level-13+ character. Autosea equips underwater breathing for you and your familiar using KoLmafia's maximizer (`maximize sea`), so you need at least one way to breathe underwater (for example a fishbowl or a diving helmet).

## Settings

Change these with `set autosea_<name> = <value>`.

| Setting | Default | Meaning |
| --- | --- | --- |
| `autosea_advReserve` | 2 | Adventures to leave unspent (never less than 2, since sea adventures can cost 2) |
| `autosea_maximize` | `mainstat` | Extra maximizer terms added after `sea` |
| `autosea_keepRecoveryScript` | `false` | Keep your own `recoveryScript` during the run. By default autosea switches it off and uses KoLmafia's built-in recovery, then restores it when it finishes |
| `autosea_buy` | `true` | Buy from the mall what saves turns: sand dollars for Big Brother's shop, the rusty diving helmet, a skate blade, sea jelly for Fishy, and the Mom speed-up gear |
| `autosea_maxPrice` | 25000 | Most autosea will pay for any single item |
| `autosea_fishyMaxPrice` | 1000 | Most it will pay for a sea jelly (1 spleen, 10 turns of Fishy) |
| `autosea_useSpleen` | `true` | Chew sea jelly for Fishy |
| `autosea_skatePark` / `autosea_sushiMat` / `autosea_helmet` | `true` | Do these optional steps |
| `autosea_abyssPace` | `true` | With the legendary seal-clubbing club, stop the Abyss for the day once its 10 daily kills are spent (see below) |
| `autosea_debug` | `false` | Print every decision |

## Fishy

Every sea adventure costs 2 turns unless you have the Fishy effect. Before each adventure autosea tries, in order: Lutz at the Skate Park (30 turns a day, once the roller skates are driven out), the fishy pipe (10 turns a day), then a sea jelly. Buying the sand dollars it needs (about 125, roughly 37,000 meat at current prices) avoids hours of farming.

## The Abyss and the legendary seal-clubbing club

The Caliginous Abyss sometimes throws a school of many at you: 20 monsters with 20,000 HP between them. If you own the legendary seal-clubbing club, autosea wields it in the Abyss and kills each school with the club's skills: first Club 'Em Back in Time (a free kill, 5 a day), then Club 'Em Across the Battlefield (an insta-kill, 5 a day). Both count towards Mom. Every other fight uses your own combat settings.

Once both skills are used up, autosea stops for the day instead of risking a school without them, so Mom takes a few days. Set `autosea_abyssPace = false` to keep going anyway.

## Safety

If a task claims to act three times in a row but neither your turn count nor your quest progress changes, autosea stops with a message instead of looping.

## License

[CC BY-NC-SA 4.0](LICENSE), the same as autoscend.
