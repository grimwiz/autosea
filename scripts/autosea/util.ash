// autosea utilities: logging, settings, preference save/restore, the adventure wrapper.

// ---------------------------------------------------------------- logging

void as_info(string msg)
{
	print("[autosea] " + msg, "blue");
}

void as_warn(string msg)
{
	print("[autosea] " + msg, "red");
}

void as_debug(string msg)
{
	if(get_property("autosea_debug").to_boolean())
	{
		print("[autosea debug] " + msg, "gray");
	}
}

// ---------------------------------------------------------------- settings
// All settings are ordinary KoLmafia properties, changed with "set autosea_<name> = <value>".

string as_setting(string name, string fallback)
{
	string value = get_property("autosea_" + name);
	return value == "" ? fallback : value;
}

int as_advReserve()
{
	//adventures to leave unspent. Sea adventures cost 2 without Fishy, so never go below 2.
	return max(2, as_setting("advReserve", "2").to_int());
}

string as_maximizeExtra()
{
	//extra maximizer terms. "sea" is always added. Sea monsters hit hard, so the default also values
	//Moxie (dodging), HP and damage reduction, not just the stat you fight with.
	return as_setting("maximize", "mainstat, moxie, 0.5 hp, 3 dr");
}

// an item that must sit in the main weapon slot (the skate blade does nothing in the off-hand)
item as_mainWeapon = $item[none];

// ---------------------------------------------------------------- preference save/restore
// Like autoscend, take over a few global settings for the run and put them back afterwards.

string[string] as_savedPrefs;

void as_overrideProperty(string prop, string value)
{
	if(!(as_savedPrefs contains prop))
	{
		as_savedPrefs[prop] = get_property(prop);
	}
	set_property(prop, value);
}

// items moved to the closet for the run (e.g. so a drop that needs them absent can happen); always put back
int[item] as_parked;

void as_parkInCloset(item it)
{
	int n = item_amount(it);
	if(n > 0)
	{
		put_closet(n, it);
		as_parked[it] += n;
	}
}

void as_restoreProperties()
{
	foreach prop, value in as_savedPrefs
	{
		set_property(prop, value);
	}
	clear(as_savedPrefs);
	foreach it, n in as_parked
	{
		take_closet(min(n, closet_amount(it)), it);
	}
	clear(as_parked);
}

void as_takeOverSettings()
{
	//a third-party recovery script can loop forever before an adventure; use KoLmafia's built-in recovery.
	if(!get_property("autosea_keepRecoveryScript").to_boolean())
	{
		as_overrideProperty("recoveryScript", "");
	}
	//never stop mid-run for a counter or an unexpected choice
	as_overrideProperty("dontStopForCounters", "true");
	//KoLmafia's recovery may otherwise sleep on the clan sofa or rest at the campground, which cost adventures
	//(one MP top-up cost 7 turns). Free rests are kept.
	foreach prop in $strings[hpAutoRecoveryItems, mpAutoRecoveryItems]
	{
		string kept = "";
		foreach i, option in get_property(prop).split_string(";")
		{
			if(option == "sleep on your clan sofa" || option == "rest at your campground" || option == "")
			{
				continue;
			}
			kept += (kept == "" ? "" : ";") + option;
		}
		if(kept != get_property(prop))
		{
			as_overrideProperty(prop, kept);
		}
	}
	//sea noncombats are decided by autosea's choice script, which can check MP and daily limits.
	//It replaces your own choice script during the run (set autosea_useChoiceScript = false to keep yours).
	if(get_property("choiceAdventureScript") == "" || as_setting("useChoiceScript", "true").to_boolean())
	{
		as_overrideProperty("choiceAdventureScript", "scripts/autosea/choice.ash");
	}
	//fallbacks if the choice script doesn't run: never stop for manual control on these
	foreach choice in $ints[304, 305, 309, 311]
	{
		if(get_property("choiceAdventure" + choice).to_int() == 0)
		{
			as_overrideProperty("choiceAdventure" + choice, "2");
		}
	}
}

// ---------------------------------------------------------------- pending encounters
// If a fight or choice was left open (for example in the relay browser), KoL redirects every action to it,
// so item uses and adventures silently do nothing. Check before starting.

