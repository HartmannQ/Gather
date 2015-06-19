/*-----------------------------------------------------------
[*] Gather v1.0
 * Copyright (C) 2015  Hartmann

[**]
 *  This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
[**]

[*] Changelog
 * v1.0
 * - First release.
[*]
-*---------------------------------------------------------*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <csx>
#include <fvault>
#include <engine>
#include <fakemeta_util>
#include <fun>

#define PLUGIN "Gather"
#define VERSION "1.0"
#define AUTHOR "Hartmann"

#define PREFIX "!g(Gather)!g"

#define ACCESS_LEVEL ADMIN_RCON 

#define TASKID  1996
#define OFFSET_TEAM 114
#define fm_get_user_team(%1) get_pdata_int(%1, OFFSET_TEAM)
#define g_VaultSkillPoints	"skillpoints_v2"
#define g_VaultNames		"skillpoints_names"
#define MAX_PLAYERS	32
#define MAX_PLAYERSS	33
#define TIMER_SECONDS 10 

#define OFFSET_MAPZONE            235
#define PLAYER_IN_BOMB_TARGET        (1<<1)

#define EXPIREDAYS	30
#define MAX_CLASSES	5
#define MAX_LEVELS	5
#define MAX_PONTUATION	10000 // max skillpoints per player

#define IsPlayer(%1)		( 1 <= %1 <= g_iMaxPlayers )

// weapons offsets
#define OFFSET_CLIPAMMO        51
#define OFFSET_LINUX_WEAPONS    4
#define fm_cs_set_weapon_ammo(%1,%2)    set_pdata_int(%1, OFFSET_CLIPAMMO, %2, OFFSET_LINUX_WEAPONS)

// players offsets
#define m_pActiveItem 373

#define MIN_AFK_TIME 30		// I use this incase stupid admins accidentally set mp_afktime to something silly.
#define WARNING_TIME 15		// Start warning the user this many seconds before they are about to be trasfered to spectator.
#define CHECK_FREQ 5		// This is also the warning message frequency.

#define MENU_KEYS (1<<0 | 1<<1 | 1<<2 | 1<<3 | 1<<4 | 1<<5 | 1<<6 | 1<<7 | 1<<8 | 1<<9)
#define MENU_SLOTS 8

#define MAX_MAPS 4 
#define DMG_GRENADE (1<<24)

#define UPDATE_TIME	1.0
#define ENTITY_CLASS	"env_host_timeleft"
#define MAX_BUFFER_LENGTH       2500

const NOCLIP_WPN_BS    = ((1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_KNIFE)|(1<<CSW_C4))

new const g_MaxClipAmmo[] = {
	0,
	13, //CSW_P228
	0,
	10, //CSW_SCOUT
	0,  //CSW_HEGRENADE
	7,  //CSW_XM1014
	0,  //CSW_C4
	30,//CSW_MAC10
	30, //CSW_AUG
	0,  //CSW_SMOKEGRENADE
	15,//CSW_ELITE
	20,//CSW_FIVESEVEN
	25,//CSW_UMP45
	30, //CSW_SG550
	35, //CSW_GALIL
	25, //CSW_FAMAS
	12,//CSW_USP
	20,//CSW_GLOCK18
	10, //CSW_AWP
	30,//CSW_MP5NAVY
	100,//CSW_M249
	8,  //CSW_M3
	30, //CSW_M4A1
	30,//CSW_TMP
	20, //CSW_G3SG1
	0,  //CSW_FLASHBANG
	7,  //CSW_DEAGLE
	30, //CSW_SG552
	30, //CSW_AK47
	0,  //CSW_KNIFE
	50//CSW_P90
}

new const CLASSES[ MAX_CLASSES ][ ] = {
	"BOT",
	"NOOB",
	"GAMER",
	"LEET",
	"TOP"
}

new const LEVELS[ MAX_LEVELS ] = {
	500,
	1200,
	1800,
	2500,
	100000 /* high value (not reachable) */
}

enum _:FvaultData {
	szSteamID[ 35 ],
	szSkillP_Data[ 128 ]
}


new g_iMaxPlayers
new g_szAuthID[ MAX_PLAYERS + 1 ][ 35 ]
new g_szName[ MAX_PLAYERS + 1 ][ 32 ]
new g_iCurrentKills[ MAX_PLAYERS + 1 ]
new g_szMotd[ 1536 ]

new g_iPoints[ MAX_PLAYERS + 1 ]
new g_iLevels[ MAX_PLAYERS + 1 ]
new g_iClasses[ MAX_PLAYERS + 1 ]

new g_iKills[ MAX_PLAYERS + 1 ]
new g_iDeaths[ MAX_PLAYERS + 1 ]
new g_iHeadShots[ MAX_PLAYERS + 1 ]
new g_iKnifeKills[ MAX_PLAYERS + 1 ]
new g_iKnifeDeaths[ MAX_PLAYERS + 1 ]
new g_iGrenadeKills[ MAX_PLAYERS + 1 ]
new g_iGrenadeDeaths[ MAX_PLAYERS + 1 ]
new g_iBombExplosions[ MAX_PLAYERS + 1 ]
new g_iDefusedBombs[ MAX_PLAYERS + 1 ]
new g_iWonRounds[ MAX_PLAYERS + 1 ]

new bool:g_bRoundEnded

new g_iHideCmds
new g_iLostPointsTK
new g_iLostPointsSuicide
new g_iWonPointsKill
new g_iLostPointsDeath
new g_iWonPointsHeadshot
new g_iLostPointsHeadshot
new g_iWonPointsKnife
new g_iLostPointsKnife
new g_iWonPointsGrenade
new g_iLostPointsGrenade
new g_iWonPointsTerrorists
new g_iWonPointsCounterTerrorists
new g_iLostPointsTerrorists
new g_iLostPointsCounterTerrorists
new g_iWonPointsPlanter
new g_iWonPointsPlanterExplode
new g_iWonPointsDefuser
new g_iWonPoints4k
new g_iWonPoints5k
new g_iNegativePoints

enum {
	TEAM_NONE,
	TEAM_T,
	TEAM_CT,
	TEAM_SPEC,
	MAX_TEAMS
};
new g_max_clients
new bool:g_IsStarted
new bool:g_bSecondHalf
new cvar_humans_join_team
new g_iScore[2]
new g_ReadySeconds = 6;
new g_ReadySeconds2 = 6;
new g_szTeamName[2]
new g_iTeam
new g_iScoreOffset
new g_iLastTeamScore[2]
new g_iAltScore
new g_szLogFile[64];
new bool:g_bStop
new bool:g_bStop2
new bool:g_Demo[33]

new bool:g_bStart 
new bool:is_plr_connected[33]
new bool:is_plr_ready[33]
new g_MsgReady[512]
new g_MsgNotReady[512]

new g_unready_color
new g_ready_color
new g_info_color
new g_plr_amount

new g_SyncReady
new g_SyncNotReady
new g_SyncInfo
new g_iPlayerCount
new g_iReadyCount 

new g_ClassName[] = "rd_msg"
enum CVARS {
	CVAR_MINLENGTH,
	CVAR_MAXLENGTH,
}

new bool:g_war
new g_MsgSync6
new g_MsgSync5
new g_MsgSync4
new g_MsgSync3
new g_MsgSync2
new g_MsgSync1
new g_oldangles[33][3]
new g_afktime[33]
new bool:g_spawned[33] = {true, ...}
new check_pcvar
new numchecked
new iArg[36]
new iArgs[64]
new iArg1[33] 
new iReason[64]
new configsDir[64] 
new dFile[256] 
new g_timeafk
new g_cvarStyle;
new g_LeftKills[32]; 
new g_LosesMatchPoints
new g_WinsMatchPoints
new g_kniferound;
new bool:g_bKnifeRound;
new bool:g_bVotingProcess;
new g_Votes[ 2 ];

new g_iMenuPage[MAX_PLAYERSS];
new g_iVotedPlayers[MAX_PLAYERSS];
new g_iVotes[MAX_PLAYERS];
new g_szVoteReason[MAX_PLAYERSS][64];

new g_iPlayers[MAX_PLAYERSS - 1];
new g_iNum;

enum {
	CVAR_PERCENT = 0,
	CVAR_BANTYPE,
	CVAR_BANTIME
};
new g_szCvarName[][] = {
	"voteban_percent",
	"voteban_type",
	"voteban_time"
};
new g_szCvarValue[][] = {
	"80",
	"1",
	"100"
};
new g_iPcvar[3];
new filename[256]

new bool:Voted[ 33 ]; 
new Timer 
new g_szKind[MAX_MAPS] 
new g_maps[MAX_MAPS][30] 


new const Change[][] = { 
	"de_dust2", 
	"de_inferno", 
	"de_nuke", 
	"de_train", 
	"de_tuscan", 
	"de_mirage"
} 
new g_Cvar_FriendlyFire
new g_Cvar_Freezetime	
new g_Cvar_Password
new g_Cvar_RestartRound

new bool:g_timerRunning = false;
new g_MsgServerName;
new g_szHostname[ 64 ];
new g_pointerHostname;
new g_cvarEnabled;
new g_iTarget[33]

