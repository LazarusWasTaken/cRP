local htmlEntities = module("lib/htmlEntities")

local cfg = module("cfg/identity")
local lang = cRP.lang

local sanitizes = module("cfg/sanitizes")

-- this module describe the identity system

-- init sql
cRP.prepare("cRP/identity_tables", [[
CREATE TABLE IF NOT EXISTS cRP_user_identities(
  user_id INTEGER,
  registration VARCHAR(20),
  phone VARCHAR(20),
  firstname VARCHAR(50),
  name VARCHAR(50),
  age INTEGER,
  CONSTRAINT pk_user_identities PRIMARY KEY(user_id),
  CONSTRAINT fk_user_identities_users FOREIGN KEY(user_id) REFERENCES cRP_users(id) ON DELETE CASCADE,
  INDEX(registration),
  INDEX(phone)
);
]])

cRP.prepare("cRP/get_user_identity","SELECT * FROM cRP_user_identities WHERE user_id = @user_id")
cRP.prepare("cRP/init_user_identity","INSERT IGNORE INTO cRP_user_identities(user_id,registration,phone,firstname,name,age) VALUES(@user_id,@registration,@phone,@firstname,@name,@age)")
cRP.prepare("cRP/update_user_identity","UPDATE cRP_user_identities SET firstname = @firstname, name = @name, age = @age, registration = @registration, phone = @phone WHERE user_id = @user_id")
cRP.prepare("cRP/get_userbyreg","SELECT user_id FROM cRP_user_identities WHERE registration = @registration")
cRP.prepare("cRP/get_userbyphone","SELECT user_id FROM cRP_user_identities WHERE phone = @phone")

-- init
async(function()
  cRP.execute("cRP/identity_tables")
end)

-- api

-- return user identity
function cRP.getUserIdentity(user_id, cbr)
  local rows = cRP.query("cRP/get_user_identity", {user_id = user_id})
  return rows[1]
end

-- return user_id by registration or nil
function cRP.getUserByRegistration(registration, cbr)
  local rows = cRP.query("cRP/get_userbyreg", {registration = registration or ""})
  if #rows > 0 then
    return rows[1].user_id
  end
end

-- return user_id by phone or nil
function cRP.getUserByPhone(phone, cbr)
  local rows = cRP.query("cRP/get_userbyphone", {phone = phone or ""})
  if #rows > 0 then
    return rows[1].user_id
  end
end

function cRP.generateStringNumber(format) -- (ex: DDDLLL, D => digit, L => letter)
  local abyte = string.byte("A")
  local zbyte = string.byte("0")

  local number = ""
  for i=1,#format do
    local char = string.sub(format, i,i)
    if char == "D" then number = number..string.char(zbyte+math.random(0,9))
    elseif char == "L" then number = number..string.char(abyte+math.random(0,25))
    else number = number..char end
  end

  return number
end

-- return a unique registration number
function cRP.generateRegistrationNumber(cbr)
  local user_id = nil
  local registration = ""
  -- generate registration number
  repeat
    registration = cRP.generateStringNumber("DDDLLL")
    user_id = cRP.getUserByRegistration(registration)
  until not user_id

  return registration
end

-- return a unique phone number (0DDDDD, D => digit)
function cRP.generatePhoneNumber(cbr)
  local user_id = nil
  local phone = ""

  -- generate phone number
  repeat
    phone = cRP.generateStringNumber(cfg.phone_format)
    user_id = cRP.getUserByPhone(phone)
  until not user_id

  return phone
end

