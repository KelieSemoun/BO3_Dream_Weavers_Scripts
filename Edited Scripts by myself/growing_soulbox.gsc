#using scripts\shared\flag_shared;
#using scripts\zm\_zm_perks;
#using scripts\shared\array_shared;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\shared\util_shared;
#using scripts\codescripts\struct;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_weapons;
#using scripts\_redspace\rs_o_jump_pad;

/*
#####################
by: M.A.K.E C E N T S
#####################
Script: 
v1.2 - fixed running in dev 2
v1.3 - Added multiple soul collector support with multiple reward support, and individual sizing with script_noteworthy
v1.3.1 - fixed player.cost to player.score
v1.4 - rotating door prefabs, modified doors to have struct as destination, endgame text added to endgame
v1.4.1 - fixed script_flag to activate zone

grow_soul::init(  );

#using scripts\zm\growing_soulbox;

scriptparsetree,scripts/zm/growing_soulbox.gsc
fx,zombie/fx_ritual_pap_energy_trail
//fx,any other fx you add
//the following is optional for anims
xanim,youranimhere//your anim here
rawfile,animtrees/youranimtreename.atr//your animtree here


###############################################################################
*/

// #precache( "xanim", "youranimhere");//your anim here

#precache( "fx", "zombie/fx_powerup_on_green_zmb" );
#precache( "fx", "zombie/fx_ritual_pap_energy_trail" );
#precache( "fx", "zombie/fx_powerup_off_green_zmb" );
#precache( "model", "spyro_text_zero" );
#precache( "model", "spyro_text_one" );
#precache( "model", "spyro_text_two" );
#precache( "model", "spyro_text_three" );
#precache( "model", "spyro_text_four" );
#precache( "model", "spyro_text_five" );
#precache( "model", "spyro_text_six" );
#precache( "model", "spyro_text_seven" );
#precache( "model", "spyro_text_eight" );
#precache( "model", "spyro_text_nine" );

#namespace grow_soul;

//#using_animtree( "youranimtreename" );//your animtree here

/*
/////////////////////////////////////////
		-- Edited part by KelieSemoun

Desc : One of the two biggest script file I've edited to adapt it to my needs in my map. The main concept of killing a certain amount of zombies in a restricted area around a specific object is still used in here but the logic, display and amount of zombies needed to be killed is completely changed by myself. 
An entire section starting with the comment "//spyro gems" contains functions all written by myself redefining the logic, how it is displayed, the apparition of gems and how they get collected and counts towards the number of zombies needed to be killed.
Video showcase available on my Google Drive in "Soulbox Script Showcase.mp4" through the README.md or my personal website under the Dream Weavers section.
/////////////////////////////////////////
*/

