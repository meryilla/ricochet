


class CDisc : ScriptBaseEntity
{
	private float m_flDontTouchEnemies;
	private float m_flDontTouchOwner;
	int m_iBounces;
	EHandle m_hOwner;
	CDiscWeapon@ m_pLauncher;
	private int m_iTrail;
	private int m_iSpriteTexture;
	bool m_bDecapitate;
	bool m_bRemoveSelf;
	int m_iPowerupFlags;
	private bool m_bTeleported;
	
	private EHandle m_hLockTarget;
	
	Vector m_vecActualVelocity;
	Vector m_vecSideVelocity;
	Vector m_vecOrg;
	
	void Spawn()
	{
		Precache();
		
		self.pev.movetype = MOVETYPE_BOUNCEMISSILE;
		self.pev.solid = SOLID_TRIGGER;
		
		//Setup Model
		if( (m_iPowerupFlags & POW_HARD) > 0 )
			g_EntityFuncs.SetModel( self, "models/ricochet/disc_hard.mdl" );
		else
			g_EntityFuncs.SetModel( self, "models/ricochet/disc.mdl" );
		
		self.SetOrigin( self.pev.origin );
		g_EntityFuncs.SetSize( self.pev, Vector( -4, -4, -4 ), Vector( 4, 4, 4 ) );
		
		
		SetTouch( TouchFunction( DiscTouch ) );
		SetThink( ThinkFunction( DiscThink ) );
		
		m_iBounces = 0;
		m_flDontTouchOwner = g_Engine.time + 0.2;
		m_flDontTouchEnemies = 0;
		m_bRemoveSelf = false;
		m_bTeleported = false;
		m_hLockTarget = null;
		
		g_EngineFuncs.MakeVectors( self.pev.angles );
		
		//increase speed here if fast powerups
		if( ( m_iPowerupFlags & POW_FAST ) > 0 )
			self.pev.velocity = g_Engine.v_forward * DISC_VELOCITY * 1.5;
		else
			self.pev.velocity = g_Engine.v_forward * DISC_VELOCITY;
		
		// Pull our owner out so we will still touch it
		if( self.pev.owner !is null )
			m_hOwner = EHandle( g_EntityFuncs.Instance( self.pev.owner ) );
			
		//self.pev.owner = null;
		
		trail( self );
		
		//Add decapitation sound here
		if( m_bDecapitate )
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "ricochet/weapons/rocket1.wav", 0.5, 0.5 );
		
		//Highlighter
		self.pev.renderfx = kRenderFxGlowShell;
		self.pev.rendercolor = Vector( 0, 0, 255 );
		self.pev.renderamt = 255;
		