public plugin_init(){
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary("gather.txt")
        register_cvar("gx_version", VERSION, FCVAR_SERVER|FCVAR_UNLOGGED);
	cvar_humans_join_team = get_cvar_pointer("humans_join_team") 
	g_Cvar_FriendlyFire = get_cvar_pointer("mp_friendlyfire"); 
	g_Cvar_Freezetime = get_cvar_pointer("mp_freezetime"); 
	g_Cvar_Password = get_cvar_pointer("sv_password")
	g_Cvar_RestartRound = get_cvar_pointer("sv_restartround")
	
	register_event("TeamScore", "Event_TeamScore", "a")
	register_logevent("logevent_round_start", 2, "1=Round_Start")
	
	
	new szLogInfo[] = "amx_logdir";
	get_localinfo(szLogInfo, g_szLogFile, charsmax(g_szLogFile));
	add(g_szLogFile, charsmax(g_szLogFile), "/gather");
	
	if(!dir_exists(g_szLogFile))
		mkdir(g_szLogFile);
	
	new szTime[32];
	get_time("%d-%m-%Y", szTime, charsmax(szTime));
	format(g_szLogFile, charsmax(g_szLogFile), "%s/%s.log", g_szLogFile, szTime);
	g_max_clients = get_maxplayers();
	
	
	register_message( get_user_msgid( "SayText" ), "MessageSayText" )
	
	register_event( "SendAudio", "TerroristsWin", "a", "2&%!MRAD_terwin" )
	register_event( "SendAudio", "CounterTerroristsWin", "a", "2&%!MRAD_ctwin" )
	
	register_event( "HLTV", "EventNewRound", "a", "1=0", "2=0" )
	register_logevent( "RoundEnd", 2, "1=Round_End" )
	g_iMaxPlayers = get_maxplayers( )
	register_think(g_ClassName,"ForwardThink")
	
	g_SyncReady = CreateHudSyncObj()
	g_SyncNotReady = CreateHudSyncObj()
	g_SyncInfo = CreateHudSyncObj()
	g_iMaxPlayers = get_maxplayers()
	g_MsgSync6 = CreateHudSyncObj()
	g_MsgSync5 = CreateHudSyncObj()
	g_MsgSync4 = CreateHudSyncObj()
	g_MsgSync3 = CreateHudSyncObj()
	g_MsgSync2 = CreateHudSyncObj()
	g_MsgSync1 = CreateHudSyncObj()
	
	new iEnt = create_entity("info_target")
	entity_set_string(iEnt, EV_SZ_classname, g_ClassName)
	entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 2.0)
	register_event("CurWeapon" , "Event_CurWeapon" , "be" , "1=1" )
	RegisterHam(Ham_Spawn, "player", "Player_Spawn_Post", 1) 
	RegisterHam(Ham_Killed, "player", "PlayerKilled", 1);
	register_message(get_user_msgid("StatusIcon"), "msg_StatusIcon")
	
	g_timeafk = register_cvar("gx_afktime", "40")	// Kick people AFK longer than this time
	set_task(float(CHECK_FREQ),"checkPlayers",_,_,_,"b")
	register_event("ResetHUD", "playerSpawned", "be")
	register_logevent("logevent_round_end", 2, "1=Round_End")  
	check_pcvar = register_cvar("gx_checktimes","3")
	numchecked = 0
	
	
	g_iHideCmds = register_cvar( "gx_hide_cmd", "0" )
	g_iLostPointsTK = register_cvar( "gx_lost_points_tk", "5" )
	g_iLostPointsSuicide = register_cvar( "gx_lost_points_suicide", "1" )
	g_iWonPointsKill = register_cvar( "gx_won_points_kill", "1" )
	g_iLostPointsDeath = register_cvar( "gx_lost_points_kill", "1" )
	g_iWonPointsHeadshot = register_cvar( "gx_won_points_headshot", "2" )
	g_iLostPointsHeadshot = register_cvar( "gx_lost_points_headshot", "2" )
	g_iWonPointsKnife = register_cvar( "gx_won_points_knife", "3" )
	g_iLostPointsKnife = register_cvar( "gx_lost_points_knife", "3" )
	g_iWonPointsGrenade = register_cvar( "gx_won_points_grenade", "3" )
	g_iLostPointsGrenade = register_cvar( "gx_lost_points_grenade", "3" )
	g_iWonPointsTerrorists = register_cvar( "gx_won_points_ts", "1" )
	g_iWonPointsCounterTerrorists = register_cvar( "gx_won_points_cts", "1" )
	g_iLostPointsTerrorists = register_cvar( "gx_lost_points_ts", "1" )
	g_iLostPointsCounterTerrorists = register_cvar( "gx_lost_points_cts", "1" )
	g_iWonPointsPlanter = register_cvar( "gx_won_points_planter", "1" )
	g_iWonPointsPlanterExplode = register_cvar( "gx_won_points_planter_explode", "2" ) 
	g_iWonPointsDefuser = register_cvar( "gx_won_points_defuser", "3" )
	g_iWonPoints4k = register_cvar( "gx_won_points_4k", "4" )
	g_iWonPoints5k = register_cvar( "gx_won_points_5k", "5" )
	g_iNegativePoints = register_cvar( "gx_negative_points", "0" )
	g_cvarStyle = register_cvar( "gx_style", "1" );
	g_ready_color = register_cvar("gx_ready_color","0 130 0")
	g_unready_color = register_cvar("gx_unready_color","0 255 255")
	g_info_color = register_cvar("gx_info_color","255 215 0")
	g_plr_amount = register_cvar("gx_plr_amount","10")
	g_WinsMatchPoints = register_cvar("gx_winsmatchpoints", "15", FCVAR_ARCHIVE|FCVAR_SERVER)
	g_LosesMatchPoints = register_cvar("gx_losesmatchpoints", "10", FCVAR_ARCHIVE|FCVAR_SERVER)
	g_kniferound = register_cvar( "gx_kniferound", "1" );
	
	fvault_prune( g_VaultSkillPoints, _, get_systime( ) - ( 86400 * EXPIREDAYS ) )
	
	register_clcmd("say", "saycommand")
	register_clcmd("say", "sayinfo")
	register_clcmd("say", "SayCmds")
	register_clcmd("say", "SayBan")
	register_clcmd("say", "saycmd")
	register_clcmd("say", "SayDemo")
	register_clcmd("chooseteam", "chooseteam");
	register_clcmd(".add", "cmd_ready")
	register_event( "DeathMsg", "tk", "a" );
	
	set_task( 20.0, "SpecKick", _, _, _, "b" )
	register_forward(FM_ClientUserInfoChanged, "ClientUserInfoChanged") 
	register_event( "CurWeapon", "EventCurWeapon", "be", "2!29" );
	register_logevent( "EventRoundEnd", 2, "0=World triggered", "1=Round_Draw", "1=Round_End" );
	register_menucmd( register_menuid( "\rSwap teams?" ), 1023, "MenuCommand" );
	register_clcmd("_voteban_reason", "Cmd_VoteBanReason", -1, "");
	
	register_menucmd(register_menuid("\rVOTEBAN \yMenu:"), MENU_KEYS, "Menu_VoteBan");
	
	for(new i = 0 ; i < 3 ; i++)
	{
		g_iPcvar[i] = register_cvar(g_szCvarName[i], g_szCvarValue[i]);
	}
	get_configsdir(filename,255)
	format(filename,255,"%s/gx.txt",filename) 
	g_cvarEnabled = register_cvar( "gx_hostname_score", "1" );
	g_pointerHostname	= get_cvar_pointer( "hostname" );
	g_MsgServerName		= get_user_msgid( "ServerName" );
	
	set_task( 2.5, "checkTimeleft" );
	register_forward(FM_GetGameDescription,"change_gamename");
        register_clcmd("PrivateMessage", "cmd_player");
	MakeTop15( )
}
public plugin_cfg() {
	gxread()
	set_pcvar_string(cvar_humans_join_team, "")
	set_pcvar_num(g_Cvar_Freezetime,0)
	get_configsdir(configsDir, charsmax(configsDir)) 
	formatex(dFile, charsmax(dFile), "%s/gather.cfg", configsDir)  
	if(!file_exists(dFile)) 
	{ 
		write_file ( dFile , "//--------------------------------------------" ); 
		write_file ( dFile , "//Gather MOD v1.0 By Hartmann" ); 
		write_file ( dFile , "//https://github.com/Hartmannq" ); 
		write_file ( dFile , "//--------------------------------------------" ); 
		write_file ( dFile , "" ); 
		write_file ( dFile , "// Note - After editing cvars you need to change map before changes can take effect!" ); 
		write_file ( dFile , "" ); 
		write_file ( dFile , "gx_ready_color ^"0 130 0^" // Ready color" ); 
		write_file ( dFile , "gx_unready_color ^"0 255 255^" // Unready color");  
		write_file ( dFile , "gx_info_color ^"255 215 0^" // Info color" ); 
		write_file ( dFile , "gx_plr_amount 10 //  How much players are needed in order to start a match")
		write_file ( dFile , "gx_hide_cmd 0 //Hide the commands");
		write_file ( dFile , "gx_lost_points_tkn 5 // Points lost for TeamKilling" );
		write_file ( dFile , "gx_lost_points_suicide 1 // Points lost for suicide" );
		write_file ( dFile , "gx_won_points_kill 1 // Points awarded per kill" );
		write_file ( dFile , "gx_lost_points_kill 1 // Points lost per death" );
		write_file ( dFile , "gx_won_points_headshot 2 // Points awarded per headshot" );
		write_file ( dFile , "gx_lost_points_headshot 2 // Points lost for dying with an headshot" );
		write_file ( dFile , "gx_won_points_knife 3 // Points awarded per knife kill" );
		write_file ( dFile , "gx_lost_points_knife 3 // Points lost for dying with knife" );
		write_file ( dFile , "gx_won_points_grenade 3 // Points awarded per HE kill" );
		write_file ( dFile , "gx_lost_points_grenade 3 // Points lost for dying with an HE" );
		write_file ( dFile , "gx_won_points_ts 1 // Points awarded to Terrorist Team for winning the round" );
		write_file ( dFile , "gx_won_points_cts 1 // Points awarded to Counter-Terrorist Team for winning the round" );
		write_file ( dFile , "gx_lost_points_ts 1 // Points lost to Terrorist Team for losing the round" );
		write_file ( dFile , "gx_lost_points_cts 1 // 1 Poits lost to Counter-Terrorist Team for losing the round" );
		write_file ( dFile , "gx_won_points_planter 1 // Points awarded for planting the bomb" );
		write_file ( dFile , "gx_won_points_planter_explode 2 // Points awarded for bomb successfully exploding" );
		write_file ( dFile , "gx_won_points_defuser 3 // Points awarded for successfully disarming the bomb" );
		write_file ( dFile , "gx_won_points_4k 4 // Points awarded for killing 4 in a round (almost)" );
		write_file ( dFile , "gx_won_points_5k 5 // Points awarded for killing 5 (or more) in a round (ace)" );
		write_file ( dFile , "gx_negative_points 0 // Turn on/off negative skillpoints" );
		write_file ( dFile , "gx_style 1 //1-Auto-Ready || 2-ready or kick If the 2 Put more time on #define TIMER_SECONDS 10 " );
		write_file ( dFile , "gx_checktimes 3 // of times server is checked players in a row before stop match" );
		write_file ( dFile , "gx_afktime 60 // Kick people AFK longer than this time");
		write_file ( dFile , "gx_winsmatchpoints 15 // Points for win." );
		write_file ( dFile , "gx_losesmatchpoints 10 // Points for lost." );
		write_file ( dFile , "gx_kniferound 1 // 2-ON || 1-OFF Knife round." );
		write_file ( dFile , "gx_hostname_score 1 // ON/OFF Score in Hostname." );
		write_file ( dFile , "" );
	}
}
public plugin_end() 
{ 
	get_configsdir(configsDir, charsmax(configsDir)) 
	server_cmd("exec %s/gather.cfg", configsDir); 
	if( g_timerRunning )
		if( strlen( g_szHostname ) )
		set_pcvar_string( g_pointerHostname, g_szHostname );
} 
public gxwrite(){
	new writedata[128]
	new anyvalue
	
	anyvalue = 0
	
	new filepointer = fopen(filename,"w+")
	if(filepointer)
	{
		
		formatex(writedata,127,"%d",anyvalue)
		fputs(filepointer,writedata)
		fprintf(filepointer,"%d",anyvalue)
		fclose(filepointer)
	}
}
public gxwriteone(){
	new writedata[128]
	new anyvalue
	
	anyvalue = 1
	
	new filepointer = fopen(filename,"w+")
	if(filepointer)
	{
		
		formatex(writedata,127,"%d",anyvalue)
		fputs(filepointer,writedata)
		fprintf(filepointer,"%d",anyvalue)
		fclose(filepointer)
	}
}
public gxread(){
	new filepointer = fopen(filename,"r")
	if(filepointer)
	{
		new readdata[128], anyvalue
		new parsedanyvalue[8]
		
		while(fgets(filepointer,readdata,127))
		{   
			parse(readdata,parsedanyvalue,7)
			
			anyvalue = str_to_num(parsedanyvalue)
			if(anyvalue == 0){
				g_bStart = true
				g_war= true
				}else{
				set_task( 15.0, "setstart" ); 
			}
			break
		}
		fclose(filepointer)
	}
}
public change_gamename()
{ 
	new game[32];
	format(game, 31, "%s%s%s ", PLUGIN, VERSION, AUTHOR);
	forward_return(FMV_STRING, game);
	
	return FMRES_SUPERCEDE
}  
public adminstart(id){
	set_task( 10.0, "ActionSpecial" ); 
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "MAP_STARTED");
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "MAP_STARTED");
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "MAP_STARTED");
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER,"MAP_STARTED");
	new name[32], szAuthid_A[32];
	get_user_name(id, name, 31) 
	get_user_authid(id, szAuthid_A, 31);
	replace_all(name, 31, "a.", "") 
	replace_all(name, 31, "b.", "") 
	replace_all(name, 31, "<", "[") 
	replace_all(name, 31, ">", "]")
	
	log_to_file(g_szLogFile,"ADMIN: %s<%s> start match.",name,szAuthid_A)
	
}
public adminstop(id){
	new name[32], szAuthid_A[32];
	get_user_name(id, name, 31) 
	get_user_authid(id, szAuthid_A, 31);
	replace_all(name, 31, "a.", "") 
	replace_all(name, 31, "b.", "") 
	replace_all(name, 31, "<", "[") 
	replace_all(name, 31, ">", "]")
	
	log_to_file(g_szLogFile,"ADMIN: %s stop match.",name,szAuthid_A)
	EndMatch()	
}
public setstart(id){
	log_to_file(g_szLogFile , "-------------------------------------MatchStarted-------------------------------------")
	CmdBalance()
	set_pcvar_num(g_Cvar_RestartRound, 1)
	new iKnife;
	iKnife = get_pcvar_num(g_kniferound);
	
	switch(iKnife) {
		case 1:{
			set_task(4.0,"start",id)
		}
		case 2:{
			CmdKnifeRound(id)
		}
	}
}

public start(id){
	gxwrite()
	g_IsStarted = true
	g_bStart = false
	g_war = false
	server_cmd("exec esl.cfg")
	MoveFromSpec(id)
	teams_cmdlog()
	set_task(1.0, "ready_messages", 345,_,_,"b",_);
	set_pcvar_string(cvar_humans_join_team, "")
	
	new players[32], pnum, tempid;
	
	get_players(players, pnum, "ch")
	for (new x ; x<pnum ; x++)
	{
		tempid = players[x]
		
		switch( cs_get_user_team(tempid) ) {
			case CS_TEAM_UNASSIGNED: continue;
				case CS_TEAM_SPECTATOR: server_cmd("kick # %d", get_user_userid(tempid))
				case CS_TEAM_T: ChangeTagB(tempid)
				case CS_TEAM_CT: ChangeTagA(tempid)
			}
	}
	
}
public MoveFromSpec(id) {
	new playersT[ 32 ] , numT , playersCt[ 32 ] , numCt
	get_players( playersT , numT , "che" , "TERRORIST" )
	get_players( playersCt , numCt , "che" , "CT" )	
	
	if (g_bSecondHalf)
	{
		if( numT > numCt )
		{
			set_pcvar_string(cvar_humans_join_team, "CT")
			client_cmd(id, "slot1")
			ChangeTagB(id)
		}
		
		else
		{
			set_pcvar_string(cvar_humans_join_team, "T")
			client_cmd(id, "slot1")
			ChangeTagA(id)
		}
	}
	
	else
	{
		if( numT > numCt )
		{
			set_pcvar_string(cvar_humans_join_team, "CT")
			client_cmd(id, "slot1")
			ChangeTagA(id)
			
		}
		
		else
		{
			set_pcvar_string(cvar_humans_join_team, "T")
			client_cmd(id, "slot1")
			ChangeTagB(id)
		}	
	}
	
	
	return PLUGIN_CONTINUE
}

public client_putinserver(id){
	if (is_user_bot(id) || is_user_hltv(id))
		return PLUGIN_HANDLED;
	
	if (g_IsStarted)
	{
		MoveFromSpec(id)
		
	}
	if(!is_user_bot(id))
	{
		g_iPlayerCount++
		is_plr_connected[id] = true
		set_msg_ready()
	}
	if(g_iPlayerCount == 0){
		set_msg_ready()
	}
	new params[1] = {TIMER_SECONDS + 1}; 
	set_task(1.0, "TaskCountDown", id, params, sizeof(params));  
	LoadPoints(id)
	g_afktime[id] = 0
	set_task(30.0, "noteam", id)
	check_server(id)
	return PLUGIN_HANDLED
}
public noteam(id) {
	if ( !is_user_connected(id) )
		return PLUGIN_HANDLED
	
	if (cs_get_user_team(id) == CS_TEAM_UNASSIGNED)
	{
		server_cmd("kick #%d noteam",get_user_userid(id))
	}
	return PLUGIN_HANDLED
}
public check_server(id)
{
	new players[32], num
	get_players(players,num,"ch")
	if(num == get_pcvar_num(g_plr_amount))
	{
		new players[32], pnum, tempid;
		get_players(players, pnum, "ch")
		for (new full; full<pnum ; full++)
		{
			players[full] = tempid
			if (is_user_connecting(tempid))
				server_cmd("kick #%d serverfull", get_user_userid(tempid))
		}
	}
	else if (num > get_pcvar_num(g_plr_amount))
	{
		server_cmd("kick #%d serverfull", get_user_userid(id))
	}
	
	return PLUGIN_HANDLED
}
public ChangeTagA(id) {
	if ( !( 1 <= id <= g_iMaxPlayers  ))
		return;
	
	new pname[32]
	new newname[32]
	get_user_info( id, "name", pname, charsmax(pname))
	replace_all(pname, 31, "a.", "") 
	replace_all(pname, 31, "b.", "") 
	replace_all(pname, 31, "<a>", "") 
	new iLen = strlen(pname) 
	
	new iPos = iLen - 1 
	if( pname[iPos] == '>' ) 
	{ 
		for( new i = 1; i < 6; i++) 
		{ 
			if( pname[iPos - i] == '<' ) 
			{ 
				iLen = iPos - i 
				pname[iLen] = '^0' 
				break 
			} 
		} 
	} 
	format(pname[iLen], charsmax(pname) - iLen, pname[iLen-1] == ' ' ? "<%d>%s" : "<%d>%s",g_iPoints[id],(get_user_flags(id)&ACCESS_LEVEL)?"<a>":"") 
	formatex(newname, 31, "a.%s", pname) 
	set_user_info(id, "name", newname)
}
public ChangeTagB(id) {
	if ( !( 1 <= id <= g_iMaxPlayers  ))
		return;
	
	new pname[32]
	new newname[32]
	get_user_info( id, "name", pname, charsmax(pname))
	replace_all(pname, 31, "a.", "") 
	replace_all(pname, 31, "b.", "") 
	replace_all(pname, 31, "<a>", "") 
	new iLen = strlen(pname) 
	
	new iPos = iLen - 1 
	if( pname[iPos] == '>' ) 
	{ 
		for( new i = 1; i < 6; i++) 
		{ 
			if( pname[iPos - i] == '<' ) 
			{ 
				iLen = iPos - i 
				pname[iLen] = '^0' 
				break 
			} 
		} 
	} 
	format(pname[iLen], charsmax(pname) - iLen, pname[iLen-1] == ' ' ? "<%d>%s" : "<%d>%s",g_iPoints[id],(get_user_flags(id)&ACCESS_LEVEL)?"<a>":"") 
	formatex(newname, 31, "b.%s", pname) 
	set_user_info(id, "name", newname)	
}