function init()
{
	//end game override
	level.growsoul_endgame_prefix = "Thanks for playing!";
	level.growsoul_win_text = "You escaped!";

	//vars for growing and reward
	level.grow_soul_grow = false;//true to grow, and false to not grow
	level.grow_soul_final_reward = "door";//options: gun, ending, door
	level.grow_soul_start_scale = 1;//starting scale of model
	level.grow_soul_anim = undefined;//set to true to play an anim, define down in PlayMyAnim function, and uncomment anim related lines
	level.grow_soulallreward = "raygun_mark3";
	level.grow_soul_explode = true;
	level.grow_soulfx_limit = 5;
	level.grow_soul_growth = 0.01;//growth per zombie
	level.grow_soul_size = 1.30;//how big you want it to get scale wise
	level.grow_souldistance = 400;//how far away they can be
	level.growspeed = .015;//how fast to grow
	level.grow_soul_scaler = .01;//how much it grows during growspeed
	level.soul_speed_divider = 200;//the higher the number the faster it travels
	level.grow_soul_reward = "spyro_jump_pad";//can also be other things, random_weapon, tesla, minigun, and so on
	level.grow_soul_rand_rewards = array("random_weapon", "free_perk", "minigun");//can add other powerups also
	level.grow_soul_rand_weapons = array( "ar_damage", "lmg_cqb", "shotgun_pump", "smg_versatile" );//added for the weapons to randomly reward
	level.grow_soul_randomize = false;//make false or undefined to not randomize rewards
	//vars for fx and sounds
	level.grow_soulsoulfx = "zombie/fx_ritual_pap_energy_trail";//fx for the soul to travel
	level.grow_soulenterfx = "zombie/fx_powerup_grab_red_zmb";//fx for when the soul gets to the box
	level.grow_soulexplode = "zombie/fx_powerup_off_green_zmb";//fx for exploding
	level.grow_soulentersound = "spyro_gem_collected";//play sound for soul to box
	level.grow_soulrewardsound = "zmb_couch_slam";//sound to play when box is
	level.grow_soul_idlefx = undefined;//"zombie/fx_powerup_on_green_zmb";// fx for model while idle
	//start it up
	level.grow_souls = [];

	//Spyro gems
	level.availableGems = [];
	level.gemBrushes = [];
	level.gemsOrigin = [];

	level.rolldownQueueCurrentIndex = 0;
	level.rolldownQueueIndex = 0;

	level.redGems = init_gems_struct("spyro_red_gem", 1);
	level.greenGems = init_gems_struct("spyro_green_gem", 2);
	level.blueGems = init_gems_struct("spyro_blue_gem", 5);
	level.yellowGems = init_gems_struct("spyro_yellow_gem", 10);
	level.purpleGems = init_gems_struct("spyro_purple_gem", 25);

	thread WatchZombies();
	thread SetUpReward("grow_soul_spyro_jp1");
	thread SetUpReward("grow_soul_spyro_jp2");//comment out if you like
	thread SetUpReward("grow_soul_spyro_jp3");//comment out if you like
	//add more above if you add more systems, match the string to all the prefabs kvps base string
}

function SetUpReward(system)
{
	grow_souls = GetEntArray(system,"targetname");
	level.grow_souls[system]=grow_souls.size;
	array::thread_all(grow_souls, &MonitorGrowSouls, system);

	trigs = GetEntArray(system + "_door","targetname");
	if(trigs.size>0)
	{
		array::thread_all(trigs, &GrowSoulDoor,system);
	}
	trig = GetEnt(system + "_ending","targetname");
	if(isdefined(trig))
	{
		trig thread GrowSoulEnding(system);
	}
}

function GrowSoulEnding(system)
{
	self SetCursorHint("HINT_NOICON");
	self SetHintString("You may not leave until you finish collecting my souls.");
	level waittill(system + "_allgrowsouls");
	IPrintLnBold("You may now escape, if you can.");
	self Show();
	cost = 50000;
	if(isdefined(self.zombie_cost))
	{
		cost = self.zombie_cost;
	}
	self SetCursorHint("HINT_NOICON");
	self SetHintString("Press & hold [{+activate}] for buyable ending [Cost: " + cost + "].");
	while(1)
	{
		self waittill("trigger", player);
		if(player.score+5<cost)
		{
			player PlayLocalSound("zmb_no_cha_ching");
			continue;
		}
		player PlayLocalSound("zmb_cha_ching");
		// IPrintLnBold("Congratulations! You escaped in " + level.round_number + " rounds.");
		if(!isdefined(level.custom_game_over_hud_elem))
		{
			level.custom_game_over_hud_elem = &Ending;
		}
		level notify("end_game");
	}
}

function GrowSoulDoor(system)
{
	self SetCursorHint("HINT_NOICON");
	//self SetHintString("This door is opened magically.");
	if(isdefined(self.script_flag) && self.script_flag!="")
	{
		flag::init(self.script_flag);
	}
	self thread HandlePaths(false);
	level waittill(system + "_allgrowsouls");
	//IPrintLnBold("A magic door has opened!");
	//self SetHintString("");
	self thread HandlePaths();
	if(isdefined(self.script_flag))
	{
		level flag::set(self.script_flag);
	}
	wait(1);
	self delete();
}

