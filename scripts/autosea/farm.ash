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
	if(as_setting("farmGoal", "meat") == "stats")
	{
		//best stats per turn while still earning ~200-280 meat
		add($location[The Coral Corral], 16);
		add($location[The Mer-Kin Outpost], 16);
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

// never farmed: trophyfish (Brinier Deepers), mine crabs (Wreck), quest zones with poor drops
string as_farmGear()
{
	string gear = as_setting("farmMaximize", "meat, 1.5 mainstat, 0.5 hp, 2 dr");
	//Better Diver and meat drop; the maximizer doesn't value Better Diver on its own
	foreach it in $items[aquamariner's necklace, aquamariner's ring]
	{
		if(available_amount(it) > 0 && can_equip(it))
		{
			gear += ", +equip " + it;
		}
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

location as_pickFarmZone()
{
	foreach i, z in as_farmLadder()
	{
		if(my_level() < z.minLevel || !can_adventure(z.loc))
		{
			continue;
		}
		as_farmEquip();
		if(as_zoneIsSafe(z.loc))
		{
			return z.loc;
		}
	}
	return $location[none];
}

int as_totalSubstats()
{
	return my_basestat($stat[SubMuscle]) + my_basestat($stat[SubMysticality]) + my_basestat($stat[SubMoxie]);
}

void as_farm(int turns)
{
	int startTurns = my_turncount();
	int startMeat = my_meat();
	int startSubs = as_totalSubstats();
	boolean requireFishy = as_setting("farmRequireFishy", "true").to_boolean();

	as_farmFamiliar();
	as_farmDailies();
	location zone = $location[none];
	int sincePick = 0;

	while(my_turncount() - startTurns < turns)
	{
		//re-pick every 10 adventures: as stats rise, deeper zones open up
		if(zone == $location[none] || sincePick >= 10)
		{
			location next = as_pickFarmZone();
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
		as_ensureFishy();
		if(requireFishy && !as_isFishy())
		{
			as_warn("Out of affordable Fishy; stopping rather than paying 2 adventures a turn.");
			break;
		}
		if(!as_farmEquip())
		{
			break;
		}
		//gear is already on, so pass no extra maximizer terms (that would undo a farm outfit)
		if(!as_adv(zone, ""))
		{
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
