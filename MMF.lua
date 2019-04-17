-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Pitch = require "Unit.ViewControl.Pitch"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local MMF = Class{}
MMF:include(Unit)

function MMF:init(args)
  args.title = "Multi Mode Filter"
  args.mnemonic = "MF"
  Unit.init(self,args)
end

function MMF:onLoadGraph(channelCount)
  local lpfilter = self:createObject("StereoLadderFilter","filter")
  local hpfilter = self:createObject("StereoLadderHPF","filter")

  -- Multiplys
  local m1 = self:createObject("Multiply","m1")
  local m2 = self:createObject("Multiply","m2")
  local m3 = self:createObject("Multiply","m3")
  local m4 = self:createObject("Multiply","m4")
  local m5 = self:createObject("Multiply","m5")
  local m6 = self:createObject("Multiply","m6")
  local m7 = self:createObject("Multiply","m7")
  local m8 = self:createObject("Multiply","m8")
  local m9 = self:createObject("Multiply","m9")

  -- Sums
  local s1 = self:createObject("Sum","s1")
  local s2 = self:createObject("Sum","s2")
  local s3 = self:createObject("Sum","s3")
  local s4 = self:createObject("Sum","s4")
  local s5 = self:createObject("Sum","s5")

  -- Offsets
  local negTwo = self:createObject("Constant","negTwo")
  negTwo:hardSet("Value",-2)

  local negOne = self:createObject("Constant","negOne")
  negOne:hardSet("Value",-1)

  local negHalf = self:createObject("Constant","negHalf")
  negHalf:hardSet("Value",-0.5)

  local one = self:createObject("Constant","one")
  one:hardSet("Value",1)

  local two = self:createObject("Constant","two")
  two:hardSet("Value",2)

  -- Clippers
  local clip1 = self:createObject("Clipper","clip1")
  clip1:setMinimum(0)
  clip1:setMaximum(1)

  local clip2 = self:createObject("Clipper","clip2")
  clip2:setMinimum(0)
  clip2:setMaximum(0.5)

  local clip3 = self:createObject("Clipper","clip3")
  clip3:setMinimum(0)
  clip3:setMaximum(0.5)

  local clip4 = self:createObject("Clipper","clip4")
  clip4:setMinimum(0)
  clip4:setMaximum(0.5)

  if channelCount==2 then
    -- erm...
  else
    connect(self,"In1",m1,"Left")
    connect(self,"In1",m7,"Left")
    connect(m1,"Out",lpfilter,"Left In")
    connect(lpfilter,"Left Out",s1,"Left")
    connect(s1,"Out",hpfilter,"Left In")
    connect(hpfilter,"Left Out",m9,"Left")
    connect(m9,"Out",s5,"Right")

    connect(negOne,"Out",m4,"Right")
    connect(m4,"Out",s3,"Right")
    connect(one,"Out",s3,"Left")
    connect(s3,"Out",m5,"Right")
    connect(two,"Out",m5,"Left")
    connect(m5,"Out",clip1,"In")
    connect(clip1,"Out",m1,"Right")

    connect(clip2,"Out",m2,"Left")
    connect(negTwo,"Out",m2,"Right")
    connect(m2,"Out",s2,"Left")
    connect(one,"Out",s2,"Right")
    connect(s2,"Out",m3,"Left")
    connect(s1,"Out",m3,"Right")
    connect(m3,"Out",s5,"Left")

    connect(negHalf,"Out",s4,"Right")
    connect(s4,"Out",clip3,"In")
    connect(clip3,"Out",m6,"Left")
    connect(two,"Out",m6,"Right")
    connect(m6,"Out",m7,"Right")
    connect(m7,"Out",s1,"Right")

    connect(two,"Out",m8,"Left")
    connect(clip4,"Out",m8,"Right")
    connect(m8,"Out",m9,"Right")

    connect(s5,"Out",self,"Out1")
  end

  -- Controls
  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")

  local f0 = self:createObject("GainBias","f0")
  local f0Range = self:createObject("MinMax","f0Range")

  local res = self:createObject("GainBias","res")
  local resRange = self:createObject("MinMax","resRange")

  local clipper = self:createObject("Clipper","clipper")
  clipper:setMaximum(0.999)
  clipper:setMinimum(0)

  local lpbphp = self:createObject("GainBias","lpbphp")
  local lpbphpRange = self:createObject("MinMax","lpbphpRange")

  -- Control Connections
  connect(tune,"Out",lpfilter,"V/Oct")
  connect(tune,"Out",hpfilter,"V/Oct")

  connect(f0,"Out",lpfilter,"Fundamental")
  connect(f0,"Out",hpfilter,"Fundamental")
  
  connect(lpbphp,"Out",clip2,"In")
  connect(lpbphp,"Out",m4,"Left")
  connect(lpbphp,"Out",s4,"Left")
  connect(lpbphp,"Out",clip4,"In")

  -- Monitors
  connect(tune,"Out",tuneRange,"In")
  connect(f0,"Out",f0Range,"In")
  connect(lpbphp,"Out",lpbphpRange,"In")
  -- Resonance Clipper
  connect(res,"Out",clipper,"In")
  connect(clipper,"Out",lpfilter,"Resonance")
  connect(clipper,"Out",hpfilter,"Resonance")
  connect(clipper,"Out",resRange,"In")

  self:createMonoBranch("tune",tune,"In",tune,"Out")
  self:createMonoBranch("Q",res,"In",res,"Out")
  self:createMonoBranch("f0",f0,"In",f0,"Out")
  self:createMonoBranch("lpbphp",lpbphp,"In",lpbphp,"Out")
end

local views = {
  expanded = {"tune","freq","resonance","lpbphp"},
  collapsed = {},
}

function MMF:onLoadViews(objects,branches)
  local controls = {}

  controls.tune = Pitch {
    button = "V/oct",
    branch = branches.tune,
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.freq = GainBias {
    button = "f0",
    branch = branches.f0,
    description = "Fundamental",
    gainbias = objects.f0,
    range = objects.f0Range,
    biasMap = Encoder.getMap("filterFreq"),
    biasUnits = app.unitHertz,
    initialBias = 440,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.resonance = GainBias {
    button = "Q",
    branch = branches.Q,
    description = "Resonance",
    gainbias = objects.res,
    range = objects.resRange,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.25,
    gainMap = Encoder.getMap("[-10,10]")
  }

  controls.lpbphp = GainBias {
    button = "lpbphp",
    branch = branches.lpbphp,
    description = "LP/BP/HP",
    gainbias = objects.lpbphp,
    range = objects.lpbphpRange,
    biasMap = Encoder.getMap("unit"),
    initialBias = 0.5
  }

  return controls, views
end

return MMF
