AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Fire Hazard"
ENT.KillName = "Fire Hazard"
ENT.NoSitAllowed = true
ENT.IsRemoteKiller = true
local ThinkRate = 22 --Hz

if (SERVER) then
	function ENT:Initialize()
		self.Ptype = 1
		self.TypeInfo = {"Napalm", {Sound("snds_jack_gmod/fire1.wav"), Sound("snds_jack_gmod/fire2.wav")}, "eff_jack_gmod_wpfire", 20, 30, 100}
		----
		self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionBounds(Vector(-20, -20, -10), Vector(20, 20, 10))
		self:PhysicsInitBox(Vector(-20, -20, -10), Vector(20, 20, 10))
    	self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE)
    	self:DrawShadow(false)
    
		local Time = CurTime()
		self.NextFizz = 0
		self.DamageMul = (self.DamageMul or 1) * math.Rand(.9, 1.1)
		self.DieTime = Time + math.Rand(self.TypeInfo[4], self.TypeInfo[5])
		self.NextSound = 0
		self.NextEffect = 0
		self.Range = self.TypeInfo[6]
		self.Power = 3
	end

	local function Inflictor(ent)
		if not (IsValid(ent)) then return game.GetWorld() end
		local Infl = ent:GetDTEntity(0)
		if (IsValid(Infl)) then return Infl end

		return ent
	end

	function ENT:Think()
		local Time, Pos, Dir = CurTime(), self:GetPos(), self:GetForward()

		--print(self:WaterLevel())
		if (self.NextFizz < Time) then
			self.NextFizz = Time + .5

			if (math.random(1, 2) == 2 or self.HighVisuals) then
				local Zap = EffectData()
				Zap:SetOrigin(Pos)
				Zap:SetStart(self:GetVelocity())
				util.Effect(self.TypeInfo[3], Zap, true, true)
			end
		end

		if (self.NextSound < Time) then
			self.NextSound = Time + 1
			self:EmitSound(table.Random(self.TypeInfo[2]), 65, math.random(90, 110))
		end

		if (self.NextEffect < Time) then
			self.NextEffect = Time + 0.5
			local Par, Att, Infl = self:GetParent(), self.Owner or self, Inflictor(self)

			if not (IsValid(Att)) then
				Att = Infl
			end

			if ((IsValid(Par)) and (Par:IsPlayer()) and not (Par:Alive())) then
				self:Remove()

				return
			end

			for k, v in pairs(ents.FindInSphere(Pos, self.Range)) do
				local blacklist = {
					["vfire_ball"] = true,
					["ent_jack_gmod_ezfirehazard"] = true,
          			["ent_jack_gmod_ezwphazard"] = true,
					["ent_jack_gmod_eznapalm"] = true
				}

				if not blacklist[v:GetClass()] and IsValid(v:GetPhysicsObject()) and util.QuickTrace(self:GetPos(), v:GetPos() - self:GetPos(), self).Entity == v then
					local Dam = DamageInfo()
					Dam:SetDamage(self.Power * math.Rand(.75, 1.25))
					Dam:SetDamageType(DMG_BURN)
					Dam:SetDamagePosition(Pos)
					Dam:SetAttacker(Att)
					Dam:SetInflictor(Infl)
					v:TakeDamageInfo(Dam)

					if vFireInstalled then
						CreateVFireEntFires(v, math.random(1, 3))
					elseif (math.random() <= 0.15) then
						v:Ignite(10)
					end
				end
			end

			if vFireInstalled and math.random() <= 0.01 then
				CreateVFireBall(math.random(20, 30), math.random(10, 20), self:GetPos(), VectorRand() * math.random(200, 400), self:GetOwner())
			end

			if (math.random(1, 3) == 1) then
				local Tr = util.QuickTrace(Pos, VectorRand() * self.Range, {self})

				if (Tr.Hit) then
					util.Decal("Scorch", Tr.HitPos + Tr.HitNormal, Tr.HitPos - Tr.HitNormal)
				end
			end
		end

		if (IsValid(self)) then
			if (self.DieTime < Time) then
				self:Remove()

				return
			end

			self:NextThink(Time + (1 / ThinkRate))
		end
    
    	--- GAS
    
    	if math.random(1, 30) == 1 then
          local Gas=ents.Create("ent_jack_gmod_ezcsparticle")
          Gas:SetPos(self:LocalToWorld(self:OBBCenter()))
          JMod_Owner(Gas,self.Owner or self)
          Gas:Spawn()
          Gas:Activate()
          Gas.DieTime = CurTime() + 7
          Gas.Think = function() -- rewriting the entire think hook for the gas cus fuck you
            local Time,SelfPos=CurTime(),Gas:GetPos()
            if(Gas.DieTime<Time)then Gas:Remove() return end
            local Force=VectorRand()*10-Vector(0,0,100)
            for key,obj in pairs(ents.FindInSphere(SelfPos,200))do
              if(not(obj==Gas)and(Gas:CanSee(obj)))then
                local distanceBetween = SelfPos:DistToSqr(obj:GetPos())
                local IsPlaya=obj:IsPlayer()
                if(not obj.EZgasParticle)then
                  if((Gas.NextDmg<Time)and(Gas:ShouldDamage(obj)))then

                    local FaceProtected = false
                    local RespiratorMultiplier = 1

                    if (obj.JackyArmor) then
                      if (obj.JackyArmor.Suit) then
                        if (obj.JackyArmor.Suit.Type == "Hazardous Material") then
                          FaceProtected = true
                        end
                      end
                    end

                    local faceProt,skinProt=JMod_GetArmorBiologicalResistance(obj,DMG_NERVEGAS)
                    if(faceProt>0)then
                      JMod_DepleteArmorChemicalCharge(obj,.01)
                    end

                    obj:Ignite(10)
                
                    if faceProt < 1 then
                      if IsPlaya then
                        net.Start("JMod_VisionBlur")
                        net.WriteFloat(5 * math.Clamp(1 - faceProt, 0, 1))
                        net.Send(obj)
                        JMod_Hint(obj, "tear gas")
                      elseif obj:IsNPC() then
                        obj.EZNPCincapacitate = Time + math.Rand(2,5)
                      end

                      JMod_TryCough(obj)

                      if math.random(1,20) == 1 then
                        local Dmg,Helf=DamageInfo(),obj:Health()
                        Dmg:SetDamageType(DMG_NERVEGAS)
                        Dmg:SetDamage(math.random(1,4)*JMOD_CONFIG.PoisonGasDamage*RespiratorMultiplier)
                        Dmg:SetInflictor(Gas)
                        Dmg:SetAttacker(Gas.Owner or Gas)
                        Dmg:SetDamagePosition(obj:GetPos())
                        obj:TakeDamageInfo(Dmg)
                      end

                    end
                  end
                elseif (obj.EZgasParticle and (distanceBetween < 250*250))then -- Push Gas
                  local Vec=(obj:GetPos()-SelfPos):GetNormalized()
                  Force=Force-Vec*10
                end
              end
            end
            Gas.DrawTranslucent = function()
              if(Gas.DebugShow)then
                Gas:DrawModel()
              end
              local Time=CurTime()
              if(Gas.NextVisCheck<Time)then
                Gas.NextVisCheck=Time+1
                Gas.Show=Gas.Visible and 1/FrameTime()>50
              end
              if(Gas.Show)then
                local SelfPos=Gas:GetPos()
                render.SetMaterial(Mat)
                render.DrawSprite(SelfPos,Gas.siz,Gas.siz,Color(Gas.Col.r,Gas.Col.g,Gas.Col.b,200))
                Gas.siz=math.Clamp(Gas.siz+FrameTime()*200,0,500)
              end
            end
            Gas:Extinguish()
            local Phys=Gas:GetPhysicsObject()
            Phys:SetVelocity(Phys:GetVelocity()*.8)
            Phys:ApplyForceCenter(Force)
            Gas:NextThink(Time+math.Rand(2,2.8))
            return true
          end
      	end

		return true
	end
