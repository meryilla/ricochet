/* Ricochet for Sven Co-op
/ All models, animations, textures, sounds, sprites etc etc by Valve
/ Script by Meryilla
/ Much of the content here is based off the ricochet related content in the HL SDK
*/

#include "proj_disc"
#include "weapon_disc"
#include "item_powerup"

const float g_flGravity = g_EngineFuncs.CVarGetFloat( "sv_gravity" );

int g_iPlayersPerTeam  = 0;

const int MAX_DISCS = 3;
const int STARTING_DISCS = MAX_DISCS;
const int NUM_FASTSHOT_DISCS = 3;
const int WEAPON_DISC = 1;

const int DISC_VELOCITY = 1000;
const int DISC_PUSH_MULTIPLIER = 1200;

const int MAX_SCORE_TIME_AFTER_HIT = 4;
const int DISC_POWERUP_RESPAWN_TIME = 10;

const int NUM_POWERUPS = 4;
const int POW_TRIPLE = 1;
const int POW_FAST = 2;
const int POW_HARD = 4;
const int POW_FREEZE = 8;

const int FREEZE_TIME = 7;
const int FREEZE_SPEED = 50;



array<CScheduledFunction@> g_playerForceSpawn;
array<CScheduledFunction@> g_playerShrink;
array<CScheduledFunction@> g_cameraSpin;

array<EHandle> g_hLastPlayersToHit;
array<float> g_flLastDiscHit;
array<int> g_iLastDiscBounces;
array<float> g_flOldZVel; //Stores old Z-axis velocity

//Arena stuff
//array<CDiscArena@> g_pCurrentArena;
array<int> g_iLastGameResult;

const array<string> ScreamSounds = 
{
	"ricochet/scream1.wav",
	"ricochet/scream2.wav",
	"ricochet/scream3.wav"

};

const string g_szDiscSpr = "ricochet/disc1.spr";
const string g_szDiscGreySpr = "ricochet/discgrey.spr";
const string g_szDisc2Spr = "ricochet/disc2.spr";

const string g_szDiscTripleSpr = "ricochet/disctriple.spr";
const string g_szDiscFastSpr = "ricochet/discfast.spr";
const string g_szDiscHardSpr = "ricochet/dischard.spr";
const string g_szDiscFreezeSpr = "ricochet/discfreeze.spr";

array<string> szSpriteType = {
	g_szDiscSpr,
	g_szDiscSpr,
	g_szDiscSpr
};

array<string> szPowerDiscSprite = {
	
	g_szDiscTripleSpr,
	g_szDiscFastSpr,
	g_szDiscHardSpr,
	g_szDiscFreezeSpr

};

void MapInit()
{
	Register();
	Precache();
	
	g_hLastPlayersToHit.resize(0);
	g_hLastPlayersToHit.resize(33);
	
	g_flLastDiscHit.resize(0);
	g_flLastDiscHit.resize(33);
	
	g_playerForceSpawn.resize(0);
	g_playerForceSpawn.resize(33);
	
	g_playerShrink.resize(0);
	g_playerShrink.resize(33);
	
	g_cameraSpin.resize(0);
	g_cameraSpin.resize(33);
	
	g_iLastDiscBounces.resize(0);
	g_iLastDiscBounces.resize(33);
	
	//g_pCurrentArena.resize(0);
	//g_pCurrentArena.resize(33);
	
	g_iLastGameResult.resize(0);
	g_iLastGameResult.resize(33);
	
	g_flOldZVel.resize(0);
	g_flOldZVel.resize(33);
}

