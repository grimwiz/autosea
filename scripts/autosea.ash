script "autosea.ash";
since r29000;

// autosea: automates The Sea, autoscend-style.
// Before every adventure it re-reads the game state and runs the first task that has something to do.
//
// Usage (KoLmafia command line):
//   autosea          run until Mom is rescued, adventures run low, or something is missing
//   autosea status   show progress without adventuring
//   autosea farm [N] farm meat and stats in the best safe sea zone for N turns (default: all but the reserve)

import <autosea/util.ash>
import <autosea/tasks.ash>
import <autosea/farm.ash>
import <autosea/deepcity.ash>

string as_currentTask;
string as_stuckReason;	//set when a task stopped for lack of quest progress: autosea then stops for you to look

// runs the first task with something to do. Returns false when no task acted.
boolean as_runOneTask()
{
	foreach i, name in as_taskOrder()
	{
		as_currentTask = name;
		as_taskStuckTurns = 0;
		if(call boolean name())
		{
			as_debug("task " + name + " acted");
			return true;
		}
	}
	as_currentTask = "";
	return false;
}

void as_run()
{
	int stuck = 0;
	//turns spent with no quest progress: a task that keeps adventuring without moving the quest is missing
	//something (run 101's aftercore spent 196 turns "practising" with no sea lasso to throw), so stop and say so
	string questSig = as_questSignature();
	int progressTurn = my_turncount();
	int stuckTurns = as_setting("stuckTurns", "40").to_int();
	while(true)
	{
		string before = as_stateSignature();
		int turnsBefore = my_turncount();

		if(!as_runOneTask())
		{
			break;
		}

		if(as_questSignature() != questSig)
		{
			questSig = as_questSignature();
			progressTurn = my_turncount();
		}
		else if(stuckTurns > 0 && my_turncount() - progressTurn >= max(stuckTurns, as_taskStuckTurns))
		{
			as_stuckReason = "Task " + as_currentTask + ": " + (my_turncount() - progressTurn) + " turns without any quest progress. Stopping: it is probably missing something.";
			as_warn(as_stuckReason);
			as_warn("Check what it needs, or \"set autosea_stuckTurns = 0\" to turn this check off.");
			return;
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
		if(as_stuckReason != "")
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
	//In 11,037 Leagues Under the Sea the Council's quests differ (both Elder Gods, five pearls, then the Nautical
	//Seaceress), so autosea's aftercore quest route would make the wrong choices. Farming is still fine.
	if(my_path() == $path[11,037 Leagues Under the Sea] && command != "farm" && command != "collect")
	{
		as_warn("You're in 11,037 Leagues Under the Sea. autosea's quest route is for aftercore and doesn't fit this path. "
			+ "Use UnderTheSea (git checkout https://github.com/tottington/UnderTheSea lowIOTM) for the run; "
			+ "\"autosea farm\" still works.");
		return;
	}

	if(!as_clearPendingEncounter())
	{
		return;
	}
	as_takeOverSettings();
	try
	{
		if(command == "farm")
		{
			int turns = count(words) > 1 ? words[1].to_int() : -1;	//no number: until adventures run out
			as_farm(turns);
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
			if(as_stuckReason != "")
			{
				//no farming on top: the warning stays the last thing in the log, and the turns stay for after the fix
				as_warn(as_stuckReason + " Not farming the remaining " + my_adventures() + " adventures.");
			}
			//nothing left to quest for: carry on farming, like autoscend carries on to the next task
			else if(as_monkeeStep() >= 999 && my_adventures() > as_advReserve())
			{
				if(as_setting("farmAfterQuest", "true").to_boolean())
				{
					as_info("The Sea Monkee quest is done; farming pearls, meat and stats with the remaining adventures (autosea_farmAfterQuest).");
					as_farm(-1);
				}
				else
				{
					as_info("The Sea Monkee quest is done; stopping with " + my_adventures() + " adventures left (autosea_farmAfterQuest = false).");
				}
			}
		}
	}
	finally
	{
		as_restoreProperties();
	}
}