elseif (CLIENT) then
	function ENT:Initialize()
		self.Ptype = 1
		self.TypeInfo = {"Napalm", {Sound("snds_jack_gmod/fire1.wav"), Sound("snds_jack_gmod/fire2.wav")}, "eff_jack_gmod_wpfire", 15, 14, 50}
		self.CastLight = math.random(1, 10) == 1
		self.Size = self.TypeInfo[6]
		--self.FlameSprite=Material("mats_jack_halo_sprites/flamelet"..math.random(1,5))
	end

	local GlowSprite = Material("sprites/physg_glow1")

	function ENT:Draw()
		local Time, Pos = CurTime(), self:GetPos()
		render.SetMaterial(GlowSprite)
		render.DrawSprite(Pos, self.Size * math.Rand(.75, 1.25), self.Size * math.Rand(.75, 1.25), Color(255, 155, 0, 255))

		if (self.CastLight and not GAMEMODE.Lagging) then
			local dlight = DynamicLight(self:EntIndex())

			if (dlight) then
				dlight.pos = Pos
				dlight.r = 255
				dlight.g = 175
				dlight.b = 100
				dlight.brightness = 3
				dlight.Decay = 200
				dlight.Size = 400
				dlight.DieTime = CurTime() + .5
			end
		end
	end
end