function HandlePaths(connect = true)
{
	if(isdefined(self.target))
	{
		doors = GetEntArray(self.target,"targetname");
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
						if(isdefined(struct.script_noteworthy))
						{
							door RotateDoor(struct);
						}
						else
						{
							door MoveTo(struct.origin,1);
						}
						
					}
					else if(isdefined(door.script_vector))
					{
						vector = VectorScale( door.script_vector, 1 );
						// IPrintLnBold("move door");
						// IPrintLnBold(self.origin + vector);
						door MoveTo(self.origin + vector,1);
					}
					if(isdefined(door.script_sound))
					{
						door PlaySound(door.script_sound);
					}
				}
			}
			if(isdefined(door))
			{
				door thread HandlePaths(connect);
			}
		}
	}
}

function RotateDoor(struct)
{
	pivot = Spawn("script_model",struct.origin);
	pivot SetModel("tag_origin");
	self LinkTo(pivot);
	rotation = 120;
	if(isdefined(struct.script_string))
	{
		rotation = Int(struct.script_string);
	}
	pivot RotateYaw(rotation,1);
	
	wait(1.1);
	pivot Delete();
}

function MonitorGrowSouls(system)
{
	self endon("death");
	if(isdefined(level.grow_soul_anim) && level.grow_soul_anim)
	{
		self thread PlayMyAnim();
	}
	if(isdefined(self) && isdefined(level.grow_soul_idlefx))
	{
		PlayFXOnTag(level.grow_soul_idlefx,self,"tag_origin");
	}
	if(isdefined(self))
	{
		if(isdefined(level.grow_soul_start_scale))
		{
			self.scale = level.grow_soul_start_scale;
		}
		else
		{
			self.scale = 1;
		}
		self.collectedGems = 0;
	}

	//Init Vars Spyro Text
	previousRemainingGems = -1;
	self.no_more_hundreds = false;
	self.no_more_tens = false;
	self.rolldownToZero = false;

	if(isdefined(self.script_noteworthy))
		neededGems = Int(self.script_noteworthy);
	else
		neededGems = 200;
	while(isdefined(self) && !self.rolldownToZero)
	{
		newRemainingGems = neededGems - self.collectedGems;
		if(newRemainingGems != previousRemainingGems)
		{
			self thread update_gems_count(previousRemainingGems, newRemainingGems);
			previousRemainingGems = newRemainingGems;
		}	
		self waittill("gem_collected");
	}
	if(isdefined(self) && isdefined(level.grow_soul_explode) && level.grow_soul_explode)
	{
		self thread BlowUpGrowSoul(system);
	}
}

function PlayMyAnim()
{
	// self UseAnimTree(#animtree);
	// self AnimScripted("done",self.origin,self.angles,%youranimhere);
}

function BlowUpGrowSoul(system)
{
	self endon("death");
	level.grow_souls[system]--;
	if(level.grow_souls[system]<=0)
	{
		thread RewardForAllGrowSouls(system);
	}
	if(isdefined(self) && isdefined(level.grow_soul_idlefx))
	{
		PlayFX(level.grow_soulexplode,self.origin);
	}
	// Playfx( level._effect["lightning_dog_spawn"], self.origin );
	if(isdefined(self))
	{
		self thread RewardPlayers(system);
	}
}