-- events, init user identity at connection
AddEventHandler("cRP:playerJoin",function(user_id,source,name,last_login)
  if not cRP.getUserIdentity(user_id) then
    local registration = cRP.generateRegistrationNumber()
    local phone = cRP.generatePhoneNumber()
    cRP.execute("cRP/init_user_identity", {
      user_id = user_id,
      registration = registration,
      phone = phone,
      firstname = cfg.random_first_names[math.random(1,#cfg.random_first_names)],
      name = cfg.random_last_names[math.random(1,#cfg.random_last_names)],
      age = math.random(25,40)
    })
  end
end)

-- city hall menu

local cityhall_menu = {name=lang.cityhall.title(),css={top="75px", header_color="rgba(0,125,255,0.75)"}}

local function ch_identity(player,choice)
  local user_id = cRP.getUserId(player)
  if user_id ~= nil then
    local firstname = cRP.prompt(player,lang.cityhall.identity.prompt_firstname(),"")
    if string.len(firstname) >= 2 and string.len(firstname) < 50 then
      firstname = sanitizeString(firstname, sanitizes.name[1], sanitizes.name[2])
      local name = cRP.prompt(player,lang.cityhall.identity.prompt_name(),"")
      if string.len(name) >= 2 and string.len(name) < 50 then
        name = sanitizeString(name, sanitizes.name[1], sanitizes.name[2])
        local age = cRP.prompt(player,lang.cityhall.identity.prompt_age(),"")
        age = parseInt(age)
        if age >= 16 and age <= 150 then
          if cRP.tryPayment(user_id,cfg.new_identity_cost) then
            local registration = cRP.generateRegistrationNumber()
            local phone = cRP.generatePhoneNumber()

            cRP.execute("cRP/update_user_identity", {
              user_id = user_id,
              firstname = firstname,
              name = name,
              age = age,
              registration = registration,
              phone = phone
            })

            -- update client registration
            cRPclient._setRegistrationNumber(player,registration)
            cRPclient._notify(player,lang.money.paid({cfg.new_identity_cost}))
          else
            cRPclient._notify(player,lang.money.not_enough())
          end
        else
          cRPclient._notify(player,lang.common.invalid_value())
        end
      else
        cRPclient._notify(player,lang.common.invalid_value())
      end
    else
      cRPclient._notify(player,lang.common.invalid_value())
    end
  end
end

cityhall_menu[lang.cityhall.identity.title()] = {ch_identity,lang.cityhall.identity.description({cfg.new_identity_cost})}

local function cityhall_enter(source)
  local user_id = cRP.getUserId(source)
  if user_id ~= nil then
    cRP.openMenu(source,cityhall_menu)
  end
end

local function cityhall_leave(source)
  cRP.closeMenu(source)
end

local function build_client_cityhall(source) -- build the city hall area/marker/blip
  local user_id = cRP.getUserId(source)
  if user_id ~= nil then
    local x,y,z = table.unpack(cfg.city_hall)

    cRPclient._addBlip(source,x,y,z,cfg.blip[1],cfg.blip[2],lang.cityhall.title())
    cRPclient._addMarker(source,x,y,z-1,0.7,0.7,0.5,0,255,125,125,150)

    cRP.setArea(source,"cRP:cityhall",x,y,z,1,1.5,cityhall_enter,cityhall_leave)
  end
end

AddEventHandler("cRP:playerSpawn",function(user_id, source, first_spawn)
  -- send registration number to client at spawn
  local identity = cRP.getUserIdentity(user_id)
  if identity then
    cRPclient._setRegistrationNumber(source,identity.registration or "000AAA")
  end

  -- first spawn, build city hall
  if first_spawn then
    build_client_cityhall(source)
  end
end)

-- player identity menu

-- add identity to main menu
cRP.registerMenuBuilder("main", function(add, data)
  local player = data.player

  local user_id = cRP.getUserId(player)
  if user_id then
    local identity = cRP.getUserIdentity(user_id)

    if identity then
      -- generate identity content
      -- get address
      local address = cRP.getUserAddress(user_id)
      local home = ""
      local number = ""
      if address then
        home = address.home
        number = address.number
      end

      local content = lang.cityhall.menu.info({htmlEntities.encode(identity.name),htmlEntities.encode(identity.firstname),identity.age,identity.registration,identity.phone,home,number})
      local choices = {}
      choices[lang.cityhall.menu.title()] = {function()end, content}

      add(choices)
    end
  end
end)
