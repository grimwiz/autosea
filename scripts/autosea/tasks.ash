// autosea tasks. Each task returns true if it took an action (an adventure, a purchase or an NPC visit),
// false if it has nothing to do right now. The engine runs the first task that acts, then starts over.
//
// Quest state comes from KoLmafia's tracked properties:
//   questS01OldGuy:  unstarted, started, step1 (holding the damp old boot), finished
//   questS02Monkees: unstarted, started (pellet used), step1 (Wreck open), step2 (Big Brother freed),
//                    step3 (bubblin' stone), step4 (Grandpa's zone open), step5 (Grandpa found),
//                    step6 (Outpost open), step7 (Grandma's Note), step8 (Grandma's Map),
//                    step9 (Grandma freed), step10, step11, step12 (black glass), finished (Mom freed)

import <autosea/util.ash>

// ---------------------------------------------------------------- quest helpers

// "unstarted" = -1, "started" = 0, "stepN" = N, "finished" = 999
int as_questStep(string prop)
{
	string value = get_property(prop);
	if(value == "unstarted" || value == "")
	{
		return -1;
	}
	if(value == "started")
	{
		return 0;
	}
	if(value == "finished")
	{
		return 999;
	}
	return value.substring(4).to_int();
}

int as_monkeeStep()
{
	return as_questStep("questS02Monkees");
}

boolean as_wantSkatePark()
{
	return as_setting("skatePark", "true").to_boolean();
}

boolean as_wantSushiMat()
{
	return as_setting("sushiMat", "true").to_boolean();
}

boolean as_wantHelmet()
{
	return as_setting("helmet", "true").to_boolean();
}

// ---------------------------------------------------------------- buying

boolean as_buyingAllowed()
{
	return can_interact() && as_setting("buy", "true").to_boolean();
}

int as_maxPrice()
{
	//most autosea will pay for one item from the mall
	return as_setting("maxPrice", "25000").to_int();
}

// get qty of it into inventory without buying: from the closet, then from Hagnk's (when allowed)
boolean as_fetch(int qty, item it)
{
	if(item_amount(it) < qty && closet_amount(it) > 0)
	{
		take_closet(min(qty - item_amount(it), closet_amount(it)), it);
	}
	if(item_amount(it) < qty && storage_amount(it) > 0 && can_interact())
	{
		take_storage(min(qty - item_amount(it), storage_amount(it)), it);
	}
	return item_amount(it) >= qty;
}

// make sure we hold qty of it: closet and storage first, then the mall if allowed. Returns true if we hold enough.
boolean as_acquire(int qty, item it)
{
	if(as_fetch(qty, it))
	{
		return true;
	}
	if(!as_buyingAllowed())
	{
		return false;
	}
	int missing = qty - item_amount(it);
	int price = mall_price(it);
	if(price <= 0 || price > as_maxPrice())
	{
		as_debug("not buying " + it + " at " + price);
		return false;
	}
	as_info("Buying " + missing + " " + it + " (about " + price + " each).");
	int bought = buy(missing, it, as_maxPrice());
	if(item_amount(it) < qty)
	{
		as_warn("Couldn't buy " + it + " (bought " + bought + "). Check the CLI for KoLmafia's reason.");
		return false;
	}
	return true;
}

boolean as_buyFromBigBrother(item it, int cost)
{
	if(!as_acquire(cost, $item[sand dollar]))
	{
		as_warn("Need " + cost + " sand dollars for " + it + " (have " + item_amount($item[sand dollar]) + ").");
		return false;
	}
	as_info("Buying " + it + " from Big Brother.");
	return buy($coinmaster[Big Brother], 1, it);
}

// ---------------------------------------------------------------- Fishy (halves the cost of sea adventures)

