#using scripts\codescripts\struct; // HARRY COMMENT
#using scripts\shared\system_shared; // HARRY COMMENT
#using scripts\shared\array_shared; // HARRY COMMENT
#using scripts\shared\vehicle_shared; // HARRY COMMENT
#using scripts\zm\_zm_score;
#using scripts\shared\flag_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\callbacks_shared; // HARRY COMMENT
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_clone;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_weapons;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hud_util_shared;
#insert scripts\shared\shared.gsh;
#using scripts\shared\scene_shared;
#using scripts\shared\animation_shared;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_weap_shrink_ray;
#insert scripts\zm\_zm_weap_shrink_ray.gsh;

#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#precache ("xanim", "spyro_male_fool_idle");
#precache ("xanim", "spyro_male_fool_death");
#precache ("model", "spyro_male_fool");
#precache ("model", "tag_origin");

#define TRIGGER_TEXT 				"Press & hold ^3&&1^7 to use the turret"
#define PLAYER_TURRET_HINT			"Press ^3[{+melee}]^7 to switch between Shrink and Unshrink mode"
#define PRICE_ACTIVATION 			0
#define TIME_IN_SEC 				300

#using_animtree("dream_weavers_anims");

#namespace buyable_turret; // HARRY COMMENT

REGISTER_SYSTEM_EX( "buyable_turret", &__init__, undefined , undefined) // HARRY COMMENT

/*
/////////////////////////////////////////
		-- Edited part by KelieSemoun

Desc : One of the two biggest script file I've edited to adapt it to my needs in my map. Still a work in progress for a later update with the unshrink fire mode. Here is what this file does :
- Inits the turret, attaches the ai zombie fool model to the turret and locks it onto a random player.
- Waits for the ai zombie fool death to restore original turret position and free it for the player.
- Handles the player interaction with the turret. Fires the shrink ray weapon shots (refer to _zm_shrink_ray.gsc)
- (Work in progress) Changes between Shrink fire mode and unshrink fire mode. Also firing at spike traps changes the states of them with the correct fire mode.
/////////////////////////////////////////
*/

function __init__()
{
	level.currentTurretTrapCycle = 0;
	level.fire_mode = FIRE_MODE_SHRINK;
	level.turret_trap_zone_trig = GetEnt("trig_enable_turret_shooting", "targetname");

	turrets = GetVehicleArray("buyable_turrets", "targetname");
		foreach(turret in turrets)
			turret thread ai_turret_intro();
}

