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
import <autosea/pearls.ash>

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

// ---------------------------------------------------------------- tracking a monster
// Transcendent Olfaction (3 a day, lasts until replaced) and Gallapagosian Mating Call make a monster turn up
// more often. Set as_trackMonster and pass "as_trackFilter" as the combat filter; your own combat settings do
// the rest of the fight.
monster as_trackMonster;

string as_trackFilter(int round, monster enemy, string text)
{
	if(as_trackMonster == $monster[none] || enemy != as_trackMonster || round > 2 || !as_setting("track", "true").to_boolean())
	{
		return "";
	}
	if(get_property("olfactedMonster") != enemy.to_string() && have_skill($skill[Transcendent Olfaction])
		&& get_property("_olfactionsUsed").to_int() < 3 && my_mp() >= mp_cost($skill[Transcendent Olfaction]) + 20)
	{
		return "skill Transcendent Olfaction";
	}
	if(get_property("_gallapagosMonster") != enemy.to_string() && have_skill($skill[Gallapagosian Mating Call])
		&& my_mp() >= mp_cost($skill[Gallapagosian Mating Call]) + 20)
	{
		return "skill Gallapagosian Mating Call";
	}
	return "";
}

// ---------------------------------------------------------------- make or buy
// Before buying, compare the mall with the in-game ways to get an item: an NPC store, Big Brother (sand dollars,
// themselves make-or-buy), or collecting it from sea monsters. Collecting costs the turns it takes times what
// those turns lose against your best farm zone: the collecting zone's own meat and drops count, so a drop from a
// zone you'd farm anyway costs next to nothing, and collecting is farming. autosea_selfSufficiency above 1
// favours in-game sources (1.5: collect even at up to 1.5 times the mall price).

record as_source
{
	string how;
	location loc;
	monster target;
	float turns;	//turns per item, when collecting
	int cost;	//meat per item
};

boolean[location] AS_COLLECT_ZONES = $locations[The Briny Deeps, The Brinier Deepers, The Briniest Deepests,
	An Octopus's Garden, Madness Reef, The Mer-Kin Outpost, The Skate Park, The Coral Corral, Anemone Mine,
	The Dive Bar, The Marinara Trench];

as_source as_dropSource(item it)
{
	as_source best;
	best.cost = 999999999;
	int bestTurn = as_bestTurnValue();
	foreach loc in AS_COLLECT_ZONES
	{
		if(!can_adventure(loc))
		{
			continue;
		}
		float netItem = numeric_modifier("Item Drop") + as_zonePenalty(loc);
		float perFight = 0;
		monster target = $monster[none];
		float targetChance = 0;
		foreach m, w in as_zoneMonsters(loc)
		{
			foreach i, d in item_drops_array(m)
			{
				if(d.drop != it || d.rate <= 0 || !as_dropApplies(d.drop, d.type, loc))
				{
					continue;
				}
				float chance = d.type.contains_text("f") ? d.rate / 100 : min(1.0, d.rate / 100 * max(0.0, 1 + netItem / 100));
				perFight += w * chance;
				if(chance > targetChance)
				{
					target = m;
					targetChance = chance;
				}
			}
		}
		if(perFight <= 0)
		{
			continue;
		}
		//what a turn here earns besides this item
		float earns = (as_turnValueKnown(loc) ? as_turnValue(loc) : as_zoneEstimate(loc)) - perFight * as_dropValue(it);
		float turns = 1 / perFight;
		int cost = round(turns * max(0.0, bestTurn - earns));
		if(cost < best.cost)
		{
			best.how = "collect";
			best.loc = loc;
			best.target = target;
			best.turns = turns;
			best.cost = cost;
		}
	}
	return best;
}

int as_unitCost(item it);

// the cheapest way to get one without the mall
as_source as_ingameSource(item it)
{
	as_source best = as_dropSource(it);
	if(npc_price(it) > 0 && npc_price(it) < best.cost)
	{
		best.how = "npc";
		best.cost = npc_price(it);
	}
	if(is_coinmaster_item(it) && sell_price($coinmaster[Big Brother], it) > 0)
	{
		int coins = sell_price($coinmaster[Big Brother], it) * as_unitCost($item[sand dollar]);
		if(coins < best.cost)
		{
			best.how = "Big Brother";
			best.cost = coins;
		}
	}
	return best;
}

// what one costs, the cheaper of the mall and the best in-game way
int as_unitCost(item it)
{
	int mall = mall_price(it) > 0 ? mall_price(it) : 999999999;
	if(it == $item[sand dollar])
	{
		return min(mall, as_dropSource(it).cost);	//not sold by Big Brother itself
	}
	return min(mall, as_ingameSource(it).cost);
}

boolean as_seaAdv(location loc, string extraMaximize, string filter);
boolean as_buyFromBigBrother(item it, int cost);
boolean as_collecting;