//modified section down to end of SpinMe for gun give reward, set to ray gun
function RewardPlayers(system)
{
	self endon("death");
	if(isdefined(self))
	{
		//self PlaySound(level.grow_soulrewardsound);
	}
	//script_script kvp on model will override level settings
	if(isdefined(self.script_string))
	{
		if(self.script_string == "random_weapon")
		{
			thread RewardGun(self.origin+(0,0,50), array::randomize(level.grow_soul_rand_weapons)[0]);
		}
		else if(self.script_string == "spyro_jump_pad")
		{
			switch(system)
			{
				case "grow_soul_spyro_jp1":
					thread rs_o_jump_pad::__init__("jump_pad_set1");
					break;
				case "grow_soul_spyro_jp2":
					thread rs_o_jump_pad::__init__("jump_pad_set2");
					break;
				case "grow_soul_spyro_jp3":
					thread rs_o_jump_pad::__init__("jump_pad_set3");
					break;
			}
			
		}
		else
		{
			zm_powerups::specific_powerup_drop( self.script_string, self.origin);
		}
	}
	else
	{
		if(isdefined(level.grow_soul_randomize) && level.grow_soul_randomize)
		{
			reward = array::randomize(level.grow_soul_rand_rewards)[0];
			if(!isdefined(level.grow_soullastreward))
			{
				if(reward=="random_weapon")
				{
					thread RewardGun(self.origin+(0,0,50), array::randomize(level.grow_soul_rand_weapons)[0]);
				}
				else
				{
					zm_powerups::specific_powerup_drop( reward, self.origin);
				}
				level.grow_soullastreward = reward;
			}
			else
			{
				while(reward==level.grow_soullastreward || (reward == "minigun" && level.round_number<5))
				{
					reward = array::randomize(level.grow_soul_rand_rewards)[0];
				}
				if(reward=="random_weapon")
				{
					thread RewardGun(self.origin+(0,0,50), array::randomize(level.grow_soul_rand_weapons)[0]);
				}
				else
				{
					zm_powerups::specific_powerup_drop( reward, self.origin);
				}
				level.grow_soullastreward = reward;
			}
		}
		else
		{
			if(level.grow_soul_reward=="random_weapon")
			{
				thread RewardGun(self.origin+(0,0,50), array::randomize(level.grow_soul_rand_weapons)[0]);
			}
			else
			{
				zm_powerups::specific_powerup_drop( level.grow_soul_reward, self.origin);
			}
		}
	}
	if(isdefined(self.target))
	{
		clips = GetEntArray(self.target,"targetname");
		foreach(clip in clips)
		{
			clip ConnectPaths();
			clip Delete();
		}
	}
	self delete();
}

function SetGunHint(text, trig)
{
	if(isdefined(self.grow_soul_hud))
	{
		return;
	}
	self.grow_soul_hud = NewClientHudElem( self );
	self.grow_soul_hud.horzAlign = "center";
	self.grow_soul_hud.vertAlign = "middle";
	self.grow_soul_hud.alignX = "center";
	self.grow_soul_hud.alignY = "middle";
	self.grow_soul_hud.foreground = 1;
	self.grow_soul_hud.fontscale = 1;
	self.grow_soul_hud.alpha = 1;
	self.grow_soul_hud.color = ( 0.44, .74, .94 );
	self.grow_soul_hud SetText(text);
	while(isdefined(trig) && self IsTouching(trig))
	{
		wait(.05);
	}
	self.grow_soul_hud SetText("");
	self.grow_soul_hud Destroy();
	self.grow_soul_hud = undefined;
}

function RewardForAllGrowSouls(system)
{
	level notify(system + "_allgrowsouls");

	structs = struct::get_array(system + "_reward", "targetname");
	if(structs.size<=0)
	{
		return;
	}
	if(structs.size>0 && structs.size<4)
	{
		//IPrintLnBold("There are not enough structs placed to give a gun reward");
		return;
	}
	//IPrintLnBold("Soul collection complete! Find & Claim your reward!");
	/*players = GetPlayers();
	for( i=0;i<players.size;i++ )
	{
		thread RewardGun(structs[i].origin);
	}*/
}

function RewardGun(pos, weapon = level.grow_soulallreward)
{
	gun = spawn("script_model", pos);
	playsoundatposition("zmb_spawn_powerup", pos);
	
	gun SetModel(GetWeaponWorldModel(GetWeapon(weapon)));
	PlayFX(level._effect["powerup_grabbed_solo"], gun.origin);
	trig = spawn("trigger_radius", gun.origin, 0, 20, 50);
	gun thread SpinMe();
	gun thread GiveMe(weapon, trig);
	if(weapon != level.grow_soulallreward)
	{
		gun thread LifeTime(trig);
	}
}