void Precache()
{
	g_SoundSystem.PrecacheSound( "ricochet/triggerjump.wav" );
	g_SoundSystem.PrecacheSound( "ricochet/r_tele1.wav" );
	g_SoundSystem.PrecacheSound( ScreamSounds[0] );
	g_SoundSystem.PrecacheSound( ScreamSounds[1] );
	g_SoundSystem.PrecacheSound( ScreamSounds[2] );
	
	g_Game.PrecacheModel( "sprites/" + g_szDiscSpr );
	g_Game.PrecacheModel( "sprites/" + g_szDisc2Spr );
	g_Game.PrecacheModel( "sprites/" + g_szDiscGreySpr );
	
	g_Game.PrecacheModel( "sprites/" + g_szDiscTripleSpr );
	g_Game.PrecacheModel( "sprites/" + g_szDiscFastSpr );
	g_Game.PrecacheModel( "sprites/" + g_szDiscHardSpr );
	g_Game.PrecacheModel( "sprites/" + g_szDiscFreezeSpr );
	
	PrecacheDisc();
	PrecacheDiscWeapon();
}

void Register()
{
	g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, PlayerSpawn );
	g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, PlayerKilled );
	g_Hooks.RegisterHook( Hooks::Player::PlayerPreThink, PlayerPreThink );
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, PlayerDisconnected );
	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, ClientPutInServer );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerJump", "trigger_jump" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerFall", "trigger_fall" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CTriggerDiscReturn", "trigger_discreturn" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CDiscPowerup", "item_powerup" );

	g_CustomEntityFuncs.RegisterCustomEntity( "CDisc", "proj_disc" );
	
	g_CustomEntityFuncs.RegisterCustomEntity( "CDiscWeapon", "weapon_disc" );
	g_ItemRegistry.RegisterWeapon( "weapon_disc", "ricochet", "disc" );
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	if( pPlayer is null )
		return HOOK_CONTINUE;
		
	//g_iLastGameResult[ pPlayer.entindex() ] = GAME_DIDNTPLAY;
	//
	//if( InArenaMode() )
	//	AddClientToArena( pPlayer );
	return HOOK_CONTINUE;
}

HookReturnCode PlayerPreThink( CBasePlayer@ pPlayer, uint& out uiFlags )
{
	if( pPlayer is null )
		return HOOK_CONTINUE;
		
	CustomKeyvalues@ kvPlayer = pPlayer.GetCustomKeyvalues();
	int iFrozen = kvPlayer.GetKeyvalue( "$i_frozen" ).GetInteger();
	int iSpawnProtection = kvPlayer.GetKeyvalue( "$i_spawnProtection" ).GetInteger();
	float fSpawnProtectionTime = kvPlayer.GetKeyvalue( "$f_spawnProtectionTime" ).GetFloat();
	
	//Reset players Z-axis velocity if they try to jump and they haven't just touched a trigger_jump
	if( ( pPlayer.m_afButtonPressed & IN_JUMP ) > 0 && kvPlayer.GetKeyvalue( "$f_lastTriggerJumpTime" ).GetFloat() < g_Engine.time )
	{
		pPlayer.pev.velocity.z = g_flOldZVel[ pPlayer.entindex() ];
	}
	g_flOldZVel[ pPlayer.entindex() ] = pPlayer.pev.velocity.z;
	
	if( pPlayer.m_afButtonPressed == IN_DUCK )
	{
		NetworkMessage m(MSG_ONE, NetworkMessages::NetworkMessageType(9), pPlayer.edict());
			m.WriteString(";-duck;");
		m.End();
	}
	
	if( iSpawnProtection == 1 && fSpawnProtectionTime < g_Engine.time )
		g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_spawnProtection", "0" );
		
	if( pPlayer.pev.renderamt > 0 )
	{
		//Fade the renderfx away
		if( iFrozen == 0 && iSpawnProtection == 0 )
			pPlayer.pev.renderamt -= 25;
			
		if ( pPlayer.pev.renderamt <= 0 || ( kvPlayer.GetKeyvalue( "$f_freezeTime" ).GetFloat() < g_Engine.time && ( iFrozen == 1 ) ) )
			ClearFreezeAndRender( pPlayer );
	}	
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{

	// Tell all this player's discs to remove themselves after the 3rd bounce
	CBaseEntity@ pFind;
	while ( ( @pFind = g_EntityFuncs.FindEntityByClassname( pFind, "proj_disc" ) ) !is null )
	{
		CDisc@ pDisc = cast<CDisc@>( CastToScriptClass( pFind ) );

		if ( pDisc !is null )
		{
			if ( pDisc.m_hOwner.GetEntity() == ( cast<CBaseEntity@>( pPlayer ) ) )
				pDisc.m_bRemoveSelf = true;
		}
	}	
	
	//Tell the arena that this player's died
	//if( g_pCurrentArena[ pPlayer.entindex() ] !is null )
	//	g_pCurrentArena[ pPlayer.entindex() ].PlayerKilled( pPlayer );
	return HOOK_CONTINUE;
}

HookReturnCode PlayerSpawn( CBasePlayer@ pPlayer )
{
	if( pPlayer is null )
		return HOOK_CONTINUE;
		
	g_Scheduler.RemoveTimer( g_playerForceSpawn[ pPlayer.entindex() ] );
	g_Scheduler.RemoveTimer( g_playerShrink[ pPlayer.entindex() ]);
	g_Scheduler.RemoveTimer( g_cameraSpin[ pPlayer.entindex() ]);		
	
	pPlayer.pev.scale = 1;
	g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_STREAM, "ricochet/r_tele1.wav", 1, ATTN_NORM );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_powerups", "0" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$s_lastPowerup", "" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_frozen", "0" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$f_freezeTime", "0" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_powerupDiscs", "0" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_spawnProtection", "1" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$f_spawnProtectionTime", string( g_Engine.time + 2.0f ) );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$f_lastTriggerJumpTime", string( g_Engine.time ) );
	
	pPlayer.pev.renderfx = kRenderFxGlowShell;
	pPlayer.pev.rendercolor = Vector(255,255,255);
	pPlayer.pev.renderamt = 150;
	
	g_iLastDiscBounces[ pPlayer.entindex() ] = 0;
	
	CBaseEntity@ pEntity = g_EntityFuncs.FindEntityByTargetname( pEntity, "camera_PID_" + pPlayer.entindex() );
	if( pEntity !is null )
	{
		g_EntityFuncs.Remove( pEntity );
		//Run stopsound for client, to fix the annoying camera/vc bug
		NetworkMessage m(MSG_ONE, NetworkMessages::NetworkMessageType(9), pPlayer.edict());
			m.WriteString(";stopsound;");
		m.End();
	}
	ShowDiscsSprite( pPlayer );
	return HOOK_CONTINUE;
	
}