		self.pev.nextthink = g_Engine.time + 0.1f;
	}
	
	void trail( CBaseEntity@ target, string sprite="sprites/smoke.spr", 
		uint8 life=3, uint8 width=5, Color c=BLUE,
		NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null )
	{
		NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
		m.WriteByte(TE_BEAMFOLLOW);
		m.WriteShort(target.entindex());
		m.WriteShort(g_EngineFuncs.ModelIndex(sprite));
		if( m_bDecapitate )
			m.WriteByte(5);
		else
			m.WriteByte(3);
		m.WriteByte(width);
		m.WriteByte(c.r);
		m.WriteByte(c.g);
		m.WriteByte(c.b);
		m.WriteByte(c.a);
		m.End();
	}	
	
	void Precache()
	{
		g_Game.PrecacheModel("models/ricochet/disc.mdl");
		g_Game.PrecacheModel("models/ricochet/disc_hard.mdl");
		g_Game.PrecacheModel("sprites/ricochet/discreturn.spr");
		g_SoundSystem.PrecacheSound("weapons/cbar_hitbod1.wav");
		g_SoundSystem.PrecacheSound("weapons/cbar_hitbod2.wav");
		g_SoundSystem.PrecacheSound("weapons/cbar_hitbod3.wav");
		g_SoundSystem.PrecacheSound("ricochet/weapons/altfire.wav");
		g_SoundSystem.PrecacheSound("ricochet/items/gunpickup2.wav");
		g_SoundSystem.PrecacheSound("weapons/electro5.wav");
		g_SoundSystem.PrecacheSound("ricochet/weapons/xbow_hit1.wav");
		g_SoundSystem.PrecacheSound("ricochet/weapons/xbow_hit2.wav");
		g_SoundSystem.PrecacheSound("ricochet/weapons/rocket1.wav");
		g_SoundSystem.PrecacheSound("ricochet/dischit.wav");
		
		m_iTrail = g_Game.PrecacheModel("sprites/smoke.spr");
		m_iSpriteTexture = g_Game.PrecacheModel( "sprites/lgtning.spr" );
	}
	
	//Give disc back to it's owner
	void ReturnToThrower()
	{
		if( m_bDecapitate )
		{
			g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, "ricochet/weapons/rocket1.wav" );
			if( !m_bRemoveSelf )
				m_hOwner.GetEntity().GiveAmmo( MAX_DISCS, "disc", MAX_DISCS );
		}
		else
		{
			if( !m_bRemoveSelf )
				m_hOwner.GetEntity().GiveAmmo( 1, "disc", MAX_DISCS );
		}
		ShowDiscsSprite( cast<CBasePlayer@>( m_hOwner.GetEntity() ) );
		g_EntityFuncs.Remove( self );
	}
	
	void DiscTouch( CBaseEntity@ pOther )
	{
		if( pOther is null )
			return;
			
		CustomKeyvalues@ kvOther = pOther.GetCustomKeyvalues();
		//Push players backwards
		if( pOther.IsPlayer() )
		{
			if( m_hOwner.GetEntity().entindex() == pOther.entindex() )
			{
				if( m_flDontTouchOwner < g_Engine.time )
				{
					//Play catch sound
					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_WEAPON, "ricochet/items/gunpickup2.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
					ReturnToThrower();
				}
				return;
			}
			else if( kvOther.GetKeyvalue( "$i_spawnProtection" ).GetInteger() == 1 )
				return;
			else if( m_flDontTouchEnemies <= g_Engine.time )
			{
				//TODO: team conditionals here?
				cast<CBasePlayer@>( pOther ).m_LastHitGroup = HITGROUP_GENERIC;
				
				if( ( (m_iPowerupFlags & POW_FREEZE) > 0 ) && kvOther.GetKeyvalue( "$i_frozen" ).GetInteger() == 0 )
				{
					// Freeze the player and make them glow blue
					g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_WEAPON, "weapons/electro5.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
					Freeze( pOther );
					
					// If it's not a decap, return now. If it's a decap, continue to shatter
					if ( !m_bDecapitate )
					{
						m_flDontTouchEnemies = g_Engine.time + 2.0;
						return;
					}					
				}
				if( m_bDecapitate )
				{
					//""Decapitate"". Just gib them here, as player models won't have decap anims
					//TODO: insert teleport shit here
					pOther.Killed( m_hOwner.GetEntity().pev, 2 );
					m_flDontTouchEnemies = g_Engine.time + 0.5;
				}
				switch( Math.RandomLong( 0, 2 ) )
				{
					case 0:
						g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_ITEM, "weapons/cbar_hitbod1.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
						break;
					
					case 1:
						g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_ITEM, "weapons/cbar_hitbod2.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
						break;
						
					case 2:
						g_SoundSystem.EmitSoundDyn( pOther.edict(), CHAN_ITEM, "weapons/cbar_hitbod3.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
						break;
				}
				
				//Push the player
				Vector vecDir = self.pev.velocity.Normalize();
				pOther.pev.flags &= ~FL_ONGROUND;
				cast<CBasePlayer@>( pOther ).pev.velocity = vecDir * DISC_PUSH_MULTIPLIER;
				
				//Shield flash (if not frozen)
				if( kvOther.GetKeyvalue( "$i_frozen" ).GetInteger() == 0 )
				{
					pOther.pev.renderfx = kRenderFxGlowShell;
					pOther.pev.rendercolor.x = 255;
					pOther.pev.renderamt = 150;
				}
				
				g_hLastPlayersToHit[ pOther.entindex() ] = m_hOwner.GetEntity();
				g_flLastDiscHit[ pOther.entindex() ] = g_Engine.time;
				//Add bounces to player, so score detection can be done
				g_iLastDiscBounces[ pOther.entindex() ] = m_iBounces;
				//if ( m_bTeleported )
				//	((CBasePlayer*)pOther)->m_flLastDiscHitTeleport = gpGlobals->time;				
					
				m_flDontTouchEnemies = g_Engine.time + 2.0f;
			}
				
		}
		//Hit a disc?
		else if( pOther.pev.classname == "proj_disc" )
		{
			CDisc@ pOtherDisc = cast<CDisc@>( CastToScriptClass( pOther ) );
			if( pOtherDisc.m_hOwner.GetEntity() != m_hOwner.GetEntity() )
			{
				//Discs destroy each other
				CSprite@ pSprite = g_EntityFuncs.CreateSprite( "sprites/ricochet/discreturn.spr", self.pev.origin, true );
				pSprite.AnimateAndDie( 60.0f );
				pSprite.SetTransparency( kRenderTransAdd, 255, 255, 255, 255, kRenderFxNoDissipation );
				pSprite.SetScale( 1 );
				g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, "ricochet/dischit.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
				
				//Return both discs to their owners
				cast<CDisc@>( CastToScriptClass( pOther ) ).ReturnToThrower();
				ReturnToThrower();
			}
			else
			{
				//Do jack shit
			}
		}
		else
		{
			m_iBounces++;
			
			switch( Math.RandomLong( 0, 1 ) )
			{
				case 0: 
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, "ricochet/weapons/xbow_hit1.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0,3 ) );  
					break;
				case 1: 
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_ITEM, "ricochet/weapons/xbow_hit2.wav", 1.0, ATTN_NORM, 0, 98 + Math.RandomLong( 0,3 ) );  
					break;
			}
			g_Utility.Sparks( self.pev.origin );
		}
	}
	
	void DiscThink()
	{
		// Make Freeze discs home towards any player ahead of them
		if( ( m_iPowerupFlags & POW_FREEZE ) > 0 && ( m_iBounces == 0 ) )
		{
			// Use an existing target if he's still in the view cone
			if( m_hLockTarget.GetEntity() !is null )
			{
				Vector vecDir = ( m_hLockTarget.GetEntity().pev.origin - self.pev.origin).Normalize();
				g_EngineFuncs.MakeVectors( self.pev.angles );
				float flDot = DotProduct( g_Engine.v_forward, vecDir );
				if ( flDot < 0.6 )
					m_hLockTarget = null;
			}
			
			// Get a new target if we don't have one
			if ( m_hLockTarget.GetEntity() is null )
			{
				CBaseEntity@ pOther = null;

				// Examine all entities within a reasonable radius
				while ( ( @pOther = g_EntityFuncs.FindEntityByClassname( pOther, "player" )) !is null )
				{
					// Skip the guy who threw this
					if ( m_hOwner.GetEntity() is pOther )
						continue;
					// Skip observers
					if ( cast<CBasePlayer@>( pOther ).GetObserver().IsObserver() )
						continue;

					// Make sure the enemy's in a cone ahead of us
					Vector vecDir = ( pOther.pev.origin - self.pev.origin ).Normalize();
					g_EngineFuncs.MakeVectors( self.pev.angles );
					float flDot = DotProduct( g_Engine.v_forward, vecDir );
					if ( flDot > 0.6 )
					{
						m_hLockTarget = EHandle( pOther );
						break;
					}
				}
			}

			// Track towards our target
			if ( m_hLockTarget.GetEntity() !is null )
			{
				// Calculate new velocity
				Vector vecDir = ( m_hLockTarget.GetEntity().pev.origin - self.pev.origin).Normalize();
				self.pev.velocity = ( self.pev.velocity.Normalize() + ( vecDir.Normalize() * 0.25 ) ).Normalize();
				self.pev.velocity = self.pev.velocity * DISC_VELOCITY;
				g_EngineFuncs.VecToAngles( self.pev.velocity, self.pev.angles );
			}			
		}
		
		
		// Track the player if we've bounced 3 or more times ( Fast discs remove immediately )
		if ( m_iBounces >= 3 || ( (m_iPowerupFlags & POW_FAST) > 0 && m_iBounces >= 1 ) )
		{
			// Remove myself if my owner's died
			if ( m_bRemoveSelf )
			{
				g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, "ricochet/weapons/rocket1.wav" );
				g_EntityFuncs.Remove( self );
				return;
			}

			// 7 Bounces, just remove myself
			if ( m_iBounces > 7 )
			{
				ReturnToThrower();
				return;
			}

			// Start heading for the player
			if ( m_hOwner.GetEntity() !is null )
			{
				Vector vecDir = ( m_hOwner.GetEntity().pev.origin - pev.origin );
				vecDir = vecDir.Normalize();
				self.pev.velocity = vecDir * DISC_VELOCITY;
				self.pev.nextthink = g_Engine.time + 0.1;
			}
			else
			{
				g_EntityFuncs.Remove( self ); 
			}
		}

		// Sanity check
		if ( self.pev.velocity == g_vecZero )
			ReturnToThrower();

		self.pev.nextthink = g_Engine.time + 0.1;
	}
}

