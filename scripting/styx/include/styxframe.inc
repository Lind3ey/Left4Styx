#if defined  _styxframe_included_
        #endinput
#endif
#define _styxframe_included_

/******************
@return ConVar mp_modeslots
*/
native GetModeSlots();

/*************************
@return ConVar mp_factmode == 1
*/
native bool Styx_IsVersus();


public SharedPlugin:__pl_styxframe =
{
	name = "styxframe",
	file = "styxframe.smx",
	required = 1,
};

public __pl_styxframe_SetNTVOptional()
{
	MarkNativeAsOptional("GetModeSlots");
	MarkNativeAsOptional("IsVersus");
}