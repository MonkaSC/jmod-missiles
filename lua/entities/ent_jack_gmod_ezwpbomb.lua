-- Jackarunda 2019
AddCSLuaFile()
ENT.Type="anim"
ENT.Author="Jackarunda"
ENT.Category="JMod - EZ Explosives"
ENT.Information="glhfggwpezpznore"
ENT.PrintName="EZ White Phosphorus Bomb"
ENT.Spawnable=true
ENT.AdminSpawnable=true
---
ENT.JModPreferredCarryAngles=Angle(0,0,0)
---
local STATE_BROKEN,STATE_OFF,STATE_ARMED=-1,0,1
function ENT:SetupDataTables()
	self:NetworkVar("Int",0,"State")
end
---
if(SERVER)then
	function ENT:SpawnFunction(ply,tr)
		local SpawnPos=tr.HitPos+tr.HitNormal*40
		local ent=ents.Create(self.ClassName)
		ent:SetPos(SpawnPos)
		JMod_Owner(ent,ply)
		ent:Spawn()
		ent:Activate()
		--local effectdata=EffectData()
		--effectdata:SetEntity(ent)
		--util.Effect("propspawn",effectdata)
		return ent
	end
	function ENT:Initialize()
		self.Entity:SetModel("models/props_phx/ww2bomb.mdl")
		self.Entity:SetMaterial("models/entities/mat_jack_firebomb")
		self.Entity:PhysicsInit(SOLID_VPHYSICS)
		self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
		self.Entity:SetSolid(SOLID_VPHYSICS)
		self.Entity:DrawShadow(true)
		self.Entity:SetUseType(SIMPLE_USE)
		---
		timer.Simple(.01,function()
			self:GetPhysicsObject():SetMass(100)
			self:GetPhysicsObject():Wake()
			self:GetPhysicsObject():EnableDrag(false)
			self:GetPhysicsObject():SetDamping(0,0)
		end)
		---
		self:SetState(STATE_OFF)
		self.LastUse=0
		self.FreefallTicks=0
	end
	function ENT:PhysicsCollide(data,physobj)
		if not(IsValid(self))then return end
		if(data.DeltaTime>0.2)then
			if(data.Speed>50)then
				self:EmitSound("Canister.ImpactHard")
			end
			local DetSpd=500
			if((data.Speed>DetSpd)and(self:GetState()==STATE_ARMED))then
				self:Detonate()
				return
			end
			if(data.Speed>2000)then
				self:Break()
			end
		end
	end
	function ENT:Break()
		if(self:GetState()==STATE_BROKEN)then return end
		self:SetState(STATE_BROKEN)
		self:EmitSound("snd_jack_turretbreak.wav",70,math.random(80,120))
		for i=1,20 do
			self:DamageSpark()
		end
		SafeRemoveEntityDelayed(self,10)
	end
	function ENT:DamageSpark()
		local effectdata=EffectData()
		effectdata:SetOrigin(self:GetPos()+self:GetUp()*10+VectorRand()*math.random(0,10))
		effectdata:SetNormal(VectorRand())
		effectdata:SetMagnitude(math.Rand(2,4)) --amount and shoot hardness
		effectdata:SetScale(math.Rand(.5,1.5)) --length of strands
		effectdata:SetRadius(math.Rand(2,4)) --thickness of strands
		util.Effect("Sparks",effectdata,true,true)
		self:EmitSound("snd_jack_turretfizzle.wav",70,100)
	end
	function ENT:OnTakeDamage(dmginfo)
		self.Entity:TakePhysicsDamage(dmginfo)
		if(dmginfo:GetDamage()>=100)then
			if(math.random(1,20)==1)then
				self:Break()
			elseif(dmginfo:IsDamageType(DMG_BLAST))then
				JMod_Owner(self,dmginfo:GetAttacker())
				self:Detonate()
			end
		end
	end
	function ENT:Use(activator)
		local State,Time=self:GetState(),CurTime()
		if(State<0)then return end
		
		if(State==STATE_OFF)then
			JMod_Owner(self,activator)
			if(Time-self.LastUse<.2)then
				self:SetState(STATE_ARMED)
				self:EmitSound("snds_jack_gmod/bomb_arm.wav",70,120)
				self.EZdroppableBombArmedTime=CurTime()
				JMod_Hint(activator, "airburst", self)
			else
				activator:PrintMessage(HUD_PRINTCENTER,"double tap E to arm")
			end
			self.LastUse=Time
		elseif(State==STATE_ARMED)then
			JMod_Owner(self,activator)
			if(Time-self.LastUse<.2)then
				self:SetState(STATE_OFF)
				self:EmitSound("snds_jack_gmod/bomb_disarm.wav",70,120)
				self.EZdroppableBombArmedTime=nil
			else
				activator:PrintMessage(HUD_PRINTCENTER,"double tap E to disarm")
			end
			self.LastUse=Time
		end
	end
    local function Inflictor(ent)
        if not (IsValid(ent)) then return game.GetWorld() end
        local Infl = ent:GetDTEntity(0)
        if (IsValid(Infl)) then return Infl end
	    return ent
    end

	function ENT:Detonate()
		if(self.Exploded)then return end
		self.Exploded=true
		local SelfPos,Att=self:GetPos()+Vector(0,0,30),self.Owner or game.GetWorld()
		JMod_Sploom(Att,SelfPos,100)
		---
		util.ScreenShake(SelfPos,1000,3,2,1000)
		---
    	local Vel = self:GetPhysicsObject():GetVelocity()
		local Dir = Vel:GetNormalized()
		---
		local Sploom=EffectData()
		Sploom:SetOrigin(SelfPos)
		Sploom:SetScale(.6)
		Sploom:SetNormal(Dir)
		util.Effect("eff_jack_firebomb",Sploom,true,true)
		---
		for i=1,25 do
      		local Haz = ents.Create("ent_jack_gmod_ezwphazard")
            Haz:SetDTInt(0, 1)
            Haz:SetPos(SelfPos)
            JMod_Owner(Haz, self.Owner)
            Haz:SetDTEntity(0, self:GetDTEntity(0))
            Haz.HighVisuals = self.HighVisuals
            Haz:Spawn()
            Haz:Activate()
      		Haz:GetPhysicsObject():SetVelocity(Vel + VectorRand() * 600)
            Haz:GetPhysicsObject():SetDragCoefficient(10)
      		local trail = util.SpriteTrail(Haz, 0, Color(255, 255, 255), false, 15, 1, 4, 1 / ( 15 + 1 ) * 0.5, "trails/smoke" )
		end
		---
		self:Remove()
	end
	function ENT:OnRemove()
		--
	end
	function ENT:EZdetonateOverride(detonator)
		self:Detonate()
	end
	function ENT:Think()
		local Phys=self:GetPhysicsObject()
		if((self:GetState()==STATE_ARMED)and(Phys:GetVelocity():Length()>400)and not(self:IsPlayerHolding())and not(constraint.HasConstraints(self)))then
			self.FreefallTicks=self.FreefallTicks+1
			if(self.FreefallTicks>=10)then
				local Tr=util.QuickTrace(self:GetPos(),Phys:GetVelocity():GetNormalized()*3000,self)
				if(Tr.Hit)then self:Detonate() end
			end
		else
			self.FreefallTicks=0
		end
		JMod_AeroDrag(self,self:GetForward())
		self:NextThink(CurTime()+.1)
		return true
	end
elseif(CLIENT)then
	function ENT:Initialize()
		--
	end
	function ENT:Think()
		--
	end
	function ENT:Draw()
		self:DrawModel()
	end
	language.Add("ent_jack_gmod_ezincendiarybomb","EZ Incendiary Bomb")
end
