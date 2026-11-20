script "autosea.ash";
since r29000;

// autosea: automates The Sea, autoscend-style.
// Before every adventure it re-reads the game state and runs the first task that has something to do.
//
// Usage (KoLmafia command line):
//   autosea          run until Mom is rescued, adventures run low, or something is missing
//   autosea status   show progress without adventuring
//   autosea farm [N] the quest first, then farm meat and stats in the best safe sea zone (at most N turns in all)
//   autosea diet     eat and drink for more adventures (the other auto scripts call this when they run out)

import <autosea/util.ash>
import <autosea/tasks.ash>
import <autosea/farm.ash>
import <autosea/deepcity.ash>
import <autosea/dad.ash>

string as_currentTask;

// runs the first task with something to do. Returns false when no task acted.
boolean as_runOneTask()
{
	foreach i, name in as_taskOrder()
	{
		as_currentTask = name;
		if(call boolean name())
		{
			as_debug("task " + name + " acted");
			return true;
		}
		if(as_stopReason != "")
		{
			return false;	//a quest step can't get what it needs: stop rather than carry on around it
		}
	}
	as_currentTask = "";
	return false;
}

void as_run()
{
	int stuck = 0;
	while(true)
	{
		string before = as_stateSignature();
		int turnsBefore = my_turncount();
		//Mom's food as soon as she's rescued, not only once farming starts: the temple quest that follows is where
		//the stats count (Dad needs 150 base of each), and run 106 went through the Outpost and Library without it
		as_farmDailies();

		if(!as_runOneTask())
		{
			break;
		}

		// a task claimed to act but nothing changed: guard against spinning forever
		if(my_turncount() == turnsBefore && as_stateSignature() == before)
		{
			stuck += 1;
			if(stuck >= 3)
			{
				as_warn("Task " + as_currentTask + " made no progress 3 times in a row. Stopping so it doesn't spin.");
				as_warn("Run \"set autosea_debug = true\" and try again for details.");
				return;
			}
		}
		else
		{
			stuck = 0;
		}
	}
	as_printStatus();
}

// "string..." so KoLmafia doesn't prompt for arguments when run from the Scripts menu
// Run the quest; if it stops because the next zone is too dangerous, farm for a while (stats grow,
// especially with Mom's Cereal Killer) and try again, until adventures run low or farming can't progress.
void as_questLoop()
{
	while(true)
	{
		as_lastUnsafeZone = $location[none];
		as_waitTurns = 0;
		as_run();
		if(as_stopReason != "")
		{
			return;
		}
		location blocked = as_lastUnsafeZone;
		if(as_waitTurns > 0 && my_adventures() > as_advReserve() + 2 && as_setting("farmWhileWaiting", "true").to_boolean())
		{
			//something has to wear off (or roll over) before the quest can continue: farm in the meantime
			as_info("Farming " + as_waitTurns + " turns while waiting (autosea_farmWhileWaiting).");
			int waited = my_turncount();
			as_farm(as_waitTurns);
			if(my_turncount() == waited)
			{
				return;
			}
			continue;
		}
		if(blocked == $location[none] || !as_setting("farmWhenBlocked", "true").to_boolean())
		{
			return;
		}
		if(my_adventures() <= as_advReserve() + 2)
		{
			as_info(blocked + " is still too dangerous and adventures are low; stopping for today.");
			return;
		}
		int turns = as_setting("farmBlockTurns", "20").to_int();
		as_info(blocked + " is too dangerous for now; farming " + turns + " turns to get stronger, then trying again.");
		int before = my_turncount();
		as_farm(turns);
		clear(as_reportedZones);
		if(my_turncount() == before)
		{
			as_warn("Farming couldn't make progress either; stopping.");
			return;
		}
	}
}