boolean as_clearPendingEncounter()
{
	string page = visit_url("main.php");
	if(current_round() > 0 || page.contains_text("fight.php") || page.contains_text("Combat!"))
	{
		as_warn("A fight was left open; finishing it with your combat settings.");
		run_combat();
		page = visit_url("main.php");
	}
	if(page.contains_text("whichchoice") || page.contains_text("choice.php"))
	{
		page = visit_url("choice.php");
		//sea choices autosea knows how to answer
		int answer = 0;
		switch(last_choice())
		{
			case 403:	//Picking Sides (Skate Park): the ice skates
				answer = 1;
				break;
			case 299:	//Down at the Hatch (the Wreck): open it only to free Big Brother
				answer = get_property("bigBrotherRescued").to_boolean() ? 2 : 1;
				break;
		}
		if(answer > 0)
		{
			as_info("Finishing the open choice " + last_choice() + " with option " + answer + ".");
			run_choice(answer);
			return true;
		}
		matcher title = create_matcher("<b>([^<]+)</b>", page);
		as_warn("KoL is waiting for you to finish a choice adventure" + (title.find() ? ": " + title.group(1) : "") + " (choice " + last_choice() + ").");
		foreach num, text in available_choice_options()
		{
			print("    option " + num + ": " + text);
		}
		as_warn("Finish it in the relay browser (or tell the autosea author which option to take), then run autosea again.");
		return false;
	}
	return true;
}

// ---------------------------------------------------------------- state

boolean as_isFishy()
{
	return have_effect($effect[Fishy]) > 0;
}

boolean as_canBreatheUnderwater()
{
	return boolean_modifier("Adventure Underwater");
}

boolean as_familiarCanBreatheUnderwater()
{
	return my_familiar() == $familiar[none] || boolean_modifier("Underwater Familiar");
}

boolean as_haveAdventures()
{
	//without Fishy an underwater adventure costs 2
	int cost = as_isFishy() ? 1 : 2;
	return my_adventures() >= as_advReserve() + cost;
}

// ---------------------------------------------------------------- buff limits
// The maximizer suggests every useful buff independently, ignoring limits: Accordion Thief songs (3, or 4 with
// some gear), one expression at a time, and pasta thralls (binding one replaces the current one).
int as_activeSongs()
{
	int n = 0;
	foreach eff in my_effects()
	{
		if(eff.song)
		{
			n += 1;
		}
	}
	return n;
}

boolean as_expressionActive()
{
	foreach eff in my_effects()
	{
		if(eff.to_skill().expression)
		{
			return true;
		}
	}
	return false;
}

// a maximizer boost that's safe to run unattended: within limits and without swapping gear
boolean as_boostCommandOk(string command)
{
	//skills granted by an item make the maximizer equip that item first; that gear swap would be undone at once
	return command.index_of("equip") < 0 && command.index_of("unequip") < 0;
}

// skills that failed this run (e.g. item-granted ones already used today): don't keep retrying them
boolean[skill] as_failedSkills;

// run a boost command; remember the skill if it fails
void as_runBoost(string command, skill sk)
{
	if(!cli_execute(command) && sk != $skill[none])
	{
		as_failedSkills[sk] = true;
	}
}

boolean as_skillFitsLimits(skill sk)
{
	if(as_failedSkills contains sk)
	{
		return false;
	}
	if(!sk.buff || adv_cost(sk) > 0)
	{
		return false;	//only real buffs, and never one that costs adventures (e.g. Hibernate)
	}
	if(sk.dailylimit > 0 && sk.timescast >= sk.dailylimit)
	{
		return false;	//already used up today
	}
	int maxSongs = (boolean_modifier("Four Songs") ? 4 : 3) + numeric_modifier("Additional Song").to_int();
	if(sk.song && as_activeSongs() >= maxSongs)
	{
		return false;
	}
	if(sk.expression && as_expressionActive())
	{
		return false;
	}
	return sk.to_string().index_of("Bind ") != 0;
}

// ---------------------------------------------------------------- gear and recovery

