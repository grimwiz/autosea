script "autosea.ash";
since r29000;

// autosea: automates The Sea, autoscend-style.
// Before every adventure it re-reads the game state and runs the first task that has something to do.
//
// Usage (KoLmafia command line):
//   autosea          run until Mom is rescued, adventures run low, or something is missing
//   autosea status   show progress without adventuring

import <autosea/util.ash>
import <autosea/tasks.ash>

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
	string command = count(args) > 0 ? args[0].to_lower_case() : "";
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
		as_run();
	}
	finally
	{
		as_restoreProperties();
	}
}
