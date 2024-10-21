#using scripts\codescripts\struct;

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\trigger_shared;

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_util;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;

#namespace rs_o_jump_pad;

// Specific variables radiant will look for inside of script_string.
// These can be changed to whatever is the easiest to use.
#define JUMP_PAD_RADIANT_VAL_TIME "time"
#define JUMP_PAD_RADIANT_VAL_ZOFFSET "zOffset"
#define JUMP_PAD_RADIANT_VAL_ZPEAKPROGRESS "zPeakProgress"
#define JUMP_PAD_RADIANT_VAL_COST "cost"
#define JUMP_PAD_RADIANT_VAL_DELAY "delay"
#define JUMP_PAD_RADIANT_VAL_COOLDOWN "cooldown"

// Default values for each specific setting for the jump pad.
#define DEF_JUMP_PAD_JUMP_TIME 2.85
#define DEF_JUMP_PAD_Z_OFFSET 800
#define DEF_JUMP_PAD_Z_PEAK_PROGRESS 72
#define DEF_JUMP_PAD_COST -1
#define DEF_JUMP_PAD_DELAY 0
#define DEF_JUMP_PAD_COOLDOWN 0

#precache( "model", "tag_origin" );

#precache( "fx", "redspace/fx_launchpad_blue" );
#precache( "fx", "redspace/fx_launchpad_red" );

// todo add ability for one jump pad to deactivate another (or multiple) for a certain amount of time
// todo add customizable notifies for launch start and launch end

REGISTER_SYSTEM( "rs_o_jump_pad", &__init__, undefined )

/* ----------------- Redspace200 Jump Pad ----------------------

Credits: 
	RedSpace200: Entire Script
	Porter: Sounds & Idea
	3arc: Broken Scripts & files
Please give credit to redspace200 & porter if used in your map. 

Setup: Add prefab into map. Use configuration settings below to setup as you like

IMPORTANT: Add line
	#using scripts\_redspace\rs_o_jump_pad;
to mapName.gsc file

Add line to .zone file
scriptparsetree,scripts/_redspace/rs_o_jump_pad.gsc

--------------------- |||||||||||||||||||||||| ----------------------

Use included prefab OR manually setup with the settings below

Trigger_Use
	targetname = trig_jump_pad
	target = startptName
		Points to the starting point.
			Should be located directly in the center of the trigger_use
	
Script_Struct
	Start_Point (Located right by trigger)
		targetname = startptName
			Start point name to reference
			
		target = entptName
			End Point to target
		
		script_string = specific settings for this particular launch pad
			Optional Settings
				time: Amount of time jump pad transition to end point will take
				zOffset: Vertical translation max height
				zPeakProgress: Percent of the transition where the player is at his maximum height
				cost: Amount this launch pad costs the player to use. Negative # means this will not cost the player and will be activated by touch.
				delay: Delay before the launch pad launches the player. Player may step off pad to avoid being launched. Stepping off a paid pad will cause the player to loose the money.
				cooldown: Amount of time a player has to wait before using this launch pad again
				
			Example Syntax (script_string = ) ---> time:4,zOffset:800,zPeakProgress:85,cost:500,delay:0.5
	
Script_Struct
	End_Point (Located by end position. There can be a infinite # of end points, a random one will be chosen)
		targetname = entptName
			End point name to reference.
*/


function __init__()
{
	level jump_pad_init();
}