public ready_messages()
{
	g_ReadySeconds--;
	switch(g_ReadySeconds)
	{
		case 5: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "MATCH");
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "FIVE");
		}
		case 4: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "FOUR");
			set_pcvar_num(g_Cvar_RestartRound, 1)
		}
		case 3: ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "THREE");
			case 2: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "TWO");
			set_pcvar_num(g_Cvar_RestartRound, 1)
		}
		case 1: ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "ONE");
			case 0: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "GAME"); 
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "LIVE");
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "GLHF");
			set_hudmessage(255, 255, 255, 0.06, 0.34, 0, 6.0, 20.0)
			ShowSyncHudMsg(0, g_MsgSync1, "%L", LANG_PLAYER, "LIVEHUD")
			remove_task(345);
			
			
		}
	}
}
public Event_TeamScore() {
	if (g_IsStarted) 
	{
		read_data(1, g_szTeamName, 1)
		
		g_iTeam = (g_szTeamName[0] == 'T') ? 0 : 1
		g_iAltScore = read_data(2)
		g_iScoreOffset = g_iAltScore - g_iLastTeamScore[g_iTeam]
		
		if(g_iScoreOffset > 0)
		{
			g_iScore[g_iTeam] += g_iScoreOffset
		}
		
		g_iLastTeamScore[g_iTeam] = g_iAltScore
		
		
		if (g_iScore[0] + g_iScore[1] == 15)
		{
			if (g_bStop2)
			{
				return PLUGIN_HANDLED;
			}
			g_bStop2 = true
			screenshot_setup()
			set_task(1.5, "SwitchTeams")
			ClientPrintColor(0,  "%s %L", PREFIX, LANG_PLAYER, "SWITCH_TEAMS")
			set_task(10.0, "scndhalf")
		}
		else if ((g_iScore[0] == 16) || (g_iScore[1] == 16))
		{
			if (g_bStop)
			{
				return PLUGIN_HANDLED
			}
			g_bStop = true
			EndMatch()
			return PLUGIN_HANDLED
		}
		
	}
	
	return PLUGIN_HANDLED
}
public SwitchTeams() {
	new supportvariable
	
	supportvariable = g_iScore[0]
	g_iScore[0] = g_iScore[1]
	g_iScore[1] = supportvariable
	
	new players[32], pnum, tempid;
	get_players(players, pnum, "ch");
	
	for( new i; i<pnum; i++ ) {
		tempid = players[i];
		switch( cs_get_user_team(tempid) ) {
			case CS_TEAM_T: cs_set_user_team(tempid, CS_TEAM_CT)
				case CS_TEAM_CT: cs_set_user_team(tempid, CS_TEAM_T)
			}
	}
	
	g_bSecondHalf = true
	return PLUGIN_HANDLED
}
public scndhalf() {
	set_pcvar_num(g_Cvar_RestartRound, 1)
	set_task(1.0, "ready_messageshalf", 346,_,_,"b",_);
}

public ready_messageshalf() {
	g_ReadySeconds2--;
	switch(g_ReadySeconds2)
	{
		case 5: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "HALF");
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "FIVE");
		}
		case 4: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "FOUR");
			set_pcvar_num(g_Cvar_RestartRound, 1)
		}
		case 3: ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "THREE");
			case 2: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "TWO");
			set_pcvar_num(g_Cvar_RestartRound, 1)
		}
		case 1: ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "ONE");
			case 0: {
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "GAME"); 
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "LIVE");
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "GLHF");
			set_hudmessage(255, 255, 255, 0.06, 0.34, 0, 6.0, 20.0)
			ShowSyncHudMsg(0, g_MsgSync5, "%L",LANG_PLAYER, "LIVEHUDHALF") 
			remove_task(346);
		}
	}
}
public showscore(id) {
	
	if (g_IsStarted)
	{
		
		if (g_bSecondHalf)
			ClientPrintColor(0,  "%s %L", PREFIX, LANG_PLAYER, "SHOW_SCORE_TAG", g_iScore[0], g_iScore[1])
		else
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "SHOW_SCORE_TAG", g_iScore[1], g_iScore[0])
	}
	
	else
	{
		ClientPrintColor(0,  "%s %L", PREFIX, LANG_PLAYER, "MATCH_NOT_STARTED")
	}
	return PLUGIN_CONTINUE
}
public logevent_round_start(id)
{           
	if (g_IsStarted)
	{
		
		if (g_bSecondHalf)
		{
			set_hudmessage(0, 212, 255, 0.52, 0.49,0, 6.0, 10.0)
			ShowSyncHudMsg(0, g_MsgSync3, "%L",LANG_PLAYER, "SHOW_SCORE_HUD", g_iScore[0], g_iScore[1]);
		} 
		else
		{
			set_hudmessage(0, 212, 255, 0.52, 0.49,0, 6.0, 10.0)
			ShowSyncHudMsg(0, g_MsgSync2, "%L",LANG_PLAYER, "SHOW_SCORE_HUD", g_iScore[1], g_iScore[0]);
		} 
	}
	return PLUGIN_CONTINUE
}
public logevent_round_end()
{ 
	if (g_IsStarted)
	{
		new players[32], num
		get_players(players,num,"ch")
		if(num<=get_pcvar_num(g_plr_amount)-3)
		{
			numchecked++
			ClientPrintColor(0,"%s %L", PREFIX, LANG_PLAYER, "CHECK",numchecked,get_pcvar_num(check_pcvar));
			if(numchecked>=get_pcvar_num(check_pcvar))
			{
				set_task(5.0,"EndMatch")
				ClientPrintColor(0,"%s %L", PREFIX, LANG_PLAYER, "MATCH_OVER_CHECK");
				numchecked=0
			}
		}
		else
			numchecked = 0
	}
	return PLUGIN_CONTINUE
}
public teams_cmd(id)
{         
	new name[30], team, all_names[MAX_TEAMS][sizeof(name) * 30];
	for(new i = 1;i <= g_max_clients;i++)
	{
		if(!is_user_connected(i))
			continue;
		
		
		team = fm_get_user_team(i);
		if(team != TEAM_T && team != TEAM_CT)
			continue;
		
		get_user_name(i,name,sizeof(name) - 1);
		replace_all(name, sizeof(name), "a.", "") 
		replace_all(name, sizeof(name), "b.", "") 
		replace_all(name, sizeof(name), "<", "[") 
		replace_all(name, sizeof(name), ">", "]")
		
		if(all_names[team][0])
			
		format(all_names[team], sizeof(all_names[]) - 1, "%s, %s", all_names[team], name);
		else
			copy(all_names[team], sizeof(all_names[]) - 1, name);
		
	} 
	
	if (g_IsStarted)
	{
		if (g_bSecondHalf)
		{
			ClientPrintColor(id,"%s %L", PREFIX, LANG_PLAYER, "NAME_TEAM_A",all_names[TEAM_T]);
			ClientPrintColor(id,"%s %L", PREFIX, LANG_PLAYER, "NAME_TEAM_B", all_names[TEAM_CT]);
		} 
		else
		{
			ClientPrintColor(id,"%s %L", PREFIX, LANG_PLAYER, "NAME_TEAM_A",all_names[TEAM_CT]);
			ClientPrintColor(id,"%s %L", PREFIX, LANG_PLAYER, "NAME_TEAM_B", all_names[TEAM_T]);
		} 
		
	}
	
	
	return PLUGIN_CONTINUE
}
public teams_cmdlog()
{         
	new name[30], team, all_names[MAX_TEAMS][sizeof(name) * 30];
	for(new i = 1;i <= g_max_clients;i++)
	{
		if(!is_user_connected(i))
			continue;
		
		
		team = fm_get_user_team(i);
		if(team != TEAM_T && team != TEAM_CT)
			continue;
		
		get_user_name(i,name,sizeof(name) - 1);
		replace_all(name, sizeof(name), "a.", "") 
		replace_all(name, sizeof(name), "b.", "") 
		replace_all(name, sizeof(name), "<", "[") 
		replace_all(name, sizeof(name), ">", "]")
		
		if(all_names[team][0])
			
		format(all_names[team], sizeof(all_names[]) - 1, "%s, %s", all_names[team], name);
		else
			copy(all_names[team], sizeof(all_names[]) - 1, name);
		
	} 
	
	if (g_IsStarted)
	{
		if (g_bSecondHalf)
		{
			log_to_file(g_szLogFile,"Team A: %s",all_names[TEAM_T]);
			log_to_file(g_szLogFile,"Team B: %s", all_names[TEAM_CT]);
		} 
		else
		{
			log_to_file(g_szLogFile,"Team A: %s",all_names[TEAM_CT]);
			log_to_file(g_szLogFile,"Team B: %s", all_names[TEAM_T]);
		} 
		
	}
	
	
	return PLUGIN_CONTINUE
}
public EndMatch() {
	log_to_file(g_szLogFile , "-------------------------------------MatchEnd-------------------------------------")
	ClientPrintColor(0,  "%s %L", PREFIX, LANG_PLAYER, "MATCH_OVER")
	ClientPrintColor(0,  "%s %L", PREFIX, LANG_PLAYER, "PLUGIN_RESTART")
	wonteam()
	screenshot_setup()
	teams_cmdlog()
	winpoinsts()
	set_task(1.0, "cmdStop")
	set_task(10.0, "restartServer")
	set_pcvar_string(g_Cvar_Password, "")
}
public restartServer()
{
	server_cmd("restart")  
}

public cmdRecord( id ) {
	if (g_IsStarted)
	{
		
		new szName_A[32], szAuthid_A[32];
		get_user_name(id, szName_A, 31);
		get_user_authid(id, szAuthid_A, 31);
		replace( szAuthid_A, 31, ":", "_" );
		replace_all(szName_A, 31, "<", "[")
		replace_all(szName_A, 31, ">", "]")
		replace_all(szName_A, 31, "a.", "")
		replace_all(szName_A, 31, "b.", "") 
		g_Demo[id] = true
		client_cmd(id, "stop; record ^"%s_-_%s^"", szName_A, szAuthid_A);
		ClientPrintColor( 0,"%s %L", PREFIX, LANG_PLAYER, "DEMO_RECORD", szName_A, szAuthid_A);
		log_to_file(g_szLogFile,"Cmd: ^"%s<%s>^" started recording demo.", szName_A, szAuthid_A);
	}
	return PLUGIN_CONTINUE
}
public screenshot_take()
{
	new players[32]
	new number
	
	get_players(players, number)
	
	for(new i=0; i < number; i++)
	{
		if (players[i])
		{
			client_cmd(players[i],"snapshot")
		}
	}
	return PLUGIN_CONTINUE
}
public screenshot_scoreboard_show()
{
	client_cmd(0, "+showscores")
	
	return PLUGIN_CONTINUE
}

public screenshot_scoreboard_remove()
{
	client_cmd(0, "-showscores")
	
	return PLUGIN_CONTINUE
}

public screenshot_setup()
{
	
	ClientPrintColor(0,"%s %L", PREFIX, LANG_PLAYER, "TAKING_SCREENSHOTS")
	
	screenshot_scoreboard_show()
	set_task(0.5, "screenshot_take")
	set_task(1.0, "screenshot_scoreboard_remove")
	
	return PLUGIN_CONTINUE
}
public cmdStop(id){
	if(g_Demo[id])
	{
		client_cmd(id, "stop")
		ClientPrintColor( 0,"%s %L", PREFIX, LANG_PLAYER, "POST_DEMO");
	}
}
public plugin_natives( )
{
	register_library( "skillpoints" )
	
	register_native( "skillpoints", "_skillpoints" )
}

public _skillpoints( plugin, params )
{
	if( params != 1 )
	{
		return 0
	}
	
	new id = get_param( 1 )
	if( !id )
	{
		return 0
	}
	
	return g_iPoints[ id ]
}


public client_authorized( id )
{
	get_user_authid( id , g_szAuthID[ id ], charsmax( g_szAuthID[ ] ) )
	get_user_info( id, "name", g_szName[ id ], charsmax( g_szName[ ] ) )
	
	fvault_set_data( g_VaultNames, g_szAuthID[ id ], g_szName[ id ] )
	
	g_iPoints[ id ] = 0
	g_iLevels[ id ] = 0
	g_iClasses[ id ] = 0
	
	g_iKills[ id ] = 0
	g_iDeaths[ id ] = 0
	g_iHeadShots[ id ] = 0
	g_iKnifeKills[ id ] = 0
	g_iKnifeDeaths[ id ] = 0
	g_iGrenadeKills[ id ] = 0
	g_iGrenadeDeaths[ id ] = 0
	g_iBombExplosions[ id ] = 0
	g_iDefusedBombs[ id ] = 0
	g_iWonRounds[ id ] = 0
	
	g_iCurrentKills[ id ] = 0
	
	LoadPoints( id )
	
}

