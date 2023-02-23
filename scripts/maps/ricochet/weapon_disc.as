
enum disc_e 
{
	DISC_IDLE = 0,
	DISC_FIDGET,
	DISC_PINPULL,
	DISC_THROW1,	// toss
	DISC_THROW2,	// medium
	DISC_THROW3,	// hard
	DISC_HOLSTER,
	DISC_DRAW
};

class CDiscWeapon : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}
	
	int m_iFastShotDiscs;
	int m_iSpriteTexture;
	
	void Spawn()
	{
		Precache();
		//self.m_iId = WEAPON_DISC;
		g_EntityFuncs.SetModel( self, "models/ricochet/disc.mdl" );
		
		self.m_iDefaultAmmo = STARTING_DISCS;
		m_iFastShotDiscs = NUM_FASTSHOT_DISCS;
		
		self.FallInit();
	}
	
	void Precache()
	{
		g_Game.PrecacheModel( "models/ricochet/disc.mdl" );
		g_Game.PrecacheModel( "models/ricochet/disc_hard.mdl" );
		g_Game.PrecacheModel( "models/ricochet/v_disc.mdl" );
		g_Game.PrecacheModel( "models/ricochet/p_disc.mdl" );
		g_SoundSystem.PrecacheSound( "ricochet/weapons/cbar_miss1.wav" );
		g_SoundSystem.PrecacheSound( "ricochet/weapons/altfire.wav" );
		
		m_iSpriteTexture = g_Game.PrecacheModel( "sprites/lgtning.spr" );
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MAX_DISCS;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= WEAPON_NOCLIP;
		info.iSlot 		= 2;
		info.iPosition 	= 4;
		info.iFlags 	= ITEM_FLAG_NOAUTORELOAD | ITEM_FLAG_NOAUTOSWITCHEMPTY;
		info.iWeight 	= 100;

		return true;
	} 
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;
			
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( self.m_iId );
		message.End();

		return true;
	}	

	bool Deploy()
	{
		self.m_flNextPrimaryAttack = g_Engine.time + 0.5f;
		return self.DefaultDeploy( "models/ricochet/v_disc.mdl", "models/ricochet/p_disc.mdl", DISC_THROW1, "crowbar" );
	}
	
	bool CanHolster()
	{
		return true;
	}
	
	void Holster( int iSkipLocal )
	{
		m_pPlayer.m_flNextAttack = g_Engine.time + 0.5;
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) >= 0 )
		{
			self.SendWeaponAnim( DISC_HOLSTER, 0 );
		}
		else
		{
			//get rid of this shitty grenade?
			//m_pPlayer.pev.weapons &= ~( 1<<WEAPON_DISC );
			m_pPlayer.pev.weapons &= ~( 1<<self.m_iId );
			SetThink( ThinkFunction( self.DestroyItem ) );
			self.pev.nextthink = g_Engine.time + 0.1f;
		}
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "common/null.wav", 1.0, ATTN_NORM );
	}
	
	CDisc@ FireDisc( bool bDecapitator )
	{
		CDisc@ pReturnDisc = null;
		
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		
		Vector vecFireDir = g_vecZero;
		vecFireDir.y = m_pPlayer.pev.v_angle.y;
		g_EngineFuncs.MakeVectors( vecFireDir );
		Vector vecSrc = m_pPlayer.pev.origin + ( m_pPlayer.pev.view_ofs * 0.25 ) + g_Engine.v_forward * 16;
		
		CustomKeyvalues@ kvPlayer = m_pPlayer.GetCustomKeyvalues();
		CDisc@ pDisc = CreateDisc( vecSrc, vecFireDir, m_pPlayer, this, bDecapitator, kvPlayer.GetKeyvalue( "$i_powerups" ).GetInteger() );
		@pReturnDisc = pDisc;
		
		// Triple Disc
		if( HasPowerup( m_pPlayer, POW_TRIPLE ) )
		{	
			vecFireDir.y = m_pPlayer.pev.v_angle.y - 7;
			g_EngineFuncs.MakeVectors( vecFireDir );
			vecSrc = m_pPlayer.pev.origin + ( m_pPlayer.pev.view_ofs * 0.25 ) + g_Engine.v_forward * 16;
			@pDisc = CreateDisc( vecSrc, vecFireDir, m_pPlayer, this, bDecapitator, POW_TRIPLE );
			pDisc.m_bRemoveSelf = true;

			vecFireDir.y = m_pPlayer.pev.v_angle.y + 7;
			g_EngineFuncs.MakeVectors( vecFireDir );
			vecSrc = m_pPlayer.pev.origin + ( m_pPlayer.pev.view_ofs * 0.25 ) + g_Engine.v_forward * 16;
			@pDisc = CreateDisc( vecSrc, vecFireDir, m_pPlayer, this, bDecapitator, POW_TRIPLE );
			pDisc.m_bRemoveSelf = true;			
		}
		
		// Fast shot allows faster throwing
		float flTimeToNextShot = 0.5;
		if( HasPowerup( m_pPlayer, POW_FAST ) )
			flTimeToNextShot = 0.2;
	
		self.m_flNextPrimaryAttack = g_Engine.time + flTimeToNextShot;
		self.m_flTimeWeaponIdle = g_Engine.time + flTimeToNextShot;

		return pReturnDisc;
	}	

	void PrimaryAttack()
	{
		if( self.m_flNextPrimaryAttack > g_Engine.time )
			return;	
		//TODO: Insert Arena code here
		
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;
			
		//g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "ricochet/weapons/cbar_miss1.wav", 1.0, ATTN_NORM );
		g_SoundSystem.PlaySound( m_pPlayer.edict(), CHAN_WEAPON, "ricochet/weapons/cbar_miss1.wav", 0.8, ATTN_NORM, 0, 100 );
		
		CDisc@ pDisc = FireDisc( false );
		
		if( HasPowerup( m_pPlayer, POW_FAST ) )
		{
			m_iFastShotDiscs--;
			if( m_iFastShotDiscs > 0 )
			{
				//Make this disc remove itself
				pDisc.m_bRemoveSelf = true;
				return;
			}
			
			m_iFastShotDiscs = NUM_FASTSHOT_DISCS;
		}
		
		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		
		CustomKeyvalues@ kvPlayer = m_pPlayer.GetCustomKeyvalues();
		int iPowerupDiscs = kvPlayer.GetKeyvalue( "$i_powerupDiscs" ).GetInteger();
		if( iPowerupDiscs > 0 )
		{
			g_EntityFuncs.DispatchKeyValue( m_pPlayer.edict(), "$i_powerupDiscs", string( iPowerupDiscs - 1 ) );
			if( kvPlayer.GetKeyvalue( "$i_powerupDiscs" ).GetInteger() == 0 )
				RemoveAllPowerups( m_pPlayer );
		}
		ShowDiscsSprite( m_pPlayer );
	}
	
	void SecondaryAttack()
	{
	
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 2 )
			return;	
		//TODO: Arena code here
		
		// Fast powerup has a number of discs per 1 normal disc (so it can throw a decap when it has at least 1 real disc)
		if ( ( HasPowerup( m_pPlayer, POW_FAST ) && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 ) ||
			 ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == MAX_DISCS ) )
		{
			g_SoundSystem.PlaySound( m_pPlayer.edict(), CHAN_WEAPON, "ricochet/weapons/altfire.wav", 0.8, ATTN_NORM, 0, 100 );

			FireDisc( true );
			CustomKeyvalues@ kvPlayer = m_pPlayer.GetCustomKeyvalues();
			int iPowerupDiscs = kvPlayer.GetKeyvalue( "$i_powerupDiscs" ).GetInteger();
			// Deduct MAX_DISCS from fast shot, or deduct all discs if we don't have fast shot
			if ( HasPowerup( m_pPlayer, POW_FAST ) )
			{
				for ( int i = 1; i <= MAX_DISCS; i++ )
				{
					m_iFastShotDiscs--;
					if ( m_iFastShotDiscs == 0 )
					{
						m_iFastShotDiscs = NUM_FASTSHOT_DISCS;
						m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, self.m_iPrimaryAmmoType - 1 );

						// Remove a powered disc
						g_EntityFuncs.DispatchKeyValue( m_pPlayer.edict(), "$i_powerupDiscs", string( iPowerupDiscs - 1 ) );
						if ( kvPlayer.GetKeyvalue( "$i_powerupDiscs" ).GetInteger() == 0 )
							RemoveAllPowerups( m_pPlayer );
					}
				}
			}
			else
			{
				m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, 0 );

				// If we have powered discs, remove one
				if ( kvPlayer.GetKeyvalue( "$i_powerupDiscs" ).GetInteger() > 0 )
				{
					g_EntityFuncs.DispatchKeyValue( m_pPlayer.edict(), "$i_powerupDiscs", string( iPowerupDiscs - 1 ) );
					if ( kvPlayer.GetKeyvalue( "$i_powerupDiscs" ).GetInteger() == 0 )
						RemoveAllPowerups( m_pPlayer );
				}
			}
		}
		ShowDiscsSprite( m_pPlayer );
	}
	
	void WeaponIdle()
	{
		//TODO: Visualise powerup shit here
		
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;
		
		//Below shit ain't needed
		//if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
		//{
		//	int iAnim;
		//	float flRand = Math.RandomFloat( 0, 1 );
		//	
		//	if( flRand <= 0.75 )
		//	{
		//		iAnim = DISC_IDLE;
		//		self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat( 10, 15 );
		//	}
		//	else
		//	{
		//		iAnim = DISC_FIDGET;
		//		self.m_flTimeWeaponIdle = g_Engine.time + 75.0 / 30.0;
		//	}
		//	
		//	self.SendWeaponAnim( iAnim );
		//}
	}
	
	bool AddDuplicate( CBasePlayerItem@ pItem )
	{
		self.pev.flags |= FL_KILLME;
		return false;
	}
}

void PrecacheDiscWeapon()
{
	g_Game.PrecacheModel( "models/ricochet/disc.mdl" );
	g_Game.PrecacheModel( "models/ricochet/disc_hard.mdl" );
	g_Game.PrecacheModel( "models/ricochet/v_disc.mdl" );
	g_Game.PrecacheModel( "models/ricochet/p_disc.mdl" );
	g_SoundSystem.PrecacheSound( "ricochet/weapons/cbar_miss1.wav" );
	g_SoundSystem.PrecacheSound( "ricochet/weapons/altfire.wav" );
	
	g_Game.PrecacheModel( "sprites/lgtning.spr" );
}