function LifeTime(trig)
{
	self endon("death");
	wait(120);//wait 2 minutes then delete
	if(isdefined(self))
	{
		self notify("rewardgun_delete");
	}
	if(isdefined(trig))
	{
		trig delete();
	}
	if(isdefined(self))
	{
		self delete();
	}
}

function GiveMe(weapon = level.grow_soulallreward, trig)
{
	self endon("rewardgun_delete");
	while(1)
	{
		trig waittill("trigger", player);
		player thread SetGunHint("Press & hold [{+activate}] to take weapon.", trig);
		if(player HasWeapon(getweapon("minigun")))
		{
			continue;
		}
		if(!(player UseButtonPressed()))
		{
			continue;
		}
		// if(player HasWeapon(getweapon(weapon)))
		// {
		// 	continue;
		// }
		if(player laststand::player_is_in_laststand())
		{
			continue;
		}
		trig delete();
		self delete();
		player zm_weapons::weapon_give(getweapon(weapon));
		player SwitchToWeapon(getweapon(weapon));
		break;
		wait(.1);
	}
}

function SpinMe()
{
	self endon("rewardgun_delete");
	self endon("death");
	if(isdefined(self) && isdefined(level.grow_soul_idlefx))
	{
		PlayFXOnTag(level.grow_soul_idlefx,self,"tag_origin");
	}
	while(isdefined(self))
	{
		if(isdefined(self))
		{
			self rotateyaw(360,2);
		}
		wait(1.9);
	}
}

function WatchZombies()
{
	level endon("allgrowsouls");
	while(1)
	{
		zombies = GetAiSpeciesArray( "axis", "all" );
		for(i=0;i<zombies.size;i++)
		{
			if(isdefined(zombies[i].grow_soul))
			{
				continue;
			}
			else
			{
				zombies[i] thread WatchMe();
			}
		}
		wait(.05);
	}
}

function WatchMe()
{
	level endon("allgrowsouls");
	if(isdefined(self))
	{
		self.grow_soul = true;
	}
	else
	{
		return;
	}
	self waittill("death");
	// start = self GetTagOrigin( "J_SpineLower" );//different for dog
	if(!isdefined(self))
	{
		return;
	}
	start = self.origin+(0,0,30);
	if(!isdefined(start))
	{
		return;
	}

	grow_souls =[];
	keys = GetArrayKeys(level.grow_souls);
	foreach(soul in keys)
	{
		grow_souls = ArrayCombine(grow_souls, GetEntArray(soul,"targetname"),false,false);
	}
	closest = level.grow_souldistance;
	cgs = undefined;
	foreach(gs in grow_souls)
	{
		if(Distance(start,gs.origin)<closest && BulletTracePassed( start, gs.origin+(0,0,50), false, self ))
		{
			closest = Distance(start,gs.origin);
			cgs = gs;
		}
	}
	if(!isdefined(cgs) || !isdefined(cgs.origin))
	{
		return;
	}
	cgs thread SendSoul(start);
}