public client_infochanged( id )
{
	if( is_user_connected( id ) )
	{
		new szNewName[ 32 ]
		get_user_info( id, "name", szNewName, charsmax( szNewName ) ) 
		
		new iLen = strlen( szNewName )
		
		new iPos = iLen - 1
		
		if( szNewName[ iPos ] == '>' )
		{    
			new i
			for( i = 1; i < 7; i++ )
			{    
				if( szNewName[ iPos - i ] == '<' )
				{    
					iLen = iPos - i
					szNewName[ iLen ] = EOS
					break
				}
			}
		}
		
		trim( szNewName )
		
		if( !equal( g_szName[ id ], szNewName ) )   
		{     
			copy( g_szName[ id ], charsmax( g_szName[ ] ), szNewName )
			
			fvault_set_data( g_VaultNames, g_szAuthID[ id ], g_szName[ id ] )
		}	
	}
}
public client_disconnect( id )
{
	if( task_exists( id ) )
	{
		remove_task( id )
	}
	if(!is_user_bot(id))
	{
		g_iPlayerCount--
		if(is_plr_ready[id])
			g_iReadyCount--
		is_plr_connected[id] = false
		is_plr_ready[id] = false
		set_msg_ready()
	}
	CheckLevelAndSave( id )
}
public client_death( iKiller, iVictim, iWpnIndex, iHitPlace, iTK )
{	
	if (g_IsStarted)
	{
		if( !IsPlayer( iKiller ) || !IsPlayer( iVictim ) )
		{
			return PLUGIN_CONTINUE
		}
		
		if( iTK )
		{
			g_iPoints[ iKiller ] -= get_pcvar_num( g_iLostPointsTK )
			
			return PLUGIN_CONTINUE
		}
		
		if( iKiller == iVictim )
		{
			g_iPoints[ iKiller ] -= get_pcvar_num( g_iLostPointsSuicide )
			g_iDeaths[ iKiller ]++
			
			return PLUGIN_CONTINUE
		}
		
		g_iCurrentKills[ iKiller ]++
		g_iKills[ iKiller ]++
		
		g_iDeaths[ iVictim ]++
		
		if( iWpnIndex == CSW_HEGRENADE )
		{
			g_iPoints[ iKiller ] += get_pcvar_num( g_iWonPointsGrenade )
			g_iGrenadeKills[ iKiller]++
			
			
			g_iPoints[ iVictim ] -= get_pcvar_num( g_iLostPointsGrenade )
			g_iGrenadeDeaths[ iVictim ]++
			
			return PLUGIN_CONTINUE
		}
		
		if( iWpnIndex == CSW_KNIFE )
		{
			g_iPoints[ iKiller ] += get_pcvar_num( g_iWonPointsKnife )
			g_iKnifeKills[ iKiller ]++
			
			g_iPoints[ iVictim ] -= get_pcvar_num( g_iLostPointsKnife )
			g_iKnifeDeaths[ iVictim ]++
			
			return PLUGIN_CONTINUE
		}
		
		if( iHitPlace == HIT_HEAD )
		{
			g_iPoints[ iKiller ] += get_pcvar_num( g_iWonPointsHeadshot )
			g_iHeadShots[ iKiller ]++
			
			g_iPoints[ iVictim ] -= get_pcvar_num( g_iLostPointsHeadshot )
			
			return PLUGIN_CONTINUE
		}
		
		g_iPoints[ iKiller ] += get_pcvar_num( g_iWonPointsKill )
		
		
		g_iPoints[ iVictim ] -= get_pcvar_num( g_iLostPointsDeath )
		
		return PLUGIN_CONTINUE	
	}
	return PLUGIN_CONTINUE
}
public TerroristsWin( )
{
	if (g_IsStarted)
	{
		if( g_bRoundEnded )
		{
			return PLUGIN_CONTINUE
		}
		
		new Players[ MAX_PLAYERS ]
		new iNum
		new i
		
		get_players( Players, iNum, "ch" )
		
		for( --iNum; iNum >= 0; iNum-- )
		{
			i = Players[ iNum ]
			
			switch( cs_get_user_team( i ) )
			{
				case( CS_TEAM_T ):
				{
					if( get_pcvar_num( g_iWonPointsTerrorists ) )
					{
						g_iPoints[ i ] += get_pcvar_num( g_iWonPointsTerrorists )
						g_iWonRounds[ i ]++
						
					}
				}
				
				case( CS_TEAM_CT ):
				{
					if( get_pcvar_num( g_iLostPointsCounterTerrorists ) )
					{
						g_iPoints[ i ] -= get_pcvar_num( g_iLostPointsCounterTerrorists )
						
					}
				}
			}
		}
		
		g_bRoundEnded = true
		
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}
public CounterTerroristsWin( )
{
	if(g_IsStarted)
	{
		if( g_bRoundEnded )
		{
			return PLUGIN_CONTINUE
		}
		
		new Players[ MAX_PLAYERS ]
		new iNum
		new i
		
		get_players( Players, iNum, "ch" )
		
		for( --iNum; iNum >= 0; iNum-- )
		{
			i = Players[ iNum ]
			
			switch( cs_get_user_team( i ) )
			{
				case( CS_TEAM_T ):
				{
					if( get_pcvar_num( g_iLostPointsTerrorists ) )
					{
						g_iPoints[ i ] -= get_pcvar_num( g_iLostPointsTerrorists )
						
					}
				}
				
				case( CS_TEAM_CT ):
				{
					if( get_pcvar_num( g_iWonPointsCounterTerrorists ) )
					{
						g_iPoints[ i ] += get_pcvar_num( g_iWonPointsCounterTerrorists )
						g_iWonRounds[ i ]++
						
					}
				}
			}
		}
		
		g_bRoundEnded = true
		
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}
public bomb_planted( planter )
{
	if(g_IsStarted)
	{
		if( get_pcvar_num( g_iWonPointsPlanter ) )
		{
			g_iPoints[ planter ] += get_pcvar_num( g_iWonPointsPlanter )
			
		}
	}
}
public bomb_explode( planter, defuser )
{
	if(g_IsStarted)
	{
		if( get_pcvar_num( g_iWonPointsPlanterExplode ) )
		{
			g_iPoints[ planter ] += get_pcvar_num( g_iWonPointsPlanterExplode )
			g_iBombExplosions[ planter ]++
			
		}
	}
	return PLUGIN_CONTINUE
}
public bomb_defused( defuser )
{
	if(g_IsStarted)
	{
		if( get_pcvar_num( g_iWonPointsDefuser ) )
		{
			g_iPoints[ defuser ] += get_pcvar_num( g_iWonPointsDefuser )
			g_iDefusedBombs[ defuser ]++
			
		}
	}
	return PLUGIN_CONTINUE
}
public EventNewRound( )
{
	g_bRoundEnded = false
	
	MakeTop15( )
}


public RoundEnd( )
{
	set_task( 0.5, "SavePointsAtRoundEnd" )
}

public SavePointsAtRoundEnd( )
{
	if(g_IsStarted)
	{
		new Players[ MAX_PLAYERS ]
		new iNum
		new i
		
		get_players( Players, iNum, "ch" )
		
		for( --iNum; iNum >= 0; iNum-- )
		{
			i = Players[ iNum ]
			
			if( g_iCurrentKills[ i ] == 4 && get_pcvar_num( g_iWonPoints4k ) )
			{
				g_iPoints[ i ] += get_pcvar_num( g_iWonPoints4k )
				
			}
			
			if( g_iCurrentKills[ i ] >= 5 && get_pcvar_num( g_iWonPoints5k ) )
			{
				g_iPoints[ i ] += get_pcvar_num( g_iWonPoints5k )
				
			}
			
			CheckLevelAndSave( i )
		}
	}
	return PLUGIN_CONTINUE
}
public CheckLevelAndSave( id )
{
	if( !get_pcvar_num( g_iNegativePoints) )
	{
		if( g_iPoints[ id ] < 0 )
		{
			g_iPoints[ id ] = 0
		}
		
		if( g_iLevels[ id ] < 0 )
		{
			g_iLevels[ id ] = 0
		}
	}
	
	while( g_iPoints[ id ] >= LEVELS[ g_iLevels[ id ] ] )
	{
		g_iLevels[ id ]++
		g_iClasses[ id ]++
		
	}
	
	new szFormattedData[ 128 ]
	formatex( szFormattedData, charsmax( szFormattedData ),
	"%i %i %i %i %i %i %i %i %i %i %i %i",
	
	g_iPoints[ id ],
	g_iLevels[ id ],
	
	g_iKills[ id ],
	g_iDeaths[ id ],
	g_iHeadShots[ id ],
	g_iKnifeKills[ id ],
	g_iKnifeDeaths[ id ],
	g_iGrenadeKills[ id ],
	g_iGrenadeDeaths[ id ],
	g_iBombExplosions[ id ],
	g_iDefusedBombs[ id ],
	g_iWonRounds[ id ] )
	
	fvault_set_data( g_VaultSkillPoints, g_szAuthID[ id ], szFormattedData )
	
	if( g_iPoints[ id ] >= MAX_PONTUATION )
	{		
		
		g_iPoints[ id ] = 0
		g_iLevels[ id ] = 0
		g_iClasses[ id ] = 0
		
		g_iKills[ id ] = 0
		g_iDeaths[ id ] = 0
		g_iHeadShots[ id ] = 0
		g_iKnifeKills[ id ] = 0
		g_iKnifeDeaths[ id ] = 0
		g_iGrenadeKills[ id ] = 0
		g_iGrenadeDeaths[ id ] = 0
		g_iBombExplosions[ id ] = 0
		g_iDefusedBombs[ id ] = 0
		g_iWonRounds[ id ] = 0
		
		CheckLevelAndSave( id )
	}
}

public LoadPoints( id )
{
	new szFormattedData[ 128 ]
	if( fvault_get_data( g_VaultSkillPoints, g_szAuthID[ id ], szFormattedData, charsmax( szFormattedData ) ) )
	{
		new szPlayerPoints[ 7 ]
		new szPlayerLevel[ 7 ]
		
		new szPlayerKills[ 7 ]
		new szPlayerDeahts[ 7 ]
		new szPlayerHeadShots[ 7 ]
		new szPlayerKnifeKills[ 7 ]
		new szPlayerKnifeDeaths[ 7 ]
		new szPlayerGrenadeKills[ 7 ]
		new szPlayerGrenadeDeaths[ 7 ]
		new szPlayerBombExplosions[ 7 ]
		new szPlayerDefusedBombs[ 7 ]
		new szPlayerWonRounds[ 7 ]
		
		parse( szFormattedData,
		szPlayerPoints, charsmax( szPlayerPoints ),
		szPlayerLevel, charsmax( szPlayerLevel ),
		
		szPlayerKills, charsmax( szPlayerKills ),
		szPlayerDeahts, charsmax( szPlayerDeahts ),
		szPlayerHeadShots, charsmax( szPlayerHeadShots ),
		szPlayerKnifeKills, charsmax( szPlayerKnifeKills ),
		szPlayerKnifeDeaths, charsmax( szPlayerKnifeDeaths ),
		szPlayerGrenadeKills, charsmax( szPlayerGrenadeKills ),
		szPlayerGrenadeDeaths, charsmax( szPlayerGrenadeDeaths ),
		szPlayerBombExplosions, charsmax( szPlayerBombExplosions ),
		szPlayerDefusedBombs, charsmax( szPlayerDefusedBombs ),
		szPlayerWonRounds, charsmax( szPlayerWonRounds ) )
		
		g_iPoints[ id ] = str_to_num( szPlayerPoints )
		g_iLevels[ id ] = str_to_num( szPlayerLevel )
		
		g_iKills[ id ] = str_to_num( szPlayerKills )
		g_iDeaths[ id ] = str_to_num( szPlayerDeahts )
		g_iHeadShots[ id ] = str_to_num( szPlayerHeadShots )
		g_iKnifeKills[ id ] = str_to_num( szPlayerKnifeKills )
		g_iKnifeDeaths[ id ] = str_to_num( szPlayerKnifeDeaths )
		g_iGrenadeKills[ id ] = str_to_num( szPlayerGrenadeKills )
		g_iGrenadeDeaths[ id ] = str_to_num( szPlayerGrenadeDeaths )
		g_iBombExplosions[ id ] = str_to_num( szPlayerBombExplosions )
		g_iDefusedBombs[ id ] = str_to_num( szPlayerDefusedBombs )
		g_iWonRounds[ id ] = str_to_num( szPlayerWonRounds )
		
	}
}

public GetSkillPoints( id )
{
	
	if( g_iLevels[ id ] < ( MAX_LEVELS - 1 ) )
	{
		ClientPrintColor( id, "%s %L", PREFIX, LANG_PLAYER, "SKILL", g_iPoints[ id ], CLASSES[ g_iLevels[ id ] ], ( LEVELS[ g_iLevels[ id ] ] - g_iPoints[ id ] ) )
	}
	
	else
	{
		ClientPrintColor( id, "%s %L", PREFIX, LANG_PLAYER, "FULL_SKILL", g_iPoints[ id ], CLASSES[ g_iLevels[ id ] ] )
	}
	return ( get_pcvar_num( g_iHideCmds ) == 0 ) ? PLUGIN_CONTINUE : PLUGIN_HANDLED_MAIN
}
public SkillRank( id )
{
	new Array:aKey = ArrayCreate( 35 )
	new Array:aData = ArrayCreate( 128 )
	new Array:aAll = ArrayCreate( FvaultData )
	
	fvault_load( g_VaultSkillPoints, aKey, aData )
	
	new iArraySize = ArraySize( aKey )
	
	new Data[ FvaultData ]
	
	new i
	for( i = 0; i < iArraySize; i++ )
	{
		ArrayGetString( aKey, i, Data[ szSteamID ], sizeof Data[ szSteamID ] - 1 )
		ArrayGetString( aData, i, Data[ szSkillP_Data ], sizeof Data[ szSkillP_Data ] - 1 )
		
		ArrayPushArray( aAll, Data )
	}
	
	ArraySort( aAll, "SortData" )
	
	new szAuthIdFromArray[ 35 ]
	
	new j
	for( j = 0; j < iArraySize; j++ )
	{
		ArrayGetString( aAll, j, szAuthIdFromArray, charsmax( szAuthIdFromArray ) )
		
		if( equal( szAuthIdFromArray, g_szAuthID[ id ] ) )
		{
			break
		}	
	}
	
	ArrayDestroy( aKey )
	ArrayDestroy( aData )
	ArrayDestroy( aAll )
	ClientPrintColor( id, "%s %L", PREFIX, LANG_PLAYER, "YOU_RANK", j + 1, iArraySize, g_iPoints[ id ] )
	
	return ( get_pcvar_num( g_iHideCmds ) == 0 ) ? PLUGIN_CONTINUE : PLUGIN_HANDLED_MAIN
}

public TopSkill( id )
{
	show_motd( id, g_szMotd, "Top SkillPointers" )
	return ( get_pcvar_num( g_iHideCmds ) == 0 ) ? PLUGIN_CONTINUE : PLUGIN_HANDLED_MAIN
}

public MakeTop15( )
{
	new iLen
	iLen = formatex( g_szMotd, charsmax( g_szMotd ),
	"<body bgcolor=#A4BED6>\
	<table width=100%% cellpadding=2 cellspacing=0 border=0>\
	<tr align=center bgcolor=#52697B>\
	<th width=4%%>#\
	<th width=30%% align=left>Player\
	<th width=8%%>Kills\
	<th width=8%%>Deaths\
	<th width=8%%>HS\
	<th width=8%%>Knife\
	<th width=8%%>Grenade\
	<th width=8%%>Bombs\
	<th width=8%%>Defuses\
	<th width=10%>SkillPoints" )
	
	new Array:aKey = ArrayCreate( 35 )
	new Array:aData = ArrayCreate( 128 )
	new Array:aAll = ArrayCreate( FvaultData )
	
	fvault_load( g_VaultSkillPoints, aKey, aData )
	
	new iArraySize = ArraySize( aKey )
	
	new Data[ FvaultData ]
	
	new i
	for( i = 0; i < iArraySize; i++ )
	{
		ArrayGetString( aKey, i, Data[ szSteamID ], sizeof Data[ szSteamID ] - 1 )
		ArrayGetString( aData, i, Data[ szSkillP_Data ], sizeof Data[ szSkillP_Data ] - 1 )
		
		ArrayPushArray( aAll, Data )
	}
	
	ArraySort( aAll, "SortData" )
	
	new szPlayerPoints[ 7 ]
	new szPlayerLevel[ 7 ]
	
	new szPlayerKills[ 7 ]
	new szPlayerDeahts[ 7 ]
	new szPlayerHeadShots[ 7 ]
	new szPlayerKnifeKills[ 7 ]
	new szPlayerKnifeDeaths[ 7 ]
	new szPlayerGrenadeKills[ 7 ]
	new szPlayerGrenadeDeaths[ 7 ]
	new szPlayerBombExplosions[ 7 ]
	new szPlayerDefusedBombs[ 7 ]
	new szPlayerWonRounds[ 7 ]
	
	new szName[ 22 ]
	new iSize = clamp( iArraySize, 0, 10 )
	
	new j
	for( j = 0; j < iSize; j++ )
	{
		ArrayGetArray( aAll, j, Data )
		
		fvault_get_data( g_VaultNames, Data[ szSteamID ], szName, charsmax( szName ) )
		
		replace_all( szName, charsmax( szName ), "<", "[" )
		replace_all( szName, charsmax( szName ), ">", "]" )
		replace_all( szName, charsmax( szName ), "a.", "")
		replace_all( szName, charsmax( szName ), "b.", "")
		
		parse( Data[ szSkillP_Data ],
		szPlayerPoints, charsmax( szPlayerPoints ),
		szPlayerLevel, charsmax( szPlayerLevel ),
		
		szPlayerKills, charsmax( szPlayerKills ),
		szPlayerDeahts, charsmax( szPlayerDeahts ),
		szPlayerHeadShots, charsmax( szPlayerHeadShots ),
		szPlayerKnifeKills, charsmax( szPlayerKnifeKills ),
		szPlayerKnifeDeaths, charsmax( szPlayerKnifeDeaths ),
		szPlayerGrenadeKills, charsmax( szPlayerGrenadeKills ),
		szPlayerGrenadeDeaths, charsmax( szPlayerGrenadeDeaths ),
		szPlayerBombExplosions, charsmax( szPlayerBombExplosions ),
		szPlayerDefusedBombs, charsmax( szPlayerDefusedBombs ),
		szPlayerWonRounds, charsmax( szPlayerWonRounds ) )
		
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<tr align=center>" )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%i", j + 1 )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td align=left>%s", szName )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerKills )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerDeahts )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerHeadShots )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerKnifeKills )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerGrenadeKills )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerBombExplosions )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerDefusedBombs )
		iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "<td>%s", szPlayerPoints )
	}
	
	iLen += formatex( g_szMotd[ iLen ], charsmax( g_szMotd ) - iLen, "</table></body>" )
	
	ArrayDestroy( aKey )
	ArrayDestroy( aData )
	ArrayDestroy( aAll )
}

