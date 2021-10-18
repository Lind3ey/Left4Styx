#if defined  _tscale_included_
        #endinput
#endif
#define _tscale_included_


/********************
@noreturn

@	Set timescale.
*/
native TimeScale(Float:scale, Float:time);

public SharedPlugin:__pl_timescale =
{
	name = "timescale",
	file = "l4d2_time_controller.smx",
	required = 1,
};

public __pl_gamemode_SetNTVOptional()
{
	MarkNativeAsOptional("TimeScale");
}