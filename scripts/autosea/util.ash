// autosea utilities: logging, settings, preference save/restore, the adventure wrapper.

// ---------------------------------------------------------------- logging

void as_info(string msg)
{
	print("[autosea] " + msg, "blue");
}

void as_warn(string msg)
{
	print("[autosea] " + msg, "red");
}

void as_debug(string msg)
{
	if(get_property("autosea_debug").to_boolean())
	{
		print("[autosea debug] " + msg, "gray");
	}
}

// ---------------------------------------------------------------- settings
// All settings are ordinary KoLmafia properties, changed with "set autosea_<name> = <value>".

string as_setting(string name, string fallback)
{
	string value = get_property("autosea_" + name);
	return value == "" ? fallback : value;
}

int as_advReserve()
{
	//adventures to leave unspent. Sea adventures cost 2 without Fishy, so never go below 2.
	return max(2, as_setting("advReserve", "2").to_int());
}

string as_maximizeExtra()
{
	//extra maximizer terms, e.g. "mainstat, 0.5 item". "sea" is always added.
	return as_setting("maximize", "mainstat");
}

// ---------------------------------------------------------------- preference save/restore
// Like autoscend, take over a few global settings for the run and put them back afterwards.

string[string] as_savedPrefs;

void as_overrideProperty(string prop, string value)
{
	if(!(as_savedPrefs contains prop))
	{
		as_savedPrefs[prop] = get_property(prop);
	}
	set_property(prop, value);
}

void as_restoreProperties()
{
	foreach prop, value in as_savedPrefs
	{
		set_property(prop, value);
	}
	clear(as_savedPrefs);
}

void as_takeOverSettings()
{
	//a third-party recovery script can loop forever before an adventure; use KoLmafia's built-in recovery.
	if(!get_property("autosea_keepRecoveryScript").to_boolean())
	{
		as_overrideProperty("recoveryScript", "");
	}
	//never stop mid-run for a counter or an unexpected choice
	as_overrideProperty("dontStopForCounters", "true");
}

// ---------------------------------------------------------------- state

boolean as_isFishy()
{
	return have_effect($effect[Fishy]) > 0;
}

boolean as_canBreatheUnderwater()
{
	return boolean_modifier("Adventure Underwater");
}

boolean as_familiarCanBreatheUnderwater()
{
	return my_familiar() == $familiar[none] || boolean_modifier("Underwater Familiar");
}

boolean as_haveAdventures()
{
	//without Fishy an underwater adventure costs 2
	int cost = as_isFishy() ? 1 : 2;
	return my_adventures() >= as_advReserve() + cost;
}

// ---------------------------------------------------------------- gear and recovery

boolean as_equipForSea(string extra)
{
	if(as_canBreatheUnderwater() && as_familiarCanBreatheUnderwater() && extra == "")
	{
		return true;
	}
	string expr = "sea";
	if(as_maximizeExtra() != "")
	{
		expr += ", " + as_maximizeExtra();
	}
	if(extra != "")
	{
		expr += ", " + extra;
	}
	as_debug("maximize " + expr);
	maximize(expr, false);
	if(as_canBreatheUnderwater() && !as_familiarCanBreatheUnderwater() && my_familiar() != $familiar[none])
	{
		as_warn("Your " + my_familiar() + " can't breathe underwater; adventuring without a familiar.");
		use_familiar($familiar[none]);
	}
	return as_canBreatheUnderwater() && as_familiarCanBreatheUnderwater();
}

boolean as_recover()
{
	if(my_hp() < my_maxhp() * 0.6)
	{
		restore_hp(ceil(my_maxhp() * 0.9));
	}
	if(my_mp() < 30 && my_maxmp() > 60)
	{
		restore_mp(min(my_maxmp(), 100));
	}
	return my_hp() > my_maxhp() * 0.3;
}

// ---------------------------------------------------------------- adventuring

// one adventure in a sea zone. Returns false (and says why) if it could not adventure.
// filter: name of a combat filter function, or "" to leave combat entirely to your own combat settings.
boolean as_adv(location loc, string extraMaximize, string filter)
{
	if(!as_haveAdventures())
	{
		as_warn("Not enough adventures left (reserve " + as_advReserve() + ").");
		return false;
	}
	if(!as_equipForSea(extraMaximize))
	{
		as_warn("Can't breathe underwater (you or your familiar) for " + loc + ". Get a fishbowl, helmet or similar first.");
		return false;
	}
	if(!as_recover())
	{
		as_warn("Couldn't recover enough HP to adventure safely.");
		return false;
	}
	as_debug("adventuring at " + loc);
	return adv1(loc, -1, filter);
}

boolean as_adv(location loc, string extraMaximize)
{
	return as_adv(loc, extraMaximize, "");
}

boolean as_adv(location loc)
{
	return as_adv(loc, "", "");
}