CDisc@ CreateDisc( Vector vecOrigin, Vector vecAngles, CBaseEntity@ pOwner, CDiscWeapon@ pLauncher, bool bDecapitator, int iPowerupFlags )
{	
	CBaseEntity@ pEntityDisc = g_EntityFuncs.CreateEntity( "proj_disc" );
	CDisc@ pDisc = cast<CDisc@>( CastToScriptClass( pEntityDisc ) );	
	
	//g_EntityFuncs.SetOrigin( cast<CBaseEntity@>( pDisc ), vecOrigin );
	pDisc.pev.origin = vecOrigin;
	pDisc.m_iPowerupFlags = iPowerupFlags;
	
	//Hard shots always ""decapitate""
	if( (pDisc.m_iPowerupFlags & POW_HARD) > 0 )
		pDisc.m_bDecapitate = true;
	else
		pDisc.m_bDecapitate = bDecapitator;
	
	pDisc.pev.angles = vecAngles;
	@pDisc.pev.owner = pOwner.edict();
	pDisc.pev.team = pOwner.pev.team;
	pDisc.pev.iuser4 = pOwner.pev.iuser4; //wtf, what does this do?
	
	// Set the group info
	pDisc.pev.groupinfo = pOwner.pev.groupinfo;
	
	@pDisc.m_pLauncher = pLauncher;
	
	pDisc.Spawn();
	
	return pDisc;
}