function jump_pad_init()
{
	jump_pad_triggers = GetEntArray( "trig_jump_pad", "targetname" );
	
	if( !isdefined( jump_pad_triggers ) )
		return;
	
	for( i = 0; i < jump_pad_triggers.size; i++ )
	{
		jump_pad_triggers[i].start = struct::get( jump_pad_triggers[i].target, "targetname" );
		jump_pad_triggers[i].destination = struct::get_array( jump_pad_triggers[i].start.target, "targetname" );
		
		padTime = DEF_JUMP_PAD_JUMP_TIME;
		padZOff = DEF_JUMP_PAD_Z_OFFSET;
		padPeakProgress = DEF_JUMP_PAD_Z_PEAK_PROGRESS;
		padCost = DEF_JUMP_PAD_COST;
		padDelay = DEF_JUMP_PAD_DELAY;
		padCooldown = DEF_JUMP_PAD_COOLDOWN;
		
		values = strtok(JUMP_PAD_RADIANT_VAL_TIME+":"+JUMP_PAD_RADIANT_VAL_ZOFFSET+":"+JUMP_PAD_RADIANT_VAL_ZPEAKPROGRESS+":"+JUMP_PAD_RADIANT_VAL_COST+":"+JUMP_PAD_RADIANT_VAL_DELAY+":"+JUMP_PAD_RADIANT_VAL_COOLDOWN,":");
		
		input = jump_pad_triggers[i].script_string;
		if (input != "")
		{
			input = strtok(input,",");
			
			for(j = 0; j < input.size; j++)
			{
				varData = strtok(input[j],":");
				setVar = "";
				for(k = 0; k < values.size; k++)
				{
					if (varData[0] == values[k])
					{
						switch(k)
						{
							case 0: // Set Time
								padTime = float(varData[1]);
								break;
							case 1: // Set Z Offset
								padZOff = int(varData[1]);
								break;
							case 2: // Set Peak Progress
								padPeakProgress = int(varData[1]);
								break;							
							case 3: // Set Cost
								padCost = int(varData[1]);
								break;							
							case 4: // Set Pad Delay
								padDelay = float(varData[1]);
								break;						
							case 5: // Set Pad Delay
								padCooldown = float(varData[1]);
								break;
						}
					}
				}
			}
		}
			
		
		// Set the variable information collected to the jump pad trigger
		jump_pad_triggers[i].padTime = padTime;
		jump_pad_triggers[i].padZOffset = padZOff;
		jump_pad_triggers[i].padPeakProgress = padPeakProgress;
		jump_pad_triggers[i].padCost = padCost;
		jump_pad_triggers[i].padDelay = padDelay;
		jump_pad_triggers[i].padCooldown = padCooldown;
		
		jump_pad_triggers[i] thread jump_pad_fx();
		jump_pad_triggers[i] thread jump_pad_think();
	}
}
function jump_pad_fx()
{
	self endon("destroyed");
	
	while( isdefined( self ) )
	{
		fx = spawn("script_model",self.origin);
		fx setModel("tag_origin");
		playFxOnTag("redspace/fx_launchpad_blue",fx,"tag_origin");
		
		self waittill("jump_pad_deactivate");
		
		fx delete();
		
		fx = spawn("script_model",self.origin);
		fx setModel("tag_origin");
		playFxOnTag("redspace/fx_launchpad_red",fx,"tag_origin");
		
		self waittill("jump_pad_activate");
		
		fx delete();
	}
}
function jump_pad_think()
{
	self endon( "destroyed" );
	
	self jump_pad_hintstring();

	while( isdefined( self ) )
	{
		wait .2;
		
		players = getPlayers();
		
		for(i = 0; i < players.size; i++)
		{
			who = players[i];
			
			if (!self anyPlayerTouchingSelf() )
				self.touchingLaunchPad = undefined;

			if (!who isTouching(self) )
				continue;
			
			if( IsPlayer( who ) && !isdefined(self.touchingLaunchPad) )
			{
				if (self.padCost >= 0 && (!who useButtonPressed() || who.score < self.padCost) )
					continue;
					
				if (self.padCost > 0)
					who.score -= self.padCost;
					
				if (self.padDelay > 0)
				{
					who playSound("flinger_activate");
					self setHintString("");
					wait self.padDelay;
					
					self jump_pad_hintstring();
					if (!who isTouching(self) )
						continue;
				}

				start = self.start;
				time = self.padTime;
				zOffset = self.padZOffset;
				zPeakProgress = self.padPeakProgress;
				end = self.destination[ RandomInt( self.destination.size ) ];
				
				who thread rs_jumppad_launch(start.origin,time,zOffset,zPeakProgress,end.origin);
				self.touchingLaunchPad = true;
				
				if (self.padCooldown > 0)
				{
					wait .5;
					self setHintString("Launch pad cooling down...");
					self notify("jump_pad_deactivate");
					wait self.padCooldown;
					self notify("jump_pad_activate");
					self jump_pad_hintstring();
				}
			}
		}		
	}
}

