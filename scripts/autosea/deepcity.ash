// autosea Deepcity, stage 1: the Mer-kin Elementary School (facecowl, waistrope, cheatsheets), vocabulary,
// and the worktea clue. Needs a tamed seahorse. The Library, the dreadscroll and the boss come later.
//
// One Temple boss per ascension, and its reward depends on class. The Scholar route (Yog-Urt) gives the
// class's "of Hatred" piece; autosea picks it when you don't have this class's piece yet.

import <autosea/tasks.ash>

boolean as_libraryCluesDone();	//defined with the Library stage below

boolean as_deepcityOpen()
{
	return get_property("seahorseName") != "" && get_property("merkinQuestPath") != "done";
}


// "scholar", "gladiator" or "none". auto: scholar when this class's Hatred piece is missing.
string as_deepcityPath()
{
	string route = as_setting("deepcityPath", "auto");
	if(route != "auto")
	{
		return route;
	}
	item hatred = as_hatredItem();
	return hatred != $item[none] && available_amount(hatred) == 0 ? "scholar" : "none";
}

// ---------------------------------------------------------------- the School

// The facecowl and waistrope are only ingredients: Grandma makes the scholar mask from a crappy Mer-kin mask
// plus a facecowl, and the scholar tailpiece from a crappy tailpiece plus a waistrope. So they're only
// farmed when the Scholar route needs a Scholar's Vestments piece you don't have.
boolean as_needFacecowl()
{
	return available_amount($item[Mer-kin scholar mask]) == 0 && available_amount($item[Mer-kin facecowl]) == 0;
}

boolean as_needWaistrope()
{
	return available_amount($item[Mer-kin scholar tailpiece]) == 0 && available_amount($item[Mer-kin waistrope]) == 0;
}

boolean as_wantSchoolGear()
{
	return as_setting("schoolGear", "true").to_boolean() && as_deepcityPath() == "scholar" && (as_needFacecowl() || as_needWaistrope());
}

// olfact the Mer-kin monitor (the only cheatsheet source) so it turns up more often
string as_schoolFilter(int round, monster enemy, string text)
{
	if(round <= 1 && enemy == $monster[Mer-kin monitor] && get_property("olfactedMonster") != "Mer-kin monitor"
		&& as_setting("olfactMonitor", "true").to_boolean() && have_skill($skill[Transcendent Olfaction])
		&& get_property("_olfactionsUsed").to_int() < 3 && my_mp() >= mp_cost($skill[Transcendent Olfaction]) + 20)
	{
		return "skill Transcendent Olfaction";
	}
	return "";
}

// Raising Cane (teacher's lounge) gives the facecowl, then the waistrope. They only drop while the matching
// Scholar's Vestments piece isn't in inventory, which is always true here: we only come for a missing piece.
boolean as_schoolGear()
{
	if(!as_deepcityOpen() || !as_wantSchoolGear())
	{
		return false;
	}
	string disguise = "+outfit Mer-kin Gladiatorial Gear";
	if(!have_outfit("Mer-kin Gladiatorial Gear"))
	{
		disguise = have_outfit("Crappy Mer-kin Disguise") ? "+outfit Crappy Mer-kin Disguise" : "";
	}
	if(disguise == "")
	{
		as_warn("The School needs a Mer-kin disguise other than the Scholar's Vestments for the facecowl and waistrope.");
		return false;
	}
	as_info("Mer-kin Elementary School: teacher's lounge for the " + (as_needFacecowl() ? "facecowl" : "waistrope")
		+ " (needed for the Scholar's Vestments; monitors may drop cheatsheets).");
	return as_seaAdv($location[Mer-kin Elementary School], disguise + ", " + NC_HUNT, "as_schoolFilter");
}

// ---------------------------------------------------------------- vocabulary

// each wordquiz used with a cheatsheet in inventory adds 10% (10 uses to 100%)
boolean as_merkinVocab()
{
	if(!as_deepcityOpen() || as_deepcityPath() != "scholar")
	{
		return false;
	}
	int target = as_setting("vocabTarget", "100").to_int();
	if(get_property("merkinVocabularyMastery").to_int() >= target)
	{
		return false;
	}
	//use cheatsheets found in the School while it's being visited anyway; otherwise buy (it's the only source)
	if(!as_fetch(1, $item[Mer-kin cheatsheet]))
	{
		if(as_wantSchoolGear())
		{
			return false;
		}
		if(!as_acquire(1, $item[Mer-kin cheatsheet]))
		{
			return false;
		}
	}
	if(!as_acquire(1, $item[Mer-kin wordquiz]))
	{
		return false;
	}
	as_info("Studying a Mer-kin wordquiz (vocabulary " + get_property("merkinVocabularyMastery") + "%).");
	use(1, $item[Mer-kin wordquiz]);
	return true;
}