void PrecacheDisc()
{
	g_Game.PrecacheModel("models/ricochet/disc.mdl");
	g_Game.PrecacheModel("models/ricochet/disc_hard.mdl");
	g_Game.PrecacheModel("sprites/ricochet/discreturn.spr");
	g_SoundSystem.PrecacheSound("weapons/cbar_hitbod1.wav");
	g_SoundSystem.PrecacheSound("weapons/cbar_hitbod2.wav");
	g_SoundSystem.PrecacheSound("weapons/cbar_hitbod3.wav");
	g_SoundSystem.PrecacheSound("ricochet/weapons/altfire.wav");
	g_SoundSystem.PrecacheSound("ricochet/items/gunpickup2.wav");
	g_SoundSystem.PrecacheSound("weapons/electro5.wav");
	g_SoundSystem.PrecacheSound("ricochet/weapons/xbow_hit1.wav");
	g_SoundSystem.PrecacheSound("ricochet/weapons/xbow_hit2.wav");
	g_SoundSystem.PrecacheSound("ricochet/weapons/rocket1.wav");
	g_SoundSystem.PrecacheSound("ricochet/dischit.wav");
	
	g_Game.PrecacheModel("sprites/smoke.spr");
	g_Game.PrecacheModel( "sprites/lgtning.spr" );	
}