function SendSoul(start)
{

	if(isdefined(self))
	{
		end = self.origin + (0, 0, 15);
	}
	if(!isdefined(start) || !isdefined(end))
	{
		return;
	}
	result = RandomInt(100);

	if(result < 35)
		currentGemColor = level.redGems;
	else if(result < 65)
		currentGemColor = level.greenGems;
	else if(result < 85)
		currentGemColor = level.blueGems;
	else if(result < 95)
		currentGemColor = level.yellowGems;
	else
		currentGemColor = level.purpleGems;

	gemIndex = currentGemColor get_indexOf_next_available_gem();
	spawn_gem(start, gemIndex);

	if(!isdefined(gemIndex) || level.availableGems[gemIndex])
		return;

	if(isdefined(self))
	{
		level.gemBrushes[gemIndex] PlaySound("spyro_spark_collect");
	}
	if(!isdefined(level.grow_soulfx_count))
	{
		level.grow_soulfx_count = 0;
	}
	if(level.grow_soulfx_count < level.grow_soulfx_limit)
	{
		/*level.grow_soulfx_count++;
		fxOrg = util::spawn_model( "tag_origin", start );
		fx = PlayFxOnTag( level.grow_soulsoulfx, fxOrg, "tag_origin" );*/
		time = Distance(start,end)/level.soul_speed_divider;
		level.gemBrushes[gemIndex] MoveTo(end,time);
		level.gemBrushes[gemIndex] waittill("movedone");
		if(isdefined(self))
		{
			self.collectedGems += currentGemColor.value;
			self PlaySound("spyro_gem_collected");
			self thread display_gem_value(currentGemColor);
			self notify("gem_collected");
		}
		PlayFX(level.grow_soulenterfx,end);
		restoreGem(gemIndex);
		/*fxOrg delete();
		level.grow_soulfx_count--;*/
	}
	else
	{
		if(isdefined(self))
		{
			self PlaySound("spyro_gem_collected");
		}
		PlayFX(level.grow_soulenterfx,end);
	}
}

function Ending(player, game_over, survived)
{	
    game_over.alignX = "center";
    game_over.alignY = "middle";
    game_over.horzAlign = "center";
    game_over.vertAlign = "middle";
    game_over.y -= 130;
    game_over.foreground = true;
    game_over.fontScale = 3;
    game_over.alpha = 0;
    game_over.color = ( 1.0, 1.0, 1.0 );
    game_over.hidewheninmenu = true;
    game_over SetText( level.growsoul_endgame_prefix + " " + level.growsoul_win_text );

    game_over FadeOverTime( 1 );
    game_over.alpha = 1;
    if ( player isSplitScreen() )
    {
        game_over.fontScale = 2;
        game_over.y += 40;
    }

    survived.alignX = "center";
    survived.alignY = "middle";
    survived.horzAlign = "center";
    survived.vertAlign = "middle";
    survived.y -= 100;
    survived.foreground = true;
    survived.fontScale = 2;
    survived.alpha = 0;
    survived.color = ( 1.0, 1.0, 1.0 );
    survived.hidewheninmenu = true;
    if ( player isSplitScreen() )
    {
        survived.fontScale = 1.5;
        survived.y += 40;
    }

}

// Spyro Gems
function init_gems_struct(targetname_value, value)
{
	s_gem = SpawnStruct();
	s_gem.value = value;
	switch(s_gem.value)
	{
		case 1:
			s_gem.offset = 0;
			break;
		case 2:
			s_gem.offset = level.redGems.count;
			break;
		case 5:
			s_gem.offset = level.greenGems.offset + level.greenGems.count;
			break;
		case 10:
			s_gem.offset = level.blueGems.offset + level.blueGems.count;
			break;
		case 25:
			s_gem.offset = level.yellowGems.offset + level.yellowGems.count;
			break;
		default:
			break;
	}

	ents = GetEntArray(targetname_value, "targetname");
	s_gem.count = ents.size;

	for(i=0 ; i<s_gem.count ; i++)
	{
		gemBrush = GetEnt(ents[i].target, "targetname");
		level.gemBrushes[i + s_gem.offset] = gemBrush;
		level.availableGems[i + s_gem.offset] = true;
		level.gemsOrigin[i + s_gem.offset] = gemBrush.origin;
	}

	return s_gem;
}

function get_indexOf_next_available_gem()
{
	for(i= self.offset ; i<self.offset + self.count ; i++)
	{
		if(level.availableGems[i])
		{
			level.availableGems[i] = false;
			return i;
		}
	}
	return undefined;
}