function ai_turret_intro()
{
	trig = GetEnt(self.target, "targetname");
	trig SetCursorHint("HINT_NOICON");
	trig SetHintString("");

	struct = struct::get(trig.target, "targetname");
	struct LinkTo(self);
	trig EnableLinkTo();
	trig LinkTo(self);

	jester = GetEnt("jester_zombie", "targetname");
	jester SetCanDamage(true);
	jester LinkTo(self, "tag_driver_camera");
	jester useanimtree(#animtree);
	jester AnimScripted( "spyro_male_fool_idle", jester.origin , self.angles + (0, 90, 0), %spyro_male_fool_idle);

	level waittill("initial_blackscreen_passed");
	self aim_turret_at_random_player();	

	jester thread dialog_trigger_think();
	thread forceshield_disable_think();
	self thread turret_spike_traps_think();
	
	while(1)
	{
		jester waittill( "damage", damage, attacker, dir, point, mod, model, tag, part, weapon, flags, inflictor, chargeLevel );

		if(mod == "MOD_EXPLOSIVE" || mod == "MOD_EXPLOSIVE_SPLASH")
			continue;

		break;
	}

	level notify("jester_death");
	jester Unlink();
	self ClearTargetEntity();
	jester AnimScripted( "spyro_male_fool_death", jester.origin + (0, 0, -15), jester.angles, %spyro_male_fool_death);
	jester PlaySound("jester_death");
	level.turret_trap_zone_trig Delete();

	turret_origin = GetEnt("turret_target_origin","targetname");
	self SetTurretTargetEnt(turret_origin);
	wait 2;
	self ClearTargetEntity();

	self thread buy_the_turret();
	wait 30;
	jester Delete();

}

function dialog_trigger_think()
{
	trig_dialog = GetEnt("play_jester_dialog", "targetname");
	while(isdefined(trig_dialog))
    {
        wait .2;
        
        players = getPlayers();
        
        for(i = 0; i < players.size; i++)
        {
            who = players[i];

            if (!who isTouching(trig_dialog) )
                continue;

            if( IsPlayer( who ) )
            {    	           	
            	trig_dialog Delete();
            }
        }
    }

    self PlaySound("jester_dialog_with_shield");
	level waittill("shield_disabled");
	self StopSound("jester_dialog_with_shield");
	self PlaySound("jester_dialog_without_shield");
	level waittill("jester_death");
	self StopSound("jester_dialog_without_shield");
	wait 1;
}

function forceshield_disable_think()
{
	trig = GetEnt("trig_forceshield_disable","targetname");
	trig SetCursorHint("HINT_NOICON");
	trig SetHintString("Press & hold ^3&&1^7 to disable the shield");
	trig waittill("trigger");

	shields = GetEntArray("forceshield_disable","targetname");
	shields[0] PlaySound("forceshield_poweroff");
	foreach(shield in shields)
		shield Delete();

	trig Delete();
	wait 1;
	level notify("shield_disabled");
}

function turret_spike_traps_think()
{
	self endon("jester_death");

	while(isdefined(level.turret_trap_zone_trig))
    {
        wait .2;
        
        players = getPlayers();
        
        for(i = 0; i < players.size; i++)
        {
            who = players[i];

            if (!level.turret_trap_zone_trig anyPlayerTouchingSelf() )
            {
                touchingTrigger = undefined;
                level notify("no_player_for_traps");
                self aim_turret_at_random_player();
            }

            if (!who isTouching(level.turret_trap_zone_trig) )
                continue;

            if( IsPlayer( who ) && !isdefined(touchingTrigger))
            {
            	touchingTrigger = true;    	           	
            	self thread play_turret_trap_cycle();
            }
        }
    }
}

function play_turret_trap_cycle()
{
	level endon ("no_player_for_traps");

	target_1 = GetEnt("spike_trap_turret_target_1", "targetname");
	target_2 = GetEnt("spike_trap_turret_target_2", "targetname");
	target_3 = GetEnt("spike_trap_turret_target_3", "targetname");

	while(1)
	{
		if(level.currentTurretTrapCycle % 3 == 0)
		{
			swap_turret_mode();
			self SetTurretTargetEnt(target_1);
			wait 1.5;
		}
		else if(level.currentTurretTrapCycle % 3 == 1)
		{
			self SetTurretTargetEnt(target_2);
			wait .5;
		}
		else if(level.currentTurretTrapCycle % 3 == 2)
		{
			self SetTurretTargetEnt(target_3);
			wait .5;
		}

		self FireWeapon(level.fire_mode);
		zm_weap_shrink_ray::function_fe7a4182(false, level.fire_mode);
		level.currentTurretTrapCycle++;	
	}
}

function aim_turret_at_random_player()
{
	players = GetPlayers();
	player_target_index = RandomIntRange(0, players.size);
	self SetTurretTargetEnt(players[player_target_index]);
}

////////////////////////////////////////////////////////////////////////////////////////////////

//============================ PLAYER FUNCTIONS ===============================================

////////////////////////////////////////////////////////////////////////////////////////////////


function buy_the_turret()
{
	trig = GetEnt(self.target, "targetname");
	struct = struct::get(trig.target, "targetname");
	trig SetHintString(TRIGGER_TEXT);
	model = util::spawn_model( "tag_origin", struct.origin, struct.angles );
	model LinkTo(self, "tag_driver_camera");
	
		while(1)
			{
				trig waittill("trigger", player);

				trig TriggerEnable(false);
				player DisableUsability();
				self thread press_use(player);
				clone = zm_clone::spawn_player_clone(player, model.origin, "invisible_gun");
				clone.angles = model.angles;
				self use_turret(model, clone, player);

				self notify("didnt press use");
				clone Unlink();
				clone Delete();
				player Unlink();
				player SetOrigin( model.origin );
				player.angles = model.angles;
				trig TriggerEnable(true);
			}
}

function press_use(player)
{
	self endon("didnt press use");

	wait 1;
	player EnableUsability();
	while(1)
		{
			if(player UseButtonPressed())
				self notify("press x");
			if(player AttackButtonPressed())
			{
				fire_mode = level.fire_mode;
				self FireWeapon( fire_mode );
				zm_weap_shrink_ray::function_fe7a4182(false, fire_mode);
				wait 0.5;
			}
			if(player MeleeButtonPressed())
			{
				swap_turret_mode();
				wait 0.1;
			}
			wait 0.1;
		}
}

function swap_turret_mode()
{
	if(level.fire_mode == FIRE_MODE_SHRINK)
		level.fire_mode = FIRE_MODE_UNSHRINK;
	else
		level.fire_mode = FIRE_MODE_SHRINK;
}

function use_turret(model, clone, player)
{
	self endon("press x");

	clone LinkTo(model);
	clone useanimtree(#animtree);
	player thread zm_equipment::show_hint_text(PLAYER_TURRET_HINT);
	clone thread symbos_anim_scripted( "turret_idle2", undefined, undefined, undefined, .5);
	self usevehicle( player, 0);
	wait TIME_IN_SEC;
}

function symbos_anim_scripted( str_anim, v_origin = self.origin, v_angles = self.angles, n_rate = 1, n_blend_in = .2, n_blend_out = 0, n_start_time = 0, b_show_player_firstperson_weapon = 0, b_unlink_after_completed = 1, b_wait_till_noanim = 0 )
{
    while ( isDefined( self.symbo_anim ) && IS_TRUE( b_wait_till_noanim ) )
        WAIT_SERVER_FRAME;
        
    self.symbo_anim = str_anim;
    self notify( "symbo_anim_playing" );
    self animation::play( str_anim, v_origin, v_angles, n_rate, n_blend_in, n_blend_out, n_start_time, b_show_player_firstperson_weapon, b_unlink_after_completed );
    self.symbo_anim = undefined;
    self notify( "symbo_anim_complete" );
    
}

function anyPlayerTouchingSelf()
{
    players = getPlayers();
    for(i = 0; i < players.size; i++)
        if (players[i] isTouching(self) )
            return true;
            
    return false;
}