void as_ensureFishy()
{
	if(as_isFishy())
	{
		return;
	}
	//free daily sources first
	if(get_property("skateParkStatus") == "ice" && !get_property("_skateBuff1").to_boolean())
	{
		cli_execute("skate lutz");
		if(as_isFishy()) return;
	}
	if(!get_property("_fishyPipeUsed").to_boolean() && as_fetch(1, $item[fishy pipe]))
	{
		use(1, $item[fishy pipe]);
		if(as_isFishy()) return;
		as_warn("Used the fishy pipe but didn't get Fishy.");
	}
	//sea jelly: 1 spleen for 10 Fishy turns, usually ~100 meat
	if(as_setting("useSpleen", "true").to_boolean() && spleen_limit() - my_spleen_use() >= 1)
	{
		if(as_fetch(1, $item[sea jelly]) || (mall_price($item[sea jelly]) <= as_setting("fishyMaxPrice", "1000").to_int() && as_acquire(1, $item[sea jelly])))
		{
			chew(1, $item[sea jelly]);
			if(!as_isFishy())
			{
				as_warn("Chewed a sea jelly but didn't get Fishy.");
			}
		}
	}
}

// ---------------------------------------------------------------- boosts for noncombat hunting

// casts or uses whatever the maximizer suggests for the expression (skills, and items already owned)
void as_applyBoosts(string expr)
{
	foreach i, entry in maximize(expr, 0, 0, true, false)
	{
		if(entry.score <= 0 || entry.command == "" || entry.command.index_of("uneffect") == 0)
		{
			continue;
		}
		if(entry.display.index_of("<font color=gray>") != -1)
		{
			continue;	//not available
		}
		boolean ownSkill = entry.skill != $skill[none] && have_skill(entry.skill);
		boolean ownItem = entry.item != $item[none] && item_amount(entry.item) > 0;
		if(ownSkill || ownItem)
		{
			as_debug("boost: " + entry.command);
			cli_execute(entry.command);
		}
	}
}

// one adventure in a sea zone, with Fishy and the right gear
boolean as_seaAdv(location loc, string extraMaximize, string filter)
{
	as_ensureFishy();
	if(extraMaximize.contains_text("combat"))
	{
		as_applyBoosts("-combat");
	}
	return as_adv(loc, extraMaximize, filter);
}

boolean as_seaAdv(location loc, string extraMaximize)
{
	return as_seaAdv(loc, extraMaximize, "");
}

boolean as_seaAdv(location loc)
{
	return as_seaAdv(loc, "", "");
}

string NC_HUNT = "-25combat";

// ---------------------------------------------------------------- tasks

boolean as_oldMan()
{
	if(as_questStep("questS01OldGuy") >= 0)
	{
		return false;
	}
	as_info("Talking to the Old Man to open the Sea.");
	visit_url("place.php?whichplace=sea_oldman&action=oldman_oldman");
	return true;
}

