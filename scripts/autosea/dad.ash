// autosea: Dad Sea Monkee, the Mer-kin Temple's third boss. He drops the Pocket Square of Loathing and an Instant Karma.
//
// The Temple gives one boss per ascension, so Dad only gets it when the Scholar route (Yog-Urt) isn't wanted. To be let
// in you wear six pieces of the Clothing of Loathing, which takes the hat slot, so you breathe with SCUBA gear instead.
// Every buff is removed as the fight starts and no items can be used in it. Dad is weak to one element each round; his
// opening text says which, and KoLmafia decodes it (the "dad" command). The right 120-MP Hobopolis spell each round wins
// by round 10, so it takes 10 casts of MP with no buffs. He hits for about a tenth of your HP every round.

import <autosea/deepcity.ash>

boolean as_dadLost = false;	//a lost or failed attempt: not again this run
boolean as_dadBlocked = false;	//not ready, and said so: don't prepare again this run

boolean[item] AS_DAD_OUTFIT = $items[Goggles of Loathing, Stick-Knife of Loathing, Scepter of Loathing, Jeans of Loathing,
	Treads of Loathing, Belt of Loathing];

// the spells KoLmafia's Dad solver suggests, one element each; the first one you know is the one it names
string[string] AS_DAD_SPELLS = {
	"hot": "Awesome Balls of Fire, Volcanometeor Showeruption",
	"cold": "Snowclone",
	"stench": "Eggsplosion",
	"spooky": "Raise Backup Dancer",
	"sleaze": "Grease Lightning",
	"physical": "Toynado, Shrap"
};

boolean as_dadDone()
{
	return get_property("autosea_dadAscension").to_int() == my_ascensions();
}

// the first problem that rules the fight out before any gear is put on, or ""
string as_dadProblem()
{
	foreach elem, spells in AS_DAD_SPELLS
	{
		boolean known = false;
		foreach i, name in spells.split_string(", ")
		{
			known = known || have_skill(name.to_skill());
		}
		if(!known)
		{
			return "no " + elem + " spell (" + spells + ")";
		}
	}
	foreach it in AS_DAD_OUTFIT
	{
		if(available_amount(it) == 0 && storage_amount(it) == 0 && closet_amount(it) == 0)
		{
			return "no " + it;
		}
	}
	//the Loathing pieces need 150 of each base stat; buffs don't count
	foreach st in $stats[Muscle, Mysticality, Moxie]
	{
		if(my_basestat(st) < 150)
		{
			return "base " + st + " " + my_basestat(st) + "/150 for the Clothing of Loathing";
		}
	}
	return "";
}

// MP needed: a Hobopolis spell every round for 10 rounds
int as_dadMPNeeded()
{
	return 10 * (120 + combat_mana_cost_modifier());
}

// Maximum MP once the fight has removed every buff: what's worn now, without the effects' share. Each part comes from
// the modifier totals with the effects' part taken out, and the result is scaled by how far that same sum is from the
// real maximum MP with the effects, so the estimate stays close even where the formula is rough.
int as_dadUnbuffedMP()
{
	float effMP = 0;
	float effPct = 0;
	float effMys = 0;
	float effMysPct = 0;
	foreach eff in my_effects()
	{
		effMP += numeric_modifier(eff, "Maximum MP");
		effPct += numeric_modifier(eff, "Maximum MP Percent");
		effMys += numeric_modifier(eff, "Mysticality");
		effMysPct += numeric_modifier(eff, "Mysticality Percent");
	}
	float base = my_basestat($stat[Mysticality]);
	float mysAll = base * (1 + numeric_modifier("Mysticality Percent") / 100) + numeric_modifier("Mysticality");
	float mysGear = base * (1 + (numeric_modifier("Mysticality Percent") - effMysPct) / 100) + numeric_modifier("Mysticality") - effMys;
	float withAll = mysAll * (1 + numeric_modifier("Maximum MP Percent") / 100) + numeric_modifier("Maximum MP");
	float withGear = mysGear * (1 + (numeric_modifier("Maximum MP Percent") - effPct) / 100) + numeric_modifier("Maximum MP") - effMP;
	if(withAll <= 0)
	{
		return 0;
	}
	return floor(withGear * my_maxmp() / withAll);
}

// Something to breathe with that leaves the outfit on: makeshift SCUBA gear (accessory) or an old SCUBA tank (back).
// With the Pocket Square of Loathing as the sixth piece, the aerated diving helmet can take the Goggles' place.
string as_dadGear()
{
	string pieces = "";
	boolean square = available_amount($item[Pocket Square of Loathing]) > 0 || as_fetch(1, $item[Pocket Square of Loathing]);
	boolean helmet = square && (available_amount($item[aerated diving helmet]) > 0 || as_fetch(1, $item[aerated diving helmet]));
	foreach it in AS_DAD_OUTFIT
	{
		if(helmet && it == $item[Goggles of Loathing])
		{
			continue;
		}
		if(!as_fetch(1, it))
		{
			return "";
		}
		pieces += ", +equip " + it;
	}
	if(helmet)
	{
		return pieces + ", +equip Pocket Square of Loathing, +equip aerated diving helmet";
	}
	foreach it in $items[makeshift SCUBA gear, old SCUBA tank]
	{
		if(as_fetch(1, it))
		{
			return pieces + ", +equip " + it;
		}
	}
	//neither owned: buy whichever is cheaper
	item scuba = mall_price($item[old SCUBA tank]) > 0 && mall_price($item[old SCUBA tank]) < mall_price($item[makeshift SCUBA gear])
		? $item[old SCUBA tank] : $item[makeshift SCUBA gear];
	if(as_acquire(1, scuba))
	{
		return pieces + ", +equip " + scuba;
	}
	return "";
}

