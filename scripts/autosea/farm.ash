// autosea farm: meat and stat farming in The Sea, based on what worked in real aftercore farming.
//   autosea farm [turns]
// Picks the best sea zone you can survive (re-checked as you level), keeps Fishy up so every turn costs 1,
// wears breathing + meat gear, and reports meat and stats per turn at the end.

import <autosea/tasks.ash>

// zones in order of preference for each goal, with the level they need
record as_farmZone
{
	location loc;
	int minLevel;
};

// "meat", "stats" or "both" (default)
string as_farmGoal()
{
	return as_setting("farmGoal", "both");
}

as_farmZone[int] as_farmLadder()
{
	as_farmZone[int] ladder;
	void add(location loc, int minLevel)
	{
		as_farmZone z;
		z.loc = loc;
		z.minLevel = minLevel;
		ladder[count(ladder)] = z;
	}
	//pearls first (about 80,000 meat each, one per zone per day). The zone with most progress goes first,
	//so a started pearl is always finished before another is begun.
	if(as_setting("farmPearls", "true").to_boolean())
	{
		location[int] pearls;
		foreach loc in $locations[The Briniest Deepests, The Marinara Trench, Anemone Mine, Madness Reef, The Dive Bar]
		{
			if(as_pearlAvailable(loc))
			{
				pearls[count(pearls)] = loc;
			}
		}
		sort pearls by -as_pearlProgress(value);
		foreach i, loc in pearls
		{
			add(loc, 13);
		}
	}
	string goal = as_farmGoal();
	if(goal == "stats")
	{
		//best stats per turn while still earning ~200-280 meat
		add($location[The Coral Corral], 16);
		add($location[The Mer-Kin Outpost], 16);
	}
	else if(goal == "both")
	{
		//the Briniest Deepests: top meat and ~138 stats a fight; the Corral: ~218 stats with decent meat
		add($location[The Briniest Deepests], 16);
		add($location[The Coral Corral], 16);
	}
	else
	{
		//best meat per turn
		add($location[The Briniest Deepests], 16);
	}
	add($location[The Briny Deeps], 13);
	return ladder;
}

string as_farmGear();

// a saved outfit to farm in instead of maximizing, e.g. "Watery" (breathing, regen, resistances)
string as_farmOutfit()
{
	return get_property("autosea_farmOutfit");
}

// wear the farm outfit (if set) or maximize for the farm gear. Returns true if you can breathe underwater.
boolean as_farmEquip()
{
	string name = as_farmOutfit();
	if(name != "")
	{
		if(!is_wearing_outfit(name) && !outfit(name))
		{
			as_warn("Couldn't put on the outfit \"" + name + "\".");
			return false;
		}
		//the outfit may not cover breathing for your current familiar
		return as_equipForSea("");
	}
	return as_equipForSea(as_farmGear());
}

// equip for a specific zone: farm gear plus that zone's pearl resistance, then potion top-up
boolean as_farmEquipFor(location loc)
{
	boolean ok;
	if(as_farmOutfit() == "" && as_pearlAvailable(loc))
	{
		//a pearl is worth far more per fight than meat gear adds, so dress for survival and the zone's resistance
		ok = as_equipForSea(as_setting("pearlMaximize", "mainstat, moxie, 1 hp, 3 dr, 0.5 exp") + ", " + as_pearlGear(loc));
	}
	else
	{
		ok = as_farmEquip();
	}
	if(ok)
	{
		as_pearlTopUp(loc);
	}
	return ok;
}

// never farmed: trophyfish (Brinier Deepers), mine crabs (Wreck), quest zones with poor drops
string as_farmGear()
{
	string gear = as_setting("farmMaximize", "meat, 1.5 mainstat, 0.5 hp, 2 dr");
	if(as_farmGoal() != "meat" && !gear.contains_text("exp"))
	{
		gear += ", 2 exp";	//more stats per fight
	}
	//Better Diver and meat drop; the maximizer doesn't value Better Diver on its own
	foreach it in $items[aquamariner's necklace, aquamariner's ring]
	{
		if(available_amount(it) > 0 && can_equip(it))
		{
			gear += ", +equip " + it;
		}
	}
	//Mer-kin begsign: +40% Meat Drop underwater, off-hand, usually ~100 meat in the mall
	if(as_farmGoal() != "stats" && (available_amount($item[Mer-kin begsign]) > 0 || as_acquire(1, $item[Mer-kin begsign]))
		&& can_equip($item[Mer-kin begsign]))
	{
		gear += ", +equip Mer-kin begsign";
	}
	return gear;
}