HookReturnCode PlayerDisconnected( CBasePlayer@ pPlayer )
{
	g_Scheduler.RemoveTimer( g_playerForceSpawn[ pPlayer.entindex() ] );
	g_Scheduler.RemoveTimer( g_playerShrink[ pPlayer.entindex() ]);
	g_Scheduler.RemoveTimer( g_cameraSpin[ pPlayer.entindex() ]);
	
	return HOOK_CONTINUE;
}

void RemoveGlow( EHandle hPlayer )
{
	if( !hPlayer )
		return;
		
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
		
	pPlayer.pev.renderfx = kRenderFxNone;
}

void Freeze( EHandle hPlayer )
{
	if( !hPlayer )
		return;
		
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	
	//Glow blue
	pPlayer.pev.renderfx = kRenderFxGlowShell;
	pPlayer.pev.rendercolor.z = 200;
	pPlayer.pev.renderamt = 25;
	
	pPlayer.SetMaxSpeed( FREEZE_SPEED );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_frozen", "1" );
	
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$f_freezeTime", string( g_Engine.time + FREEZE_TIME ) );
}

void ClearFreezeAndRender( EHandle hPlayer )
{
	if( !hPlayer )
		return;
		
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	
	pPlayer.pev.renderfx = kRenderFxNone;
	pPlayer.pev.rendercolor = g_vecZero;
	pPlayer.pev.renderamt = 0;

	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_frozen", "0" );

	//What's the deal with this observer condition?
	//if ( pPlayer.GetObserver().IsObserver() )
	//	pPlayer.SetMaxSpeed( 1 );
	//else
	//	pPlayer.SetMaxSpeed( 270 );
	pPlayer.SetMaxSpeed( 270 );
}

