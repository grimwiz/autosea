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
