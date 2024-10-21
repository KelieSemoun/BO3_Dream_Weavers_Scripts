#using scripts\shared\flag_shared;
#using scripts\zm\_zm_perks;
#using scripts\shared\array_shared;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\shared\util_shared;
#using scripts\codescripts\struct;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_weapons;

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
#namespace grow_soul;

//#using_animtree( "youranimtreename" );//your animtree here

function init()
{
	//end game override
	level.growsoul_endgame_prefix = "Thanks for playing!";
	level.growsoul_win_text = "You escaped!";

	//vars for growing and reward
	level.grow_soul_grow = true;//true to grow, and false to not grow
	// level.grow_soul_final_reward = "door";//options: gun, ending, door
	level.grow_soul_start_scale = 1;//starting scale of model
	level.grow_soul_anim = undefined;//set to true to play an anim, define down in PlayMyAnim function, and uncomment anim related lines
	level.grow_soulallreward = "raygun_mark3";
	level.grow_soul_explode = true;
	level.grow_soulfx_limit = 5;
	level.grow_soul_growth = 0.15;//growth per zombie
	level.grow_soul_size = 3.5;//how big you want it to get scale wise
	level.grow_souldistance = 300;//how far away they can be
	level.growspeed = .015;//how fast to grow
	level.grow_soul_scaler = .001;//how much it grows during growspeed
	level.soul_speed_divider = 200;//the higher the number the faster it travels
	level.grow_soul_reward = "random_weapon";//can also be other things, random_weapon, tesla, minigun, and so on
	level.grow_soul_rand_rewards = array("random_weapon", "free_perk", "minigun");//can add other powerups also
	level.grow_soul_rand_weapons = array( "ar_damage", "lmg_cqb", "shotgun_pump", "smg_versatile" );//added for the weapons to randomly reward
	level.grow_soul_randomize = true;//make false or undefined to not randomize rewards
	//vars for fx and sounds
	level.grow_soulsoulfx = "zombie/fx_ritual_pap_energy_trail";//fx for the soul to travel
	level.grow_soulenterfx = "zombie/fx_powerup_grab_red_zmb";//fx for when the soul gets to the box
	level.grow_soulexplode = "zombie/fx_powerup_off_green_zmb";//fx for exploding
	level.grow_soulentersound = "evt_nuked";//play sound for soul to box
	level.grow_soulrewardsound = "zmb_couch_slam";//sound to play when box is
	level.grow_soul_idlefx = undefined;//"zombie/fx_powerup_on_green_zmb";// fx for model while idle
	//start it up
	level.grow_souls = [];
	
	thread WatchZombies();
	thread SetUpReward("grow_soul");
	thread SetUpReward("grow_soul2");//comment out if you like
	thread SetUpReward("grow_soul3");//comment out if you like
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
	self SetHintString("This door is opened magically.");
	if(isdefined(self.script_flag) && self.script_flag!="")
	{
		flag::init(self.script_flag);
	}
	self thread HandlePaths(false);
	level waittill(system + "_allgrowsouls");
	IPrintLnBold("A magic door has opened!");
	self SetHintString("");
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
	}
	finalscale = level.grow_soul_size;
	if(isdefined(self.script_noteworthy))
	{
		finalscale = Float(self.script_noteworthy);
	}
	while(isdefined(self) && self.scale<finalscale)
	{
		wait(.05);
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
		self thread RewardPlayers();
	}
}

//modified section down to end of SpinMe for gun give reward, set to ray gun
function RewardPlayers()
{
	self endon("death");
	if(isdefined(self))
	{
		self PlaySound(level.grow_soulrewardsound);
	}
	//script_script kvp on model will override level settings
	if(isdefined(self.script_string))
	{
		if(self.script_string == "random_weapon")
		{
			thread RewardGun(self.origin+(0,0,50), array::randomize(level.grow_soul_rand_weapons)[0]);
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
		IPrintLnBold("There are not enough structs placed to give a gun reward");
		return;
	}
	IPrintLnBold("Soul collection complete! Find & Claim your reward!");
	players = GetPlayers();
	for( i=0;i<players.size;i++ )
	{
		thread RewardGun(structs[i].origin);
	}
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
	start = self.origin+(0,0,60);
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
		end = self.origin;
	}
	if(!isdefined(start) || !isdefined(end))
	{
		return;
	}
	if(isdefined(self))
	{
		self PlaySound(level.grow_soulentersound);
	}
	if(isdefined(self))
	{
		if(isdefined(level.grow_soul_grow) && level.grow_soul_grow)
		{
			self thread Grow();
		}
		else
		{
			self.scale+=level.grow_soul_growth;
		}
	}
	if(!isdefined(level.grow_soulfx_count))
	{
		level.grow_soulfx_count = 0;
	}
	if(level.grow_soulfx_count < level.grow_soulfx_limit)
	{
		level.grow_soulfx_count++;
		fxOrg = util::spawn_model( "tag_origin", start );
		fx = PlayFxOnTag( level.grow_soulsoulfx, fxOrg, "tag_origin" );
		time = Distance(start,end)/level.soul_speed_divider;
		fxOrg MoveTo(end+(0,0,50),time);
		wait(time - .05);
		fxOrg moveto(end, .5);
		fxOrg waittill("movedone");
		if(isdefined(self))
		{
			self PlaySound(level.grow_soulentersound);
		}
		PlayFX(level.grow_soulenterfx,end);
		fxOrg delete();
		level.grow_soulfx_count--;
	}
	else
	{
		if(isdefined(self))
		{
			self PlaySound(level.grow_soulentersound);
		}
		PlayFX(level.grow_soulenterfx,end);
	}
}

function Grow()
{
	level endon("allgrowsouls");
	self endon("death");
	scale = 0;
	finalscale = level.grow_soul_size;
	if(isdefined(self.script_noteworthy))
	{
		finalscale = Float(self.script_noteworthy);
	}
	while(isdefined(self) && scale<level.grow_soul_growth)
	{
		wait(level.growspeed);
		if(isdefined(self))
		{
			self SetScale(self.scale+level.grow_soul_scaler);
		}
		if(isdefined(self))
		{
			self.scale = self.scale+level.grow_soul_scaler;
		}
		scale+=level.grow_soul_scaler;
		if(isdefined(self) && self.scale>=finalscale)
		{
			break;
		}
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