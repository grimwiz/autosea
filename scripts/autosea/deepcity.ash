// autosea Deepcity, stage 1: the Mer-kin Elementary School (facecowl, waistrope, cheatsheets), vocabulary,
// and the worktea clue. Needs a tamed seahorse. The Library, the dreadscroll and the boss come later.
//
// One Temple boss per ascension, and its reward depends on class. The Scholar route (Yog-Urt) gives the
// class's "of Hatred" piece; autosea picks it when you don't have this class's piece yet.

import <autosea/tasks.ash>

boolean as_deepcityOpen()
{
	return get_property("seahorseName") != "" && get_property("merkinQuestPath") != "done";
}

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
	if(as_workteaTried || !as_deepcityOpen() || as_deepcityPath() != "scholar" || get_property("dreadScroll7").to_int() != 0)
	{
		return false;
	}
	if(!as_sushiMatInstalled() || fullness_limit() - my_fullness() < 2)
	{
		return false;	//needs room for a nigiri; try again on a day with free fullness
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