function spawn_gem(origin, gemIndex)
{
	if(!isdefined(gemIndex))
		return;

	level.gemBrushes[gemIndex] MoveTo(origin, .05);
	wait .2;	
	level.gemBrushes[gemIndex] MoveTo(origin + (0, 0, 30), .4, 0, .4);
	wait .4;	
	level.gemBrushes[gemIndex] MoveTo(origin + (0, 0, -25), .8, .8, 0);
	wait .8;
	level.gemBrushes[gemIndex] PlaySound("spyro_gem_fall");

	trig = spawn("trigger_radius", level.gemBrushes[gemIndex].origin, 0, 30, 24);
	trig sethintstring("");
	trig setcursorhint("HINT_NOICON");
	trig thread gem_countdown(gemIndex);
	while(1)
	{
		trig waittill("trigger", who);
		if(!isplayer(who))
		{
			continue;
		}
		return;
	}
}

function gem_countdown(gemIndex)
{
	self endon("gem_collected");
	time_elapsed = 0;
	while(time_elapsed < 30)
	{
		wait 1;
		time_elapsed++;
	}
	restoreGem(gemIndex);
	self delete();
		
}

function restoreGem(gemIndex)
{
	level.availableGems[gemIndex] = true;
	level.gemBrushes[gemIndex] MoveTo(level.gemsOrigin[gemIndex], .05);
}

function update_gems_count(oldNb, newNb)
{
	previous_number = oldNb;
	if(oldNb == -1)
	{
		previous_number = newNb;
	}
	previous_number_backup = previous_number;
	previous_number_units = previous_number % 10;
	previous_number = Int(previous_number / 10);
	previous_number_tens = previous_number % 10;
	previous_number = Int(previous_number / 10);
	previous_number_hundreds = previous_number % 10;
	previous_number = previous_number_backup;



	nbCount = 3;
	if(previous_number_hundreds == 0)
	{
		nbCount -= 1;
		if(previous_number_tens == 0)
			nbCount -= 1;
	}

	if(oldNb==-1)
	{
		self.number_hundreds = spawn("script_model", self get_model_origin_from_nbCount(nbCount, 1));
		self.number_tens = spawn("script_model", self get_model_origin_from_nbCount(nbCount, 2));
		self.number_units = spawn("script_model", self get_model_origin_from_nbCount(nbCount, 3));

		self.number_hundreds setup_visual_text(previous_number_hundreds, self, false);
		self.number_tens setup_visual_text(previous_number_tens, self, false);
		self.number_units setup_visual_text(previous_number_units, self, false);
	}
	else
	{
		positionInQueue = level.rolldownQueueIndex;
		level.rolldownQueueIndex++;
		while(1)
		{
			if(positionInQueue == level.rolldownQueueCurrentIndex)
				break;
			wait .05;
		}
		
		new_number_hundreds = previous_number_hundreds;
		new_number_tens = previous_number_tens;
		first_number_no_more_hundreds = false;
		first_number_no_more_tens = false;

		for(i = oldNb - 1 ; i > newNb - 1; i--)
		{
			i_backup = i;
			new_number_units = i % 10;
			if(new_number_units == 9)
			{
				i = Int(i / 10);
				new_number_tens = i % 10;
				if(new_number_tens == 9)
				{
					i = Int(i / 10);
					new_number_hundreds = i % 10;
					if(new_number_hundreds == 0)
					{
						self.no_more_hundreds = true;
						first_number_no_more_hundreds = true;
					}
				}
				if(new_number_tens == 0 && self.no_more_hundreds)
				{
					self.no_more_tens = true;
					first_number_no_more_tens = true;
				}
			}
			i = i_backup;

			if(first_number_no_more_hundreds)
			{
				first_number_no_more_hundreds = false;
				nbCount = 2;
				self.number_hundreds delete();
				self.number_tens SetOrigin(self get_model_origin_from_nbCount(nbCount, 2));
				self.number_units SetOrigin(self get_model_origin_from_nbCount(nbCount, 3));
			}
			if(first_number_no_more_tens)
			{
				first_number_no_more_tens = false;
				nbCount = 1;
				self.number_tens delete();
				self.number_units SetOrigin(self get_model_origin_from_nbCount(nbCount, 3));
			}

			if(!self.no_more_hundreds)
				self.number_hundreds SetModel(get_str_model_from_number(new_number_hundreds));
			if(!self.no_more_tens)
				self.number_tens SetModel(get_str_model_from_number(new_number_tens));
			self.number_units SetModel(get_str_model_from_number(new_number_units));

			wait 0.2;
			if(i == 0)
			{
				self.rolldownToZero = true;
				self.number_units delete();
				self notify("gem_collected");
				break;
			}
		}
		level.rolldownQueueCurrentIndex++;
	}
}

