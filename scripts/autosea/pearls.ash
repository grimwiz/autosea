// Unblemished pearls: five sea zones each give one pearl a day. Each won fight there adds
// clamp(floor(resistance / 3), 1, 6) sixtieths of progress, where resistance is your level in the zone's element,
// so 18 resistance means 10 fights per pearl instead of 30-60. Pearls sell for far more in the mall than autosell.

import <autosea/util.ash>

element as_pearlElement(location loc)
{
	switch(loc)
	{
		case $location[The Briniest Deepests]: return $element[cold];
		case $location[The Marinara Trench]: return $element[hot];
		case $location[Anemone Mine]: return $element[spooky];
		case $location[Madness Reef]: return $element[stench];
		case $location[The Dive Bar]: return $element[sleaze];
	}
	return $element[none];
}

// KoLmafia's "found today" flag for the zone
string as_pearlProperty(location loc)
{
	switch(loc)
	{
		case $location[The Briniest Deepests]: return "_unblemishedPearlTheBriniestDeepests";
		case $location[The Marinara Trench]: return "_unblemishedPearlMarinaraTrench";
		case $location[Anemone Mine]: return "_unblemishedPearlAnemoneMine";
		case $location[Madness Reef]: return "_unblemishedPearlMadnessReef";
		case $location[The Dive Bar]: return "_unblemishedPearlDiveBar";
	}
	return "";
}

boolean as_pearlAvailable(location loc)
{
	string prop = as_pearlProperty(loc);
	return prop != "" && !get_property(prop).to_boolean();
}

int as_pearlTarget()
{
	//18 is where progress stops improving
	return as_setting("pearlResistance", "18").to_int();
}

int as_resistance(element el)
{
	return numeric_modifier(el.to_string() + " Resistance").to_int();
}

// progress per won fight, in sixtieths of a pearl
int as_pearlUnitsPerFight(location loc)
{
	return max(1, min(6, as_resistance(as_pearlElement(loc)) / 3));
}

// KoLmafia's running total of the progress shown after each fight (sums of rounded percentages, so approximate)
float as_pearlProgress(location loc)
{
	return get_property(as_pearlProperty(loc) + "Progress").to_float();
}

// won fights still needed for today's pearl at your current resistance
int as_pearlFightsLeft(location loc)
{
	if(!as_pearlAvailable(loc))
	{
		return 0;
	}
	float perFight = as_pearlUnitsPerFight(loc) * 100.0 / 60.0;
	return max(1, ceil((100.0 - as_pearlProgress(loc)) / perFight));
}

int as_pearlValue()
{
	int value = as_setting("pearlValue", "0").to_int();
	if(value <= 0)
	{
		value = mall_price($item[unblemished pearl]);
	}
	return value > 0 ? value : 80000;
}

// what the next fight in this zone is worth towards today's pearl. Grows as progress builds,
// because progress is lost at rollover: a half-finished pearl is worth nothing.
int as_pearlTurnValue(location loc)
{
	if(!as_pearlAvailable(loc))
	{
		return 0;
	}
	return as_pearlValue() / as_pearlFightsLeft(loc);
}

// ---------------------------------------------------------------- buff economics
// Every paid buff has a cost per turn: price / effect duration (owned items count at their mall price,
// since they could be sold). The total of all paid buffs running must stay below what a turn in the zone
// earns: its recorded meat per turn, plus the pearl's value per remaining fight while a pearl is in progress.

int as_zoneWorth(location loc)
{
	return as_turnValue(loc) + (as_pearlAvailable(loc) ? as_pearlTurnValue(loc) : 0);
}

int as_costPerTurn(item it)
{
	int turns = numeric_modifier(it, "Effect Duration").to_int();
	int price = it.tradeable ? max(0, mall_price(it)) : 0;
	return turns > 0 ? price / turns : price;
}

// paid buffs autosea uses, and what their running effects cost per turn
item[int] AS_PAID_SOURCES;
AS_PAID_SOURCES[0] = $item[sea jelly];
AS_PAID_SOURCES[1] = $item[lustrous oyster egg];
AS_PAID_SOURCES[2] = $item[scroll of minor invulnerability];
AS_PAID_SOURCES[3] = $item[Ancient Protector Soda];
AS_PAID_SOURCES[4] = $item[pec oil];
AS_PAID_SOURCES[5] = $item[programmable turtle];
AS_PAID_SOURCES[6] = $item[Polysniff Perfume];

int as_committedCost()
{
	int total = 0;
	foreach i, it in AS_PAID_SOURCES
	{
		effect eff = effect_modifier(it, "Effect");
		if(eff != $effect[none] && have_effect(eff) > 0)
		{
			total += as_costPerTurn(it);
		}
	}
	if(have_effect($effect[Dances with Tweedles]) > 0)
	{
		total += get_property("_autosea_teaCostPerTurn").to_int();
	}
	return total;
}

// is one more paid buff (costing costPerTurn) worth it for adventuring in loc?
boolean as_worthBuff(int costPerTurn, location loc)
{
	int committed = as_committedCost();
	int worth = as_zoneWorth(loc);
	if(committed + costPerTurn < worth)
	{
		return true;
	}
	as_debug("buff not worth it in " + loc + ": " + committed + " + " + costPerTurn + " per turn vs " + worth + " earned");
	return false;
}

// maximizer terms that push the zone's element resistance up to the useful cap
string as_pearlGear(location loc)
{
	if(!as_pearlAvailable(loc))
	{
		return "";
	}
	return "10 " + as_pearlElement(loc).to_string() + " resistance " + as_pearlTarget() + " max";
}

// top up resistance with potions that use no stomach, liver or spleen: owned ones first, then cheap mall ones
void as_pearlTopUp(location loc)
{
	if(!as_pearlAvailable(loc))
	{
		return;
	}
	element el = as_pearlElement(loc);
	int maxPrice = as_setting("pearlBuffMaxPrice", "1000").to_int();

	boolean tryPotion(item it, effect eff, boolean mayBuy)
	{
		if(as_resistance(el) >= as_pearlTarget() || have_effect(eff) > 0)
		{
			return false;
		}
		//worth it only while all paid buffs together cost less than a fight here earns
		if(!as_worthBuff(as_costPerTurn(it), loc))
		{
			return false;
		}
		if(item_amount(it) == 0)
		{
			if(!mayBuy || !can_interact() || !as_setting("buy", "true").to_boolean() || mall_price(it) > maxPrice)
			{
				return false;
			}
			buy(1, it, maxPrice);
		}
		if(item_amount(it) == 0)
		{
			return false;
		}
		use(1, it);
		return have_effect(eff) > 0;
	}

	tryPotion($item[pec oil], $effect[Oiled-Up], false);
	tryPotion($item[programmable turtle], $effect[Spiro Gyro], false);
	if(el == $element[stench])
	{
		tryPotion($item[Polysniff Perfume], $effect[Neutered Nostrils], false);
	}
	tryPotion($item[scroll of minor invulnerability], $effect[Minor Invulnerability], true);
	tryPotion($item[Ancient Protector Soda], $effect[Ancient Protected], true);

	if(as_resistance(el) < as_pearlTarget())
	{
		as_debug(el + " resistance is " + as_resistance(el) + " (target " + as_pearlTarget() + ") for the " + loc + " pearl");
	}
}