// ---------------------------------------------------------------- dreadscroll clue 7: the worktea

// eating sushi you rolled yourself with a Mer-kin worktea in inventory reveals one dreadscroll clue
boolean as_workteaTried = false;

boolean as_workteaClue()
{
	//doesn't need the Deepcity or the dreadscroll: do it as soon as the Scholar route is planned and there's room
	if(as_workteaTried || as_deepcityPath() != "scholar" || get_property("dreadScroll7").to_int() != 0
		|| get_property("isMerkinHighPriest").to_boolean() || get_property("questS02Monkees") != "finished")
	{
		return false;
	}
	if(!as_sushiMatInstalled())
	{
		return false;
	}
	if(fullness_limit() - my_fullness() < 2)
	{
		//needs room for a nigiri. Fullness comes back at rollover, so put today's turns to use meanwhile;
		//tomorrow this runs before farm mode's sushi diet fills the stomach.
		if(as_libraryCluesDone() && as_setting("farmWhileWaiting", "true").to_boolean())
		{
			as_info("Waiting for the worktea clue: it needs 2 free fullness, which comes back at rollover. Run autosea again tomorrow before eating.");
			as_waitTurns = max(0, my_adventures() - as_advReserve());
		}
		return false;
	}
	as_workteaTried = true;
	if(!as_acquire(1, $item[Mer-kin worktea]) || !as_acquire(1, $item[beefy fish meat]) || !as_acquire(1, $item[white rice]))
	{
		return false;
	}
	as_info("Eating sushi with a Mer-kin worktea for a dreadscroll clue.");
	cli_execute("create 1 beefy nigiri");
	return true;
}

// ---------------------------------------------------------------- the Library: dreadscroll and clues
// In Scholar's Vestments. The 6th Library encounter gives the Mer-kin dreadscroll. With it in hand:
//   clue 2: use a Mer-kin healscroll in a fight (reveal chance rises with vocabulary)
//   clue 5: use a Mer-kin killscroll in a fight
//   clues 1, 6, 8: Catalog Card books (choice 704, answered in choice.ash)
// Clues 3 (Deep Dark Visions) and 4 (Mer-kin knucklebone) aren't farmed; stage 3 guesses them.

boolean as_clueKnown(int n)
{
	return get_property("dreadScroll" + n).to_int() != 0;
}

// clues the Library can give
boolean as_libraryCluesDone()
{
	return as_clueKnown(1) && as_clueKnown(2) && as_clueKnown(5) && as_clueKnown(6) && as_clueKnown(8);
}

string as_libraryFilter(int round, monster enemy, string text)
{
	if(item_amount($item[Mer-kin dreadscroll]) == 0 || round > 1)
	{
		return "";
	}
	//the healscroll heals the monster, so it goes first; the killscroll finishes most Mer-kin outright
	if(!as_clueKnown(2) && item_amount($item[Mer-kin healscroll]) > 0)
	{
		return "item Mer-kin healscroll";
	}
	if(!as_clueKnown(5) && item_amount($item[Mer-kin killscroll]) > 0)
	{
		return "item Mer-kin killscroll";
	}
	return "";
}

boolean as_merkinLibrary()
{
	if(!as_deepcityOpen() || as_deepcityPath() != "scholar" || get_property("isMerkinHighPriest").to_boolean())
	{
		return false;
	}
	//vocabulary first: it trims the Catalog Card to the clue books and raises the scroll reveal chances
	if(get_property("merkinVocabularyMastery").to_int() < as_setting("vocabTarget", "100").to_int())
	{
		return false;
	}
	if(item_amount($item[Mer-kin dreadscroll]) > 0 && as_libraryCluesDone())
	{
		return false;
	}
	if(!have_outfit("Mer-kin Scholar's Vestments"))
	{
		as_warn("The Mer-kin Library needs the Mer-kin Scholar's Vestments.");
		return false;
	}
	string goal = item_amount($item[Mer-kin dreadscroll]) == 0 ? "the dreadscroll" : "dreadscroll clues";
	as_info("Mer-kin Library: looking for " + goal + ".");
	return as_seaAdv($location[Mer-kin Library], "+outfit Mer-kin Scholar's Vestments", "as_libraryFilter");
}