void as_farmFamiliar()
{
	familiar fam = as_setting("farmFamiliar", "Grouper Groupie").to_familiar();
	if(fam != $familiar[none] && have_familiar(fam) && my_familiar() != fam)
	{
		use_familiar(fam);
	}
}

// Mom's daily food: Cereal Killer (+200 Experience, 50 turns) was behind most big stat days
void as_farmDailies()
{
	if(as_monkeeStep() >= 999 && !get_property("_momFoodReceived").to_boolean() && as_setting("farmMomFood", "stats") != "none")
	{
		cli_execute("mom " + as_setting("farmMomFood", "stats"));
	}
}

// Fill the stomach with sushi before farming: each beefy maki is 3 fullness, 7-12 adventures and 45 turns of Fishy
// (Fishy stacks), so a full stomach keeps a whole day of sea adventures at 1 turn each. Doing this first also
// means Veracity's daily setup finds the stomach full and leaves the food alone.
void as_farmDiet()
{
	if(!as_setting("farmFillStomach", "true").to_boolean() || !as_setting("eatSushi", "true").to_boolean() || !as_sushiMatInstalled())
	{
		return;
	}
	while(fullness_limit() - my_fullness() >= 2)
	{
		int before = my_fullness();
		boolean maki = fullness_limit() - my_fullness() >= 3;
		item fish = $item[beefy fish meat];
		if(!as_acquire(1, fish) || !as_acquire(1, $item[white rice]) || (maki && !as_acquire(1, $item[seaweed])))
		{
			as_warn("Couldn't get sushi ingredients; leaving " + (fullness_limit() - my_fullness()) + " fullness free.");
			return;
		}
		cli_execute("create 1 " + (maki ? "beefy maki" : "beefy nigiri"));
		if(my_fullness() == before)
		{
			as_warn("Sushi didn't get eaten; stopping the diet step.");
			return;
		}
	}
}

// Daily setup from Veracity's meat farm ("nofarm": its daily tasks, buffs and lounge raids, no farming).
// Only with stomach, liver and spleen full: otherwise its diet step tries to buy food and can loop.
void as_farmPrep()
{
	if(as_setting("farmPrep", "veracity") != "veracity" || get_property("_autosea_vmfPrep").to_boolean())
	{
		return;
	}
	if(my_fullness() < fullness_limit() || my_inebriety() < inebriety_limit() || my_spleen_use() < spleen_limit())
	{
		as_warn("Skipping Veracity's daily setup: your " + (my_fullness() < fullness_limit() ? "stomach" : my_inebriety() < inebriety_limit() ? "liver" : "spleen")
			+ " isn't full, and its diet step would try to fill it (and can loop). Autosea fills the stomach with sushi; fill liver and spleen yourself.");
		return;
	}
	as_info("Running Veracity's daily setup (VeracityMeatFarm nofarm) for its buffs.");
	set_property("_autosea_vmfPrep", "true");
	if(!cli_execute("call scripts/VeracityMeatFarm.ash nofarm"))
	{
		as_warn("Veracity's daily setup didn't complete (is VeracityMeatFarm.ash installed?). Farming without it.");
	}
}

// keep meat and experience buffs from your own skills running (never consumables). The maximizer suggests every
// useful skill independently, so respect the limits it ignores: Accordion Thief songs (3, or 4 with some gear),
// one expression at a time, and never rebind a pasta thrall.
void as_farmBuffs()
{
	string expr = as_farmGoal() == "stats" ? "exp" : as_farmGoal() == "both" ? "meat drop, 0.5 exp" : "meat drop";
	foreach i, entry in maximize(expr, 0, 0, true, false)
	{
		skill sk = entry.skill;
		if(entry.score <= 0 || sk == $skill[none] || !have_skill(sk) || entry.command == "")
		{
			continue;
		}
		if(entry.display.index_of("<font color=gray>") != -1 || my_mp() < mp_cost(sk) + 50)
		{
			continue;
		}
		if(entry.effect != $effect[none] && have_effect(entry.effect) > 0)
		{
			continue;
		}
		if(!as_skillFitsLimits(sk) || !as_boostCommandOk(entry.command))
		{
			continue;
		}
		as_debug("buff: " + entry.command);
		as_runBoost(entry.command, sk);
	}
}