public SortData( Array:aArray, iItem1, iItem2, iData[ ], iDataSize )
{
	new Data1[ FvaultData ]
	new Data2[ FvaultData ]
	
	ArrayGetArray( aArray, iItem1, Data1 )
	ArrayGetArray( aArray, iItem2, Data2 )
	
	new szPoints_1[ 7 ]
	parse( Data1[ szSkillP_Data ], szPoints_1, charsmax( szPoints_1 ) )
	
	new szPoints_2[ 7 ]
	parse( Data2[ szSkillP_Data ], szPoints_2, charsmax( szPoints_2 ) )
	
	new iCount1 = str_to_num( szPoints_1 )
	new iCount2 = str_to_num( szPoints_2 )
	
	return ( iCount1 > iCount2 ) ? -1 : ( ( iCount1 < iCount2 ) ? 1 : 0 )
}
public MessageSayText( iMsgID, iDest, iReceiver )
{
	new const Cstrike_Name_Change[ ] = "#Cstrike_Name_Change"
	
	new szMessage[ sizeof( Cstrike_Name_Change ) + 1 ]
	get_msg_arg_string( 2, szMessage, charsmax( szMessage ) )
	
	if( equal( szMessage, Cstrike_Name_Change ) )
	{
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE;
}
public TaskCountDown(params[], id){
	if(g_bStart){
		new name[32] ,iStyle;
		iStyle = get_pcvar_num( g_cvarStyle );
		get_user_name(id, name, 31) 
		replace_all(name, 31, "a.", "") 
		replace_all(name, 31, "b.", "") 
		replace_all(name, 31, "<a>", "")
		switch( iStyle ) {
			case 1:{
				if(--params[0] > 0) { 
					
					set_hudmessage(255, 255, 0, -1.0, 0.20, 0, 6.0, 1.0)
					ShowSyncHudMsg(id, g_MsgSync4, "%L",LANG_PLAYER, "AUTO_READY",name, params[0])
					set_task(1.0, "TaskCountDown", id, params, 1); 
					} else { 
					exec_hola(id) 
				} 
			}
			case 2:{
				if(is_plr_ready[id] == false){
					if(--params[0] > 0) { 
						
						set_hudmessage(255, 255, 0, -1.0, 0.20, 0, 6.0, 1.0)
						ShowSyncHudMsg(id, g_MsgSync4, "%L",LANG_PLAYER, "SAY_REAY",name, params[0])
						set_task(1.0, "TaskCountDown", id, params, 1); 
						} else { 
						server_cmd("kick #%d", get_user_userid(id)); 
					}
				} 
			} 
		}
	}
}
public exec_hola(id) {
	client_cmd(id,".add")
	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "FORCED_READY", szName);
	message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, id)
	write_short(14<<7)
	write_short(58<<6)
	write_short(1<<0)
	write_byte(5)
	write_byte(255)
	write_byte(0)
	write_byte(255)
	message_end()
}

public cmd_ready(id)
{
	if(g_bStart)
	{
		if(!is_plr_ready[id])
		{
			is_plr_ready[id] = true
			g_iReadyCount++
		}
		set_msg_ready()
		ClientPrintColor(0,"%s %L", PREFIX, LANG_PLAYER, "READY_NUM" ,g_iReadyCount,get_pcvar_num(g_plr_amount))
		
		if(g_iPlayerCount == get_pcvar_num(g_plr_amount) && g_iPlayerCount == g_iReadyCount)
		{
			
			ShowHudMsg(0, g_ready_color, 0.40, 0.35, g_SyncInfo, "Going Live everbody is ready!", 4)
			set_task( 10.0, "ActionSpecial" ); 
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "MAP_STARTED");
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "MAP_STARTED");
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "MAP_STARTED");
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER,"MAP_STARTED");
		}
	}
	
	return PLUGIN_HANDLED
}

public cmd_unready(id)
{
	if(g_bStart)
	{
		if(is_plr_ready[id] && g_iReadyCount > 0)
		{
			is_plr_ready[id] = false        
			g_iReadyCount--
		}
		set_msg_ready()
		ClientPrintColor(0,"%s %L", PREFIX, LANG_PLAYER, "READY_NUM" ,g_iReadyCount,get_pcvar_num(g_plr_amount))
		
		new params[1] = {TIMER_SECONDS + 1};
		set_task(1.0, "TaskCountDown", id, params, sizeof(params)); 
	}
	return PLUGIN_HANDLED
}
public set_msg_ready()
{
	static ClientName[32], pos, len, i
	pos = 0
	len = 0
	pos += formatex(g_MsgReady[pos], 511-pos, "Players Ready:")
	len += formatex(g_MsgNotReady[len], 511-len, "Players Not Ready:")
	
	for(i = 1 ; i <= g_iMaxPlayers ; i++)
	{    
		if(is_plr_connected[i])
		{
			if(is_plr_ready[i])
			{
				get_user_name(i, ClientName, 31)
				pos += formatex(g_MsgReady[pos], 511-pos, "^n%s", ClientName)
			}
			else
			{
				get_user_name(i, ClientName, 31)
				len += formatex(g_MsgNotReady[len], 511-len, "^n%s", ClientName)
			}
		}
	}
}

public show_ready_msg() 
{
	static i
	
	ShowHudMsg(0, g_ready_color, 0.8, 0.5, g_SyncReady, g_MsgReady, 1)
	ShowHudMsg(0, g_unready_color, 0.8, 0.2, g_SyncNotReady, g_MsgNotReady, 2)
	
	for(i = 1 ; i <= g_iMaxPlayers ; i++)
	{    
		if(is_plr_connected[i])
		{
			if(is_plr_ready[i])
			{
				new CsTeams:Team = cs_get_user_team(i)
				if(Team == CS_TEAM_SPECTATOR)
				{    
					g_iReadyCount--
					is_plr_ready[i] = false
					set_msg_ready()    
				}
			}
			else
			{
				ShowHudMsg(i, g_info_color, 0.45, 0.75, g_SyncInfo, "Type ^".add^" in chat!", 3)
			}
		}
	}
}

public ForwardThink(iEnt)
{
	if(g_bStart)
		show_ready_msg()
	
	entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 1.0)
}

public HudMsgColor(cvar, &r, &g, &b)
{
	static color[16], piece[5]
	get_pcvar_string(cvar, color, 15)
	
	strbreak( color, piece, 4, color, 15)
	r = str_to_num(piece)
	
	strbreak( color, piece, 4, color, 15)
	g = str_to_num(piece)
	b = str_to_num(color)
}

ShowHudMsg(id, cvar, Float:x, Float:y, synctype, msg[], channel) {
	
	static index, r, g, b 
	
	if(id)
		index = id
	else
		index = 0
	
	HudMsgColor(cvar, r, g, b)
	set_hudmessage(r, g, b, x, y, _, _, 4.0, _, _, channel)
	ShowSyncHudMsg(index, synctype, "%s", msg)
}

public Event_CurWeapon( id ){
	if(g_war){
		new iWeapon = read_data(2)
		if( !( NOCLIP_WPN_BS & (1<<iWeapon) ) )
		{
			fm_cs_set_weapon_ammo( get_pdata_cbase(id, m_pActiveItem) , g_MaxClipAmmo[ iWeapon ] )
		}
	}
}
public Player_Spawn_Post(id)
{	
	if(is_user_alive( id ) )
	{
		if(g_war){
			cs_set_user_money(id,0)
			cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM)
			fm_give_item(id, "weapon_deagle")
			fm_give_item(id, "weapon_ak47")
			fm_give_item(id, "weapon_m4a1")
			fm_give_item(id, "weapon_awp")
			cs_set_user_deaths(id, 0)
			set_user_frags(id, 0)
			cs_set_user_deaths(id, 0)
			set_user_frags(id, 0)
		}
	}
}
public PlayerKilled(Victim){
	if (!is_user_alive(Victim))
		set_task(1.0, "PlayerRespawn", Victim);
}
public PlayerRespawn(Client){
	if(g_war){
		if (!is_user_alive(Client) && CS_TEAM_T <= cs_get_user_team(Client) <= CS_TEAM_CT )
		{
			remove_task(Client);
			ExecuteHamB(Ham_CS_RoundRespawn, Client);
		}
	}
}
public msg_StatusIcon(msg_id, msg_dest, id) {
	if(g_war){
		if( get_msg_args() != 5 )
			return PLUGIN_CONTINUE
		
		new icon[3]
		get_msg_arg_string(2, icon, 2)
		if( !(icon[0] == 'c' && icon[1] == '4') )
			return PLUGIN_CONTINUE
		
		if(get_msg_arg_int(1) != 2)
			return PLUGIN_CONTINUE
		
		new mapzones = get_pdata_int(id, OFFSET_MAPZONE)
		if(mapzones & PLAYER_IN_BOMB_TARGET)
		{
			mapzones &= ~PLAYER_IN_BOMB_TARGET
			set_pdata_int(id, OFFSET_MAPZONE, mapzones)
		}
		set_msg_arg_int(1, ARG_BYTE, 1)
		return PLUGIN_CONTINUE
	} 
	return PLUGIN_CONTINUE
} 
public checkPlayers() {
	for (new i = 1; i <= get_maxplayers(); i++) {
		if (is_user_alive(i) && is_user_connected(i) && !is_user_bot(i) && !is_user_hltv(i) && g_spawned[i]) {
			new newangle[3]
			get_user_origin(i, newangle)
			
			if ( newangle[0] == g_oldangles[i][0] && newangle[1] == g_oldangles[i][1] && newangle[2] == g_oldangles[i][2] ) {
				g_afktime[i] += CHECK_FREQ
				check_afktime(i)
				} else {
				g_oldangles[i][0] = newangle[0]
				g_oldangles[i][1] = newangle[1]
				g_oldangles[i][2] = newangle[2]
				g_afktime[i] = 0
			}
		}
	}
	return PLUGIN_HANDLED
}
check_afktime(id) {
	new maxafktime = get_pcvar_num(g_timeafk)
	if (maxafktime < MIN_AFK_TIME) {
		log_to_file(g_szLogFile,"cvar mp_afktime %i is too low. Minimum value is %i.", maxafktime, MIN_AFK_TIME)
		maxafktime = MIN_AFK_TIME
		set_cvar_num("mp_afktime", MIN_AFK_TIME)
	}
	
	if ( maxafktime-WARNING_TIME <= g_afktime[id] < maxafktime) {
		new timeleft = maxafktime - g_afktime[id]
		ClientPrintColor(id, "%s %L", PREFIX, LANG_PLAYER, "AFK_TIME", timeleft)
		} else if (g_afktime[id] > maxafktime) {
		new name[32]
		get_user_name(id, name, 31)
		ClientPrintColor(0,"%s %L", PREFIX, LANG_PLAYER, "AFK_KICK", name, maxafktime)
		log_to_file(g_szLogFile,"%s was kicked for being AFK longer than %i seconds", name, maxafktime)
		server_cmd("kick #%d ^"You were kicked for being AFK longer than %i seconds^"", get_user_userid(id), maxafktime)
	}
}
public client_connect(id) {
	g_afktime[id] = 0
	return PLUGIN_HANDLED
}
public playerSpawned(id) {
	g_spawned[id] = false
	new sid[1]
	sid[0] = id
	set_task(0.75, "delayedSpawn",_, sid, 1)	
	return PLUGIN_HANDLED
}