//Waaaaaaay too laggy if it runs every frame!
void ShowDiscsSprite( EHandle hPlayer )
{
	if( !hPlayer )
		return;
		
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
		
	CustomKeyvalues@ kvPlayer = pPlayer.GetCustomKeyvalues();
	
	int iPowerup = kvPlayer.GetKeyvalue( "$s_lastPowerup" ).GetInteger();
	
	//Allow us to do a left-shift for ease
	if( iPowerup == 8 )
		iPowerup = 6;
	
	int iCurrentAmmo = pPlayer.m_rgAmmo( g_PlayerFuncs.GetAmmoIndex( "disc" ) );	
	
	RGBA RGBA_DISC = RGBA( 255, 255, 255, 255 );

	if( iPowerup != 0 )
	{
		switch( iCurrentAmmo )
		{
			case 0:
				szSpriteType[0] = g_szDiscGreySpr;
				szSpriteType[1] = g_szDiscGreySpr;
				szSpriteType[2] = g_szDiscGreySpr;
				break;
			
			case 1:
				szSpriteType[0] = szPowerDiscSprite[ (iPowerup >> 1) ];
				szSpriteType[1] = g_szDiscGreySpr;
				szSpriteType[2] = g_szDiscGreySpr;
				break;
				
			case 2:
				szSpriteType[0] = szPowerDiscSprite[ (iPowerup >> 1) ];
				szSpriteType[1] = szPowerDiscSprite[ (iPowerup >> 1) ];
				szSpriteType[2] = g_szDiscGreySpr;
				break;
				
			case 3:
				szSpriteType[0] = szPowerDiscSprite[ (iPowerup >> 1) ];
				szSpriteType[1] = szPowerDiscSprite[ (iPowerup >> 1) ];
				szSpriteType[2] = szPowerDiscSprite[ (iPowerup >> 1) ];
				break;
		}	
	}
	else
	{
		switch( iCurrentAmmo )
		{
			case 0:
				szSpriteType[0] = g_szDiscGreySpr;
				szSpriteType[1] = g_szDiscGreySpr;
				szSpriteType[2] = g_szDiscGreySpr;
				break;
			
			case 1:
				szSpriteType[0] = g_szDiscSpr;
				szSpriteType[1] = g_szDiscGreySpr;
				szSpriteType[2] = g_szDiscGreySpr;
				break;
				
			case 2:
				szSpriteType[0] = g_szDiscSpr;
				szSpriteType[1] = g_szDiscSpr;
				szSpriteType[2] = g_szDiscGreySpr;
				break;
				
			case 3:
				szSpriteType[0] = g_szDisc2Spr;
				szSpriteType[1] = g_szDisc2Spr;
				szSpriteType[2] = g_szDisc2Spr;
				break;
		}		
	}

	HUDSpriteParams DiscDisplayParams1;
	DiscDisplayParams1.channel = 0;
	DiscDisplayParams1.flags = HUD_ELEM_EFFECT_ONCE;
	DiscDisplayParams1.x = 0.38;
	DiscDisplayParams1.y = 0.9;
	DiscDisplayParams1.spritename = szSpriteType[0];
	DiscDisplayParams1.left = 0; 
	DiscDisplayParams1.top = 255; 
	DiscDisplayParams1.width = 0; 
	DiscDisplayParams1.height = 0;
	DiscDisplayParams1.color1 = RGBA_DISC;
	DiscDisplayParams1.color2 = RGBA_DISC;
	DiscDisplayParams1.fxTime = 0.5;
	DiscDisplayParams1.effect = HUD_EFFECT_RAMP_DOWN;
	
	HUDSpriteParams DiscDisplayParams2;
	DiscDisplayParams2.channel = 1;
	DiscDisplayParams2.flags =  HUD_ELEM_EFFECT_ONCE;
	DiscDisplayParams2.x = 0.48;
	DiscDisplayParams2.y = 0.9;
	DiscDisplayParams2.spritename = szSpriteType[1];
	DiscDisplayParams2.left = 0; 
	DiscDisplayParams2.top = 255; 
	DiscDisplayParams2.width = 0; 
	DiscDisplayParams2.height = 0;
	DiscDisplayParams2.color1 = RGBA_DISC;
	DiscDisplayParams2.color2 = RGBA_DISC;
	DiscDisplayParams2.fxTime = 0.5;
	DiscDisplayParams2.effect = HUD_EFFECT_RAMP_DOWN;

	HUDSpriteParams DiscDisplayParams3;
	DiscDisplayParams3.channel = 2;
	DiscDisplayParams3.flags =  HUD_ELEM_EFFECT_ONCE;
	DiscDisplayParams3.x = 0.58;
	DiscDisplayParams3.y = 0.9;
	DiscDisplayParams3.spritename = szSpriteType[2];
	DiscDisplayParams3.left = 0; 
	DiscDisplayParams3.top = 255; 
	DiscDisplayParams3.width = 0; 
	DiscDisplayParams3.height = 0;
	DiscDisplayParams3.color1 = RGBA_DISC;
	DiscDisplayParams3.color2 = RGBA_DISC;
	DiscDisplayParams3.fxTime = 0.5;
	DiscDisplayParams3.effect = HUD_EFFECT_RAMP_DOWN;
	
	DiscHudText( pPlayer );
	
	
	g_PlayerFuncs.HudCustomSprite( pPlayer, DiscDisplayParams1 );
	g_PlayerFuncs.HudCustomSprite( pPlayer, DiscDisplayParams2 );
	g_PlayerFuncs.HudCustomSprite( pPlayer, DiscDisplayParams3 );
	
}