// zones that turned out unsafe once actually geared and buffed this session
boolean[location] as_farmExcluded;

// turnsLeft: turns remaining in this farm session; a pearl zone is only started if its pearl fits
location as_pickFarmZone(int turnsLeft)
{
	int budget = min(turnsLeft, my_adventures() - as_advReserve());
	foreach i, z in as_farmLadder()
	{
		if(my_level() < z.minLevel || !can_adventure(z.loc) || (as_farmExcluded contains z.loc))
		{
			continue;
		}
		as_farmEquipFor(z.loc);
		if(!as_zoneIsSafe(z.loc))
		{
			continue;
		}
		//don't start a pearl that can't be finished today: the progress would be wasted at rollover
		if(as_pearlAvailable(z.loc) && as_pearlFightsLeft(z.loc) > budget)
		{
			as_info("Not enough turns for the " + z.loc + " pearl (" + as_pearlFightsLeft(z.loc)
				+ " fights at " + as_resistance(as_pearlElement(z.loc)) + " " + as_pearlElement(z.loc) + " resistance).");
			continue;
		}
		return z.loc;
	}
	return $location[none];
}

int as_totalSubstats()
{
	return my_basestat($stat[SubMuscle]) + my_basestat($stat[SubMysticality]) + my_basestat($stat[SubMoxie]);
}

void as_farm(int turns)
{
	clear(as_farmExcluded);
	int startTurns = my_turncount();
	int startMeat = my_meat();
	int startSubs = as_totalSubstats();
	boolean requireFishy = as_setting("farmRequireFishy", "true").to_boolean();

	as_farmDiet();
	as_farmPrep();
	as_farmFamiliar();
	as_farmDailies();
	location zone = $location[none];
	int sincePick = 0;

	while(my_turncount() - startTurns < turns)
	{
		//re-pick every 10 adventures (as stats rise, deeper zones open up) and as soon as a pearl is found,
		//but never walk away from a pearl in progress
		boolean pearlDone = as_pearlProperty(zone) != "" && !as_pearlAvailable(zone);
		boolean pearlInProgress = as_pearlAvailable(zone) && as_pearlProgress(zone) > 0;
		if(zone == $location[none] || pearlDone || (sincePick >= 10 && !pearlInProgress))
		{
			location next = as_pickFarmZone(turns - (my_turncount() - startTurns));
			if(next == $location[none])
			{
				as_warn("No sea zone is safe to farm with your current gear and stats.");
				break;
			}
			if(next != zone)
			{
				as_info("Farming " + next + ".");
			}
			zone = next;
			sincePick = 0;
		}
		as_farmBuffs();
		as_ensureFishy();
		if(requireFishy && !as_isFishy())
		{
			as_warn("Out of affordable Fishy; stopping rather than paying 2 adventures a turn.");
			break;
		}
		if(!as_farmEquipFor(zone))
		{
			break;
		}
		//gear is already on, so pass no extra maximizer terms (that would undo a farm outfit)
		as_lastUnsafeZone = $location[none];
		if(!as_adv(zone, ""))
		{
			if(as_lastUnsafeZone == zone)
			{
				//it passed the check when picked, but not once buffed and geared for real: try the next zone
				as_farmExcluded[zone] = true;
				zone = $location[none];
				continue;
			}
			break;
		}
		sincePick += 1;
		if(have_effect($effect[Beaten Up]) > 0)
		{
			as_warn("Beaten up in " + zone + "; stopping. Try a shallower zone or more defensive gear.");
			break;
		}
	}

	int spent = max(1, my_turncount() - startTurns);
	int meat = my_meat() - startMeat;
	int subs = as_totalSubstats() - startSubs;
	as_info("Farmed " + (my_turncount() - startTurns) + " turns: " + meat + " meat (" + (meat / spent) + "/turn), "
		+ subs + " substats (" + (subs / spent) + "/turn). Meat includes anything bought for Fishy.");
}