boolean as_equipForSea(string extra)
{
	if(as_canBreatheUnderwater() && as_familiarCanBreatheUnderwater() && extra == "")
	{
		return true;
	}
	string expr = "sea";
	if(as_maximizeExtra() != "")
	{
		expr += ", " + as_maximizeExtra();
	}
	if(extra != "")
	{
		expr += ", " + extra;
	}
	as_debug("maximize " + expr);
	maximize(expr, false);
	if(as_mainWeapon != $item[none] && equipped_item($slot[weapon]) != as_mainWeapon && available_amount(as_mainWeapon) > 0)
	{
		if(equipped_item($slot[off-hand]) == as_mainWeapon)
		{
			equip($slot[off-hand], $item[none]);
		}
		equip($slot[weapon], as_mainWeapon);
	}
	if(as_canBreatheUnderwater() && !as_familiarCanBreatheUnderwater() && my_familiar() != $familiar[none])
	{
		as_warn("Your " + my_familiar() + " can't breathe underwater; adventuring without a familiar.");
		use_familiar($familiar[none]);
	}
	return as_canBreatheUnderwater() && as_familiarCanBreatheUnderwater();
}

boolean as_recover()
{
	//sea monsters can take most of your HP in one fight, so start every fight close to full
	float threshold = as_setting("hpThreshold", "0.9").to_float();
	if(my_hp() < my_maxhp() * threshold)
	{
		restore_hp(my_maxhp());
	}
	if(my_mp() < 30 && my_maxmp() > 60)
	{
		restore_mp(min(my_maxmp(), 100));
	}
	return my_hp() > my_maxhp() * 0.5;
}

// Refuse zones where you'd likely be beaten up: KoLmafia's estimate of each monster's damage per hit
// (with your current gear and buffs) times a typical fight length, against your maximum HP.
boolean[location] as_reportedZones;

// the last zone the survival check refused, so the quest loop can farm to get stronger
location as_lastUnsafeZone = $location[none];

// turns the quest must wait (e.g. Deep-Tainted Mind before a dreadscroll re-read); the quest loop farms them
int as_waitTurns = 0;

// the hardest-hitting monster in the zone and its expected damage per round, with current gear and buffs
monster as_worstMonster;
int as_worstDamage(location loc)
{
	int worst = 0;
	as_worstMonster = $monster[none];
	foreach mon, rate in appearance_rates(loc)
	{
		if(rate <= 0 || mon == $monster[none])
		{
			continue;
		}
		int dmg = expected_damage(mon);
		if(dmg > worst)
		{
			worst = dmg;
			as_worstMonster = mon;
		}
	}
	return worst;
}

// the survival check without any reporting
boolean as_zoneSafeQuiet(location loc)
{
	if(as_setting("ignoreDanger", "false").to_boolean())
	{
		return true;
	}
	return as_worstDamage(loc) * as_setting("dangerRounds", "4").to_int() < my_maxhp() * 0.9;
}

boolean as_zoneIsSafe(location loc)
{
	if(as_zoneSafeQuiet(loc))
	{
		return true;
	}
	int rounds = as_setting("dangerRounds", "4").to_int();
	int worst = as_worstDamage(loc);
	monster worstMonster = as_worstMonster;
	as_lastUnsafeZone = loc;
	if(!(as_reportedZones contains loc))
	{
		as_reportedZones[loc] = true;
		as_warn("Skipping " + loc + ": " + worstMonster + " can hit you for about " + worst + " a round, and you have "
			+ my_maxhp() + " HP. More Moxie, HP or damage reduction will open it up. (set autosea_ignoreDanger = true to go anyway)");
	}
	return false;
}

// ---------------------------------------------------------------- adventuring

// turn counter, adventures, last encounter and sea quest state: if any of these change, an adventure happened
string as_progressMarker()
{
	return my_turncount() + "|" + my_adventures() + "|" + get_property("lastEncounter") + "|" + get_property("questS01OldGuy")
		+ "|" + get_property("questS02Monkees") + "|" + get_property("momSeaMonkeeProgress") + "|" + get_property("skateParkStatus");
}