void main(string... args)
{
	//KoLmafia may pass "farm 50" as one argument or several; split it ourselves
	string joined = "";
	foreach i, a in args
	{
		joined += " " + a;
	}
	string[int] words;
	matcher m = create_matcher("\\S+", joined.to_lower_case());
	while(m.find())
	{
		words[count(words)] = m.group(0);
	}
	string command = count(words) > 0 ? words[0] : "";
	//"autosea N": the usual day for at most N turns, one step at a time
	if(command != "" && command.to_int() > 0 && command == command.to_int().to_string())
	{
		as_turnLimit = my_turncount() + command.to_int();
		command = "";
	}
	//"autosea farm [N]": the quest first, then farm the turns that are left (at most N turns in all). Plain autosea is
	//like autoscend: finish the quest and stop (user, 2026-11-20)
	boolean farmAfterQuest = command == "farm";
	if(farmAfterQuest && count(words) > 1 && words[1].to_int() > 0)
	{
		as_turnLimit = my_turncount() + words[1].to_int();
	}
	if(my_level() < 11)
	{
		as_warn("The Old Man only talks to you from level 11.");
		return;
	}
	if(command == "status")
	{
		as_printStatus();
		return;
	}
	//"autosea diet": eat and drink for more adventures and stop there. autoslime, autodread and autohobo call it
	//when they run out of adventures, so every script fills the organs the same way.
	if(command == "diet")
	{
		int before = my_adventures();
		as_dietNow();
		as_info(my_adventures() > before ? "Ate and drank for " + (my_adventures() - before) + " more adventures."
			: "Nothing worth eating or drinking for more adventures (fullness " + my_fullness() + "/" + fullness_limit()
				+ ", drunkenness " + my_inebriety() + "/" + inebriety_limit() + ", spleen " + my_spleen_use() + "/" + spleen_limit() + ").");
		return;
	}
	//"autosea bedtime": a nightcap and rollover gear, only once the day's adventures are spent. The other auto scripts
	//call it when they stop out of adventures, so every script ends the day the same way.
	if(command == "bedtime")
	{
		as_bedtime();
		return;
	}
	//In 11,037 Leagues Under the Sea the Council's quests differ (both Elder Gods, five pearls, then the Nautical
	//Seaceress), so autosea's aftercore quest route would make the wrong choices. Farming is still fine.
	if(my_path() == $path[11,037 Leagues Under the Sea] && command != "farm" && command != "collect")
	{
		as_warn("You're in 11,037 Leagues Under the Sea. autosea's quest route is for aftercore and doesn't fit this path. "
			+ "Use UnderTheSea (git checkout https://github.com/tottington/UnderTheSea lowIOTM) for the run; "
			+ "\"autosea farm\" still works.");
		return;
	}
	//the Slime Tube's debuff hits at the start of every fight, anywhere, for a share of max HP that grows as it
	//runs down (290% with 3 turns left): sea fights would be lost to it and the zones wrongly marked as too
	//dangerous. Shrugging can't remove it; a chamois from the clan's bucket by the tube can.
	if(have_effect($effect[Coated in Slime]) > 0)
	{
		visit_url("clan_slimetube.php?action=chamois");
		if(have_effect($effect[Coated in Slime]) > 0)
		{
			as_warn("You're Coated in Slime and the chamois didn't wipe it off. It hits you at the start of every fight, harder each turn, for "
				+ have_effect($effect[Coated in Slime]) + " more turns. Spend those without fighting (rest, or noncombats), then run autosea.");
			return;
		}
		as_info("Wiped off the Slime Tube's slime with a chamois (it would have hit in every fight).");
	}

	if(!as_clearPendingEncounter())
	{
		return;
	}
	as_takeOverSettings();
	try
	{
		as_useStill();	//a daily chore with no turns: done first so a stop later on doesn't skip it
		while(true)
		{
			boolean questAgain = false;		//a farm reached what the quest was waiting for: quest before farming more
			if(command == "farm" && my_path() == $path[11,037 Leagues Under the Sea])
			{
				as_farm(-1);	//no quest route in the path: farm only (until adventures or "autosea farm N" run out)
			}
			else if(command == "collect")
			{
				//"collect [how many] <item name> [turns]"
				int turns = 0;
				int qty = 1;
				int first = 1;
				int last = count(words) - 1;
				if(last >= 2 && words[1].to_int() > 0 && words[1] == words[1].to_int().to_string())
				{
					qty = words[1].to_int();
					first = 2;
				}
				if(last > first && words[last].to_int() > 0 && words[last] == words[last].to_int().to_string())
				{
					turns = words[last].to_int();
					last -= 1;
				}
				string name = "";
				for i from first to last
				{
					name += (name == "" ? "" : " ") + words[i];
				}
				if(name == "skills")
				{
					as_collectSeaSkills(turns);
				}
				else
				{
					as_collectCommand(name.to_item(), turns, qty);
				}
			}
			else
			{
				as_questLoop();
				if(as_stopReason != "")
				{
					//no farming on top: the reason stays the last thing in the log, and the turns stay for after
					as_warn(as_stopReason + " Not farming the remaining " + my_adventures() + " adventures.");
				}
				//the temple boss is done: Dad Sea Monkee is what's left of the quest
				else if(as_monkeeStep() >= 999 && my_adventures() > as_advReserve())
				{
					//Dad Sea Monkee held back only by a base stat (the Clothing of Loathing needs 150 of each): raising
					//it is the next step of the quest, so farm for it with or without "farm" (user, 2026-11-19:
					//grimwiz stopped at base Muscle 116/150 saying the quest was done)
					string dadNeeds = as_dadBlocked && !as_dadDone() ? as_dadProblem() : "";
					if(dadNeeds.starts_with("base "))
					{
						if(as_haveAdventures())
						{
							//questing comes first: the farm stops once the stat is there, and the day goes back to
							//the quest for Dad (user, 2026-11-20: grimwiz reached 150 Muscle and farmed 100 more turns)
							as_farmStat = dadNeeds.substring(5, dadNeeds.index_of(" ", 5)).to_stat();
							matcher need = create_matcher("/(\\d+)", dadNeeds);
							as_farmUntilStat = as_farmStat;
							as_farmUntilBase = need.find() ? need.group(1).to_int() : 150;
							as_farmGoalOverride = "stats";
							as_info("Dad Sea Monkee is next and needs " + dadNeeds + "; farming " + as_farmStat
								+ " until it's there.");
							as_farm(-1);
							questAgain = my_basestat(as_farmUntilStat) >= as_farmUntilBase && as_haveAdventures();
							as_farmUntilStat = $stat[none];
							as_farmUntilBase = 0;
							as_farmGoalOverride = "";
							as_farmStat = $stat[none];
						}
					}
					//Dad out of reach for now, or the quest done: stop, like autoscend, unless "autosea farm" was given;
					//then the turns left after questing go to farming (user, 2026-11-20)
					else if(farmAfterQuest)
					{
						as_info((dadNeeds != "" ? "Dad Sea Monkee is next but needs " + dadNeeds : "The Sea Monkee quest is done")
							+ "; farming pearls, meat and stats with the remaining adventures (autosea farm).");
						as_farm(-1);
					}
					else
					{
						as_info((dadNeeds != "" ? "Dad Sea Monkee is next but needs " + dadNeeds : "The Sea Monkee quest is done")
							+ "; stopping with " + my_adventures() + " adventures left (\"autosea farm\" farms them after the quest).");
					}
				}
			}
			if(questAgain && as_stopReason == "")
			{
				as_info("That's what the quest was waiting for; back to the quest with " + my_adventures() + " adventures.");
				continue;
			}
			//out of adventures: fill what's left of stomach, liver and spleen, and carry on if that gave enough
			if(as_stopReason != "" || !as_bedtimeTopUp())
			{
				break;
			}
			as_info("The leftover stomach, liver and spleen gave enough for more; carrying on with " + my_adventures() + " adventures.");
		}
		if(as_turnLimit > 0)
		{
			as_info("Stopped at turn " + my_turncount() + " (autosea with a turn limit), level " + my_level() + ", with "
				+ my_adventures() + " adventures left.");
		}
		if(as_stopReason == "")
		{
			as_bedtime();	//a nightcap and rollover gear once the day's adventures are spent
		}
	}
	finally
	{
		as_restoreProperties();
	}
}
