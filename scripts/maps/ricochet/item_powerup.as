

array<string> POWERUP_MODELS = 
{
	"models/ricochet/pow_triple.mdl",
	"models/ricochet/pow_fast.mdl",
	"models/ricochet/pow_hard.mdl",
	"models/ricochet/pow_freeze.mdl"
};

class CDiscPowerup : ScriptBaseAnimating
{

	EHandle m_hPlayerIGaveTo;
	int m_iPowerupType;
	
	void Spawn()
	{
		Precache();
		
		//Don't fall down
		self.pev.movetype = MOVETYPE_NONE;
		self.pev.solid = SOLID_TRIGGER;
			
		g_EntityFuncs.SetModel( self, POWERUP_MODELS[0] );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
		g_EntityFuncs.SetSize( self.pev, Vector( -32, -32, -32 ), Vector( 32, 32, 32 ) );
		
		self.pev.effects |= EF_NODRAW;
	}
	
	void Precache()
	{
		for( int i = 0; i < NUM_POWERUPS; i++ )
			g_Game.PrecacheModel( POWERUP_MODELS[i] );
			 
		g_SoundSystem.PrecacheSound( "ricochet/powerup.wav" );
		g_SoundSystem.PrecacheSound( "ricochet/pspawn.wav" );
	}
	
	void Activate()
	{
		//Add arena logic here
		
		//Make the powerup start thinking
		Enable();
	}
	
	void SetObjectCollisionBox()
	{
		self.pev.absmin = self.pev.origin + Vector( -64, -64, 0 );
		self.pev.absmax = self.pev.origin + Vector( 64, 64, 128 );
	}
	
	void PowerupTouch( CBaseEntity@ pOther )
	{
		if( pOther is null || !pOther.IsPlayer() )
			return;
			
		CBasePlayer@ pPlayer = cast<CBasePlayer@>( pOther );
		
		//Give the powerup to the player
		GivePowerup( pPlayer, m_iPowerupType );
		m_hPlayerIGaveTo = EHandle( pPlayer );	
		SetTouch( null );
		self.pev.effects |= EF_NODRAW;
		
		//Chose another powerup soon
		SetThink( ThinkFunction( ChoosePowerupThink ) );
		self.pev.nextthink = g_Engine.time + DISC_POWERUP_RESPAWN_TIME;
		
		g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_STATIC, "ricochet/powerup.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
	
	}
	
	//Disappear and don't appear again until enabled
	void Disable()
	{
		self.pev.effects |= EF_NODRAW;
		self.pev.nextthink = 0;
		SetThink( null );
		SetTouch( null );
	}
	
	void Enable()
	{
		//Pick a powerup
		SetThink( ThinkFunction( ChoosePowerupThink ) );
		self.pev.nextthink = g_Engine.time + ( DISC_POWERUP_RESPAWN_TIME / 2 );
	}
	
	void ChoosePowerupThink()
	{
		int iPowerup = Math.RandomLong( 0, NUM_POWERUPS -1 );
		m_iPowerupType = ( 1 << iPowerup );
		
		g_EntityFuncs.SetModel( self, POWERUP_MODELS[iPowerup] );
		//Set the size again, as changing model sets size back to (0,0,0)
		g_EntityFuncs.SetSize( self.pev, Vector( -64, -64, 0 ), Vector( 64, 64, 128 ) );
		self.pev.effects &= ~EF_NODRAW;
		
		SetTouch( TouchFunction( PowerupTouch ) );
		
		//Start animating
		self.pev.sequence = 0;
		self.pev.frame = 0;
		self.ResetSequenceInfo();
		
		SetThink( ThinkFunction( AnimateThink ) );
		self.pev.nextthink = g_Engine.time + 0.1f;
		
		self.pev.rendermode = kRenderTransAdd;
		self.pev.renderamt = 150;
		
		//Play the powerup appear Sound
		g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_STATIC, "ricochet/pspawn.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
	}
	
	void AnimateThink()
	{
		self.StudioFrameAdvance();
		self.pev.nextthink = g_Engine.time + 0.1f;
	}
	
	void RemovePowerupThink()
	{
		if( m_hPlayerIGaveTo.GetEntity() is null )
			return;
			
		CBasePlayer@ pPlayer = cast<CBasePlayer@>( m_hPlayerIGaveTo.GetEntity() );
		RemovePowerup( pPlayer, m_iPowerupType );
		
		//Pick a powerup later
		SetThink( ThinkFunction( ChoosePowerupThink ) );
		self.pev.nextthink = g_Engine.time + DISC_POWERUP_RESPAWN_TIME;
	}
}


//Player handling for powerups

void GivePowerup( EHandle hPlayer, int iPowerupType )
{
	if( !hPlayer )
		return;
	
	int iCurrentPowerups, iNewPowerups;
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	CustomKeyvalues@ kvPlayer = pPlayer.GetCustomKeyvalues();
	
	//TODO Change p model based on powerup?
	
	//Add new powerup to current list
	iCurrentPowerups = kvPlayer.GetKeyvalue( "$i_powerups" ).GetInteger();
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_powerups", string( iCurrentPowerups |= iPowerupType ) );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$s_lastPowerup", string( iPowerupType ) );
	
	//if ( m_iPowerups & POW_HARD )
	//	strcpy( m_szAnimExtention, "models/p_disc_hard.mdl" );
	//
	//MESSAGE_BEGIN( MSG_ONE, gmsgPowerup, NULL, pev );
	//	WRITE_BYTE( m_iPowerups );
	//MESSAGE_END();
	//
	
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_powerupDiscs", string( MAX_DISCS ) );
	ShowDiscsSprite( pPlayer );
}

void RemovePowerup( EHandle hPlayer, int iPowerupType )
{
	if( !hPlayer )
		return;
	
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	CustomKeyvalues@ kvPlayer = pPlayer.GetCustomKeyvalues();
	
	int iCurrentPowerups = kvPlayer.GetKeyvalue( "$i_powerups" ).GetInteger(); 
	
	//TODO Change p model based on powerup?	
	
	//Add new powerup to current list
	iCurrentPowerups = kvPlayer.GetKeyvalue( "$i_powerups" ).GetInteger();
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_powerups", string( iCurrentPowerups - ( iPowerupType )) );
	int iNewPowerups = kvPlayer.GetKeyvalue( "$i_powerups" ).GetInteger();	
}

//Probably not necessary with the playerspawn hook
void RemoveAllPowerups( EHandle hPlayer )
{
	if( !hPlayer )
		return;
		
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_powerups", "0" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$i_powerupDiscs", "0" );
	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "$s_lastPowerup", "" );
	
	//inform about powerup loss?

}

bool HasPowerup( EHandle hPlayer, int iPowerupType )
{
	if( !hPlayer )
		return false;
	
	int iCurrentPowerups;
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
	CustomKeyvalues@ kvPlayer = pPlayer.GetCustomKeyvalues();
	
	iCurrentPowerups = kvPlayer.GetKeyvalue( "$i_powerups" ).GetInteger();
	
	if( ( iCurrentPowerups & iPowerupType ) > 0 )
		return true;
		
	return false;
}