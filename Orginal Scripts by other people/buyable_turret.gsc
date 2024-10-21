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
#using scripts\zm\_zm_weapons;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\hud_util_shared;
#insert scripts\shared\shared.gsh;
#using scripts\shared\scene_shared;
#using scripts\shared\animation_shared;
#using scripts\zm\_zm_audio;

#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#define TRIGGER_TEXT 				"Press & hold ^3&&1^7 to use the turret"
#define PRICE_ACTIVATION 			50
#define TIME_IN_SEC 				10

#using_animtree("generic");

#namespace buyable_turret; // HARRY COMMENT

REGISTER_SYSTEM_EX( "buyable_turret", &__init__, undefined , undefined) // HARRY COMMENT


function __init__()
{
	turrets = GetVehicleArray("buyable_turrets", "targetname");
		foreach(turret in turrets)
			turret thread buy_the_turret();
}

function buy_the_turret()
{
	trig = GetEnt(self.target, "targetname");
	struct = struct::get(trig.target, "targetname");
	clip = GetEnt(struct.target, "targetname");
	clip LinkTo(self);
	trig SetCursorHint("HINT_NOICON");
	trig EnableLinkTo();
	trig LinkTo(self);
	trig SetHintString(TRIGGER_TEXT +  " [Cost:" + PRICE_ACTIVATION + "]");
	model = util::spawn_model( "tag_origin", struct.origin, struct.angles );
	model LinkTo(self, "tag_driver_camera");
	
		while(1)
			{
				trig waittill("trigger", player);
				if(player.score < PRICE_ACTIVATION)
					{
					self playsound("evt_perk_deny");
                   	player zm_audio::create_and_play_dialog( "general", "outofmoney" );
					continue;
					}

				self playsound("enter_turret");
				trig TriggerEnable(false);
				player DisableUsability();
				player zm_score::minus_to_player_score(PRICE_ACTIVATION);
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

			wait 0.05;
		}
}

function use_turret(model, clone, player)
{
	self endon("press x");

	clone LinkTo(model);
	clone useanimtree(#animtree);
	clone thread symbos_anim_scripted( "turret_idle2", undefined, undefined, undefined, .5);
	self usevehicle( player, 0 );
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