// ---------------------------------------------------------------- stage 3a: reading the dreadscroll
// Fill in every known clue and guess the rest. Each wrong read costs a turn plus Deep-Tainted Mind
// (about 3 turns per wrong phrase) before you can read again. The effect's length tells how many phrases
// were wrong, so each new guess is chosen to agree with every earlier result (like Mastermind).
// Guesses are stored in autosea_dreadGuesses as "12341234:wrong,...".

int as_deepTaintedTurns()
{
	return have_effect($effect[Deep-Tainted Mind]);
}

int[int] as_dreadDigits(string s)
{
	int[int] d;
	for i from 0 to 7
	{
		d[i + 1] = s.char_at(i).to_int();
	}
	return d;
}

// the first full answer consistent with known clues and every earlier wrong read
string as_nextDreadGuess()
{
	int[int] known;
	int[int] unknown;
	for n from 1 to 8
	{
		known[n] = get_property("dreadScroll" + n).to_int();
		if(known[n] == 0)
		{
			unknown[count(unknown)] = n;
		}
	}
	string[int] history = get_property("autosea_dreadGuesses").split_string(",");
	int k = count(unknown);
	int combos = 1;
	for i from 1 to k
	{
		combos *= 4;
	}
	for c from 0 to combos - 1
	{
		int[int] answer;
		foreach n, v in known
		{
			answer[n] = v;
		}
		int rest = c;
		foreach i, n in unknown
		{
			answer[n] = rest % 4 + 1;
			rest = rest / 4;
		}
		boolean consistent = true;
		foreach i, entry in history
		{
			string[int] parts = entry.split_string(":");
			if(count(parts) < 2 || length(parts[0]) != 8)
			{
				continue;
			}
			int[int] g = as_dreadDigits(parts[0]);
			int differ = 0;
			for n from 1 to 8
			{
				if(g[n] != answer[n])
				{
					differ += 1;
				}
			}
			if(differ != parts[1].to_int())
			{
				consistent = false;
				break;
			}
		}
		if(consistent)
		{
			string s = "";
			for n from 1 to 8
			{
				s += answer[n];
			}
			return s;
		}
	}
	return "";
}

// set when autosea must wait (e.g. Deep-Tainted Mind) and the quest loop should farm meanwhile
boolean as_readDreadscroll()
{
	if(!as_deepcityOpen() || as_deepcityPath() != "scholar" || get_property("isMerkinHighPriest").to_boolean())
	{
		return false;
	}
	if(item_amount($item[Mer-kin dreadscroll]) == 0 || !as_libraryCluesDone())
	{
		return false;
	}
	//clues you can simply look up: a Mer-kin knucklebone gives clue 4 (it's used up; autosea_keepKnucklebones
	//holds some back, e.g. for an 11,037 Leagues run), and Deep Dark Visions gives clue 3 even if its damage
	//beats you up
	item bone = $item[Mer-kin knucklebone];
	if(!as_clueKnown(4) && available_amount(bone) > as_setting("keepKnucklebones", "0").to_int() && as_fetch(1, bone))
	{
		as_info("Using a Mer-kin knucklebone for dreadscroll clue 4.");
		use(1, bone);
	}
	if(!as_clueKnown(3) && have_skill($skill[Deep Dark Visions]) && my_mp() >= mp_cost($skill[Deep Dark Visions]))
	{
		as_info("Casting Deep Dark Visions for dreadscroll clue 3.");
		as_recover();
		use_skill(1, $skill[Deep Dark Visions]);
		as_recover();
	}
	//the worktea clue cuts 64 combinations to 16; wait for it unless told not to
	if(!as_clueKnown(7) && !as_setting("readWithoutWorktea", "false").to_boolean())
	{
		return false;
	}
	if(as_deepTaintedTurns() > 0)
	{
		as_waitTurns = as_deepTaintedTurns();
		as_info("Deep-Tainted Mind for " + as_waitTurns + " more turns before the dreadscroll can be read again.");
		return false;
	}
	if(my_adventures() < 3)
	{
		return false;
	}
	string guess = as_nextDreadGuess();
	if(guess == "")
	{
		as_warn("No dreadscroll answer fits the known clues and earlier reads; check the dreadScroll settings.");
		return false;
	}
	as_ensureFishy();	//a wrong read costs 2 turns without Fishy
	as_info("Reading the Mer-kin dreadscroll: " + guess + ".");
	visit_url("inv_use.php?pwd&which=3&whichitem=" + $item[Mer-kin dreadscroll].to_int());
	string url = "choice.php?pwd&whichchoice=703&option=1";
	for n from 1 to 8
	{
		url += "&pro" + n + "=" + guess.char_at(n - 1);
	}
	visit_url(url);
	if(get_property("isMerkinHighPriest").to_boolean())
	{
		as_info("You're the Mer-kin High Priest now.");
		return true;
	}
	int taint = as_deepTaintedTurns();
	int wrong = taint > 0 ? (taint + 1) / 3 : 0;
	if(wrong == 0)
	{
		as_warn("The dreadscroll read didn't give a result autosea recognises; stopping the guessing.");
		set_property("autosea_readWithoutWorktea", "false");
		return false;
	}
	string history = get_property("autosea_dreadGuesses");
	set_property("autosea_dreadGuesses", (history == "" ? "" : history + ",") + guess + ":" + wrong);
	as_info(wrong + " phrase" + (wrong == 1 ? " was" : "s were") + " wrong; next guess after Deep-Tainted Mind wears off.");
	return true;
}

