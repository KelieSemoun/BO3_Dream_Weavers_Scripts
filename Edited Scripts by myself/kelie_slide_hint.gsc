#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;

#namespace kelie_slide_hint;

#precache( "model", "tag_origin" );

/*
/////////////////////////////////////////
        -- Edited part by KelieSemoun

Desc : Script made by myself to turn on/off a trail of lights representing the edges of the slides above the emptyness to traverse between islands depending on players positions.
/////////////////////////////////////////
*/


function init()
{
    level slide_hint_init();
}

function slide_hint_init()
{
    slide_hint_triggers = GetEntArray( "play_slide_hint_fx", "targetname" );
    if( !isdefined( slide_hint_triggers ) )
        return;

    for( i = 0; i < slide_hint_triggers.size; i++ )
    {
        slide_hint_triggers[i].start = GetEntArray( slide_hint_triggers[i].target, "targetname" );
        slide_hint_triggers[i] thread slide_hint_think();
    }
}

function slide_hint_think()
{
    self endon( "destroyed" );

    self.clientfxs = array("");

    while( isdefined( self ) )
    {
        wait .2;
        
        players = getPlayers();
        
        for(i = 0; i < players.size; i++)
        {
            who = players[i];

            if (!self anyPlayerTouchingSelf() )
            {
                self delete_fxs();
                self notify("slide_hint_deactivate");
                self.touchingTrigger = undefined;
            }

            if (!who isTouching(self) )
                continue;

            if( IsPlayer( who ) && !isdefined(self.touchingTrigger) )
            {
                thread slide_hint_fx_init(self.start);

                self.touchingTrigger = true;
            }
        }
    }
}

function delete_fxs()
{
    for(i = 0; i<self.clientfxs.size ; i++)
    {
        self.clientfxs[i] clientfield::set("fx_spyro_slide_sides_hint0", 0);
        self.clientfxs[i] Delete();
    }
    self.clientfxs = array();
}

function slide_hint_fx_init(start_structs)
{
    self notify("slide_hint_active");

    str_structs_base = "slide_hint" + start_structs[0].script_string;

    thread play_slide_hint_fx(str_structs_base, 0);
}

function play_slide_hint_fx(str_base, it)
{
    str_struct = str_base + it;
    fx_ents = GetEntArray(str_struct, "targetname");
    if( !fx_ents.size>0 )
        return;

    self endon("slide_hint_deactivate");

    for(i = 0; i<fx_ents.size; i++)
    {
        fx = spawn("script_model", fx_ents[i].origin);
        fx setModel("tag_origin");

        ArrayInsert(self.clientfxs, fx, self.clientfxs.size);
        fx clientfield::set( "fx_spyro_slide_sides_hint0", 1);
    }

    wait 0.2;
    it++;
    play_slide_hint_fx(str_base, it);
}

function anyPlayerTouchingSelf()
{
    players = getPlayers();
    for(i = 0; i < players.size; i++)
        if (players[i] isTouching(self) )
            return true;
            
    return false;
}