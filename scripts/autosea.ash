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

	if(!as_clearPendingEncounter())
	{
		return;
	}
	as_takeOverSettings();
	try
	{
		if(command == "farm")
		{
			int turns = count(words) > 1 ? words[1].to_int() : my_adventures();
			as_farm(turns);
		}
		else
		{
			as_run();
			//nothing left to quest for: carry on farming, like autoscend carries on to the next task
			if(as_monkeeStep() >= 999 && as_setting("farmAfterQuest", "true").to_boolean() && my_adventures() > as_advReserve())
			{
				as_info("The Sea Monkee quest is done; farming pearls, meat and stats (autosea_farmAfterQuest).");
				as_farm(my_adventures());
			}
		}
	}
	finally
	{
		as_restoreProperties();
	}
}
