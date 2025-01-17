#include <amxmodx>
#include <amxmisc>
#include <map_manager>
#include <map_manager_scheduler>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif

#define PLUGIN "Map Manager: Rtv"
#define VERSION "0.1.1"
#define AUTHOR "Mistrick"

#pragma semicolon 1

#if !defined client_disconnected
#define client_disconnected client_disconnect
#endif

#define get_num(%0) get_pcvar_num(g_pCvars[%0])
#define get_float(%0) get_pcvar_float(g_pCvars[%0])

enum (+=100) {
    TASK_CHECK_AFK
};

enum Cvars {
    MODE,
    PERCENT,
    PLAYERS,
    DELAY,
    CHANGE_AFTER_VOTE,
    CHANGE_TYPE,
    ALLOW_EXTEND,
    IGNORE_SPECTATORS,
    IGNORE_AFK,
    AFK_TIME_THRESHOLD
};

enum {
    MODE_PERCENTS,
    MODE_PLAYERS
};

new g_pCvars[Cvars];
new g_iMapStartTime;
new bool:g_bVoted[33];
new g_iVotes;

new g_iOrigin[MAX_PLAYERS + 1][3];
new Float:g_fLastMovedOn[MAX_PLAYERS + 1];
new bool:g_bAfk[MAX_PLAYERS + 1];
new g_iAfkNum;

new g_sPrefix[48];

