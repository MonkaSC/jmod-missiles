-- Jackarunda 2019
AddCSLuaFile()
ENT.Type="anim"
ENT.Author="Jackarunda"
ENT.Category="JMod - EZ Explosives"
ENT.Information="glhfggwpezpznore"
ENT.PrintName="EZ HEAT Missile (Anti Tank)"
ENT.Spawnable=true
ENT.AdminSpawnable=true
---
ENT.JModPreferredCarryAngles=Angle(0,90,0)
---
local STATE_BROKEN,STATE_OFF,STATE_ARMED,STATE_LAUNCHED=-1,0,1,2
function ENT:SetupDataTables()
	self:NetworkVar("Int",0,"State")
end
---
if(SERVER)then
	function ENT:SpawnFunction(ply,tr)
		local SpawnPos=tr.HitPos+tr.HitNormal*40
		local ent=ents.Create(self.ClassName)
		ent:SetAngles(Angle(180,0,0))
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
		self:SetModel("models/weapons/w_missile_closed.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		---
		timer.Simple(.01,function()
			self:GetPhysicsObject():SetMass(40)
			self:GetPhysicsObject():EnableDrag(false)
			self:GetPhysicsObject():Wake()
		end)
		---
		self:SetState(STATE_OFF)
		self.NextDet=0
	end
	function ENT:PhysicsCollide(data,physobj)
		if not(IsValid(self))then return end
		if(data.DeltaTime>0.2)then
			if(data.Speed>50)then
				self:EmitSound("Canister.ImpactHard")
			end
			local DetSpd=300
			if((data.Speed>DetSpd)and(self:GetState()==STATE_LAUNCHED))then
				self:Detonate()
				return
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
		self:TakePhysicsDamage(dmginfo)
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
		local State=self:GetState()
		if(State<0)then return end
		
		local Alt=activator:KeyDown(JMOD_CONFIG.AltFunctionKey)
		if(State==STATE_OFF)then
			if(Alt)then
				JMod_Owner(self,activator)
				self:EmitSound("snds_jack_gmod/bomb_arm.wav",60,120)
				self:SetState(STATE_ARMED)
				self.EZlaunchableWeaponArmedTime=CurTime()
				JMod_Hint(activator, "launch", self)
			else
				activator:PickupObject(self)
				JMod_Hint(activator, "arm", self)
			end
		elseif(State==STATE_ARMED)then
			self:EmitSound("snds_jack_gmod/bomb_disarm.wav",60,120)
			self:SetState(STATE_OFF)
			JMod_Owner(self,activator)
			self.EZlaunchableWeaponArmedTime=nil
		end
	end

	function ENT:Detonate()
		if(self.NextDet>CurTime())then return end
		if(self.Exploded)then return end
		self.Exploded=true
		local SelfPos,Att,Dir=self:GetPos()+Vector(0,0,30),self.Owner or game.GetWorld(),self:GetForward()
		JMod_Sploom(Att,SelfPos,10)
		---
		util.ScreenShake(SelfPos,1000,3,2,1500)
		self:EmitSound("snd_jack_fragsplodeclose.wav",90,100)
		---
		for i=1,10 do
			util.BlastDamage(self,Att,SelfPos+Dir*30*i,100-i*7,3000-i*290)
			print("hi")
		end
		for k,ent in pairs(ents.FindInSphere(SelfPos,200))do
			if(ent:GetClass()=="npc_helicopter")then ent:Fire("selfdestruct","",math.Rand(0,2)) end
		end
		---
		JMod_WreckBuildings(self,SelfPos,2)
		JMod_BlastDoors(self,SelfPos,2)
		---
		timer.Simple(.2,function()
			local Tr=util.QuickTrace(SelfPos-Dir*100,Dir*300)
			if(Tr.Hit)then util.Decal("Scorch",Tr.HitPos+Tr.HitNormal,Tr.HitPos-Tr.HitNormal) end
		end)
		---
		self:Remove()
		local Ang=self:GetAngles()
		Ang:RotateAroundAxis(Ang:Forward(),-90)
		timer.Simple(.1,function()
			ParticleEffect("50lb_air",SelfPos+Dir*130,Ang)
			ParticleEffect("50lb_air",SelfPos,Ang)
			ParticleEffect("50lb_air",SelfPos-Dir*50,Ang)
		end)
	end

	function ENT:OnRemove()
		--
	end
	function ENT:Launch()
		if(self:GetState()~=STATE_ARMED)then return end
		self:SetState(STATE_LAUNCHED)
		local Phys=self:GetPhysicsObject()
		constraint.RemoveAll(self)
		Phys:EnableMotion(true)
		Phys:Wake()
		Phys:ApplyForceCenter(self:GetForward()*20000)
		---
		self:EmitSound("snds_jack_gmod/rocket_launch.wav",80,math.random(95,105))
		---
    	local Closest = math.huge
		for i, v in pairs(ents.GetAll()) do
			local MinimumDot = math.cos(math.rad(20))
			local Direction = (v:GetPos() - self:GetPos()):GetNormalized()
			if self:GetForward():Dot(Direction) < MinimumDot then continue end

			if v:GetClass() == "gmod_sent_vehicle_fphysics_base" then
        		local Dist = self:GetPos():DistToSqr(v:GetPos())
        		if Dist < Closest then
					self.Target = v
          			Closest = Dist
         		end
			end
		end
		---
		self.NextDet=CurTime()+.25
		---
		timer.Simple(30,function()
			if(IsValid(self))then self:Detonate() end
		end)
		JMod_Hint(self.Owner, "backblast", self:GetPos())
	end
	function ENT:EZdetonateOverride(detonator)
		self:Detonate()
	end
  	local function Distance2D(pos1, pos2)
    	return Vector(pos1.x, pos1. y, 0):Distance(Vector(pos2.x, pos2.y, 0))
    end
  	
  	function ENT:AimAt()
    	if !self.Target then return false end
    	local selfpos = self:GetPos()
        local tr = util.TraceLine({
            start = selfpos,
         	endpos = selfpos + Vector(0, 0, 50000),
            mask = MASK_NPCWORLDSTATIC -- only hit da world
          })
        local dist2d = Distance2D(self.Target:GetPos(), selfpos)
        if dist2d > 10000 then
          local zdif = tr.HitPos.z - selfpos.z
          if zdif > 2000 then
            return (self.Target:GetPos() + selfpos) / 2 + Vector(0, 0, tr.HitPos.z - 300)
          else
            return self.Target:GetPos() + Vector(0, 0, tr.HitPos.z - 300)
          end
        end
    	return (self.Target:LocalToWorld(self.Target:OBBCenter()) + self.Target:GetPos()) / 2
   	end
    	
	function ENT:PhysicsUpdate(Phys)
		JMod_AeroDrag(self, self:GetForward(), .75)
		if self:GetState() == STATE_LAUNCHED then
			Phys:ApplyForceCenter(self:GetForward() * 20000)

			-- thanks acf missiles
			if !self.LastPhysCalc then self.LastPhysCalc = CurTime() end
			local DeltaTime = CurTime() - self.LastPhysCalc
			if DeltaTime <= 0 then return end
			local aimpos = self:AimAt()
			if aimpos then
              local AF = self:WorldToLocalAngles((aimpos - self:GetPos()):Angle())
              AF.p = math.Clamp(AF.p * 400,-40,40)
              AF.y = math.Clamp(AF.y * 400,-40,40)
              AF.r = math.Clamp(AF.r * 400,-40,40)

              Phys:AddAngleVelocity(Vector(AF.r,AF.p,AF.y) - Phys:GetAngleVelocity())
        	  Phys:EnableGravity(false)
			else
        	  Phys:EnableGravity(true)
        	end
		end
	end
elseif(CLIENT)then
	function ENT:Initialize()
		--
	end
	function ENT:Think()
		--
	end
	local GlowSprite=Material("mat_jack_gmod_glowsprite")
	function ENT:Draw()
		local Pos,Ang,Dir=self:GetPos(),self:GetAngles(),-self:GetForward()
		Ang:RotateAroundAxis(Ang:Up(),90)
		self:DrawModel()
		if self:GetState() == STATE_LAUNCHED then
			render.SetMaterial(GlowSprite)
			for i=1,10 do
				local Inv=10-i
				render.DrawSprite(Pos+Dir*(i*10+math.random(30,40)),5*Inv,5*Inv,Color(255,255-i*10,255-i*20,255))
			end
			local dlight=DynamicLight(self:EntIndex())
			if dlight then
				dlight.pos = Pos + Dir * 45
				dlight.r = 255
				dlight.g = 175
				dlight.b = 100
				dlight.brightness = 2
				dlight.Decay = 200
				dlight.Size = 400
				dlight.DieTime = CurTime()+.5
			end
		end
	end
	language.Add("ent_jack_gmod_ezherocket","EZ HE Rocket")
end
