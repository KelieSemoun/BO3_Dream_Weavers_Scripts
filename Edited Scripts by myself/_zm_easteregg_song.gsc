#using scripts\shared\array_shared;
#using scripts\zm\_zm_audio;
#using scripts\shared\util_shared;
#using scripts\codescripts\struct;

#namespace zm_easteregg_song;

/*
/////////////////////////////////////////
		-- Edited part by KelieSemoun

Desc : The original script plays the song whenever all triggers in the map are activated. Mine doesn't even play the song as it is handled in another file and instead would open up a debris in the map upon all triggers activated and update the navmesh so zombies can access the new area.
/////////////////////////////////////////
*/

function init()
{
	/*	Editable Variables - change the values in here */
	level.easterEggTriggerSound = "zmb_meteor_activate";				// sound alias name for the sound played when activating a trigger
	level.easterEggTriggerLoopSound = "zmb_meteor_loop";	// sound alias name for the loop sound when you are near a trigger
	level.multipleActivations = false;						// whether or not the song can be activated multiple times (true means it can, false means just once)
	thread HandleDoor();
	/*	End of Editable Variables - don't touch anything below here */

	setupMusic();
}

function setupMusic()
{
	level.triggersActive = 0;
	triggers = GetEntArray("song_trigger", "targetname");

	foreach(trigger in triggers)
	{
		trigger SetCursorHint("HINT_NOICON");
		trigger UseTriggerRequireLookAt();
		trigger thread registerTriggers(triggers.size);
	}
}

function registerTriggers(numTriggers)
{
	ent = self play_2D_loop_sound(level.easterEggTriggerLoopSound);

	self waittill("trigger");
	ent delete();
	self PlaySound(level.easterEggTriggerSound);
	level.triggersActive++;

	if(level.triggersActive >= numTriggers)
		level notify("allbearstriggered");
}

function HandleDoor()
{
	thread HandlePaths(false);
	level waittill("allbearstriggered");
	IPrintLnBold("The jukebox is now available");
	thread HandlePaths();
}

function HandlePaths(connect = true)
{
	doors = GetEntArray("easter_egg_door","targetname");
	foreach(door in doors)
	{
		if(!isdefined(door.model))
		{
			if(connect)
			{
				door NotSolid();
				door ConnectPaths();
			}
			else
			{
				door DisconnectPaths();
			}
		}
		if(connect)
		{
			if(isdefined(door.script_noteworthy) && door.script_noteworthy=="clip")
			{
				door Delete();
			}
			else
			{
				if(isdefined(door.target))
				{
					struct = struct::get(door.target, "targetname");
					door MoveTo(struct.origin,1);
					
				}
				if(isdefined(door.script_sound))
				{
					door PlaySound(door.script_sound);
				}
			}
			wait(1);
			door Delete();
		}
		if(isdefined(door))
		{
			door thread HandlePaths(connect);
		}
	}
}

function play_2D_loop_sound(sound)
{
	temp_ent = spawn("script_origin", self.origin);
	temp_ent PlayLoopSound(sound);
	return temp_ent;
}