// gear weights that put survival first
string as_defensiveTerms()
{
	return as_setting("defensiveMaximize", "2 hp, 6 dr, 2 moxie");
}

// ---------------------------------------------------------------- what a turn earns, per zone
// A running average (weight 0.2 for the newest) of what each adventure in a zone actually brought in: meat plus
// the mall value of the items it dropped. Kept in autosea_zoneValue_<location id>. Paid buffs are only worth it
// while they cost less than this, and farm mode prefers the zone where it's highest.
int as_turnValue(location loc)
{
	string v = get_property("autosea_zoneValue_" + loc.to_int());
	return v == "" ? as_setting("defaultTurnValue", "400").to_int() : v.to_int();
}

boolean as_turnValueKnown(location loc)
{
	return get_property("autosea_zoneValue_" + loc.to_int()) != "";
}

void as_recordTurn(location loc, int value)
{
	string v = get_property("autosea_zoneValue_" + loc.to_int());
	int updated = v == "" ? value : round(0.8 * v.to_float() + 0.2 * value);
	set_property("autosea_zoneValue_" + loc.to_int(), updated);
	set_property("autosea_lastFarmZone", loc.to_string());
}

// the best a turn is known to earn: what spending adventures (drinks, food, spleen) is measured against
int as_bestTurnValue()
{
	string last = get_property("autosea_lastFarmZone");
	return last == "" ? as_setting("defaultTurnValue", "400").to_int() : as_turnValue(last.to_location());
}

// ---------------------------------------------------------------- what a zone's drops are worth
// Each sea zone has a pressure penalty on item and meat drops (-25% in the Briny Deeps to -200% in the Trench),
// reduced by "better diver" gear. KoLmafia models both, but only for the zone it thinks you're in, so set the
// location before choosing gear.

// Items you want for themselves, such as skill books and collection pieces: autosea_wantItems, comma-separated,
// plus whatever "autosea collect" is after. They're valued at autosea_wantValue (default 1,000,000) until you
// have one, or know the skill it teaches, so the monster that drops them gets tracked and dolphins that steal
// them get chased.
item as_collectItem;

boolean as_wanted(item it)
{
	if(it == $item[none])
	{
		return false;
	}
	//the Mer-kin darkbook teaches Deep Dark Visions, a sea skill (autosea_wantSeaSkills)
	boolean listed = it == as_collectItem || (it == $item[Mer-kin darkbook] && as_setting("wantSeaSkills", "true").to_boolean());
	foreach i, name in get_property("autosea_wantItems").split_string(",")
	{
		matcher m = create_matcher("^\\s*(.*?)\\s*$", name);
		if(m.find() && m.group(1) != "" && m.group(1).to_item() == it)
		{
			listed = true;
		}
	}
	if(!listed)
	{
		return false;
	}
	skill teaches = string_modifier(it, "Skill").to_skill();
	if(teaches != $skill[none])
	{
		return !have_skill(teaches);
	}
	return it == as_collectItem || available_amount(it) + storage_amount(it) + display_amount(it) == 0;
}

int as_dropValue(item it)
{
	if(as_wanted(it))
	{
		return as_setting("wantValue", "1000000").to_int();
	}
	if(it.tradeable)
	{
		int price = mall_price(it);
		if(price > 0)
		{
			return price;
		}
	}
	return max(0, autosell_price(it));
}

// conditional drops autosea knows how to switch on
boolean as_dropApplies(item it, string type, location loc)
{
	if(type.contains_text("p") || type == "0")
	{
		return false;	//pickpocket only, or unknown rate
	}
	if(!type.contains_text("c"))
	{
		return true;
	}
	switch(it)
	{
		case $item[temporary teardrop tattoo]:
		case $item[shark cartilage]:
		case $item[eel battery]:
			//only while you have Fishbreath
			return have_effect($effect[Fishbreath]) > 0
				|| (loc == $location[The Briniest Deepests] && as_setting("fishbreath", "false").to_boolean()
					&& !get_property("_autosea_fishbreathLost").to_boolean());
		case $item[eel sauce]:
			return get_property("grandpaUnlockedEelSauce").to_boolean();
		case $item[shark jumper]:
			return true;	//turns up in your logs without any special setup
	}
	return false;
}