function jump_pad_hintstring()
{
	self setCursorHint("HINT_NOICON");
	if (self.padCost >= 0)
		self SetHintString( "Press and Hold ^3[{+activate}]^7 use Launch Pad. Cost[" + self.padCost + "]" );
	else
		self setHintString("");
}

function anyPlayerTouchingSelf()
{
	players = getPlayers();
	for(i = 0; i < players.size; i++)
		if (players[i] isTouching(self) )
			return true;
			
	return false;
}

// Redspace200 jump pad launch function
// Launch the player from point A to B with a nice arc on the Z axis
function rs_jumppad_launch(start,time,zOffset,zPeakProgress,end)
{
	self notify("stop_player_out_of_playable_area_monitor");
	self.onLaunchPad = true;
	self notify("launchpad_start");
	
	level util::clientNotify("player_fling_blur_0");

	// Get starting location
	org = start;
	startX = org[0];
	startY = org[1];
	startZ = org[2];
	
	// Get ending location
	endOrg = end;
	byX = endOrg[0] - startX;
	byY = endOrg[1] - startY;
	byZ = endOrg[2] - startZ;
	
	totalTime = time; // Total animation duration in seconds
	currentTime = 0; // Elapsed time from the animation
	
	animProgress = 0; // Acutal animation progress / maxProgress. Must start at 0 for smooth animation.
	animMaxProgress = 100; // Maximum animation progress. Default to 100 for easy reference.
	
	animZPeak = zPeakProgress; // Percentage out of 100 before the animation Z starts to descend.
	zOffsetMax = zOffset; // Highest point of the animation Z.
	
	increments = .065; // Increments per frame. .065 Is a good number.
	
	ent = spawn("script_origin",self.origin);

	self playSound("flinger_fly");
	
	ent playLoopSound("flinger_wind_loop");
	
	wait .05;
	
	self playerLinkTo(ent);
	
	for(i = 0; i < totalTime; i+=increments)
	{
		ent.angles = self.angles;
	
		animProgress = map(i,0,totalTime,0,animMaxProgress);
	
		// Normal delta speed from starting point to end point.
		// Input current animation frame number to get position.
		dx = linear(animProgress,0,byX,animMaxProgress+1);
		dy = linear(animProgress,0,byY,animMaxProgress+1);
		dz = linear(animProgress,0,byZ,animMaxProgress+1);
		
		addZ = 0;
		
		// Z Axis Arc / Offset
		if (animProgress < animZPeak)
			addZ = easeOutSine(animProgress,0,zOffsetMax,animMaxProgress - (animMaxProgress - animZPeak) );
		else
			addZ = zOffsetMax - easeInSine(animProgress-animZPeak,0,zOffsetMax,animMaxProgress-animZPeak);

		x = startX + dx;
		y = startY + dy;
		z = startZ + dz + addZ;
		
		ent moveTo( (x,y,z), increments, 0 ,0);
	
		wait increments;
	}
	
	self setOrigin(endOrg);
	earthQuake(.6, 3, self.origin, 200);
	
	level util::clientNotify("player_fling_blur_disable_0");
	
	self unlink();
	ent delete();
	
	self playSound("flinger_land");
	
	self thread zm::player_out_of_playable_area_monitor();
	self.onLaunchPad = undefined;
	self notify("launchpad_finish");
}

function linear(t,b,c,d)
{
	return c*t/(d-1) + b;
}

function easeInSine(t, b, c, d) 
{
	return -c * cos(toRadian(t/d * (Math_PI()/2) ) ) + c + b;
}

function easeOutSine(t, b, c, d)
{
	return c * sin(toRadian(t/d * (Math_PI()/2) ) ) + b;
}

function Math_PI()
{
	return 3.14159265359;
}

function toRadian(degree)
{
	return degree * (180 / Math_PI() );
}

function map(input,lower1,upper1,lower2,upper2)
{
	return ( (input-lower1)*(upper2-lower2) ) / (upper1-lower1) + lower2;
}