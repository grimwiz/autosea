script "autosea/choice.ash";

import <autosea/pearls.ash>

// autosea's choice adventure script, active only while autosea runs.
// It decides sea noncombats from the situation at the time (MP, daily limits, items held),
// and leaves every other choice to your own settings.

boolean as_takeSeaItems()
{
	string value = get_property("autosea_takeSeaItems");
	return value == "" || value.to_boolean();
}

// taking an item costs the turn; skipping costs nothing and the next turn is likely a fight.
// In a pearl zone that fight is worth the pearl's value over the fights still needed, so only
// take the item if it's worth more than that.
boolean as_itemBeatsPearl(item it, int extraCost)
{
	int itemValue = mall_price(it) - extraCost;
	int fightValue = as_pearlTurnValue(my_location());
	return itemValue > fightValue;
}

void main(int choice, string page)
{
	switch(choice)
	{
		case 299:	//Down at the Hatch: open it only to free Big Brother (reopening brings exploding mine crabs)
			run_choice(get_property("bigBrotherRescued").to_boolean() ? 2 : 1);
			return;
		case 304:	//A Vent Horizon: bubbling tempura batter (~6,000 meat) for 200 MP, 3 a day
			run_choice(as_takeSeaItems() && get_property("tempuraSummons").to_int() < 3 && my_mp() >= 200
				&& as_itemBeatsPearl($item[bubbling tempura batter], 0) ? 1 : 2);
			return;
		case 305:	//There is Sauce at the Bottom of the Ocean: globe of Deep Sauce, uses a Mer-kin pressureglobe
			run_choice(as_takeSeaItems() && item_amount($item[Mer-kin pressureglobe]) > 0
				&& as_itemBeatsPearl($item[globe of Deep Sauce], mall_price($item[Mer-kin pressureglobe])) ? 1 : 2);
			return;
		case 309:	//Barback: seaode (~4,000 meat), 3 a day
			run_choice(as_takeSeaItems() && get_property("seaodesFound").to_int() < 3
				&& as_itemBeatsPearl($item[seaode], 0) ? 1 : 2);
			return;
		case 311:	//Heavily Invested in Pun Futures: the scale trades lose value at mall prices
			run_choice(2);
			return;
		case 312:	//Into the Outpost: the tent that matches the monster that dropped the lockkey
		{
			string dropper = get_property("merkinLockkeyMonster");
			run_choice(dropper == "Mer-kin burglar" ? 1 : dropper == "Mer-kin raider" ? 2 : dropper == "Mer-kin healer" ? 3 : 4);
			return;
		}
		case 313:	//Sneaky / Aggressive / Mysterious Intent: the stashbox hides behind one of the first three
		case 314:	//options, so try them in turn
		case 315:
		{
			int next = get_property("autosea_stashboxOption").to_int() % 3 + 1;
			set_property("autosea_stashboxOption", next);
			run_choice(item_amount($item[Mer-kin lockkey]) > 0 ? next : 4);
			return;
		}
		case 403:	//Picking Sides (Skate Park): the ice skates
			run_choice(1);
			return;
	}
	//anything else: KoLmafia carries on with your own choiceAdventure settings
}