// how often each monster turns up in the zone (combats only), summing to 1
float[monster] as_zoneMonsters(location loc)
{
	float[monster] weights;
	float total = 0;
	foreach m, rate in appearance_rates(loc)
	{
		if(m != $monster[none] && rate > 0)
		{
			weights[m] = rate;
			total += rate;
		}
	}
	foreach m in weights
	{
		weights[m] = weights[m] / total;
	}
	return weights;
}

// expected mall value of one monster's item drops at a net item drop bonus (in %, after the pressure penalty)
float as_monsterItemValue(monster m, location loc, float itemBonus)
{
	float value = 0;
	foreach i, d in item_drops_array(m)
	{
		if(d.rate <= 0 || !as_dropApplies(d.drop, d.type, loc))
		{
			continue;
		}
		float chance = d.type.contains_text("f") ? d.rate / 100 : min(1.0, d.rate / 100 * max(0.0, 1 + itemBonus / 100));
		value += chance * as_dropValue(d.drop);
	}
	return value;
}

// the same for a fight in the zone, averaged over its monsters
float as_zoneItemValue(location loc, float itemBonus)
{
	float value = 0;
	foreach m, w in as_zoneMonsters(loc)
	{
		value += w * as_monsterItemValue(m, loc, itemBonus);
	}
	return value;
}

// meat a turn each 1% of item drop is worth here (drops already at 100% don't count)
float as_zoneItemSlope(location loc, float itemBonus)
{
	return as_zoneItemValue(loc, itemBonus + 1) - as_zoneItemValue(loc, itemBonus);
}

// average base meat a fight drops here, before any meat drop bonus
float as_zoneBaseMeat(location loc)
{
	float meat = 0;
	foreach m, w in as_zoneMonsters(loc)
	{
		meat += w * meat_drop(m);
	}
	return meat;
}

// the zone's pressure penalty after your current "better diver" gear (0 or less)
float as_zonePenalty(location loc)
{
	float penalty = numeric_modifier("Loc:" + loc, "Item Drop Penalty");
	return min(0.0, penalty + numeric_modifier("Better Diver"));
}

// what fighting one monster here is worth with the gear you have on now: meat plus drops
float as_monsterValue(monster m, location loc)
{
	float netItem = numeric_modifier("Item Drop") + as_zonePenalty(loc);
	float netMeat = numeric_modifier("Meat Drop") + as_zonePenalty(loc);
	return meat_drop(m) * max(0.0, 1 + netMeat / 100) + as_monsterItemValue(m, loc, netItem);
}

// The monster worth tracking (olfaction and similar) in this zone: the one worth clearly more than an average
// fight here, by autosea_trackMargin (default 1.3 times) and at least 100 meat. $monster[none] if none stands out.
monster as_trackTarget(location loc)
{
	monster best = $monster[none];
	float bestValue = 0;
	float average = 0;
	foreach m, w in as_zoneMonsters(loc)
	{
		float v = as_monsterValue(m, loc);
		average += w * v;
		if(v > bestValue)
		{
			best = m;
			bestValue = v;
		}
	}
	if(best == $monster[none] || bestValue < average * as_setting("trackMargin", "1.3").to_float() || bestValue - average < 100)
	{
		return $monster[none];
	}
	return best;
}

// a rough estimate of a turn's value in a zone you haven't farmed yet, with the gear you have on now
int as_zoneEstimate(location loc)
{
	float netItem = numeric_modifier("Item Drop") + as_zonePenalty(loc);
	float netMeat = numeric_modifier("Meat Drop") + as_zonePenalty(loc);
	return round(as_zoneBaseMeat(loc) * max(0.0, 1 + netMeat / 100) + as_zoneItemValue(loc, netItem));
}