public delayedSpawn(sid[]) {
	get_user_origin(sid[0], g_oldangles[sid[0]])
	g_spawned[sid[0]] = true
	return PLUGIN_HANDLED
}

public wonteam(){
	new winningTeam[65]
	
	if ( g_iScore[g_bSecondHalf ? 0 : 1] > g_iScore[g_bSecondHalf ? 1 : 0] )
		formatex(winningTeam, charsmax(winningTeam), "Team A")
	else
		formatex(winningTeam, charsmax(winningTeam), "Team B")
	
	set_hudmessage(135, 135, 135, 0.35, 0.21, 1, 6.0, 1.0)
	ShowSyncHudMsg(0, g_MsgSync6, "%L", LANG_PLAYER, "TEAM_WONEND", winningTeam)
	
}
public CmdBalance() {
	BalancePlayers();
}

BalancePlayers() {
	new players[32], pnum, id, CsTeams:teams[33], playerData[32][2];
	get_players(players, pnum, "h");
	
	for(new i = 0; i < pnum; i++) {
		playerData[i][0] = id = players[i];
		
		if(!(CS_TEAM_T <= (teams[id] = cs_get_user_team(id)) <= CS_TEAM_CT)) {
			players[i--] = players[--pnum];
			} else {
			playerData[i][1] = g_iPoints[i]
		}
	}
	
	SortCustom2D(playerData, pnum, "SortPlayers");
	
	log_to_file(g_szLogFile,"Starting skill balance");
	
	for(new i = 0, j = pnum - 1, CsTeams:team = CS_TEAM_T; i < j; i++, j--, team = CS_TEAM_SPECTATOR - team) {
		MovePlayer(playerData[i][0], teams, team);
		MovePlayer(playerData[j][0], teams, CS_TEAM_SPECTATOR - team);
	}
}

public SortPlayers(player1[], player2[], playerData[][], data[], dataSize) {
	return clamp(player1[1] - player2[1], -1, 1);
}

MovePlayer(id, CsTeams:teams[], CsTeams:team) {
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	if(teams[id] != team) {
		cs_set_user_team(id, team);
		
		log_to_file(g_szLogFile,"Moved %s to %sTerrorist team", name, (team == CS_TEAM_T) ? "" : "Counter-");
		} else {
		log_to_file(g_szLogFile,"%s was already on the %sTerrorist team", name, (team == CS_TEAM_T) ? "" : "Counter-");
	}
}
public show_top(id)
{
	new i, count;
	static sort[33][2], maxPlayers;
	
	if(!maxPlayers) maxPlayers = get_maxplayers();
	
	for(i=1;i<=maxPlayers;i++)
	{
		sort[count][0] = i;
		sort[count][1] = g_iPoints[i]
		count++;
	}
	
	SortCustom2D(sort,count,"stats_custom_compare");
	
	new motd[1024], len	
	
	len = format(motd, 1023,"<body bgcolor=#000000><font color=#FFB000><pre>")
	len += format(motd[len], 1023-len,"%s %-22.22s %3s^n", "#", "Name", "Skill")
	
	new players[32], num
	get_players(players, num)
	
	new b = clamp(count,0,10)
	
	new name[32], player
	
	for(new a = 0; a < b; a++)
	{
		player = sort[a][0]
		
		get_user_name(player, name, 31)		
		len += format(motd[len], 1023-len,"%d %-22.22s %d^n", a+1, name, sort[a][1])
	}
	
	len += format(motd[len], 1023-len,"</body></font></pre>")
	show_motd(id, motd, "Online Rank Player")
	
	return PLUGIN_CONTINUE
}

public stats_custom_compare(elem1[],elem2[])
{
	if(elem1[1] > elem2[1]) return -1;
	else if(elem1[1] < elem2[1]) return 1;
		
	return 0;
}
public chooseteam(id) {
	if ( cs_get_user_team(id) == CS_TEAM_UNASSIGNED )
		return PLUGIN_CONTINUE
	
	player(id)
	return PLUGIN_HANDLED
}
public player(id) {
	
	new title[94]
	new item1[64], item2[64], item3[64], item4[64],item5[64];
	
	formatex(title, charsmax(title), "%L", LANG_PLAYER, "PLAYERS_MENU_TITLE")
	formatex(item1, charsmax(item1), "%L", LANG_PLAYER, "PLAYERS_MENU_ITEM1")
	formatex(item2, charsmax(item2), "%L", LANG_PLAYER, "PLAYERS_MENU_ITEM2")
	formatex(item3, charsmax(item3), "%L", LANG_PLAYER, "PLAYERS_MENU_ITEM3")
	formatex(item4, charsmax(item4), "%L", LANG_PLAYER, "PLAYERS_MENU_ITEM4")
	formatex(item5, charsmax(item5), "%L", LANG_PLAYER, "PLAYERS_MENU_ITEM5")
	
	new playermenu = menu_create(title, "playermenu")
	
	menu_additem(playermenu, item1)
	menu_additem(playermenu, item2)
	menu_additem(playermenu, item3)
	menu_additem(playermenu, item4)	
	menu_additem(playermenu, item5)	
	menu_display(id, playermenu)
	return PLUGIN_CONTINUE
}
public playermenu(id, menu, item) { 
	if( item == MENU_EXIT )
		return PLUGIN_HANDLED; 
	
	switch(item) {
		case 0: {
			help_cmd(id)
		}
		case 1: {
			show_top(id)
		}
		
		case 2: {
			Cmd_VoteBan(id)
		}
		case 3: {
			cmdPMMenu(id)
		}
		case 4: {
			ahelp_cmd(id)
		}
		
	}
	return PLUGIN_HANDLED
} 
public cmdPMMenu(id)
{
    new menu = menu_create("Send PM To:", "handlePMMEnu")
    
    new players[32], num
    new szName[32], szTempid[32]
    
    get_players(players, num, "ach")
    
    for(new i; i < num; i++)
    {
        get_user_name(players[i], szName, charsmax(szName))
        
        num_to_str(get_user_userid(players[i]), szTempid, charsmax(szTempid))
        
        menu_additem(menu, szName, szTempid, 0)
    }
    
    menu_display(id, menu)
}

