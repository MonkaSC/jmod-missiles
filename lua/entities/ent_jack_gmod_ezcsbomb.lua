-- Jackarunda 2019
AddCSLuaFile()
ENT.Type="anim"
ENT.Author="Jackarunda"
ENT.Category="JMod - EZ Explosives"
ENT.Information="glhfggwpezpznore"
ENT.PrintName="EZ CS Gas Bomb"
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
		self.Entity:SetMaterial("models/entities/mat_jack_faebomb")
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

			--local accuracy = self:GetVelocity():GetNormalized():Distance(self:GetForward())
			if --[[accuracy <= 0.1 and ]]data.Speed > 800 and self:GetState()==STATE_ARMED then
				self:Detonate(data, physobj)
				return
			end
			if data.Speed > 2000 then
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
				JMod_Hint(activator, "impactdet", self)
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
	function ENT:Detonate(data, phys)
		if(self.Exploded)then return end
		self.Exploded=true
		self:SetPos(data.HitPos)
		phys:EnableMotion(false)
		self.Fuel = 20
		self:EmitSound("Dirt.BulletImpact")
		--self:Remove()
	end

	function ENT:Think()
		JMod_AeroDrag(self,self:GetForward())
		if(self.Exploded)then
			local Gas=ents.Create("ent_jack_gmod_ezcsparticle")
			Gas:SetPos(self:GetPos() - self:GetForward() * 25)
			JMod_Owner(Gas,self.Owner or self)
			Gas:Spawn()
			Gas:Activate()
			Gas:GetPhysicsObject():SetVelocity(self:GetPhysicsObject():GetVelocity() - self:GetForward() * math.random(10, 100) )
			self:EmitSound("snd_jack_sss.wav",55,80)
			self.Fuel = self.Fuel - 1
			if self.Fuel <= 0 then SafeRemoveEntityDelayed(self,1) end
		end
	end

	function ENT:OnRemove()
		--
	end
	function ENT:EZdetonateOverride(detonator)
		self:Detonate()
	end
elseif(CLIENT)then
	function ENT:Initialize()
		--
	end
	function ENT:Draw()
		self:DrawModel()
	end
	language.Add("ent_jack_gmod_ezcsbomb","EZ CS Gas Bomb")
end