boolean as_littleBrother()
{
	int step = as_monkeeStep();
	if(step >= 1 || as_questStep("questS01OldGuy") < 0)
	{
		return false;
	}
	if(step == 0)
	{
		as_info("Visiting Little Brother.");
		visit_url("monkeycastle.php?who=1");
		return true;
	}
	if(item_amount($item[wriggling flytrap pellet]) > 0)
	{
		as_info("Using the wriggling flytrap pellet to find the Sea Monkees' castle.");
		use(1, $item[wriggling flytrap pellet]);
		return true;
	}
	as_info("Looking for a Neptune flytrap in the Octopus's Garden.");
	return as_seaAdv($location[An Octopus's Garden]);
}

boolean as_bigBrother()
{
	int step = as_monkeeStep();
	if(step < 1 || step >= 4)
	{
		return false;
	}
	if(step == 1 && !get_property("bigBrotherRescued").to_boolean())
	{
		set_property("choiceAdventure299", "1");	//open the hatch
		as_info("Looking for Big Brother in the Wreck of the Edgar Fitzsimmons.");
		return as_seaAdv($location[The Wreck of the Edgar Fitzsimmons], NC_HUNT);
	}
	//never reopen the hatch by accident: mine crabs appear and explode for huge damage
	set_property("choiceAdventure299", "2");
	if(step <= 2)
	{
		as_info("Visiting Big Brother.");
		visit_url("monkeycastle.php?who=2");
		return true;
	}
	as_info("Checking in with Little Brother.");
	visit_url("monkeycastle.php?who=1");
	return true;
}

// 0-turn purchases once Big Brother's shop is open
boolean as_fishyPipe()
{
	if(!get_property("bigBrotherRescued").to_boolean() || as_questStep("questS01OldGuy") >= 999)
	{
		return false;
	}
	//the boot is only worth it for the pipe, or das boot if we have no familiar breathing gear
	boolean wantPipe = available_amount($item[fishy pipe]) == 0;
	boolean wantDasBoot = available_amount($item[das boot]) == 0 && available_amount($item[little bitty bathysphere]) == 0;
	if(!wantPipe && !wantDasBoot)
	{
		return false;
	}
	if(item_amount($item[damp old boot]) == 0)
	{
		if(get_property("dampOldBootPurchased").to_boolean() || !as_buyFromBigBrother($item[damp old boot], 50))
		{
			return false;
		}
		return true;
	}
	int reward = wantPipe ? 6314 : 3609;
	as_info("Returning the boot to the Old Man for the " + (wantPipe ? "fishy pipe." : "das boot."));
	visit_url("place.php?whichplace=sea_oldman&action=oldman_oldman");
	visit_url("place.php?whichplace=sea_oldman&action=oldman_oldman&preaction=pickreward&whichreward=" + reward);
	return true;
}

boolean as_sushiMatInstalled()
{
	return get_property("hasSushiMat").to_boolean() || (get_campground() contains $item[sushi-rolling mat]);
}

boolean as_sushiMatRefreshed = false;
boolean as_sushiMatFailed = false;

boolean as_sushiMat()
{
	if(!as_wantSushiMat() || as_sushiMatFailed || as_sushiMatInstalled())
	{
		return false;
	}
	//KoLmafia only learns the mat is installed from the campground page, which may be stale
	if(!as_sushiMatRefreshed)
	{
		as_sushiMatRefreshed = true;
		visit_url("campground.php");
		if(as_sushiMatInstalled())
		{
			as_info("Your sushi-rolling mat is already installed.");
			return false;
		}
	}
	//the Old Man hands back a mat you installed in an earlier ascension, so you may already hold one
	if(!as_fetch(1, $item[sushi-rolling mat]))
	{
		if(!get_property("bigBrotherRescued").to_boolean())
		{
			return false;
		}
		return as_buyFromBigBrother($item[sushi-rolling mat], 50);
	}
	as_info("Installing the sushi-rolling mat.");
	string reply = visit_url("inv_use.php?pwd&whichitem=" + $item[sushi-rolling mat].to_int());
	visit_url("campground.php");
	if(!as_sushiMatInstalled())
	{
		as_sushiMatFailed = true;
		matcher m = create_matcher("<td[^>]*>((?:(?!<td).)*?(?:mat|kitchen)(?:(?!<td).)*?)</td>", reply);
		string said = m.find() ? m.group(1).replace_string("<br>", " ").to_string() : reply;
		said = create_matcher("<[^>]*>", said).replace_all("");
		as_warn("Using the sushi-rolling mat didn't install it. KoL said: " + said.substring(0, min(300, length(said))));
		as_warn("Carrying on without the mat; tell the autosea author what KoL said.");
	}
	return true;
}

boolean as_helmet()
{
	if(!as_wantHelmet() || available_amount($item[aerated diving helmet]) > 0 || item_amount($item[bubblin' stone]) == 0)
	{
		return false;
	}
	if(!as_acquire(1, $item[rusty diving helmet]))
	{
		return false;
	}
	as_info("Making an aerated diving helmet.");
	create(1, $item[aerated diving helmet]);
	return true;
}

// Skate Park, ice route: Lutz gives 30 turns of Fishy a day
boolean as_skateParkChecked = false;

boolean as_skatePark()
{
	if(!as_wantSkatePark() || !get_property("bigBrotherRescued").to_boolean())
	{
		return false;
	}
	if(!get_property("mapToTheSkateParkPurchased").to_boolean())
	{
		return as_buyFromBigBrother($item[map to the Skate Park], 25);
	}
	if(!as_skateParkChecked)
	{
		visit_url("sea_skatepark.php");	//the only way to refresh skateParkStatus
		as_skateParkChecked = true;
	}
	if(get_property("skateParkStatus") != "war")
	{
		return false;	//already decided
	}
	//Picking Sides: side with the ice skates (and take a skate blade). Without this KoLmafia stops at the choice.
	as_overrideProperty("choiceAdventure403", "1");
	if(available_amount($item[skate blade]) == 0)
	{
		as_acquire(1, $item[skate blade]);
	}
	string gear = available_amount($item[skate blade]) > 0 ? "+equip skate blade" : "";
	as_info("Fighting the roller skates out of the Skate Park.");
	boolean acted = as_seaAdv($location[The Skate Park], gear);
	visit_url("sea_skatepark.php");
	return acted;
}

location as_grandpaZone()
{
	switch(my_class())
	{
		case $class[Seal Clubber]:
		case $class[Turtle Tamer]:
			return $location[Anemone Mine];
		case $class[Pastamancer]:
		case $class[Sauceror]:
			return $location[The Marinara Trench];
		case $class[Disco Bandit]:
		case $class[Accordion Thief]:
			return $location[The Dive Bar];
	}
	return $location[none];
}

boolean as_grandpa()
{
	int step = as_monkeeStep();
	if(step != 4 && step != 5)
	{
		return false;
	}
	if(step == 5)
	{
		as_info("Asking Grandpa about Grandma.");
		cli_execute("grandpa grandma");
		return true;
	}
	location zone = as_grandpaZone();
	if(zone == $location[none])
	{
		as_warn("autosea only knows Grandpa's zone for the six standard classes.");
		return false;
	}
	as_info("Looking for Grandpa in " + zone + ".");
	return as_seaAdv(zone, NC_HUNT);
}

boolean as_grandma()
{
	int step = as_monkeeStep();
	if(step < 6 || step > 8)
	{
		return false;
	}
	boolean haveNoteSet = item_amount($item[Grandma's Note]) > 0 && item_amount($item[Grandma's Fuchsia Yarn]) > 0 && item_amount($item[Grandma's Chartreuse Yarn]) > 0;
	if(step < 8 && haveNoteSet)
	{
		as_info("Showing Grandpa the note and yarn.");
		cli_execute("grandpa note");
		return true;
	}
	as_info(step < 8 ? "Searching the Mer-Kin Outpost for Grandma's note and yarn." : "Following Grandma's Map in the Mer-Kin Outpost.");
	return as_seaAdv($location[The Mer-Kin Outpost], NC_HUNT);
}

// ---------------------------------------------------------------- the Abyss and the legendary seal-clubbing club
// A school of many is 20 monsters with 20,000 HP between them. The club's skills deal with it:
//   Club 'Em Back in Time:          free kill (no adventure used, no drops), 5 a day
//   Club 'Em Across the Battlefield: insta-kill (uses the turn, keeps drops), 5 a day
// Both count as won fights, so Mom's progress goes up as usual. Club 'Em Into Next Week is never used here:
// it would bring the school back as a wandering monster.

boolean as_haveClub()
{
	return available_amount($item[legendary seal-clubbing club]) > 0;
}

int as_clubKillsLeft()
{
	return max(0, 5 - get_property("_clubEmTimeUsed").to_int()) + max(0, 5 - get_property("_clubEmBattlefieldUsed").to_int());
}

// combat filter for adv1: club the school of many, leave every other fight to your own combat settings
string as_abyssFilter(int round, monster enemy, string text)
{
	if(enemy != $monster[school of many] || !have_equipped($item[legendary seal-clubbing club]))
	{
		return "";
	}
	if(get_property("_clubEmTimeUsed").to_int() < 5)
	{
		return "skill Club 'Em Back in Time";
	}
	if(get_property("_clubEmBattlefieldUsed").to_int() < 5)
	{
		return "skill Club 'Em Across the Battlefield";
	}
	return "";
}

// optional Abyss speed-ups: each adds 1 progress per won fight (40 fights without, 10 with all three)
string as_momGear()
{
	string gear = "+equip black glass";
	if(as_haveClub())
	{
		gear += ", +equip legendary seal-clubbing club";
	}
	if(available_amount($item[scale-mail underwear]) > 0 || as_acquire(1, $item[scale-mail underwear]))
	{
		gear += ", +equip scale-mail underwear";
	}
	if(have_skill($skill[Torso Awareness]) && (available_amount($item[shark jumper]) > 0 || as_acquire(1, $item[shark jumper])))
	{
		gear += ", +equip shark jumper";
	}
	return gear;
}

boolean as_mom()
{
	int step = as_monkeeStep();
	if(step < 9 || step >= 999)
	{
		return false;
	}
	if(step == 9)
	{
		as_info("Telling Little Brother about Grandma.");
		visit_url("monkeycastle.php?who=1");
		return true;
	}
	if(step == 10)
	{
		as_info("Checking on Big Brother.");
		visit_url("monkeycastle.php?who=2");
		return true;
	}
	if(step == 11)
	{
		//costs 13 sand dollars, refunded straight away
		return as_buyFromBigBrother($item[black glass], 13);
	}
	if(have_effect($effect[Jelly Combed]) == 0 && as_acquire(1, $item[comb jelly]))
	{
		use(1, $item[comb jelly]);
	}
	//with the club, pace the Abyss over several days: stop once today's club kills are spent,
	//rather than meet a school of many without them
	if(as_haveClub() && as_setting("abyssPace", "true").to_boolean() && as_clubKillsLeft() == 0)
	{
		as_info("Out of club kills for today. Mom is at " + get_property("momSeaMonkeeProgress") + "/40; run autosea again tomorrow.");
		return false;
	}
	as_info("Fighting through the Caliginous Abyss for Mom (" + get_property("momSeaMonkeeProgress") + "/40).");
	return as_seaAdv($location[The Caliginous Abyss], as_momGear(), "as_abyssFilter");
}

// ---------------------------------------------------------------- engine hooks

string[int] AS_TASKS;
AS_TASKS[0] = "as_oldMan";
AS_TASKS[1] = "as_sushiMat";
AS_TASKS[2] = "as_littleBrother";
AS_TASKS[3] = "as_bigBrother";
AS_TASKS[4] = "as_fishyPipe";
AS_TASKS[5] = "as_helmet";
AS_TASKS[6] = "as_skatePark";
AS_TASKS[7] = "as_grandpa";
AS_TASKS[8] = "as_grandma";
AS_TASKS[9] = "as_mom";

string[int] as_taskOrder()
{
	return AS_TASKS;
}

string as_stateSignature()
{
	string sig = "";
	foreach prop in $strings[questS01OldGuy, questS02Monkees, bigBrotherRescued, dampOldBootPurchased, hasSushiMat, mapToTheSkateParkPurchased, skateParkStatus, momSeaMonkeeProgress]
	{
		sig += get_property(prop) + "|";
	}
	foreach it in $items[sand dollar, wriggling flytrap pellet, bubblin' stone, rusty diving helmet, aerated diving helmet, damp old boot, fishy pipe, das boot, sushi-rolling mat, skate blade, Grandma's Note, Grandma's Fuchsia Yarn, Grandma's Chartreuse Yarn, Grandma's Map, black glass, scale-mail underwear, shark jumper, comb jelly]
	{
		sig += available_amount(it) + "|";
	}
	return sig;
}

void as_printStatus()
{
	void line(string name, boolean done)
	{
		print((done ? "  [x] " : "  [ ] ") + name, done ? "green" : "black");
	}
	int step = as_monkeeStep();
	print("autosea progress:", "blue");
	line("Old Man (Sea open)", as_questStep("questS01OldGuy") >= 0);
	line("Little Brother", step >= 1);
	line("Big Brother", get_property("bigBrotherRescued").to_boolean());
	line("Grandpa", step >= 5);
	line("Grandma", step >= 9);
	line("Mom", step >= 999);
	print("Helpers:", "blue");
	line("fishy pipe" + (get_property("_fishyPipeUsed").to_boolean() ? " (used today)" : ""), available_amount($item[fishy pipe]) > 0);
	line("sushi-rolling mat" + (!as_sushiMatInstalled() && available_amount($item[sushi-rolling mat]) > 0 ? " (owned, not installed yet)" : ""), as_sushiMatInstalled());
	line("aerated diving helmet", available_amount($item[aerated diving helmet]) > 0);
	line("Skate Park (" + get_property("skateParkStatus") + ")", get_property("skateParkStatus") == "ice");
	print("Fishy: " + have_effect($effect[Fishy]) + " turns. Adventures: " + my_adventures() + ".", "blue");
}