public handlePMMEnu(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    
    new szData[6], szName[64], iAccess, iCallback
    menu_item_getinfo(menu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback)
    
    g_iTarget[id] = find_player("k", str_to_num(szData))
    
    client_cmd(id, "messagemode PrivateMessage")
    
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public cmd_player(id)
{
    new say[300]
    read_args(say, charsmax(say))
    remove_quotes(say)
    
    if(!strlen(say))
        return PLUGIN_HANDLED
    
    new szSenderName[32], szReceiverName[32]
    get_user_name(id, szSenderName, charsmax(szSenderName))
    get_user_name(g_iTarget[id], szReceiverName, charsmax(szReceiverName))
    
    ClientPrintColor(id, "PM to %s: %s", szReceiverName, say)
    ClientPrintColor(g_iTarget[id],"PM from %s: %s", szSenderName, say)
    
    return PLUGIN_CONTINUE
}
public SpecKick()
{
	
	new players[32], pnum;
	get_players(players, pnum, "ch")
	
	for (new x ; x<pnum ; x++) {
		if (is_user_connected(players[x])) {
			if (!(get_user_flags(players[x]) & ACCESS_LEVEL)) {
				if ((cs_get_user_team(players[x]) == CS_TEAM_SPECTATOR)) {
					new userid = get_user_userid(players[x])
					server_cmd("kick #%d ^"Spectators aren't welcome on this server.^"",userid)
				}
				
			}
		}
	}
	return PLUGIN_CONTINUE
}
public saycmd(id)
{
	static message[64] 
	read_args (message, 63) 
	remove_quotes (message) 
	
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 's' && message[2] == 'c' && message[3] == 'o' && message[4] == 'r'&& message[5] == 'e' ) { 
		showscore(id)
	} 
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 't' && message[2] == 'e'&& message[3] == 'a'&& message[4] == 'm' && message[5] == 's' ){ 
		teams_cmd(id)
		
	} 
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 'd' && message[2] == 'e' && message[3] == 'm'&& message[4] == 'o'&& message[5] == 'm'&& message[6] == 'e'){  
		cmdRecord(id)
	}   
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 'r' && message[2] == 'a' && message[3] == 't' && message[4] == 'i'&& message[5] == 'o'){  
		ClientPrintColor(id, "%s %L", PREFIX, LANG_PLAYER, "RATIO", 1.0*g_iKills[ id ]/g_iDeaths[ id ] )
	}   
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 's' && message[2] == 'k' && message[3] == 'i'&& message[4] == 'l' && message[5] == 'l'){  
		GetSkillPoints(id)
	}   
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 't' && message[2] == 'o' && message[3] == 'p'&& message[4] == 's' && message[5] == 'k'&& message[6] == 'i'&& message[7] == 'l' && message[8] == 'l'){  
		
	}   
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 'r' && message[2] == 'a' && message[3] == 'n'&& message[4] == 'k' && message[5] == 's'&& message[6] == 'k'&& message[7] == 'i' && message[8] == 'l'&& message[9] == 'l'){  
		SkillRank(id)
	} if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 'a' && message[2] == 'd' && message[3] == 'd'){  
		cmd_ready(id)
	} 
	if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
	&& message[1] == 'r' && message[2] == 'e' && message[3] == 'm'&& message[4] == 'o' && message[5] == 'v'&& message[6] == 'e'){  
		cmd_unready(id)
	} 
}
public saycommand(id)
{
	if(get_user_flags(id) & ACCESS_LEVEL){
		
		static message[64] 
		read_args (message, 63) 
		remove_quotes (message) 
		
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'p' && message[2] == 'a' && message[3] == 's' && message[4] == 's' ) { 
			static pass[31]; 
			strbreak(message, message, 6, pass, 30); 
			remove_quotes(pass); 
			set_pcvar_string(g_Cvar_Password, pass)
			ClientPrintColor( 0,"%s %L", PREFIX, LANG_PLAYER, "PASSWORD",pass )
			
		} if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'm' && message[2] == 'a' && message[3] == 'p') { 
			static  map[31]; 
			strbreak(message, message, 6, map, 30); 
			remove_quotes(map); 
			server_cmd( "changelevel ^"%s^"", map);
			ClientPrintColor( 0,"%s %L", PREFIX, LANG_PLAYER, "MAP",map )
			
		} 
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'f' && message[2] == 'f'&& message[3] == ' '&& message[4] == 'o' && message[5] == 'n' ){ 
			set_pcvar_num(g_Cvar_FriendlyFire,1)
			ClientPrintColor( 0,"%s %L", PREFIX, LANG_PLAYER, "FRIENDLYFIRE_ON")
		} 
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'f' && message[2] == 'f' && message[3] == ' '&& message[4] == 'o' && message[5] == 'f' && message[6] == 'f'){  
			set_pcvar_num(g_Cvar_FriendlyFire,0)
			ClientPrintColor( 0,"%s %L", PREFIX, LANG_PLAYER, "FRIENDLYFIRE_OFF")
		}   
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'r' && message[2] == 'r' ){  
			set_pcvar_num(g_Cvar_RestartRound, 1)
			
		}   
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'r' && message[2] == 'e' && message[3] == 's'&& message[4] == 't' && message[5] == 'a' && message[6] == 'r'&& message[7] == 't'){  
			server_cmd("restart")
		}   
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'p' && message[2] == 'a' && message[3] == 'u'&& message[4] == 's' && message[5] == 'e'){  
			server_cmd("amx_pause")
		}   
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 'r' && message[2] == 'e' && message[3] == 'a'&& message[4] == 'd' && message[5] == 'y'){  
			adminstart(id)
		}   
		if( (message[0] == '!' || message[0] == '/' || message[0] == '.')  
		&& message[1] == 's' && message[2] == 't' && message[3] == 'o'&& message[4] == 'p'){  
			adminstop(id)
		}   
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}
public sayinfo(iPlayer)
{
	new iTarget[33]
	read_argv(1, iArg, charsmax(iArg))
	parse(iArg, iArg, 35, iTarget, charsmax(iTarget))
	read_args(iArgs, 63)
	remove_quotes(iArgs)
	
	strtok(iArgs, iArg, charsmax(iArg), iArgs, charsmax(iArgs), ' ');
	strtok(iArgs, iArg1, charsmax(iArg1), iReason, charsmax(iReason), ' ');
	
	if(equali(iArg, ".info"))
	{
		if(!iTarget[0]) ClientPrintColor(iPlayer,"%s %L", PREFIX, LANG_PLAYER, "INFO_USAGE")
		else if(!iReason[0]) ClientPrintColor(iPlayer, "%s %L", PREFIX, LANG_PLAYER, "VALID_COMMAND")
			else
		{
			new iTargetID = cmd_target(iPlayer, iTarget, 2)
			if(iTargetID)
			{    
				
				query_client_cvar(iTargetID, iReason, "CheckCvar");
				new name[32];
				get_user_name(iTargetID, name, 31);
				ClientPrintColor(iTargetID, "%s %L", PREFIX, LANG_PLAYER, "CHECK_CVAR", iReason, name);
				
			}
			else ClientPrintColor(iPlayer,"%s %L", PREFIX, LANG_PLAYER, "MULTIPLE_NAME")
		}
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}
public CheckCvar(iTargetID, cvar_name[], cvar_value[])
{
	new plr_name[32];
	get_user_name(iTargetID, plr_name, 31);
	
	ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "CVAR_SET_TO", plr_name, cvar_name, cvar_value);
}
public SayCmds(iPlayer)
{
	new iTarget[33]
	read_argv(1, iArg, charsmax(iArg))
	parse(iArg, iArg, 35, iTarget, charsmax(iTarget))
	read_args(iArgs, 63)
	remove_quotes(iArgs)
	
	strtok(iArgs, iArg, charsmax(iArg), iArgs, charsmax(iArgs), ' ');
	strtok(iArgs, iArg1, charsmax(iArg1), iReason, charsmax(iReason), ' ');
	
	if(get_user_flags(iPlayer) & ACCESS_LEVEL)
	{
		new iSteamID[33]; get_user_authid(iPlayer, iSteamID, charsmax(iSteamID))
		
		if(equali(iArg, ".kick"))
		{
			if(!iTarget[0]) ClientPrintColor(iPlayer,"%s %L", PREFIX, LANG_PLAYER, "KICK_USAGE" )
			else if(!iReason[0]) ClientPrintColor(iPlayer, "%s %L", PREFIX, LANG_PLAYER, "VALID_REASON")
				else
			{
				new iTargetID = cmd_target(iPlayer, iTarget, 2)
				if(iTargetID)
				{    
					new szName[33]; get_user_name(iPlayer, szName, charsmax(szName))
					new szName2[33]; get_user_name(iTargetID, szName2, charsmax(szName2))
					
					server_cmd("kick #%d ^"%s^"", get_user_userid(iTargetID), iReason)
					ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "KICK_BY_KICK", szName2, szName, iReason)
					
					log_to_file(g_szLogFile,"%s [%s] kicked %s Reason: %s", szName, iSteamID, szName2, iReason)
				}
				else ClientPrintColor(iPlayer,"%s %L", PREFIX, LANG_PLAYER, "MULTIPLE_NAME")
			}
			return PLUGIN_HANDLED
		}
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}
public SayBan(iPlayer)
{
	new iTarget[33]
	read_argv(1, iArg, charsmax(iArg))
	parse(iArg, iArg, 35, iTarget, charsmax(iTarget))
	read_args(iArgs, 63)
	remove_quotes(iArgs)
	
	strtok(iArgs, iArg, charsmax(iArg), iArgs, charsmax(iArgs), ' ');
	strtok(iArgs, iArg1, charsmax(iArg1), iReason, charsmax(iReason), ' ');
	
	if(get_user_flags(iPlayer) & ACCESS_LEVEL)
	{
		new iSteamID[33]; get_user_authid(iPlayer, iSteamID, charsmax(iSteamID))
		
		if(equali(iArg, ".ban"))
		{
			if(!iTarget[0]) ClientPrintColor(iPlayer,"%s %L", PREFIX, LANG_PLAYER, "BAN_USAGE")
			else if(!iReason[0]) ClientPrintColor(iPlayer, "%s %L", PREFIX, LANG_PLAYER, "VALID_TIME")
				else
			{
				new iTargetID = cmd_target(iPlayer, iTarget, 2)
				if(iTargetID)
				{    
					new szName[33]; get_user_name(iPlayer, szName, charsmax(szName))
					new szName2[33]; get_user_name(iTargetID, szName2, charsmax(szName2))
					
					server_cmd("amx_ban #%d ^"%s^"", get_user_userid(iTargetID), iReason)
					ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "BAN_BY_BAN", szName2, szName, iReason)
					log_to_file(g_szLogFile,"%s [%s] banned %s Time: %s", szName, iSteamID, szName2, iReason)
				}
				else ClientPrintColor(iPlayer, "%s %L", PREFIX, LANG_PLAYER, "MULTIPLE_NAME")
			}
			return PLUGIN_HANDLED
		}
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}
public SayDemo(iPlayer)
{
	new iTarget[33]
	read_argv(1, iArg, charsmax(iArg))
	parse(iArg, iArg, 35, iTarget, charsmax(iTarget))
	read_args(iArgs, 63)
	remove_quotes(iArgs)
	
	strtok(iArgs, iArg, charsmax(iArg), iArgs, charsmax(iArgs), ' ');
	strtok(iArgs, iArg1, charsmax(iArg1), iReason, charsmax(iReason), ' ');
	
	if(get_user_flags(iPlayer) & ACCESS_LEVEL)
	{
		new iSteamID[33]; get_user_authid(iPlayer, iSteamID, charsmax(iSteamID))
		
		if(equali(iArg, ".demo"))
		{
			if(!iTarget[0]) ClientPrintColor(iPlayer,"%s %L", PREFIX, LANG_PLAYER, "DEMO_USAGE")
			else if(!iReason[0]) ClientPrintColor(iPlayer, "%s %L", PREFIX, LANG_PLAYER, "VALID_NAME")
				else
			{
				new iTargetID = cmd_target(iPlayer, iTarget, 2)
				if(iTargetID)
				{    
					new szName[33]; get_user_name(iPlayer, szName, charsmax(szName))
					new szName2[33]; get_user_name(iTargetID, szName2, charsmax(szName2))
					
					client_cmd(iTargetID, "record ^"%s^"", iReason)
					ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "DEMO_ON_DEMO", szName2, szName, iReason)
					log_to_file(g_szLogFile,"%s [%s] start demo record on %s DemoName: %s", szName, iSteamID, szName2, iReason)
				}
				else ClientPrintColor(iPlayer, "%s %L", PREFIX, LANG_PLAYER, "MULTIPLE_NAME")
			}
			return PLUGIN_HANDLED
		}
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}
public tk( ) 
{
	new killer = read_data( 1 );
	new victim = read_data( 2 );
	
	if( g_IsStarted )
	{
		if( ( cs_get_user_team( killer ) == cs_get_user_team( victim ) ) ) 
		{
			if( g_LeftKills[killer] < 1 )
				g_LeftKills[ killer ] ++;
			else
				server_cmd( "amx_ban #%d 60 Team-Kills are not allowed!", get_user_userid( killer ) );
		}
	}
} 
public winpoinsts()
{
	for ( new i = 1 ; i <= g_iMaxPlayers  ; i++ )
	{
		if ( !is_user_connected(i) || ( g_iScore[0] != 16 && g_iScore[1] != 16 ) )
			continue;
		
		if ( g_iScore[0] > g_iScore[1] && cs_get_user_team(i) == CS_TEAM_T )
		{
			if (get_pcvar_num(g_WinsMatchPoints) )
				g_iPoints[i] += get_pcvar_num(g_WinsMatchPoints)
			
		}
		
		else if ( g_iScore[1] > g_iScore[0] && cs_get_user_team(i) == CS_TEAM_CT )
		{
			if (get_pcvar_num(g_WinsMatchPoints) )
				g_iPoints[i] += get_pcvar_num(g_WinsMatchPoints)
		}
		
		else
		{
			if (get_pcvar_num(g_LosesMatchPoints) )
				g_iPoints[i] -= get_pcvar_num(g_LosesMatchPoints)
		}
		CheckLevelAndSave(i)
	}
}
public ClientUserInfoChanged(id) 
{ 
	if(g_IsStarted )
	{
		if( is_user_connected(id) ) 
		{ 
			static const name[] = "name" 
			static szOldName[32], szNewName[32] 
			pev(id, pev_netname, szOldName, charsmax(szOldName)) 
			get_user_info(id, name, szNewName, charsmax(szNewName)) 
			if (g_bSecondHalf)
			{
				if (cs_get_user_team(id) == CS_TEAM_CT)
				{
					if (containi( szOldName, "b.") != -1)
					{
						if( !equal(szOldName, szNewName) ) 
						{ 
							set_user_info(id, name, szOldName) 
							return FMRES_HANDLED 
						} 
					}
				}
				
				else if (cs_get_user_team(id) == CS_TEAM_T)
				{
					if (containi( szOldName, "a.") != -1)
					{
						if( !equal(szOldName, szNewName) ) 
						{ 
							set_user_info(id, name, szOldName) 
							return FMRES_HANDLED 
						} 
					}
				}
			}
			
			else
			{
				if (cs_get_user_team(id) == CS_TEAM_CT)
				{
					if (containi( szOldName, "a.") != -1)
					{
						if( !equal(szOldName, szNewName) ) 
						{ 
							set_user_info(id, name, szOldName) 
							return FMRES_HANDLED 
						} 
					}
					
				}
				
				else if (cs_get_user_team(id) == CS_TEAM_T)
				{
					if (containi( szOldName, "b.") != -1)
					{
						if( !equal(szOldName, szNewName) ) 
						{ 
							set_user_info(id, name, szOldName) 
							return FMRES_HANDLED 
						} 
					}
					
				}
			}
		} 
	}
	return FMRES_IGNORED 
}
public EventCurWeapon( id ) {
	if( g_bKnifeRound ) engclient_cmd( id, "weapon_knife" );
	return PLUGIN_CONTINUE;
}

public CmdKnifeRound(id) {    
	
	set_pcvar_num(g_Cvar_RestartRound, 1)
	set_task( 2.0, "KnifeRoundStart", id );
	
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "KR_STARTED");
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "KR_STARTED");
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "KR_STARTED");
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER,"KR_STARTED");
	
	return PLUGIN_CONTINUE;
}

public KnifeRoundStart( ) {
	g_bKnifeRound = true;
	g_bVotingProcess = false;
	
	new players[ 32 ], num;
	get_players( players, num );
	
	for( new i = 0; i < num ; i++ )
	{
		new item = players[ i ];
		EventCurWeapon( item );
	}
	
	return PLUGIN_CONTINUE;
}

public SwapTeams( ) {
	for( new i = 1; i <= g_iMaxPlayers; i++ ) {
		if( is_user_connected( i ) )
		{
			switch( cs_get_user_team( i ) )
			{
				case CS_TEAM_T: cs_set_user_team( i, CS_TEAM_CT );			
					case CS_TEAM_CT: cs_set_user_team( i, CS_TEAM_T );
				}
		}
	}
}

public EventRoundEnd( ) {
	if(g_bKnifeRound) {
		new players[ 32 ], num;
		get_players( players, num, "ae", "TERRORIST" );
		
		if(!num) 
		{
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER,"KR_WIN_CT"); 
			set_task( 6.0, "vote_ct" );
		}
		else
		{	        
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "KR_WIN_T");
			set_task( 6.0, "vote_t" );  
		}    
	}
	g_bKnifeRound = false;
	
	return PLUGIN_CONTINUE;
}

public vote_t( ) {
	for( new i = 1; i <= g_iMaxPlayers; i++ ) {
		if( is_user_alive( i ) && cs_get_user_team( i ) == CS_TEAM_T )
		{
			ShowMenu( i );
		}
	}
	set_task( 8.0, "finishvote" );
}

public vote_ct( ) {
	for( new i = 1; i <= g_iMaxPlayers; i++ ) {
		if( is_user_alive( i ) && cs_get_user_team( i ) == CS_TEAM_CT )
		{
			ShowMenu( i );
		}
	}
	set_task( 8.0, "finishvote" );
}

public ShowMenu( id ) {
	g_bVotingProcess = true;
	
	if( g_bVotingProcess ) {
		new szMenuBody[ 256 ], keys;
		
		new nLen = format( szMenuBody, 255, "\rSwap teams?^n" );
		nLen += format( szMenuBody[nLen], 255-nLen, "^n\y1. \wYes" );
		nLen += format( szMenuBody[nLen], 255-nLen, "^n\y2. \wNo" );
		nLen += format( szMenuBody[nLen], 255-nLen, "^n^n\y0. \wExit" );
		
		keys = ( 1<<0 | 1<<1 | 1<<9 );
		
		show_menu( id, keys, szMenuBody, -1 );
	}
	
	return PLUGIN_CONTINUE;
}

public MenuCommand( id, key ) {
	if( !g_bVotingProcess ) return PLUGIN_HANDLED;
	
	new szName[ 32 ];
	get_user_name( id, szName, charsmax( szName ) );
	
	switch( key )
	{
		case 0: 
		{
			g_Votes[ 0 ]++;
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "KR_VOTE_YES", szName );
		}
		case 1: 
		{
			g_Votes[ 1 ]++;
			ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "KR_VOTE_NO",  szName );
		}  
		case 9: show_menu( id, 0, "" );
		} 
	
	return PLUGIN_HANDLED;
}

public finishvote( ) {
	if( !g_bVotingProcess ) return PLUGIN_HANDLED;
	
	set_pcvar_num(g_Cvar_RestartRound, 1)
	
	if ( g_Votes[ 0 ] > g_Votes[ 1 ] ) 
	{
		ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER,"KR_SWITCH_TEAMS");
		SwapTeams( );
	}
	else
	{
		ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "KR_STAY_IN");
	}
	
	g_Votes[ 0 ] = 0;
	g_Votes[ 1 ] = 0;
	g_bVotingProcess = false;
	set_task(4.0,"start")
	
	return PLUGIN_HANDLED;
}
public Cmd_VoteBan(id)
{
	get_players(g_iPlayers, g_iNum, "h");
	
	if(g_iNum < 3)
	{
		ClientPrintColor(id, "%s %L", PREFIX, LANG_PLAYER, "NOT_VOTEBAN");
		return PLUGIN_HANDLED;
	}
	ShowBanMenu(id, g_iMenuPage[id] = 0);
	return PLUGIN_CONTINUE;
}