// maximizer terms weighting meat and item drop by what each is worth in this zone. One maximizer point
// is roughly one meat a turn, scaled by autosea_dropWeight.
string as_dropTerms(location loc, float scale)
{
	scale *= as_setting("dropWeight", "1").to_float();
	float netItem = numeric_modifier("Item Drop") + as_zonePenalty(loc);
	float meatWeight = as_zoneBaseMeat(loc) / 100 * scale;
	float itemWeight = as_zoneItemSlope(loc, netItem) * scale;
	string terms = "";
	if(meatWeight >= 0.1)
	{
		terms += to_string(meatWeight, "%.1f") + " meat";
	}
	if(itemWeight >= 0.1)
	{
		terms += (terms == "" ? "" : ", ") + to_string(itemWeight, "%.1f") + " item";
	}
	return terms;
}

// the items a fight here can drop, to count what an adventure brought in
boolean[item] as_zoneDrops(location loc)
{
	boolean[item] drops;
	foreach m in as_zoneMonsters(loc)
	{
		foreach i, d in item_drops_array(m)
		{
			drops[d.drop] = true;
		}
	}
	return drops;
}

location as_dolphinZone;	//set when a dolphin steals an item, to the zone it was stolen in

// one adventure in a sea zone. Returns false (and says why) if it could not adventure.
// filter: name of a combat filter function, or "" to leave combat entirely to your own combat settings.
boolean as_adv(location loc, string extraMaximize, string filter)
{
	if(!as_haveAdventures())
	{
		as_warn("Not enough adventures left (reserve " + as_advReserve() + ").");
		return false;
	}
	set_location(loc);	//so gear is judged against this zone's pressure penalty
	if(!as_equipForSea(extraMaximize))
	{
		as_warn("Can't breathe underwater (you or your familiar) for " + loc + ". Get a fishbowl, helmet or similar first.");
		return false;
	}
	if(!as_zoneSafeQuiet(loc) && as_equipForSea(extraMaximize + (extraMaximize == "" ? "" : ", ") + as_defensiveTerms()) && as_zoneSafeQuiet(loc))
	{
		as_debug("defensive gear makes " + loc + " safe");
	}
	if(!as_zoneIsSafe(loc))
	{
		return false;
	}
	if(!as_recover())
	{
		as_warn("Couldn't recover enough HP to adventure safely (" + my_hp() + "/" + my_maxhp() + ").");
		return false;
	}
	if(!can_adventure(loc))
	{
		as_warn("KoLmafia says you can't adventure at " + loc + " yet.");
		return false;
	}
	as_debug("adventuring at " + loc);
	string before = as_progressMarker();
	int meatBefore = my_meat();
	int turnsBefore = my_turncount();
	int[item] itemsBefore;
	foreach it in as_zoneDrops(loc)
	{
		itemsBefore[it] = item_amount(it);
	}
	string dolphinBefore = get_property("dolphinItem");
	if(adv1(loc, -1, filter))
	{
		if(my_turncount() > turnsBefore)
		{
			int value = my_meat() - meatBefore;
			foreach it, n in itemsBefore
			{
				value += max(0, item_amount(it) - n) * as_dropValue(it);
			}
			as_recordTurn(loc, value / (my_turncount() - turnsBefore));
		}
		if(get_property("dolphinItem") != "" && get_property("dolphinItem") != dolphinBefore)
		{
			as_dolphinZone = loc;	//a dolphin just stole something here: the caller decides whether to chase it
		}
		return true;
	}
	//KoLmafia stops automation on some quest encounters ("You've Hit Bottom", "Granny, Does Your Dogfish Bite?",
	//Mom's rescue); adv1 then reports failure even though the adventure happened. Count it if anything moved.
	if(as_progressMarker() != before)
	{
		as_debug("adventure happened (" + get_property("lastEncounter") + ") although KoLmafia stopped automation");
		return true;
	}
	as_warn("The adventure at " + loc + " didn't happen. HP " + my_hp() + "/" + my_maxhp() + ", adventures " + my_adventures()
		+ ", Fishy " + have_effect($effect[Fishy]) + ", breathing " + as_canBreatheUnderwater() + "/" + as_familiarCanBreatheUnderwater()
		+ ". KoLmafia's reason is in the CLI just above.");
	return false;
}

boolean as_adv(location loc, string extraMaximize)
{
	return as_adv(loc, extraMaximize, "");
}

boolean as_adv(location loc)
{
	return as_adv(loc, "", "");
}