void DiscHudText( EHandle hPlayer )
{
	if( !hPlayer )
		return;
		
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	CustomKeyvalues@ kvPlayer = pPlayer.GetCustomKeyvalues();
	string szHudText = "";
	int iPowerup = ( kvPlayer.GetKeyvalue( "$i_powerups" ).GetInteger() );
	
	if( ( iPowerup & POW_TRIPLE ) > 0 )
		szHudText = szHudText + "Triple Shot ";
	if( ( iPowerup & POW_FAST ) > 0 )
		szHudText = szHudText + "Fast Shot ";
	if( ( iPowerup & POW_HARD ) > 0 )
		szHudText = szHudText + "Power Shot ";
	if( ( iPowerup & POW_FREEZE ) > 0 )
		szHudText = szHudText + "Freeze Shot";
	
	HUDTextParams DiscTextParams;

	DiscTextParams.r1 = 255;
	DiscTextParams.g1 = 255;
	DiscTextParams.b1 = 255;
	DiscTextParams.a1 = 255;
	DiscTextParams.x = -1;
	DiscTextParams.y = 0.94;
	DiscTextParams.effect = 0;
	DiscTextParams.fxTime = 0.5;
	DiscTextParams.holdTime = 999;
	DiscTextParams.fadeinTime = 0;
	DiscTextParams.fadeoutTime = 0.5;
	DiscTextParams.channel = 4;

	g_PlayerFuncs.HudMessage( pPlayer, DiscTextParams, szHudText );
}


class CTriggerJump: ScriptBaseEntity
{
	private float m_flNextTouchTime;
	private float m_flHeight = 150.0f;
	