public ShowBanMenu(id, iPos)
{
	static i, iPlayer, szName[32];
	static szMenu[256], iCurrPos; iCurrPos = 0;
	static iStart, iEnd; iStart = iPos * MENU_SLOTS;
	static iKeys;
	
	get_players(g_iPlayers, g_iNum, "h");
	
	if(iStart >= g_iNum)
	{
		iStart = iPos = g_iMenuPage[id] = 0;
	}
	
	static iLen;
	iLen = formatex(szMenu, charsmax(szMenu), "\rVOTEBAN \yMenu:^n^n");
	
	iEnd = iStart + MENU_SLOTS;
	iKeys = MENU_KEY_0;
	
	if(iEnd > g_iNum)
	{
		iEnd = g_iNum;
	}
	
	for(i = iStart ; i < iEnd ; i++)
	{
		iPlayer = g_iPlayers[i];
		get_user_name(iPlayer, szName, charsmax(szName));
		
		iKeys |= (1 << iCurrPos++);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d\w.%s \d(\r%d%%\d)^n", iCurrPos, szName, get_percent(g_iVotes[iPlayer], g_iNum));
	}
	
	if(iEnd != g_iNum)
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9\w.Next ^n\r0\w.%s", iPos ? "Back" : "Exit");
		iKeys |= MENU_KEY_9;
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0\w.%s", iPos ? "Back" : "Exit");
	}
	show_menu(id, iKeys, szMenu, -1, "");
	return PLUGIN_HANDLED;
}

public Menu_VoteBan(id, key)
{
	switch(key)
	{
		case 8:
		{
			ShowBanMenu(id, ++g_iMenuPage[id]);
		}
		case 9:
		{
			if(!g_iMenuPage[id])
				return PLUGIN_HANDLED;
			
			ShowBanMenu(id, --g_iMenuPage[id]);
		}
		default: {
			static iPlayer;
			iPlayer = g_iPlayers[g_iMenuPage[id] * MENU_SLOTS + key];
			
			if(!is_user_connected(iPlayer))
			{
				ShowBanMenu(id, g_iMenuPage[id]);
				return PLUGIN_HANDLED;
			}
			if(iPlayer == id)
			{
				ClientPrintColor(id, "%s %L", PREFIX, LANG_PLAYER, "NOT_YOU");
				ShowBanMenu(id, g_iMenuPage[id]);
				
				return PLUGIN_HANDLED;
			}
			if(g_iVotedPlayers[id] & (1 << iPlayer))
			{
				ClientPrintColor(id, "%s %L", PREFIX, LANG_PLAYER, "ALREADY_VOTEBAN");
				ShowBanMenu(id, g_iMenuPage[id]);
				
				return PLUGIN_HANDLED;
			}
			g_iVotes[iPlayer]++;
			g_iVotedPlayers[id] |= (1 << iPlayer);
			
			static szName[2][32];
			get_user_name(id, szName[0], charsmax(szName[]));
			get_user_name(iPlayer, szName[1], charsmax(szName[]));
			
			ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "BAN_X_PLAYER", szName[0], szName[1]);
			
			CheckVotes(iPlayer, id);
			client_cmd(id, "messagemode _voteban_reason");
			
			ShowBanMenu(id, g_iMenuPage[id]);
		}
	}
	return PLUGIN_HANDLED;
}

public Cmd_VoteBanReason(id)
{
	if(!g_iVotedPlayers[id])
		return PLUGIN_HANDLED;
	
	new szArgs[64];
	read_argv(1, szArgs, charsmax(szArgs));
	
	if(szArgs[0])
	{
		formatex(g_szVoteReason[id], charsmax(g_szVoteReason[]), szArgs);
	}
	return PLUGIN_HANDLED;
}

public CheckVotes(id, voter)
{
	get_players(g_iPlayers, g_iNum, "h");
	new iPercent = get_percent(g_iVotes[id], g_iNum);
	
	if(iPercent >= get_pcvar_num(g_iPcvar[CVAR_PERCENT]))
	{
		switch(get_pcvar_num(g_iPcvar[CVAR_BANTYPE]))
		{
			case 1:
			{
				new szAuthid[32];
				get_user_authid(id, szAuthid, charsmax(szAuthid));
				server_cmd("kick #%d;wait;wait;wait;banid %d ^"%s^";wait;wait;wait;writeid", get_user_userid(id), get_pcvar_num(g_iPcvar[CVAR_BANTIME]), szAuthid);
			}
			case 2:
			{
				new szIp[32];
				get_user_ip(id, szIp, charsmax(szIp), 1);
				server_cmd("kick #%d;wait;wait;wait;addip %d ^"%s^";wait;wait;wait;writeip", get_user_userid(id), get_pcvar_num(g_iPcvar[CVAR_BANTIME]), szIp);
			}
		}
		g_iVotes[id] = 0;
		
		new szName[2][32];
		get_user_name(id, szName[0], charsmax(szName[]));
		get_user_name(id, szName[1], charsmax(szName[]));
		ClientPrintColor(0, "%s %L", PREFIX, LANG_PLAYER, "VOTEBAN_BAN", szName[0], get_pcvar_num(g_iPcvar[CVAR_BANTIME]));
		
		log_to_file(g_szLogFile, "Player '%s' voted for banning '%s' for: %s", szName[1], szName[0], g_szVoteReason[voter]);
	}
}

stock get_percent(value, tvalue)
{     
	return floatround(floatmul(float(value) / float(tvalue) , 100.0));
}
public help_cmd(id) {
	new motd[MAX_BUFFER_LENGTH],len;
	len = format(motd, MAX_BUFFER_LENGTH,"<body bgcolor=#000000><font color=#87cefa><pre>")
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<center><h1><font color=^"blue^"> Player's commands </font></h4></center>");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<center><h3><font color=^"green^"> (all command on say) </font></h3></center>");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.score</B> -> <font color=^"white^">Displays the team score</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.teams</B> -> <font color=^"white^">Displays team's</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.demome</B> -> <font color=^"white^">Start recording demo.</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.skill</B> -> <font color=^"white^">Shows your Skillpoints.</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.rankskill</B> -> <font color=^"white^">Show your current rank.</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.topskill</B> -> <font color=^"white^">Show the Top15 players with the highest SkillPoints.</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.add</B> -> <font color=^"white^">Adds yourself to a match.</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.remove</B> -> <font color=^"white^">Remove yourself to a match.</color></left>^n");	
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.info [name] [command]</B> -> <font color=^"white^">Request player informations.(eg say .info player rate)</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.ratio</B> -> <font color=^"white^">Shows your ratio.</color></left>^n");
        len += format(motd[len], MAX_BUFFER_LENGTH-len,"");
	show_motd(id, motd, "PlayerHelp");
	return PLUGIN_CONTINUE;
}
public ahelp_cmd(id)
{
	new motd[MAX_BUFFER_LENGTH],len;
	len = format(motd, MAX_BUFFER_LENGTH,"<body bgcolor=#000000><font color=#87cefa><pre>")
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<center><h1><font color=^"blue^"> Admin's Commands </font></h4></center>");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<center><h3><font color=^"green^"> (all command on say) </font></h3></center>");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.ready</B> -> <font color=^"white^">Start match.</color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.stop</B> -> <font color=^"white^">Stop match.</color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.pass <password></B> -> <font color=^"white^">Set password server.</color></left>^n");
        len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.map <mapname></B> -> <font color=^"white^">Change map..</color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.restart</B>  -> <font color=^"white^">Restart server.</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.rr</B> -> <font color=^"white^">Round restart.</color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.pause</B> -> <font color=^"white^">Pause server/Unpause server.</color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.ff on</B> -> <font color=^"white^">Friendlyfire is ON!</color></left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.ff off</B> -> <font color=^"white^">Friendlyfire is OFF!</color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"blue^">----------------------------------</color></left>^n")
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.ban [name] [time]</B> -> <font color=^"white^">Ban the user from the server.</color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.kick [name] [reason]</B> -> <font color=^"white^">Kick the user from the server </color> </left>^n");
	len += format(motd[len], MAX_BUFFER_LENGTH-len,"<left><font color=^"red^"><B>.demo [name] [demoname]</B> -> <font color=^"white^">Start demo from a player.</color> </left>^n");
	show_motd(id, motd, "AdminHelp");
	return PLUGIN_CONTINUE;
}
public ActionSpecial() 
{ 
	new mapid, bool:g_choosedmap[sizeof(Change)] = false
	for(new i = 0; i < MAX_MAPS; i++) //select X maps  
	{
		g_szKind[i] = 0
		mapid = random_num(0, sizeof(Change)-1)	
		
		while(g_choosedmap[mapid])		
			mapid = random_num(0, sizeof(Change)-1) 
		
		g_choosedmap[mapid] = true		
		format(g_maps[i], 29, "%s", Change[mapid])
	}
	
	new players[32], num, id
	get_players(players, num)
	for( new i = 0; i < num; i++ )
	{
		id = players[i]
		Voted[id] = false;
		ChangeMaps(id)
	}
	
	Timer = 17
	client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use bay(s18) mass(e42) cap(s50)^"")  
	set_task( 17.0, "checkvotesd");  
	countdown2();
} 

public ChangeMaps(client) 
{ 
	static szMap[128];  
	new st[ 3 ]; 
	formatex(szMap, charsmax(szMap)-1, "\r[GATHER]\w Choose Map:^n\r// \wStatus: %s^n\r// \wTime to choose: \y%d",Voted[client] ? "\yVoted" : "\rNot Voted", Timer);  
	new menu = menu_create(szMap, "handlerdddd"); 
	
	for( new k = 0; k < MAX_MAPS; k++ ) 
	{ 
		num_to_str( k, st, 2 ); 
		formatex( szMap, charsmax( szMap ), "\w%s \d[\y%i\w Votes\d]", g_maps[k] , g_szKind[k]); 
		menu_additem( menu, szMap, st ); 
	} 
	
	menu_setprop( menu, MPROP_EXIT, MEXIT_NEVER ); 
	menu_display(client,menu); 
} 

public checkvotesd() 
{  
	new Winner = 0; 
	for( new i = 1; i < sizeof g_maps; i++ )  
	{ 
		if( g_szKind[ Winner ] < g_szKind[ i ] ) 
			Winner = i; 
	} 
	
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "WON_MAP", g_maps[ Winner ], g_szKind[ Winner ] ); 
	new map[30] 
	format(map, 29, "%s", g_maps[Winner]) 
	gxwriteone()
	set_task(5.0, "changemap_", _, map, 30)  
} 

public changemap_(param[]) 
	server_cmd("changelevel %s", param) 

public handlerdddd( client, menu, item ) { 
	if( item == MENU_EXIT )
		return PLUGIN_HANDLED
	if( Voted[ client ] == true ) 
	{ 
		ChangeMaps( client); 
		return PLUGIN_HANDLED 
	} 
	
	new szName[ 32 ]; 
	get_user_name( client, szName, 31 );  
	
	ClientPrintColor( 0, "%s %L", PREFIX, LANG_PLAYER, "MAP_X_VOTE", szName, g_maps[ item ] ) 
	g_szKind[ item ]++; 
	
	Voted[ client ] = true; 
	ChangeMaps(client); 
	return PLUGIN_HANDLED
	
} 

public countdown2() 
{ 
	if(Timer <= 0) 
		remove_task(2000) 
	else 
	{ 
		Timer-- 
		set_task(1.0,"countdown2"); 
		for( new i = 1; i <= get_maxplayers(); i++ ) 
			if(is_user_connected( i ) ) 
			ChangeMaps(i) 
	} 
} 
public checkTimeleft( ) {
	get_pcvar_string( g_pointerHostname, g_szHostname, 63 );
	
	if( get_pcvar_num( g_cvarEnabled ) != 1 ) {
		g_timerRunning = false;
		
		return;
	} else
	register_think( ENTITY_CLASS, "fwdThink_Updater" );
	
	g_timerRunning = true;
	new iEntityTimer = create_entity( "info_target" );
	entity_set_string( iEntityTimer, EV_SZ_classname, ENTITY_CLASS );
	entity_set_float( iEntityTimer, EV_FL_nextthink, get_gametime() + UPDATE_TIME );
}

public fwdThink_Updater( iEntity ) {
	static szHostname[ 64 ]
	if (g_IsStarted)
	{
		
		if (g_bSecondHalf)
			formatex( szHostname, 63, "%s (A %d:%d B)",g_szHostname, g_iScore[0], g_iScore[1])
		else
			formatex( szHostname, 63, "%s (A %d:%d B)",g_szHostname, g_iScore[1], g_iScore[0])
	}
	else
	{
		formatex( szHostname, 63, "%s (NS)",g_szHostname)
	}
	set_pcvar_string( g_pointerHostname, szHostname );
	message_begin( MSG_BROADCAST, g_MsgServerName );
	write_string( szHostname );
	message_end( );
	
	entity_set_float( iEntity, EV_FL_nextthink, get_gametime() + UPDATE_TIME );
	
	return PLUGIN_CONTINUE;
}
ClientPrintColor( id, String[ ], any:... ){
	new szMsg[ 190 ]
	vformat( szMsg, charsmax( szMsg ), String, 3 )
	
	replace_all( szMsg, charsmax( szMsg ), "!n", "^1" )
	replace_all( szMsg, charsmax( szMsg ), "!t", "^3" )
	replace_all( szMsg, charsmax( szMsg ), "!g", "^4" )
	
	static msgSayText = 0
	static fake_user
	
	if( !msgSayText )
	{
		msgSayText = get_user_msgid( "SayText" )
		fake_user = get_maxplayers( ) + 1
	}
	
	message_begin( id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, _, id )
	write_byte( id ? id : fake_user )
	write_string( szMsg )
	message_end( )
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1045\\ f0\\ fs16 \n\\ par }
*/