// collect qty of an item from the sea, tracking the monster that drops it. Gives up after twice the expected
// turns (or autosea_collectMaxTurns), or if the zone isn't safe.
boolean as_collect(int qty, item it, as_source src)
{
	int limit = min(as_setting("collectMaxTurns", "60").to_int(), ceil(src.turns * (qty - item_amount(it)) * 2) + 5);
	if(my_adventures() - as_advReserve() < limit / 2)
	{
		return false;
	}
	as_info("Collecting " + (qty - item_amount(it)) + " " + it + " in " + src.loc + " (about " + ceil(src.turns) + " turns each, "
		+ src.cost + " meat each in lost farming, against " + mall_price(it) + " in the mall).");
	as_collecting = true;
	monster oldTarget = as_trackMonster;
	as_trackMonster = src.target;
	int start = my_turncount();
	try
	{
		while(item_amount(it) < qty && my_turncount() - start < limit)
		{
			if(!as_seaAdv(src.loc, "", "as_trackFilter"))
			{
				break;
			}
		}
	}
	finally
	{
		as_collecting = false;
		as_trackMonster = oldTarget;
	}
	return item_amount(it) >= qty;
}

// make sure we hold qty of it: closet and storage first, then the cheapest of the mall and the in-game ways.
// Returns true if we hold enough.
boolean as_acquire(int qty, item it)
{
	if(as_fetch(qty, it))
	{
		return true;
	}
	if(!as_collecting && as_setting("collect", "true").to_boolean())
	{
		as_source src = as_ingameSource(it);
		int mall = mall_price(it) > 0 ? mall_price(it) : 999999999;
		if(src.how == "collect" && src.cost < mall * as_setting("selfSufficiency", "1").to_float()
			&& as_collect(qty, it, src))
		{
			return true;
		}
		if(src.how == "Big Brother" && src.cost < mall)
		{
			while(item_amount(it) < qty && as_buyFromBigBrother(it, sell_price($coinmaster[Big Brother], it)))
			{
			}
			if(item_amount(it) >= qty)
			{
				return true;
			}
		}
		if(src.how == "collect" && mall < 999999999)
		{
			as_debug("Buying " + it + " (~" + mall + "): collecting would cost about " + src.cost + " (" + ceil(src.turns) + " turns in " + src.loc + ").");
		}
	}
	if(!as_buyingAllowed())
	{
		as_warn("Need " + it + " but buying is off" + (can_interact() ? " (autosea_buy)." : " (no mall access yet)."));
		return false;
	}
	int missing = qty - item_amount(it);
	int price = mall_price(it);
	if(npc_price(it) > 0 && (price <= 0 || npc_price(it) < price))
	{
		price = npc_price(it);	//an NPC store is cheaper, and KoLmafia buys from it first
	}
	if(price <= 0)
	{
		as_warn("Need " + it + " but KoLmafia found no mall price for it.");
		return false;
	}
	if(price > as_maxPrice())
	{
		as_warn("Need " + it + " but it costs about " + price + ", over autosea_maxPrice (" + as_maxPrice() + ").");
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

boolean as_sushiMatInstalled()
{
	return get_property("hasSushiMat").to_boolean() || (get_campground() contains $item[sushi-rolling mat]);
}

item as_hatredItem();

// fullness held back for quest steps that need to eat: the worktea clue (a self-rolled nigiri) is needed on
// every Scholar route, so hold room from the moment that route is planned until the clue is known
int as_fullnessReserve()
{
	if(get_property("dreadScroll7").to_int() != 0 || get_property("isMerkinHighPriest").to_boolean())
	{
		return 0;
	}
	string route = as_setting("deepcityPath", "auto");
	boolean scholar = route == "scholar" || (route == "auto" && as_hatredItem() != $item[none] && available_amount(as_hatredItem()) == 0);
	return scholar ? 2 : 0;
}

// ---------------------------------------------------------------- diet
// Spleen first and straight away (nothing waits on it): spleen items you own that give adventures, best per
// spleen first, then (farming for meat) a lustrous oyster egg. Never Instant Karma, never anything worth more
// than autosea_spleenMaxValue. Food and drink only when adventures run low, so organs stay open for quest steps:
// drinks in a batch under The Ode to Booze, food after, and 2 fullness kept for the worktea clue while it's needed.

float as_avgAdventures(item it)
{
	matcher m = create_matcher("(\\d+)(?:-(\\d+))?", it.adventures);
	if(!m.find())
	{
		return 0;
	}
	float low = m.group(1).to_float();
	float high = m.group(2) == "" ? low : m.group(2).to_float();
	return (low + high) / 2;
}

boolean as_spleenCandidate(item it, int room)
{
	if(it.spleen <= 0 || it.spleen > room || it.levelreq > my_level() || it == $item[Instant Karma])
	{
		return false;	//Instant Karma is worth more as Karma at ascension
	}
	if(it.notes.contains_text("Vampyre") || it.notes.contains_text("Zombie"))
	{
		return false;
	}
	int maxValue = as_setting("spleenMaxValue", "5000").to_int();
	return !it.tradeable || mall_price(it) <= maxValue;
}

// spleen items that give adventures and sell in quantity (4 spleen, 7-8 adventures each)
boolean[item] AS_SPLEEN_BUY = $items[strange paste, demonic paste, ectoplasmic paste, elemental paste, Crimbo paste,
	grim fairy tale, Unconscious Collective Dream Jar, powdered gold];

// the cheapest of those to buy, if its cost per adventure is below what a farm turn earns
item as_spleenToBuy(int room)
{
	if(!as_setting("buySpleen", "true").to_boolean() || !as_buyingAllowed())
	{
		return $item[none];
	}
	item best = $item[none];
	float bestCost = as_bestTurnValue();
	foreach it in AS_SPLEEN_BUY
	{
		if(it.spleen > room || it.levelreq > my_level() || as_avgAdventures(it) <= 0)
		{
			continue;
		}
		int price = mall_price(it);
		float perAdv = price / as_avgAdventures(it);
		if(price > 0 && price <= as_setting("spleenMaxValue", "5000").to_int() && perAdv < bestCost)
		{
			best = it;
			bestCost = perAdv;
		}
	}
	if(best != $item[none] && !as_acquire(1, best))
	{
		return $item[none];
	}
	return best;
}

boolean as_dietSpleen()
{
	if(!as_setting("diet", "true").to_boolean() || !as_setting("useSpleen", "true").to_boolean())
	{
		return false;
	}
	boolean acted = false;
	while(spleen_limit() - my_spleen_use() > 0)
	{
		int room = spleen_limit() - my_spleen_use();
		item best = $item[none];
		float bestRatio = 0;
		foreach it, n in get_inventory()
		{
			if(as_spleenCandidate(it, room) && as_avgAdventures(it) > 0
				&& (!it.tradeable || mall_price(it) / as_avgAdventures(it) < as_bestTurnValue()))
			{
				float ratio = as_avgAdventures(it) / it.spleen;
				if(ratio > bestRatio)
				{
					best = it;
					bestRatio = ratio;
				}
			}
		}
		location zone = get_property("autosea_lastFarmZone").to_location();
		if(best == $item[none] && as_setting("farmGoal", "both") != "stats" && room >= 1
			&& have_effect($effect[Lustre After Wealth]) == 0 && item_amount($item[lustrous oyster egg]) > 0
			&& as_worthBuff(as_costPerTurn($item[lustrous oyster egg], zone), zone))
		{
			best = $item[lustrous oyster egg];	//+50% Meat Drop for 50 turns
		}
		if(best == $item[none])
		{
			best = as_spleenToBuy(room);
		}
		if(best == $item[none])
		{
			break;
		}
		int before = my_spleen_use();
		chew(1, best);
		if(my_spleen_use() == before)
		{
			break;
		}
		acted = true;
	}
	return acted;
}

// the diet as a task of its own, first in the list: it has to run even when there are too few adventures
// left to adventure (that's exactly when food and drink are needed)
boolean as_dietTopUp();

boolean as_dietTask()
{
	boolean chewed = as_dietSpleen();
	boolean consumed = as_dietTopUp();
	return chewed || consumed;
}

// eat or drink when adventures run low; never touches the worktea fullness
boolean as_dietTopUp()
{
	if(!as_setting("diet", "true").to_boolean() || my_adventures() > as_advReserve() + as_setting("dietAt", "6").to_int())
	{
		return false;
	}
	//an adventure is only worth buying for less than a turn earns
	int maxPrice = min(as_setting("dietMaxPrice", "1000").to_int(), as_bestTurnValue() * 6);
	//drinks first, in a batch under The Ode to Booze
	item booze = as_setting("booze", "elemental caipiroska").to_item();
	int batch = as_setting("boozeBatch", "5").to_int();
	if(booze != $item[none] && booze.inebriety > 0 && inebriety_limit() - my_inebriety() >= booze.inebriety
		&& mall_price(booze) / max(1.0, as_avgAdventures(booze) + booze.inebriety) < as_bestTurnValue())
	{
		int drinks = min(batch, (inebriety_limit() - my_inebriety()) / booze.inebriety);
		if(as_fetch(drinks, booze) || (mall_price(booze) <= maxPrice && as_acquire(drinks, booze)) || item_amount(booze) > 0)
		{
			drinks = min(drinks, item_amount(booze));
			if(have_skill($skill[The Ode to Booze]) && as_skillFitsLimits($skill[The Ode to Booze]))
			{
				while(have_effect($effect[Ode to Booze]) < drinks * booze.inebriety && my_mp() >= mp_cost($skill[The Ode to Booze]))
				{
					int odeBefore = have_effect($effect[Ode to Booze]);
					use_skill(1, $skill[The Ode to Booze]);
					if(have_effect($effect[Ode to Booze]) == odeBefore)
					{
						break;
					}
				}
			}
			as_info("Drinking " + drinks + " " + booze + (have_effect($effect[Ode to Booze]) > 0 ? " under The Ode to Booze." : "."));
			drink(drinks, booze);
			return true;
		}
	}
	//then food, keeping fullness for quest steps
	item food = as_setting("food", "autumn-spice donut").to_item();
	int room = fullness_limit() - my_fullness() - as_fullnessReserve();
	if(food != $item[none] && food.fullness > 0 && room >= food.fullness && mall_price(food) / max(1.0, as_avgAdventures(food)) < as_bestTurnValue())
	{
		int meals = min(5, room / food.fullness);
		if(as_fetch(meals, food) || (mall_price(food) <= maxPrice && as_acquire(meals, food)) || item_amount(food) > 0)
		{
			meals = min(meals, item_amount(food));
			as_info("Eating " + meals + " " + food + ".");
			eat(meals, food);
			return true;
		}
	}
	return false;
}

// ---------------------------------------------------------------- Fishy (halves the cost of sea adventures)

void as_ensureFishy(location loc);

void as_ensureFishy()
{
	as_ensureFishy(get_property("autosea_lastFarmZone").to_location());
}

void as_ensureFishy(location loc)
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
	//sushi: 3 fullness of food you'd eat anyway, 7-12 adventures and 45 Fishy. Ingredients come from the mall
	//(fish meat ~100, seaweed ~140, white rice ~1000), which is far cheaper than farming fish meat underwater.
	if(as_setting("eatSushi", "true").to_boolean() && as_sushiMatInstalled() && fullness_limit() - my_fullness() - as_fullnessReserve() >= 3)
	{
		if(as_acquire(1, $item[beefy fish meat]) && as_acquire(1, $item[white rice]) && as_acquire(1, $item[seaweed]))
		{
			as_info("Rolling and eating a beefy maki for Fishy.");
			cli_execute("create 1 beefy maki");	//sushi is rolled and eaten in one step
			if(as_isFishy()) return;
			as_warn("Ate sushi but didn't get Fishy.");
		}
	}
	//sea jelly: 1 spleen for 10 Fishy turns, usually ~100 meat
	if(as_setting("useSpleen", "true").to_boolean() && spleen_limit() - my_spleen_use() >= 1)
	{
		//Fishy saves a whole adventure per sea turn, so it's worth up to that turn's value
		boolean jellyWorth = as_costPerTurn($item[sea jelly], loc) <= as_zoneWorth(loc);
		if(jellyWorth && (as_fetch(1, $item[sea jelly]) || (mall_price($item[sea jelly]) <= as_setting("fishyMaxPrice", "1000").to_int() && as_acquire(1, $item[sea jelly]))))
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
		//never spend stomach, liver or spleen on a boost (and never risk eating something like Instant Karma)
		if(entry.command.index_of("eat ") == 0 || entry.command.index_of("drink ") == 0 || entry.command.index_of("chew ") == 0)
		{
			continue;
		}
		if(entry.display.index_of("<font color=gray>") != -1)
		{
			continue;	//not available
		}
		if(!as_boostCommandOk(entry.command))
		{
			continue;
		}
		boolean ownSkill = entry.skill != $skill[none] && have_skill(entry.skill) && as_skillFitsLimits(entry.skill);
		boolean ownItem = entry.item != $item[none] && item_amount(entry.item) > 0;
		if(ownSkill || (ownItem && entry.skill == $skill[none]))
		{
			as_debug("boost: " + entry.command);
			as_runBoost(entry.command, entry.skill);
		}
	}
}

// one adventure in a sea zone, with Fishy and the right gear
// ---------------------------------------------------------------- dolphins
// Underwater, a dolphin can snatch a drop you just missed. A dolphin whistle (1 sand dollar from Big Brother)
// summons the thief, an easy fight on the surface that gives the item back, but costs an adventure. Only the
// last stolen item can be recovered, so chase straight away or not at all. Worth it when the item is worth
// more than the whistle plus the turn it takes (what a turn in the zone earns).
int as_whistleCost()
{
	//owned whistles count at mall value (they could be sold); otherwise the cheaper of the mall and Big Brother
	int mall = mall_price($item[dolphin whistle]);
	if(item_amount($item[dolphin whistle]) > 0 || closet_amount($item[dolphin whistle]) > 0)
	{
		return mall > 0 ? mall : 300;
	}
	return as_unitCost($item[dolphin whistle]);
}

boolean as_chaseDolphin(location loc)
{
	item stolen = get_property("dolphinItem").to_item();
	if(stolen == $item[none] || !as_setting("chaseDolphins", "true").to_boolean())
	{
		return false;
	}
	int value = as_dropValue(stolen);
	int cost = as_whistleCost() + as_zoneWorth(loc);
	if(value <= cost)
	{
		as_debug("A dolphin has your " + stolen + " (" + value + " meat): not worth a whistle and a turn (" + cost + ").");
		return false;
	}
	if(my_inebriety() > inebriety_limit() || !as_haveAdventures())
	{
		return false;
	}
	if(!as_acquire(1, $item[dolphin whistle]))
	{
		as_warn("A dolphin stole your " + stolen + " (" + value + " meat), but there's no dolphin whistle to get it back.");
		return false;
	}
	as_recover();
	as_info("A dolphin stole your " + stolen + " (about " + value + " meat). Whistling it back.");
	int before = item_amount(stolen);
	int meatBefore = my_meat();
	use(1, $item[dolphin whistle]);
	if(item_amount(stolen) > before)
	{
		//count the recovery as a turn in the zone it came from
		as_recordTurn(loc, value - as_whistleCost() + my_meat() - meatBefore);
		return true;
	}
	as_warn("The dolphin fight didn't return the " + stolen + ".");
	return false;
}

// after an adventure: chase a dolphin that stole something there
void as_afterSeaAdv()
{
	if(as_dolphinZone != $location[none])
	{
		location loc = as_dolphinZone;
		as_dolphinZone = $location[none];
		as_chaseDolphin(loc);
	}
}

boolean as_seaAdvOnce(location loc, string extraMaximize, string filter)
{
	as_dietSpleen();
	as_dietTopUp();
	as_ensureFishy(loc);
	if(extraMaximize.contains_text("combat"))
	{
		as_applyBoosts("-combat");
	}
	//pearl zones: push the zone's element resistance towards 18 before fighting
	if(as_pearlAvailable(loc))
	{
		set_location(loc);
		string gear = extraMaximize + (extraMaximize == "" ? "" : ", ") + as_pearlGear(loc);
		if(!as_equipForSea(gear))
		{
			return as_adv(loc, extraMaximize, filter);	//reports the breathing problem
		}
		as_pearlTopUp(loc);
		return as_adv(loc, "", filter);	//gear is on; don't re-maximize it away
	}
	return as_adv(loc, extraMaximize, filter);
}

boolean as_seaAdv(location loc, string extraMaximize, string filter)
{
	boolean ok = as_seaAdvOnce(loc, extraMaximize, filter);
	as_afterSeaAdv();
	return ok;
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

boolean as_helmetTried = false;

// Another breathing hat makes the aerated diving helmet redundant: the Mer-kin masks have the same stats.
boolean as_haveBreathingHat()
{
	foreach it in $items[Mer-kin gladiator mask, Mer-kin scholar mask, crappy Mer-kin mask]
	{
		if(available_amount(it) > 0)
		{
			return true;
		}
	}
	return false;
}

// Rusty diving helmet: craft it from parts if they're all held, else buy whichever is cheaper,
// the helmet or the missing parts (rusty rivets are the expensive bit).
boolean as_getRustyHelmet()
{
	if(available_amount($item[rusty diving helmet]) > 0)
	{
		return as_fetch(1, $item[rusty diving helmet]);
	}
	int missingRivets = max(0, 8 - available_amount($item[rusty rivet]));
	int partsCost = missingRivets * mall_price($item[rusty rivet])
		+ (available_amount($item[rusty porthole]) > 0 ? 0 : mall_price($item[rusty porthole]))
		+ (available_amount($item[rusty broken diving helmet]) > 0 ? 0 : mall_price($item[rusty broken diving helmet]));
	if(partsCost <= mall_price($item[rusty diving helmet]))
	{
		if(as_acquire(8, $item[rusty rivet]) && as_acquire(1, $item[rusty porthole]) && as_acquire(1, $item[rusty broken diving helmet]))
		{
			as_info("Assembling a rusty diving helmet from parts.");
			create(1, $item[rusty diving helmet]);
		}
		return item_amount($item[rusty diving helmet]) > 0;
	}
	return as_acquire(1, $item[rusty diving helmet]);
}

boolean as_helmet()
{
	if(as_helmetTried || available_amount($item[aerated diving helmet]) > 0)
	{
		return false;
	}
	//"true" (default): only when you have no other breathing hat; "force": always; "false": never
	string want = as_setting("helmet", "true");
	if(want == "false" || (want != "force" && as_haveBreathingHat()))
	{
		return false;
	}
	if(!as_fetch(1, $item[bubblin' stone]))
	{
		return false;	//comes from Big Brother on his first visit
	}
	as_helmetTried = true;	//one attempt per run, so a missing purchase doesn't repeat every turn
	if(!as_getRustyHelmet())
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
	//the roller skates' noncombats only happen with the blade in the main weapon slot
	as_mainWeapon = $item[skate blade];
	boolean acted = as_seaAdv($location[The Skate Park], gear + (gear == "" ? "" : ", ") + NC_HUNT);
	as_mainWeapon = $item[none];
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

// Grandpa's stories unlock monster drops that otherwise never drop. They persist across ascensions,
// so this only asks the ones not yet heard. Trophyfish is left out: it adds a very dangerous boss.
boolean[string] as_grandpaAsked;

boolean as_grandpaTopics()
{
	if(as_monkeeStep() < 5 || !as_setting("grandpaTopics", "true").to_boolean())
	{
		return false;
	}
	string[string] topics = {
		"grandpaUnlockedFishyWand": "wizardfish;avius ticklium",
		"grandpaUnlockedEelSauce": "eel",
		"grandpaUnlockedWaterPoloCap": "neptune flytrap",
		"grandpaUnlockedSeaRadish": "octopus",
		"grandpaUnlockedGlowingSyringe": "diver",
		"grandpaUnlockedJellyfishGel": "reef",
		"grandpaUnlockedWaterPoloMitt": "belle",
		"grandpaUnlockedHalibut": "fisherfish",
		"grandpaUnlockedMarineAquamarine": "mine",
		"grandpaUnlockedMidgetClownfish": "clownfish",
		"grandpaUnlockedHairOfTheFish": "lounge lizardfish",
		"grandpaUnlockedBlankPrescriptionSheet": "nurse shark",
		"grandpaUnlockedHeavilyInvestedInPunFutures": "scales",
		"grandpaUnlockedGroupieSpangles": "groupie"
	};
	foreach prop, words in topics
	{
		if(get_property(prop).to_boolean() || (as_grandpaAsked contains prop))
		{
			continue;
		}
		as_grandpaAsked[prop] = true;
		foreach i, topic in words.split_string(";")
		{
			as_info("Asking Grandpa about " + topic + ".");
			cli_execute("grandpa " + topic);
		}
		return true;
	}
	return false;
}

// the Midget Clownfish (an underwater familiar) only drops at 1% after Grandpa's clownfish story; buying the hatchling is practical
boolean as_clownfishTried = false;

boolean as_clownfish()
{
	if(as_clownfishTried || have_familiar($familiar[Midget Clownfish]) || !as_setting("clownfish", "true").to_boolean())
	{
		return false;
	}
	as_clownfishTried = true;
	if(!as_acquire(1, $item[midget clownfish]))
	{
		return false;
	}
	as_info("Hatching the midget clownfish.");
	use(1, $item[midget clownfish]);
	return true;
}

// ---------------------------------------------------------------- the seahorse
// Chain: Mer-kin lockkey (Outpost burglar/raider/healer drop) -> "Into the Outpost" noncombat -> Mer-kin stashbox
// -> Mer-kin trailmap -> Intense Currents -> "grandpa currents" opens the Coral Corral. Meanwhile throw a sea lasso
// in underwater fights until expert (lassoTrainingCount 20; sea chaps make each throw count double). In the Corral,
// ring 3 sea cowbells at the wild seahorse, then lasso it: taming costs no adventure.

boolean as_wantSeahorse()
{
	return get_property("seahorseName") == "" && as_monkeeStep() >= 999 && as_setting("seahorse", "true").to_boolean();
}

boolean as_lassoExpert()
{
	return get_property("lassoTrainingCount").to_int() >= 20;
}

int as_cowbellsThisFight = 0;

// combat filter for the seahorse chain: tame the seahorse, otherwise practise with a lasso once per fight
string as_seahorseFilter(int round, monster enemy, string text)
{
	if(round <= 1)
	{
		as_cowbellsThisFight = 0;
	}
	if(enemy == $monster[wild seahorse])
	{
		if(!as_lassoExpert() || item_amount($item[sea lasso]) == 0)
		{
			return "runaway";	//it's immune to damage; come back once the lasso is expert
		}
		if(as_cowbellsThisFight < 3 && item_amount($item[sea cowbell]) > 0)
		{
			as_cowbellsThisFight += 1;
			return "item sea cowbell";
		}
		return "item sea lasso";
	}
	if(round <= 1 && !as_lassoExpert() && item_amount($item[sea lasso]) > 0)
	{
		return "item sea lasso";
	}
	return "";
}

// breathing that doesn't need the hat slot: an effect that's already running (never bought or used for this),
// or non-hat breathing gear you own
boolean as_breathingWithoutHat()
{
	foreach eff in $effects[Driving Waterproofly, Hyperoxygenated Blood, Mer-kinny Flavor, Oxygenated Blood, Pneumatic, Pumped Stomach, Really Deep Breath]
	{
		if(have_effect(eff) > 0)
		{
			return true;
		}
	}
	foreach it in $items[old SCUBA tank, makeshift SCUBA gear, Elf Guard SCUBA tank]
	{
		if(available_amount(it) > 0 && can_equip(it))
		{
			return true;
		}
	}
	return false;
}

string as_seahorseGear()
{
	if(as_lassoExpert())
	{
		return "";
	}
	//sea chaps and the sea cowboy hat each add a point per lasso throw. The hat takes the breathing hat slot,
	//so it's only worn when breathing is already covered some other way.
	string gear = available_amount($item[sea chaps]) > 0 ? "+equip sea chaps" : "";
	//tempura air (Pumped Stomach: 20 turns of breathing, no organ, untradeable) frees the hat slot for the
	//whole of lasso practice. Only air you already own: batter sells for far more than it saves.
	if(available_amount($item[sea cowboy hat]) > 0 && !as_breathingWithoutHat() && as_setting("useTempuraAir", "true").to_boolean()
		&& as_fetch(1, $item[tempura air]))
	{
		as_info("Using a tempura air so the sea cowboy hat can join lasso practice.");
		use(1, $item[tempura air]);
	}
	if(available_amount($item[sea cowboy hat]) > 0 && as_breathingWithoutHat())
	{
		gear += (gear == "" ? "" : ", ") + "+equip sea cowboy hat";
	}
	return gear;
}

boolean as_seahorse()
{
	if(!as_wantSeahorse())
	{
		return false;
	}
	//Coral Corral open: tame the seahorse once the lasso is expert
	if(get_property("corralUnlocked").to_boolean())
	{
		if(!as_lassoExpert())
		{
			as_info("Practising with the sea lasso (" + get_property("lassoTrainingCount") + "/20) in the Briny Deeps.");
			return as_seaAdv($location[The Briny Deeps], as_seahorseGear(), "as_seahorseFilter");
		}
		if(!as_acquire(3, $item[sea cowbell]) || !as_acquire(1, $item[sea lasso]))
		{
			as_warn("Need 3 sea cowbells and a sea lasso to tame the seahorse.");
			return false;
		}
		as_info("Looking for the wild seahorse in the Coral Corral.");
		return as_seaAdv($location[The Coral Corral], "", "as_seahorseFilter");
	}
	if(get_property("intenseCurrents").to_boolean())
	{
		as_info("Asking Grandpa about the currents to open the Coral Corral.");
		cli_execute("grandpa currents");
		return true;
	}
	if(as_fetch(1, $item[Mer-kin trailmap]))
	{
		as_info("Following the Mer-kin trailmap to the Intense Currents.");
		use(1, $item[Mer-kin trailmap]);
		return true;
	}
	if(as_fetch(1, $item[Mer-kin stashbox]))
	{
		as_info("Opening the Mer-kin stashbox.");
		use(1, $item[Mer-kin stashbox]);
		return true;
	}
	//the Outpost: fight for the lockkey, then hunt the "Into the Outpost" noncombat for the stashbox
	if(item_amount($item[Mer-kin lockkey]) > 0)
	{
		as_info("Looking for the Mer-kin stashbox in the Outpost (lockkey from " + get_property("merkinLockkeyMonster") + ").");
		return as_seaAdv($location[The Mer-Kin Outpost], NC_HUNT + (as_seahorseGear() == "" ? "" : ", " + as_seahorseGear()), "as_seahorseFilter");
	}
	as_info("Fighting in the Mer-Kin Outpost for a Mer-kin lockkey (lasso practice " + get_property("lassoTrainingCount") + "/20).");
	return as_seaAdv($location[The Mer-Kin Outpost], as_seahorseGear(), "as_seahorseFilter");
}

// this class's Temple reward on the Scholar route (Yog-Urt)
item as_hatredItem()
{
	switch(my_class())
	{
		case $class[Seal Clubber]: return $item[Cold Stone of Hatred];
		case $class[Turtle Tamer]: return $item[Girdle of Hatred];
		case $class[Pastamancer]: return $item[Staff of Simmering Hatred];
		case $class[Sauceror]: return $item[Pantaloons of Hatred];
		case $class[Disco Bandit]: return $item[Fuzzy Slippers of Hatred];
		case $class[Accordion Thief]: return $item[Lens of Hatred];
	}
	return $item[none];
}

// ---------------------------------------------------------------- engine hooks

string[int] AS_TASKS;
AS_TASKS[0] = "as_dietTask";
AS_TASKS[1] = "as_oldMan";
AS_TASKS[2] = "as_sushiMat";
AS_TASKS[3] = "as_clownfish";
AS_TASKS[4] = "as_littleBrother";
AS_TASKS[5] = "as_bigBrother";
AS_TASKS[6] = "as_fishyPipe";
AS_TASKS[7] = "as_helmet";
AS_TASKS[8] = "as_skatePark";
AS_TASKS[9] = "as_grandpa";
AS_TASKS[10] = "as_grandpaTopics";
AS_TASKS[11] = "as_grandma";
AS_TASKS[12] = "as_mom";
AS_TASKS[13] = "as_seahorse";
AS_TASKS[14] = "as_schoolGear";		//defined in deepcity.ash
AS_TASKS[15] = "as_merkinVocab";
AS_TASKS[16] = "as_workteaClue";
AS_TASKS[17] = "as_merkinLibrary";
AS_TASKS[18] = "as_readDreadscroll";
AS_TASKS[19] = "as_yogUrt";

string[int] as_taskOrder()
{
	return AS_TASKS;
}

string as_stateSignature()
{
	string sig = my_adventures() + "|" + my_fullness() + "|" + my_inebriety() + "|" + my_spleen_use() + "|";
	foreach prop in $strings[questS01OldGuy, questS02Monkees, bigBrotherRescued, dampOldBootPurchased, hasSushiMat, mapToTheSkateParkPurchased, skateParkStatus, momSeaMonkeeProgress, intenseCurrents, corralUnlocked, seahorseName, lassoTrainingCount, merkinVocabularyMastery, merkinElementaryTeacherUnlock, dreadScroll1, dreadScroll2, dreadScroll5, dreadScroll6, dreadScroll7, dreadScroll8, merkinCatalogChoices, merkinQuestPath, isMerkinHighPriest, yogUrtDefeated, autosea_dreadGuesses]
	{
		sig += get_property(prop) + "|";
	}
	foreach it in $items[sand dollar, wriggling flytrap pellet, bubblin' stone, rusty diving helmet, aerated diving helmet, damp old boot, fishy pipe, das boot, sushi-rolling mat, skate blade, Grandma's Note, Grandma's Fuchsia Yarn, Grandma's Chartreuse Yarn, Grandma's Map, black glass, scale-mail underwear, shark jumper, comb jelly, Mer-kin lockkey, Mer-kin stashbox, Mer-kin trailmap, Mer-kin facecowl, Mer-kin waistrope, Mer-kin cheatsheet, Mer-kin wordquiz, Mer-kin worktea, Mer-kin dreadscroll, Mer-kin healscroll, Mer-kin killscroll]
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
	line("Midget Clownfish", have_familiar($familiar[Midget Clownfish]));
	line("Seahorse" + (get_property("seahorseName") != "" ? " (" + get_property("seahorseName") + ")"
		: " (Corral " + (get_property("corralUnlocked").to_boolean() ? "open" : "closed") + ", lasso " + get_property("lassoTrainingCount") + "/20)"),
		get_property("seahorseName") != "");
	if(get_property("seahorseName") != "")
	{
		print("Deepcity:", "blue");
		line("Scholar's Vestments" + (have_outfit("Mer-kin Scholar's Vestments") ? "" : " (needs the facecowl/waistrope route)"),
			have_outfit("Mer-kin Scholar's Vestments"));
		line("Vocabulary " + get_property("merkinVocabularyMastery") + "% (cheatsheets " + available_amount($item[Mer-kin cheatsheet]) + ")",
			get_property("merkinVocabularyMastery").to_int() >= 100);
		line("Worktea clue", get_property("dreadScroll7").to_int() != 0);
		line("Mer-kin dreadscroll", available_amount($item[Mer-kin dreadscroll]) > 0);
		string clues = "";
		for n from 1 to 8
		{
			clues += get_property("dreadScroll" + n).to_int() != 0 ? " " + n : "";
		}
		print("  Dreadscroll clues known:" + (clues == "" ? " none" : clues) + " (the Library gives 1, 2, 5, 6, 8)", "black");
		line("Mer-kin High Priest", get_property("isMerkinHighPriest").to_boolean());
		line("Yog-Urt (" + as_hatredItem() + ")", get_property("yogUrtDefeated").to_boolean() || available_amount(as_hatredItem()) > 0);
	}
	print("Pearls found today:", "blue");
	foreach loc in $locations[The Briniest Deepests, The Marinara Trench, Anemone Mine, Madness Reef, The Dive Bar]
	{
		line(loc + " (" + as_pearlElement(loc) + ", resistance " + as_resistance(as_pearlElement(loc)) + ")", !as_pearlAvailable(loc));
	}
	print("Fishy: " + have_effect($effect[Fishy]) + " turns. Adventures: " + my_adventures() + ".", "blue");
}
