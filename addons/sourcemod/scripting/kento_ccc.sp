#include <sourcemod>
#include <sdktools>
#include <kento_csgocolors>

#pragma newdecls required

#define MAX_CVAR_COUNT 1000

int CvarCount;
int i_warn;
int g_iCvarPunishment[MAX_CVAR_COUNT];
int g_iCvarBanTime[MAX_CVAR_COUNT];
int g_iCvarMode[MAX_CVAR_COUNT];
int i_playerwarn[MAXPLAYERS + 1];

float f_checktimer;

Handle h_CheckTimer;
Handle kv;

char Configfile[PLATFORM_MAX_PATH];
char g_sCvarName[MAX_CVAR_COUNT][PLATFORM_MAX_PATH + 1];
char g_sCvarImmunity[MAX_CVAR_COUNT][PLATFORM_MAX_PATH + 1];
char g_sCvarValue[MAX_CVAR_COUNT][PLATFORM_MAX_PATH + 1];

ConVar Cvar_Timer, Cvar_Warn;

public Plugin myinfo =
{
	name = "[CS:GO] Client Convar Checker",
	author = "Kento",
	version = "1.2.2",
	description = "Check Client Convar",
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart()
{
	Cvar_Timer = CreateConVar("sm_ccc_timer",  "10.0", "Check cvar timer, FLOAT ONLY", _, true, 0.0);
	Cvar_Warn = CreateConVar("sm_ccc_warn",  "3", "Warn player x times before punishment?", _, true, 0.0);
	
	Cvar_Timer.AddChangeHook(OnCvarChange);
	Cvar_Warn.AddChangeHook(OnCvarChange);
	
	RegAdminCmd("sm_ccc_test", Command_Test, ADMFLAG_ROOT, "Test ccc plugin.");
	RegAdminCmd("sm_ccc_reload", Command_Reload, ADMFLAG_ROOT, "Reload ccc settings.");
	
	AutoExecConfig(true, "kento_ccc");
	
	LoadTranslations("kento.ccc.phrases.txt");
}

public void OnConfigsExecuted()
{
	f_checktimer = Cvar_Timer.FloatValue;
	i_warn = Cvar_Warn.IntValue;
	LoadConfig();
}

public void OnMapStart()
{
	h_CheckTimer = CreateTimer(f_checktimer, Timer_CheckCvar, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void LoadConfig()
{
	BuildPath(Path_SM, Configfile, sizeof(Configfile), "configs/kento_ccc.cfg");
	
	kv = CreateKeyValues("cvar");
	FileToKeyValues(kv, Configfile);
	
	CvarCount = 0;
	
	// Read Config
	if(KvGotoFirstSubKey(kv))
	{
		char cvarname[256], value[32], immunity[32];
		int punishment, bantime, mode;
		
		do
		{
			// Get kv
			CvarCount++;
			
			KvGetSectionName(kv, cvarname, sizeof(cvarname));
			KvGetString(kv, "immunity", immunity, sizeof(immunity));
			KvGetString(kv, "value", value, sizeof(value));
			
			mode = KvGetNum(kv, "mode");
			bantime = KvGetNum(kv, "bantime");
			punishment = KvGetNum(kv, "punishment");
			
			strcopy(g_sCvarName[CvarCount], sizeof(g_sCvarName[]), cvarname);
			strcopy(g_sCvarImmunity[CvarCount], sizeof(g_sCvarImmunity[]), immunity);
			g_iCvarMode[CvarCount] = mode;
			strcopy(g_sCvarValue[CvarCount], sizeof(g_sCvarValue[]), value);
			g_iCvarPunishment[CvarCount] = punishment;
			g_iCvarBanTime[CvarCount] = bantime;
		}
		while (KvGotoNextKey(kv));
	}
	
	KvRewind(kv);
	CloseHandle(kv);
	
	// reset warn
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && !IsFakeClient(i))
		{
			i_playerwarn[i] = 0;
		}
	}
}

public Action Timer_CheckCvar(Handle timer)
{
	// Loop all client
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidClient(i) && !IsFakeClient(i))
		{
			QueryClientConVar2(i);
		}
	}
}

void QueryClientConVar2(int client)
{
	// Loop all cvar in cfg
	for (int j = 1; j <= CvarCount; j++) 
	{
		QueryClientConVar(client, g_sCvarName[j], CheckCvar);
	}
}