	void Spawn()
	{
		self.pev.movetype   = MOVETYPE_NONE;
		self.pev.solid      = SOLID_TRIGGER;
		self.pev.effects    |= EF_NODRAW;
		
		self.pev.mins = self.pev.absmin - self.GetOrigin();
		self.pev.maxs = self.pev.absmax - self.GetOrigin();
		
		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		
		g_EntityFuncs.SetOrigin( self, pev.origin );

		BaseClass.Spawn();
		
		m_flNextTouchTime = g_Engine.time + 0.1f;
	}
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "height" )
			m_flHeight = atof( szValue );
		else
			return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}
	
	void Touch( CBaseEntity@ pOther )
	{

		if( m_flNextTouchTime > g_Engine.time )
			return;	
		
		if( pOther is null || !pOther.IsPlayer() )
			return;
		
		CBaseEntity@ pTarget = g_EntityFuncs.FindEntityByTargetname( pTarget, string( self.pev.target ) );
		if( pTarget is null )
			return;

		Vector vecApex, vecPlayerVel;

		vecApex = pOther.pev.origin + ( pTarget.pev.origin - pOther.pev.origin )*0.5;
		vecApex.z += m_flHeight;
		
		//How high
		float flDistance1 = vecApex.z - pOther.pev.origin.z;
		float flDistance2 = vecApex.z - pTarget.pev.origin.z;
		
		//How long
		float flTime1 = sqrt( abs( flDistance1 )/ ( 0.5* g_flGravity ) );
		float flTime2 = sqrt( abs( flDistance2 )/ ( 0.5* g_flGravity ) );
		
		if( flTime1 < 0.1 )
			return;
		
		//How fast
		vecPlayerVel = ( pTarget.pev.origin - pOther.pev.origin ) / ( flTime1 + flTime2 );
		vecPlayerVel.z = g_flGravity * flTime1;
		
		pOther.pev.velocity = vecPlayerVel;
		
		g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_STREAM, "ricochet/triggerjump.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		g_EntityFuncs.DispatchKeyValue( pOther.edict(), "$f_lastTriggerJumpTime", string( g_Engine.time + 0.5f ) );
		m_flNextTouchTime = g_Engine.time + 0.1f;
	}
}

class CTriggerFall: ScriptBaseEntity
{
	
	void Spawn()
	{
		self.pev.movetype   = MOVETYPE_NONE;
		self.pev.solid      = SOLID_TRIGGER;
		self.pev.effects    |= EF_NODRAW;
		
		self.pev.mins = self.pev.absmin - self.GetOrigin();
		self.pev.maxs = self.pev.absmax - self.GetOrigin();
		
		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		
		g_EntityFuncs.SetOrigin( self, pev.origin );

		BaseClass.Spawn();
	}
	
	void Touch( CBaseEntity@ pOther )
	{
		if( pOther is null || !pOther.IsPlayer() )
			return;
			
		if( !pOther.IsAlive() )
			return;
		
		int iEntityIndex = pOther.entindex();
		CBaseEntity@ pKiller;
		if( ( g_flLastDiscHit[ iEntityIndex ] != 0 ) && ( g_Engine.time < g_flLastDiscHit[ iEntityIndex ] + MAX_SCORE_TIME_AFTER_HIT ) )
		{
			@pKiller = g_hLastPlayersToHit[ iEntityIndex ].GetEntity();
			
			int iLastDiscBounces = g_iLastDiscBounces[ iEntityIndex ];
			if( iLastDiscBounces > 0 )
			{
				pKiller.pev.frags += iLastDiscBounces;
				
				switch( iLastDiscBounces )
				{
					case 1:
						g_PlayerFuncs.ClientPrint( cast<CBasePlayer@>( pKiller ), HUD_PRINTCENTER, "Ricochet Kill! +1 Point\n" );
						break;
					case 2:
						g_PlayerFuncs.ClientPrint( cast<CBasePlayer@>( pKiller ), HUD_PRINTCENTER, "DOUBLE Ricochet Kill! +2 Points\n" );
						break;
					case 3:
						g_PlayerFuncs.ClientPrint( cast<CBasePlayer@>( pKiller ), HUD_PRINTCENTER, "TRIPLE Ricochet Kill! +3 Points\n" );
						break;
				}
			}
		}
		else
		{
			@pKiller = self;
		}
		
		pOther.Killed( pKiller.pev, 0 );
		pOther.pev.frame = 0;
		pOther.pev.sequence = 15;
		cast<CBasePlayer@>( pOther ).ResetSequenceInfo();
		g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STREAM, ScreamSounds[Math.RandomLong(0, 2)], VOL_NORM, ATTN_NORM, 0, 98 + Math.RandomLong( 0,3 ) );
		
		
		dictionary cameraValues = 
		{
			{ "origin", "" + pOther.pev.origin.ToString() },
			{ "wait", "5" },
			{ "angles", Vector( 90, 0, 0 ).ToString() },
			{ "spawnflags", "16" },
			{ "targetname", "camera_PID_" + iEntityIndex }
		};
		