// ---------------------------------------------------------------- stage 3b: Yog-Urt
// Yog-Urt: 750 HP, physical-immune, stun-immune. Her More Like a Suckrament lasts 8 rounds minus one per
// equipped Mer-kin prayerbeads (5 with 3 beads). While it lasts: skills are disabled, base stats are capped at
// 30, you lose 80-90% of your HP each round, and ANY damage to her (yours or your familiar's) kills you.
// So: no familiar, no damage-dealing effects or gear, a different healing item each round (each combat item
// can only be used once in the fight), then spells once the Suckrament ends.

effect[int] AS_DAMAGE_EFFECTS;
AS_DAMAGE_EFFECTS[0] = $effect[Scarysauce];
AS_DAMAGE_EFFECTS[1] = $effect[Jalape&ntilde;o Saucesphere];
AS_DAMAGE_EFFECTS[2] = $effect[Spiky Shell];
AS_DAMAGE_EFFECTS[3] = $effect[Psalm of Pointiness];
AS_DAMAGE_EFFECTS[4] = $effect[Mayeaugh];
AS_DAMAGE_EFFECTS[5] = $effect[Feeling Nervous];

// healing items in preference order, with the least they restore (99999 = full HP)
int[item] AS_YOG_HEALERS;
AS_YOG_HEALERS[$item[Mer-kin healscroll]] = 99999;
AS_YOG_HEALERS[$item[soggy used band-aid]] = 99999;
AS_YOG_HEALERS[$item[red pixel potion]] = 100;
AS_YOG_HEALERS[$item[filthy poultice]] = 80;
AS_YOG_HEALERS[$item[gauze garter]] = 80;
AS_YOG_HEALERS[$item[Doc Galaktik's Ailment Ointment]] = 35;

boolean[item] as_yogUsed;
boolean as_yogLost = false;

int as_beadsWorn()
{
	int n = 0;
	foreach s in $slots[acc1, acc2, acc3]
	{
		if(equipped_item(s) == $item[Mer-kin prayerbeads])
		{
			n += 1;
		}
	}
	return n;
}

string as_yogFilter(int round, monster enemy, string text)
{
	int suckrament = 8 - as_beadsWorn();
	if(round <= suckrament)
	{
		//heal with an unused item that covers the damage; never anything that deals damage
		int need = my_maxhp() - my_hp();
		item best = $item[none];
		foreach it, minRestore in AS_YOG_HEALERS
		{
			if(!(as_yogUsed contains it) && item_amount(it) > 0 && minRestore >= need)
			{
				best = it;
				break;
			}
		}
		if(best == $item[none])
		{
			foreach it, minRestore in AS_YOG_HEALERS
			{
				if(!(as_yogUsed contains it) && item_amount(it) > 0)
				{
					best = it;
					break;
				}
			}
		}
		if(best == $item[none])
		{
			return "abort";	//nothing safe left to do
		}
		as_yogUsed[best] = true;
		//", none": exactly one item. With Funkslinging, KoLmafia would otherwise add a second copy (each item only
		//works once this fight) or a damage item such as a seal tooth, which kills you during the Suckrament.
		return "item " + best + ", none";
	}
	foreach sk in $skills[Saucegeyser, Weapon of the Pastalord, Saucestorm, Cannelloni Cannon, Stream of Sauce]
	{
		if(have_skill(sk) && my_mp() >= mp_cost(sk))
		{
			return "skill " + sk;
		}
	}
	return "";
}

// everything checked before entering; returns a reason it isn't safe, or ""
string as_yogProblem()
{
	if(my_familiar() != $familiar[none])
	{
		return "a familiar is out";
	}
	foreach i, eff in AS_DAMAGE_EFFECTS
	{
		if(have_effect(eff) > 0)
		{
			return eff + " is active";
		}
	}
	foreach mod in $strings[Damage Aura, Sporadic Damage Aura, Thorns]
	{
		if(numeric_modifier(mod) != 0)
		{
			return "your gear or effects have " + mod;
		}
	}
	if(as_beadsWorn() < 3)
	{
		return "fewer than 3 Mer-kin prayerbeads are worn";
	}
	if(!have_outfit("Mer-kin Scholar's Vestments") || !is_wearing_outfit("Mer-kin Scholar's Vestments"))
	{
		return "the Mer-kin Scholar's Vestments aren't worn";
	}
	//the Suckrament caps base stats at 30 and makes you lose 80-90% of max HP each round, so max HP in the fight is
	//about 33 plus what gear and effects add; each round needs a different healer covering that loss
	int fightHP = 33 + max(0, numeric_modifier("Maximum HP").to_int());
	int loss = ceil(0.9 * fightHP);
	int healers = 0;
	foreach it, minRestore in AS_YOG_HEALERS
	{
		if(item_amount(it) > 0 && minRestore >= loss)
		{
			healers += 1;
		}
	}
	if(healers < 8 - as_beadsWorn())
	{
		return "max HP in the fight would be about " + fightHP + " (a loss of up to " + loss + " a round), and only " + healers
			+ " different healing items restore that much (need " + (8 - as_beadsWorn()) + "). Take off +HP gear, or get more healers";
	}
	return "";
}

boolean as_yogUrt()
{
	if(as_yogLost || !as_deepcityOpen() || !get_property("isMerkinHighPriest").to_boolean() || get_property("yogUrtDefeated").to_boolean())
	{
		return false;
	}
	string mode = as_setting("yogUrt", "true");
	if(mode == "false")
	{
		return false;
	}
	//prepare: no familiar, no damage sources, Scholar's Vestments plus 3 prayerbeads, healers in hand
	use_familiar($familiar[none]);
	foreach i, eff in AS_DAMAGE_EFFECTS
	{
		if(have_effect(eff) > 0)
		{
			cli_execute("uneffect " + eff);
		}
	}
	as_fetch(1, $item[soggy used band-aid]);
	if(item_amount($item[soggy used band-aid]) == 0 && shop_amount($item[soggy used band-aid]) > 0)
	{
		take_shop(1, $item[soggy used band-aid]);
	}
	as_acquire(3, $item[Mer-kin prayerbeads]);
	//as little max HP as possible (the Suckrament's self-damage is a share of it), a little MP for spells afterwards
	maximize("sea, -2 hp, -1 muscle, 0.2 mp, +outfit Mer-kin Scholar's Vestments, -familiar", false);
	foreach s in $slots[acc1, acc2, acc3]
	{
		equip(s, $item[Mer-kin prayerbeads]);
	}
	restore_mp(min(my_maxmp(), 200));
	restore_hp(my_maxhp());
	string problem = as_yogProblem();
	if(problem != "")
	{
		as_warn("Not fighting Yog-Urt yet: " + problem + ".");
		return false;
	}
	if(mode == "dryrun")
	{
		as_info("Yog-Urt dry run: ready. Healers in order: " + count(AS_YOG_HEALERS) + " kinds checked, " + (8 - as_beadsWorn())
			+ " rounds of Suckrament, then spells. Set autosea_yogUrt = true to fight.");
		return false;
	}
	as_ensureFishy();
	as_info("Entering the Mer-kin Temple to face Yog-Urt.");
	//take the Temple choices here, so the fight is always run with as_yogFilter, never handed to a CCS
	string choiceScript = get_property("choiceAdventureScript");
	set_property("choiceAdventureScript", "");
	clear(as_yogUsed);	//each healing item works once per fight
	visit_url("sea_merkin.php?action=temple");
	//Temple choices 710 (Enter), 711 (Drink), 712 (IÄ YOG-URT!) lead into the fight; 713 after it
	for i from 1 to 4
	{
		if(handling_choice() && $ints[710, 711, 712] contains last_choice())
		{
			//false: don't let KoLmafia fight the combat these lead into with your normal combat settings (an attack
			//during the Suckrament kills you); the fight is run below with as_yogFilter
			run_choice(1, false);
		}
	}
	if(current_round() > 0)
	{
		run_combat("as_yogFilter");
	}
	if(handling_choice() && last_choice() == 713)
	{
		run_choice(1);
	}
	set_property("choiceAdventureScript", choiceScript);
	if(get_property("yogUrtDefeated").to_boolean() || available_amount(as_hatredItem()) > 0)
	{
		as_info("Yog-Urt is defeated.");
		return true;
	}
	as_yogLost = true;
	as_warn("The Yog-Urt fight didn't end in a win. Not trying again this run; check the CLI and session log.");
	return true;
}