public plugin_init()
{
    register_plugin(PLUGIN, VERSION + VERSION_HASH, AUTHOR);

    g_pCvars[MODE] = register_cvar("mapm_rtv_mode", "0"); // 0 - percents, 1 - players
    g_pCvars[CHANGE_AFTER_VOTE] = register_cvar("mapm_rtv_change_after_vote", "0"); // 0 - disable, 1 - enable
    g_pCvars[PERCENT] = register_cvar("mapm_rtv_percent", "60");
    g_pCvars[PLAYERS] = register_cvar("mapm_rtv_players", "5");
    g_pCvars[DELAY] = register_cvar("mapm_rtv_delay", "0"); // minutes
    g_pCvars[ALLOW_EXTEND] = register_cvar("mapm_rtv_allow_extend", "0"); // 0 - disable, 1 - enable
    g_pCvars[IGNORE_SPECTATORS] = register_cvar("mapm_rtv_ignore_spectators", "0"); // 0 - disable, 1 - enable
    g_pCvars[IGNORE_AFK] = register_cvar("mapm_rtv_ignore_afk", "0"); // 0 - disable, 1 - enable
    g_pCvars[AFK_TIME_THRESHOLD] = register_cvar("mapm_rtv_afk_time_threshold", "15.0"); // seconds

    register_clcmd("say rtv", "clcmd_rtv");
    register_clcmd("say /rtv", "clcmd_rtv");

    // reset it with sv_restart?
    g_iMapStartTime = get_systime();

    set_task_ex(1.0, "check_afk", TASK_CHECK_AFK, .flags = SetTask_Repeat);
}
public plugin_cfg()
{
    mapm_get_prefix(g_sPrefix, charsmax(g_sPrefix));
    g_pCvars[CHANGE_TYPE] = get_cvar_pointer("mapm_change_type");
}
public client_putinserver(id)
{
  get_user_origin(id, g_iOrigin[id]);
  g_fLastMovedOn[id] = get_gametime();
  g_bAfk[id] = false;
}
public client_disconnected(id)
{
    if(g_bVoted[id]) {
        g_bVoted[id] = false;
        g_iVotes--;
    }
    if(g_bAfk[id]) {
        g_bAfk[id] = false;
        g_iAfkNum--;
    }
    attempt_vote_start();
}
public clcmd_rtv(id)
{
    if(is_vote_started() || is_vote_finished() || is_vote_will_in_next_round()) {
        // add msg?
        return PLUGIN_HANDLED;
    }

    new delay = get_num(DELAY) * 60 - (get_systime() - g_iMapStartTime);
    if(delay > 0) {
        client_print_color(id, print_team_default, "%s^1 %L", g_sPrefix, id, "MAPM_RTV_DELAY", delay / 60, delay % 60);
        return PLUGIN_HANDLED;
    }

    if(!g_bVoted[id]) {
        g_iVotes++;
    }

    new need_votes = 0;
    new ignored_spec = 0;
    new ignored_afk = 0;

    if (attempt_vote_start(need_votes, ignored_spec, ignored_afk)) {
        return PLUGIN_HANDLED;
    }

    if(!g_bVoted[id]) {
        g_bVoted[id] = true;
        new name[32]; get_user_name(id, name, charsmax(name));
        client_print_color(0, print_team_default, "%s^3 %L.", g_sPrefix, LANG_PLAYER, "MAPM_RTV_VOTED", name, need_votes);
    } else {
        client_print_color(id, print_team_default, "%s^1 %L.", g_sPrefix, id, "MAPM_RTV_ALREADY_VOTED", need_votes);
    }

    return PLUGIN_HANDLED;
}
public mapm_can_be_extended(type)
{
    if(type == VOTE_BY_RTV && !get_num(ALLOW_EXTEND)) {
        return EXTEND_BLOCKED;
    }
    return EXTEND_ALLOWED;
}
public mapm_vote_started(type)
{
    g_iVotes = 0;
    arrayset(g_bVoted, false, sizeof(g_bVoted));
}
public mapm_vote_finished(const map[], type, total_votes)
{
    if(type == VOTE_BY_RTV && get_num(CHANGE_TYPE) && get_num(CHANGE_AFTER_VOTE)) {
        intermission();
    }
}
public check_afk()
{
    if(!get_num(IGNORE_SPECTATORS)) {
        return;
    }

    new players[MAX_PLAYERS];
    new pnum;
    get_players_ex(players, pnum, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);

    new Float:time = get_gametime();
    new Float:afk_threshold = get_float(AFK_TIME_THRESHOLD);

    new origin[3];
    for(new i = 0; i != pnum; i++) {
        new pid = players[i];
        if(!is_user_alive(pid)) {
            if(g_bAfk[pid]) {
                g_bAfk[pid] = false;
                g_iAfkNum--;
            }
            continue;
        }

        get_user_origin(pid, origin);
        if(origin[0] == g_iOrigin[pid][0] && origin[1] == g_iOrigin[pid][1] && origin[2] == g_iOrigin[pid][2]) {
            if(!g_bAfk[pid] && time - g_fLastMovedOn[pid] > afk_threshold) {
                g_bAfk[pid] = true;
                g_iAfkNum++;
                attempt_vote_start();
            }
        } else {
            g_iOrigin[pid][0] = origin[0];
            g_iOrigin[pid][1] = origin[1];
            g_iOrigin[pid][2] = origin[2];
            g_fLastMovedOn[pid] = time;
            g_bAfk[pid] = false;
            g_iAfkNum--;
        }
    }
}
bool:attempt_vote_start(&need_votes = 0, &ignored_spec = 0, &ignored_afk = 0)
{
    if(g_iVotes == 0) {
        return false;
    }

    new pnum = get_pnum(ignored_spec, ignored_afk);
    if(get_num(MODE) == MODE_PERCENTS) {
        need_votes = floatround(pnum * get_num(PERCENT) / 100.0, floatround_ceil) - g_iVotes;
    } else {
        need_votes = min(get_num(PLAYERS), pnum) - g_iVotes;
    }

    if(need_votes <= 0) {
        map_scheduler_start_vote(VOTE_BY_RTV);
        return true;
    }

    return false;
}
get_pnum(&ignored_spec = 0, &ignored_afk = 0)
{
    static maxplayers;
    if(!maxplayers) {
        maxplayers = get_maxplayers();
    }

    new ignore_spec = get_num(IGNORE_SPECTATORS);
    ignored_spec = 0;

    new pnum = 0;
    for(new i = 1; i <= maxplayers; i++) {
        if(!is_user_connected(i)
            || is_user_bot(i)
            || is_user_hltv(i)) {
            continue;
        }
        if (ignore_spec) {
            new team = get_user_team(i);
            if(team == 0 || team == 3) {
                ignored_spec++;
                continue;
            }
        }
        pnum++;
    }
    if(get_num(IGNORE_AFK)) {
        pnum -= g_iAfkNum;
        ignored_afk = g_iAfkNum;
    } else {
        ignored_afk = 0;
    }

    return pnum;
}