		CBaseEntity@ pCamera = g_EntityFuncs.CreateEntity( "trigger_camera", cameraValues );
		pCamera.Use( pOther, pOther, USE_ON, 0 );
		
		//Run stopsound for client, to fix the annoying camera/vc bug
		NetworkMessage m(MSG_ONE, NetworkMessages::NetworkMessageType(9), pOther.edict());
			m.WriteString(";stopsound;");
		m.End();
		
		@g_playerForceSpawn[ iEntityIndex ] = g_Scheduler.SetTimeout( "ForceSpawn", 4 , EHandle( pOther ) );
		@g_playerShrink[ iEntityIndex ] = g_Scheduler.SetInterval( "ShrinkModel", 0.05, 25, EHandle( pOther ) );
		@g_cameraSpin[ iEntityIndex ] = g_Scheduler.SetInterval( "SpinCamera", 0.01, 500, EHandle( pCamera ) );
		
		pOther.pev.velocity.x = 0;
		pOther.pev.velocity.y = 0;
	}
}

void ForceSpawn( EHandle hPlayer )
{
	if( !hPlayer )
		return;
		
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	g_PlayerFuncs.RespawnPlayer( pPlayer, true, true );
	
}

//Shrink the player's model, to give the impression he is falling further than he actually is
void ShrinkModel( EHandle hPlayer )
{
	if( !hPlayer )
		return;

	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	if( pPlayer.pev.scale > 0.04 )
		pPlayer.pev.scale -= 0.04;
}

void SpinCamera( EHandle hCamera )
{
	if( !hCamera )
		return;
		
	CBaseEntity@ pCamera = cast<CBaseEntity@>( hCamera.GetEntity() );
	pCamera.pev.angles.y -= 2;
}

class CTriggerDiscReturn: ScriptBaseEntity
{
	
	void Spawn()
	{
		Precache();
		
		self.pev.movetype   = MOVETYPE_NONE;
		self.pev.solid      = SOLID_TRIGGER;
		self.pev.effects    |= EF_NODRAW;
		
		self.pev.mins = self.pev.absmin - self.GetOrigin();
		self.pev.maxs = self.pev.absmax - self.GetOrigin();
		
		g_EntityFuncs.SetModel( self, self.pev.model );
		g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
		
		g_EntityFuncs.SetOrigin( self, pev.origin );

		BaseClass.Spawn();		
		SetTouch( TouchFunction( DiscReturnTouch ) );
	}
	
	void Precache()
	{
		g_Game.PrecacheModel("sprites/ricochet/discreturn.spr");
		g_SoundSystem.PrecacheSound("ricochet/discreturn.wav");
	}
	
	void DiscReturnTouch( CBaseEntity@ pOther )
	{
		if( pOther.pev.classname != "proj_disc" )
			return;
			
		CSprite@ pSprite = g_EntityFuncs.CreateSprite( "sprites/ricochet/discreturn.spr", pOther.pev.origin, true );
		pSprite.AnimateAndDie( 60 );
		pSprite.SetTransparency( kRenderTransAdd, 255, 255, 255, 255, kRenderFxNoDissipation );
		pSprite.SetScale( 1 );
		pSprite.pev.groupinfo = pOther.pev.groupinfo;

		g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_AUTO, "ricochet/discreturn.wav", 0.2, ATTN_NORM, 0, 98 + Math.RandomLong( 0,3 ) );

		// Return
		cast<CDisc@>( CastToScriptClass( pOther ) ).ReturnToThrower();		
	}
}

// Colour shit

class Color
{ 
	uint8 r, g, b, a;
	
	Color() { r = g = b = a = 0; }
	Color(uint8 _r, uint8 _g, uint8 _b, uint8 _a = 255 ) { r = _r; g = _g; b = _b; a = _a; }
	Color (Vector v) { r = int(v.x); g = int(v.y); b = int(v.z); a = 255; }
	string ToString() { return "" + r + " " + g + " " + b + " " + a; }
}

const Color RED(255,0,0);
const Color GREEN(0,255,0);
const Color BLUE(0,0,255);