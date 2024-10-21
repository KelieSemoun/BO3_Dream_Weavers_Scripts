#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weap_shrink_ray;
#insert scripts\zm\kelie_spike_traps.gsh;
#insert scripts\zm\_zm_weap_shrink_ray.gsh;

#precache( "model", "tag_origin" );

#namespace kelie_spike_traps;

/*
/////////////////////////////////////////
        -- Edited part by KelieSemoun

Desc : Work in Progress. Script made by myself to create specific traps that are either permanently activated and blocks the path (killing zombies and players when changing states when on it) or that are permanently down and frees the path for zombies and players.
Gets changed after a shrink/unshrink ray weapon shot on a trigger for each set of traps.
/////////////////////////////////////////
*/

function init()
{
    level.trig_ents_array = [];
    level.spikes_ents_array = [];
    level.spikes_state = [];
    level.flags_spikes = [];

    init_spike_trap(TRIG_TRAP_NAME_1, TRAP_NAME_1, FLAG_SPIKES_UP_1);
    init_spike_trap(TRIG_TRAP_NAME_2, TRAP_NAME_2, FLAG_SPIKES_UP_2);
    init_spike_trap(TRIG_TRAP_NAME_3, TRAP_NAME_3, FLAG_SPIKES_UP_3);
}

function init_spike_trap(trig_name, trap_name, flag_name)
{
    trig = GetEnt(trig_name, "targetname");
    spikes = GetEntArray(trap_name, "targetname");

    zm_weap_shrink_ray::add_shrinkable_object(trig);
    flag::init(flag_name);
    level.trig_ents_array[level.trig_ents_array.size] = trig;
    level.spikes_ents_array[level.spikes_ents_array.size] = spikes;
    level.spikes_state[level.spikes_state.size] = STATE_DOWN;
    level.flags_spikes[level.flags_spikes.size] = flag_name;
}

function handle_spike_trap(trig, fire_mode)
{
    index_trap = find_trap_index(trig);
    if(isdefined(index_trap))
    {
        spikesState = level.spikes_state[index_trap];
        spikes = level.spikes_ents_array[index_trap];
        if(fire_mode == FIRE_MODE_UNSHRINK && spikesState == STATE_DOWN)
        {
            //state up
            IPrintLnBold("Up");
            level.spikes_state[index_trap] = STATE_UP;
            //array::thread_all(spikes, &MoveTo, self.origin + (0, 0, 117), .2);
            spikes MoveTo(spikes.origin + (0, 0, 117), .2);
            wait .2;
            flag::set_val(level.flags_spikes[index_trap], 1);
        }
        else if (fire_mode == FIRE_MODE_SHRINK && spikesState == STATE_UP)
        {
            //state down
            IPrintLnBold("Down");
            level.spikes_state[index_trap] = STATE_DOWN;
            //array::thread_all(spikes, &MoveTo, self.origin - (0, 0, 117), .2);
            spikes MoveTo(spikes.origin - (0, 0, 117), .2);
            wait .2;
            flag::set_val(level.flags_spikes[index_trap], 0);
        }
    }
}

function find_trap_index(ent)
{
    for (i = 0 ; i < level.trig_ents_array.size ; i++)
    {
        if(level.trig_ents_array[i] == ent)
            return i;
    } 
    return undefined;
}