// the round-by-round plan from KoLmafia's "dad" command, once the fight's opening text is in: "Round 3: cold (Snowclone)"
string[int] as_dadPlan;
int as_dadRound;

void as_dadReadPlan()
{
	clear(as_dadPlan);
	matcher m = create_matcher("Round (\\d+): (\\w+) \\(([^)]*)\\)", cli_execute_output("dad"));
	while(m.find())
	{
		as_dadPlan[m.group(1).to_int()] = m.group(3);
	}
}

// casts the spell for this round's weakness; once the plan runs out (or a spell can't be cast), attacks
string as_dadFilter(int round, monster enemy, string text)
{
	as_dadRound += 1;
	if(as_dadRound == 1)
	{
		as_dadReadPlan();
		int decoded = 0;
		foreach r, spell in as_dadPlan
		{
			decoded += spell != "Unknown" ? 1 : 0;
		}
		if(decoded == 0)
		{
			//without the clues every round is a guess: leave the fight to you rather than lose it
			as_warn("KoLmafia didn't decode Dad's clues (the \"dad\" command shows Unknown). Stopping in the fight for you.");
			as_dadLost = true;
			return "abort";
		}
		as_info("Dad's weaknesses decoded for " + decoded + " rounds.");
	}
	skill sk = as_dadPlan[as_dadRound].to_skill();
	if(sk == $skill[Volcanometeor Showeruption] && item_amount($item[volcanic ash]) == 0)
	{
		sk = $skill[Awesome Balls of Fire];
	}
	if(sk != $skill[none] && have_skill(sk) && my_mp() >= mp_cost(sk))
	{
		return "skill " + sk;
	}
	return "attack";
}

boolean as_dadSeaMonkee()
{
	if(as_dadLost || as_dadBlocked || as_dadDone() || !as_deepcityOpen() || as_deepcityPath() == "scholar")
	{
		return false;
	}
	string mode = as_setting("dad", "true");
	if(mode == "false")
	{
		return false;
	}
	string problem = as_dadProblem();
	if(problem != "")
	{
		as_info("Not fighting Dad Sea Monkee yet: " + problem + ".");
		as_dadBlocked = true;
		return false;
	}
	//no familiar (it would need to breathe too), and fight gear: MP above all, then spell damage and HP
	use_familiar($familiar[none]);
	string gear = as_dadGear();
	if(gear == "")
	{
		as_warn("Not fighting Dad Sea Monkee: couldn't get the six Clothing of Loathing pieces and SCUBA gear together.");
		as_dadBlocked = true;
		return false;
	}
	maximize("mp, 0.3 spell damage percent, 0.2 hp, -familiar" + gear, false);
	int mp = as_dadUnbuffedMP();
	if(mp < as_dadMPNeeded())
	{
		as_info("Not fighting Dad Sea Monkee yet: about " + mp + " maximum MP once his fight removes your buffs, and 10 spells need "
			+ as_dadMPNeeded() + ".");
		as_dadBlocked = true;
		return false;
	}
	restore_hp(my_maxhp());
	restore_mp(my_maxmp());
	if(my_mp() < as_dadMPNeeded())
	{
		as_warn("Not fighting Dad Sea Monkee: couldn't restore MP to " + as_dadMPNeeded() + " (have " + my_mp() + ").");
		as_dadBlocked = true;
		return false;
	}
	if(mode == "dryrun")
	{
		as_info("Dad Sea Monkee dry run: ready, with " + my_mp() + " MP (about " + mp + " without buffs) and " + my_maxhp()
			+ " HP. Set autosea_dad = true to fight.");
		as_dadBlocked = true;
		return false;
	}
	as_ensureFishy();
	as_info("Entering the Mer-kin Temple to face Dad Sea Monkee.");
	string choiceScript = get_property("choiceAdventureScript");
	set_property("choiceAdventureScript", "");
	as_dadRound = 0;
	int karma = available_amount($item[Instant Karma]);
	int squares = available_amount($item[Pocket Square of Loathing]);
	string page = visit_url("sea_merkin.php?action=temple");
	if(page.contains_text("The temple is empty"))
	{
		set_property("choiceAdventureScript", choiceScript);
		as_info("The Mer-kin Temple is empty: its boss is done for this ascension.");
		set_property("autosea_dadAscension", my_ascensions());
		return false;
	}
	//Temple choices 714 (Life in the Stillness), 715 (An Unguarded Door), 716 (go inside) lead into the fight; 717 after it
	for i from 1 to 4
	{
		if(handling_choice() && $ints[714, 715, 716] contains last_choice())
		{
			run_choice(1, false);	//the fight is run below with as_dadFilter, not your normal combat settings
		}
	}
	string fight = "";
	if(current_round() > 0)
	{
		fight = run_combat("as_dadFilter");
	}
	//after the win the reward comes from choice 717 (unless your choiceAdventure717 setting already took it)
	if(!handling_choice())
	{
		visit_url("choice.php");
	}
	if(handling_choice() && last_choice() == 717)
	{
		run_choice(1);
	}
	boolean won = fight.contains_text("You win the fight") || available_amount($item[Instant Karma]) > karma
		|| available_amount($item[Pocket Square of Loathing]) > squares;
	set_property("choiceAdventureScript", choiceScript);
	if(won)
	{
		set_property("autosea_dadAscension", my_ascensions());
		as_info("Dad Sea Monkee is defeated.");
		return true;
	}
	as_dadLost = true;
	as_warn("The Dad Sea Monkee fight didn't end in a win. Not trying again this run; check the CLI and session log.");
	return true;
}
