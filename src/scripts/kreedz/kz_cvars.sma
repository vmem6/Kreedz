#include <amxmodx>
#include <amxmisc>

#define PLUGIN 	 	"[Kreedz] Cvars"
#define VERSION 	__DATE__
#define AUTHOR	 	"vmem6"

#define MAX_CVAR_TITLE_LENGTH 64

#define TASK_CVAR_CHECK	1234

enum CvarType {
	ct_int = 0,
	ct_float
};

enum Cvar {
	c_title[64],
	CvarType:c_type,
	c_int_bounds[2],
	Float:c_fl_bounds[2]
};

new const g_cvars[][Cvar] = {
	{ "fps_max", ct_float, {0, 0}, {0.0, 100.0} },
	{ "fps_override", ct_int, {0, 0}, {0.0, 0.0} }
};

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	set_task_ex(2.0, "task_checkCvars", TASK_CVAR_CHECK, .flags = SetTask_Repeat);
}

public task_checkCvars()
{
	new players[MAX_PLAYERS];
	new pnum;
	get_players_ex(players, pnum, GetPlayers_ExcludeDead | GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);

	new data[1];
	for (new i = 0; i != pnum; ++i) {
		for (new j = 0; j != sizeof(g_cvars); ++j) {
			data[0] = j;
			query_client_cvar(players[i], g_cvars[j][c_title], "cvar_query_callback", 1, data);
		}
	}
}

public cvar_query_callback(pid, const cvar[], const value[], const param[])
{
	new cvar_id = param[0];
	switch (g_cvars[cvar_id][c_type]) {
		case ct_int: {
			new val = str_to_num(value);
			handle_cvar_check(pid, cvar_id, value, val >= g_cvars[cvar_id][c_int_bounds][0] && val <= g_cvars[cvar_id][c_int_bounds][1]);
		}
		case ct_float: {
			new Float:val = str_to_float(value);
			handle_cvar_check(pid, cvar_id, value, val >= g_cvars[cvar_id][c_fl_bounds][0] && val <= g_cvars[cvar_id][c_fl_bounds][1]);
		}
	}
}

handle_cvar_check(pid, cvar_id, const value[], bool:result)
{
	if (!result) {
		new user_id = get_user_userid(pid);
		switch (g_cvars[cvar_id][c_type]) {
			case ct_int: {
				new bounds[2];
				bounds[0] = g_cvars[cvar_id][c_int_bounds][0];
				bounds[1] = g_cvars[cvar_id][c_int_bounds][1];
				if (bounds[0] == bounds[1])
					server_cmd("kick #%d %L", user_id, pid, "KZ_CVARS_BAD_CVAR_INT_EXACT", g_cvars[cvar_id][c_title], value, bounds[0]);
				else
					server_cmd("kick #%d %L", user_id, pid, "KZ_CVARS_BAD_CVAR_INT_RANGE", g_cvars[cvar_id][c_title], value, bounds[0], bounds[1]);
			}
			case ct_float: {
				new Float:bounds[2];
				bounds[0] = g_cvars[cvar_id][c_fl_bounds][0];
				bounds[1] = g_cvars[cvar_id][c_fl_bounds][1];
				if (bounds[0] == bounds[1])
					server_cmd("kick #%d %L", user_id, pid, "KZ_CVARS_BAD_CVAR_FLOAT_EXACT", g_cvars[cvar_id][c_title], value, bounds[0]);
				else
					server_cmd("kick #%d %L", user_id, pid, "KZ_CVARS_BAD_CVAR_FLOAT_RANGE", g_cvars[cvar_id][c_title], value, bounds[0], bounds[1]);
			}
		}
	}
}