public void CheckCvar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	// Get cvar number
	int cvar_id;
	for(int k = 1; k <= CvarCount; k++) 
	{
		if(StrEqual(cvarName, g_sCvarName[k])) 
		{
			cvar_id = CvarCount;
			break;
		}
	}
	
	char clientname [PLATFORM_MAX_PATH];
	GetClientName(client, clientname, sizeof(clientname));
							
	// query okay
	if (result == ConVarQuery_Okay)
	{	
		if(HasImmunity(client, cvar_id))
			return;
		
		/* warn client should work like dis
		cvar	warnclient	diff	warnchat
		3 		1			2		2		<- warn 1
		3		2			1		1		<- warn 2
		3		3			0		0		<- warn 3
		3		4			-1		-1		<- kick
		*/
		
		if((g_iCvarMode[cvar_id] == 0 && StrEqual(cvarValue, g_sCvarValue[cvar_id])) 
		|| (g_iCvarMode[cvar_id] == 1 && !StrEqual(cvarValue, g_sCvarValue[cvar_id])))
		{
			char path[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, path, sizeof(path), "logs/kento_ccc.log");
			
			i_playerwarn[client]++;
				
			int diffwarn = i_warn - i_playerwarn[client];
					
			// show warn message to client
			if(diffwarn > 0)
			{
				CPrintToChat(client, "%T", "Warn Client", client, cvarName, cvarValue, diffwarn);
			}
			else if(diffwarn == 0)
			{
				CPrintToChat(client, "%T", "Warn Client 2", client, cvarName, cvarValue, GetConVarFloat(FindConVar("sm_ccc_timer")));
			}
				
			// warn admin
			for (int l = 1; l <= MaxClients; l++) 
			{
				if (IsValidClient(l) && !IsFakeClient(l) && IsAdmin(l))	CPrintToChat(l, "%T", "Warn Admin", l, clientname, cvarName, cvarValue);
			}
						
			// log
			LogToFile(path, "%L %T", client, "Log Warn", LANG_SERVER, cvarName, cvarValue);
				
			// Punishment
			if(i_warn == i_playerwarn[client] -1)
			{
				if(g_iCvarPunishment[cvar_id] == 1) // kick
				{
					// no warn set, kick
					char kickreason[512];
					Format(kickreason, sizeof(kickreason), "%T", "Kick Reason", client, cvarName, cvarValue);	
					
					KickClient(client, kickreason);
					
					LogToFile(path, "%L %T", client, "Log Kick", LANG_SERVER, cvarName, cvarValue);
				}
				
				else if(g_iCvarPunishment[cvar_id] == 2) // ban
				{
					char banreason[512];
					Format(banreason, sizeof(banreason), "%T", "Ban Reason", client, cvarName, cvarValue);
					
					char bankickreason[512];
					Format(bankickreason, sizeof(bankickreason), "%T", "Ban Kick Reason", client, cvarName, cvarValue);	
					
					BanClient(client, g_iCvarBanTime[cvar_id], BANFLAG_AUTO, banreason, bankickreason, "sm_ban");
					
					LogToFile(path, "%L %T", client, "Log Ban", LANG_SERVER, cvarName, cvarValue, g_iCvarBanTime[cvar_id]);
				}
			}
		}
	}
	
	else if (result == ConVarQuery_NotFound)
		LogError("Client convar %s was not found.", cvarName);
		
	else if (result == ConVarQuery_NotValid)
		LogError(" A console command with the same name %s was found, but there is no convar.", cvarName);
	
	else if (result == ConVarQuery_Protected)
		LogError("Client convar %s was found, but it is protected. The server cannot retrieve its value.", cvarName);
}

public void OnClientPutInServer(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		i_playerwarn[client] = 0;
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		i_playerwarn[client] = 0;
	}
}

public Action Command_Test (int client, int args)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		for(int i = 1; i <= CvarCount; i++) 
		{
			PrintToConsole(client, "Cvar name %s, id %d, Punishment %d, Immunity %s, Value %s, Bantime %d, Mode %d",
				g_sCvarName[i],
				i,
				g_iCvarPunishment[i],
				g_sCvarImmunity[i],
				g_sCvarValue[i],
				g_iCvarBanTime[i],
				g_iCvarMode[i]);
		}
	}
	return Plugin_Handled;
}

public Action Command_Reload (int client, int args)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		LoadConfig();
		PrintToChat(client, "client convar checker settings reloaded.");
	}
	return Plugin_Handled;
}

public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if (convar == Cvar_Timer)
	{
		f_checktimer = Cvar_Timer.FloatValue;
		
		// Reset Timer
		if (h_CheckTimer != INVALID_HANDLE)
		{
			KillTimer(h_CheckTimer);
		}
		h_CheckTimer = INVALID_HANDLE;
		
		h_CheckTimer = CreateTimer(f_checktimer, Timer_CheckCvar, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (convar == Cvar_Warn)
	{
		i_warn = Cvar_Warn.IntValue;
		
		// Reset Warn
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (IsValidClient(i) && !IsFakeClient(i))
			{
				i_playerwarn[i] = 0;
			}
		}
	}
}

stock bool IsAdmin(int client)
{
	if(CheckCommandAccess(client, "ccc_admin", ADMFLAG_GENERIC, true))	return true;
	else return false;
}

stock bool HasImmunity(int client, int cvarid)
{
	if(StrEqual(g_sCvarImmunity[CvarCount], ""))	return false;
	else
	{
		if (CheckCommandAccess(client, "ccc_immunity", ReadFlagString(g_sCvarImmunity[CvarCount]), true))	return true;
		else return false;
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}