function setup_visual_text(nb, gs, isGemValue)
{
	self SetModel(get_str_model_from_number(nb));
	self SetScale(25.0);
	self RotateTo(gs.angles + (0, 90, 90), .05);
	wait .05;
	if(!isGemValue)
		self thread pan_text_model();
}

function pan_text_model()
{
	self RotateTo(self.angles + (0, -45, 0), .05);
	wait .05;
	while(1)
	{
		self RotateTo(self.angles + (0, 90, 0), 1.5);
		wait 1.5;
		self RotateTo(self.angles + (0, -90, 0), 1.5);
		wait 1.5;
	}
}

function get_model_origin_from_nbCount(nbCount, unit)
{
	if(nbCount == 3)
	{
		y = 15;
		y_ang = self.angles[1];
		if(unit == 1)
		{
			if(y_ang == 200)
				return (self.origin + (0, y, 100));
			return (self.origin + (0, -y, 100));
		}
		if(unit == 2)
			return (self.origin + (0, 0, 100));
		if (y_ang == 200)
			return (self.origin + (0, -y, 100));
		return (self.origin + (0, y, 100));
	}
	if(nbCount == 2)
	{
		y = 8;
		if(unit == 2)
			if(y_ang == 200)
				return (self.origin + (0, y, 100));
			return (self.origin + (0, -y, 100));
		if(y_ang == 200)
			return (self.origin + (0, -y, 100));
		return (self.origin + (0, y, 100));
	}
	return (self.origin + (0, 0, 100));
}

function get_str_model_from_number(number)
{
	str = undefined;
	switch(number)
	{
		case 0:
			str = "spyro_text_zero";
			break;
		case 1:
			str = "spyro_text_one";
			break;
		case 2:
			str = "spyro_text_two";
			break;
		case 3:
			str = "spyro_text_three";
			break;
		case 4:
			str = "spyro_text_four";
			break;
		case 5:
			str = "spyro_text_five";
			break;
		case 6:
			str = "spyro_text_six";
			break;
		case 7:
			str = "spyro_text_seven";
			break;
		case 8:
			str = "spyro_text_eight";
			break;
		case 9:
			str = "spyro_text_nine";
			break;
		default:
			break;	
	}
	return str;
}

function display_gem_value(gem)
{
	value = gem.value;

	value_backup = value;
	value_units = value % 10;
	value = Int(value / 10);
	value_tens = value % 10;

	nbCount = 2;
	if(value_tens == 0)
		nbCount --;

	y_ang = self.angles[1];
	is_inverted = y_ang == 200;

	number_units = spawn("script_model", (self.origin + (0, 0, 15)));
	number_units setup_visual_text(value_units, self, true);
	number_tens = undefined;
	if(nbCount == 2)
	{
		y_offset = 15;
		if(is_inverted)
			number_tens = spawn("script_model", (self.origin + (0, y_offset, 15)));
		else
			number_tens = spawn("script_model", (self.origin + (0, - y_offset, 15)));
		number_tens setup_visual_text(value_tens, self, true);
		number_tens EnableLinkTo();
		number_tens LinkTo(number_units);
	}
	y_offset = 30;
	if(is_inverted)
		number_units MoveTo(self.origin + (0, - y_offset, 50), .5);
	else 
		number_units MoveTo(self.origin + (0, y_offset, 50), .5);
	wait .5;
	number_units delete();
	if(isdefined(number_tens))
		number_tens delete();
}