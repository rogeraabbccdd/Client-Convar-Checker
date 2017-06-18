#include <sourcemod>
#include <sdktools>
#include <kento_csgocolors>

#pragma newdecls required

#define MAX_CVAR_COUNT 1000

int CvarCount;

char Configfile[PLATFORM_MAX_PATH];

Handle kv;

char g_sCvarName[MAX_CVAR_COUNT][PLATFORM_MAX_PATH + 1];
int g_iCvarPunishment[MAX_CVAR_COUNT];
char g_sCvarImmunity[MAX_CVAR_COUNT][PLATFORM_MAX_PATH + 1];
char g_sCvarValue[MAX_CVAR_COUNT][PLATFORM_MAX_PATH + 1];
int g_iCvarBanTime[MAX_CVAR_COUNT];
int g_iCvarMode[MAX_CVAR_COUNT];

public Plugin myinfo =
{
	name = "[CS:GO] Client Convar Checker",
	author = "Kento from Akami Studio",
	version = "1.0",
	description = "Check Client Convar",
	url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart()
{
	CreateConVar("sm_ccc_timer",  "1.0", "Check cvar timer, FLOAT ONLY", _, true, 0.0);
	RegAdminCmd("sm_ccc_test", Command_Test, ADMFLAG_ROOT, "Test ccc plugin.");
	RegAdminCmd("sm_ccc_reload", Command_Reload, ADMFLAG_ROOT, "Reload ccc settings.");
	
	AutoExecConfig(true, "kento_ccc");
	
	LoadTranslations("kento.ccc.phrases.txt");
}

public void OnConfigsExecuted()
{
	LoadConfig();
}

public void OnMapStart()
{
	CreateTimer(GetConVarFloat(FindConVar("sm_ccc_timer")), Timer_CheckCvar, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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
		char cvarname[256];
		char spunishment[32];
		int punishment;
		char value[32];
		char immunity[32];
		char sbantime[32];
		int bantime;
		char smode[32];
		int mode;
		
		do
		{
			// Get kv
			CvarCount++;
			
			KvGetSectionName(kv, cvarname, sizeof(cvarname));
			KvGetString(kv, "immunity", immunity, sizeof(immunity));
			KvGetString(kv, "mode", smode, sizeof(smode));
			KvGetString(kv, "value", value, sizeof(value));
			KvGetString(kv, "punishment", spunishment, sizeof(spunishment));
			KvGetString(kv, "bantime", sbantime, sizeof(sbantime));
			
			mode = StringToInt(smode);
			bantime = StringToInt(sbantime);
			punishment = StringToInt(spunishment);
			
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
}

public Action Timer_CheckCvar(Handle timer)
{
	// Loop all client
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
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
		
		// not allow value
		if(g_iCvarMode[cvar_id] == 0)
		{
			// client cvar = not allow value
			if(StrEqual(cvarValue, g_sCvarValue[cvar_id]))
			{
				// Punishment
				if(g_iCvarPunishment[cvar_id] == 0) //Warn admin
				{
					// Loop all client
					for (int l = 1; l <= MaxClients; l++) 
					{
						// warn admin
						if(IsAdmin(l))
							CPrintToChat(l, "%T", "Warn Admin", l, clientname, cvarName, cvarValue);
					}
				}
					
				else if(g_iCvarPunishment[cvar_id] == 1) // kick
				{
					char kickreason[512];
					Format(kickreason, sizeof(kickreason), "%T", "Kick Reason", client, cvarName, cvarValue);	
					
					KickClient(client, kickreason);
				}
				
				else if(g_iCvarPunishment[cvar_id] == 2) // ban
				{
					char banreason[512];
					Format(banreason, sizeof(banreason), "%T", "Ban Reason", client, cvarName, cvarValue);
					
					char bankickreason[512];
					Format(bankickreason, sizeof(bankickreason), "%T", "Ban Kick Reason", client, cvarName, cvarValue);	
					
					BanClient(client, g_iCvarBanTime[cvar_id], BANFLAG_AUTO, banreason, bankickreason, "sm_ban");
				}
			}
		}
		
		// only allow value
		else if(g_iCvarMode[cvar_id] == 1)
		{
			// client cvar != value
			if(!StrEqual(cvarValue, g_sCvarValue[cvar_id]))
			{
				// Punishment
				if(g_iCvarPunishment[cvar_id] == 0) //Warn admin
				{
					// Loop all client
					for (int l = 1; l <= MaxClients; l++) 
					{
						// warn admin
						if(IsAdmin(l))
							CPrintToChat(l, "%T", "Warn Admin", l, clientname, cvarName, cvarValue);
					}
				}
					
				else if(g_iCvarPunishment[cvar_id] == 1) // kick
				{
					char kickreason[512];
					Format(kickreason, sizeof(kickreason), "%T", "Kick Reason", client, cvarName, cvarValue);	
					
					KickClient(client, kickreason);
				}
				
				else if(g_iCvarPunishment[cvar_id] == 2) // ban
				{
					char banreason[512];
					Format(banreason, sizeof(banreason), "%T", "Ban Reason", client, cvarName, cvarValue);
					
					char bankickreason[512];
					Format(bankickreason, sizeof(bankickreason), "%T", "Ban Kick Reason", client, cvarName, cvarValue);	
					
					BanClient(client, g_iCvarBanTime[cvar_id], BANFLAG_AUTO, banreason, bankickreason, "sm_ban");
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

public Action Command_Test (int client, int args)
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
	return Plugin_Handled;
}

public Action Command_Reload (int client, int args)
{
	LoadConfig();
	PrintToChat(client, "client convar checker settings reloaded.");
	return Plugin_Handled;
}

stock bool IsAdmin(int client)
{
	if(CheckCommandAccess(client, "ccc_admin", ADMFLAG_GENERIC, true))	return true;
	else return false;
}

stock bool HasImmunity(int client, int cvarid)
{
	if(StrEqual(g_sCvarImmunity[CvarCount], ""))
		return false;
	
	// Check if player is having any access (including skins overrides)
	else
	{
		if (CheckCommandAccess(client, "ccc_immunity", ReadFlagString(g_sCvarImmunity[CvarCount]), true))
		return true;
	
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