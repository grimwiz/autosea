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
		//Mer-kin Elementary School: unlock the rooms, then the teacher's lounge (facecowl, waistrope, wordquizzes)
		case 396:	//Woolly Scaly Bully: unlock the janitor's closet
			run_choice(3);
			return;
		case 397:	//Bored of Education: unlock the bathrooms
			run_choice(2);
			return;
		case 398:	//A Mer-kin Graffiti: unlock the teacher's lounge
			run_choice(1);
			return;
		case 399:	//The Case of the Closet: fight a monitor (the cheatsheet carrier)
			run_choice(1);
			return;
		case 400:	//No Rest for the Room: cancerstick
			run_choice(2);
			return;
		case 401:	//Raising Cane: the teacher's lounge
			run_choice(2);
			return;
		case 705:	//Halls Passing in the Night (hallpass): the teacher's lounge if it's open
			run_choice(get_property("merkinElementaryTeacherUnlock").to_boolean() ? 4 : 2);
			return;
		case 704:	//Playing the Catalog Card: read an unread book (at 100% vocabulary only the 3 clue books remain)
		{
			//KoLmafia keeps "ID:option:status" per book, refreshed with this page's option numbers
			int pick = 0;
			int fallback = 0;
			foreach i, card in get_property("merkinCatalogChoices").split_string(",")
			{
				string[int] parts = card.split_string(":");
				if(count(parts) < 3)
				{
					continue;
				}
				if(parts[2] == "unknown" && pick == 0)
				{
					pick = parts[1].to_int();
				}
				if(parts[2] == "clue" && fallback == 0)
				{
					fallback = parts[1].to_int();
				}
			}
			run_choice(pick > 0 ? pick : fallback > 0 ? fallback : 1);
			return;
		}
		case 403:	//Picking Sides (Skate Park): the ice skates
			run_choice(1);
			return;
	}
	//anything else: KoLmafia carries on with your own choiceAdventure settings
}
