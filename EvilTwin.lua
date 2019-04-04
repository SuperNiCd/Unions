-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Pitch = require "Unit.ViewControl.Pitch"
local GainBias = require "Unit.ViewControl.GainBias"
local Fader = require "Unit.ViewControl.Fader"
local Gate = require "Unit.ViewControl.Gate"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local EvilTwin = Class{}
EvilTwin:include(Unit)

function EvilTwin:init(args)
  args.title = "Evil Twin"
  args.mnemonic = "ET"
  Unit.init(self,args)
end

function EvilTwin:onLoadGraph(channelCount)
  if channelCount==2 then
    self:loadStereoGraph()
  else
    self:loadMonoGraph()
  end
end

function EvilTwin:loadMonoGraph()

    -- Objects
    local main = self:createObject("SineOscillator","main")
    local mod = self:createObject("SineOscillator","mod")
    local fbMain = self:createObject("GainBias","fbMain")
    local fbMainRange = self:createObject("MinMax","fbMainRange")
    local fbMod = self:createObject("GainBias","fbMod")
    local fbModRange = self:createObject("MinMax","fbModRange")
    -- local wavefolder = self:createObject("SineOscillator","wavefolder")
    local tune = self:createObject("ConstantOffset","tune")
    local tuneRange = self:createObject("MinMax","tuneRange")
    local f0 = self:createObject("GainBias","f0")
    local f0Range = self:createObject("MinMax","f0Range")
    local fmMixer = self:createObject("Sum","fmMixer")
    local fmVCA = self:createObject("Multiply","fmVCA")
    local fmIndex = self:createObject("GainBias","fmIndex")
    local fmIndexRange = self:createObject("MinMax","fmIndexRange")
    local fmGain = self:createObject("Multiply","fmGain")
    local fmGainConst = self:createObject("ConstantOffset","fmGainConst")
    local pmVCA = self:createObject("Multiply","pmVCA")
    local pmIndex = self:createObject("GainBias","pmIndex")
    local pmIndexRange = self:createObject("MinMax","pmIndexRange")
    local amVCA = self:createObject("Multiply","amVCA")
    local amAttenuator = self:createObject("Multiply","amAttenuator")
    local amMixer = self:createObject("Sum","amMixer")
    local amOffset = self:createObject("Sum","amOffset")
    local amIndex = self:createObject("GainBias","amIndex")
    local amIndexRange = self:createObject("MinMax","amIndexRange")
    local one = self:createObject("ConstantOffset","one")
    local negOne = self:createObject("ConstantOffset","negOne")
    local invertingVCA = self:createObject("Multiply","invertingVCA")
    local ratioVCA = self:createObject("Multiply","ratioVCA")
    local ratio = self:createObject("GainBias","ratio")
    local ratioRange = self:createObject("MinMax","ratioRange")
    local outputLevel = self:createObject("GainBias","outputLevel")
    local outputLevelRange = self:createObject("MinMax","outputLevelRange")
    local outputVCA = self:createObject("Multiply","outputVCA")

    -- Setttings
    one:hardSet("Offset",1.0)
    negOne:hardSet("Offset",-1.0)
    fmGainConst:hardSet("Offset",2500.0)

    -- Indicators
    connect(tune,"Out",tuneRange,"In")
    connect(f0,"Out",f0Range,"In")
    connect(fmIndex,"Out",fmIndexRange,"In")
    connect(pmIndex,"Out",pmIndexRange,"In")
    connect(amIndex,"Out",amIndexRange,"In")
    connect(ratio,"Out",ratioRange,"In")
    connect(fbMain,"Out",fbMainRange,"In")
    connect(fbMod,"Out",fbModRange,"In")
    connect(outputLevel,"Out",outputLevelRange,"In")

    -- Tuning
    connect(tune,"Out",main,"V/Oct")
    connect(tune,"Out",mod,"V/Oct")
    connect(f0,"Out",main,"Fundamental")
    connect(f0,"Out",ratioVCA,"Left")
    connect(ratio,"Out",ratioVCA,"Right")
    connect(ratioVCA,"Out",mod,"Fundamental")

    -- Linear Frequency Modulation
    connect(mod,"Out",fmGain,"Left")
    connect(fmGainConst,"Out",fmGain,"Right")
    connect(fmGain,"Out",fmVCA,"Left")
    connect(fmIndex,"Out",fmVCA,"Right")
    connect(fmVCA,"Out",fmMixer,"Right")
    connect(f0,"Out",fmMixer,"Left")
    connect(fmMixer,"Out",main,"Fundamental")

    -- Phase Modulation
    connect(mod,"Out",pmVCA,"Left")
    connect(pmIndex,"Out",pmVCA,"Right")
    connect(pmVCA,"Out",main,"Phase")

    -- Phase Feedback
    connect(fbMain,"Out",main,"Feedback")
    connect(fbMod,"Out",mod,"Feedback")

    -- Amplitude Modulation
    -- main out to AM circuit
    connect(main,"Out",amVCA,"Left")
    connect(mod,"Out",amAttenuator,"Left")
    connect(amIndex,"Out",amAttenuator,"Right")
    connect(amIndex,"Out",invertingVCA,"Left")
    connect(negOne,"Out",invertingVCA,"Right")
    connect(invertingVCA,"Out",amMixer,"Left")
    connect(one,"Out",amMixer,"Right")
    connect(amMixer,"Out",amVCA,"Right")
    connect(amMixer,"Out",amOffset,"Left")
    connect(amAttenuator,"Out",amOffset,"Right")
    connect(amOffset,"Out",amVCA,"Right")

    -- Output
    connect(amVCA,"Out",outputVCA,"Left")
    connect(outputLevel,"Out",outputVCA,"Right")
    connect(outputVCA,"Out",self,"Out1")

    -- Export control chains
    self:createMonoBranch("fm",fmIndex,"In",fmIndex,"Out")
    self:createMonoBranch("am",amIndex,"In",amIndex,"Out")
    self:createMonoBranch("pm",pmIndex,"In",pmIndex,"Out")
    self:createMonoBranch("ratio",ratio,"In",ratio,"Out")
    self:createMonoBranch("fbMain",fbMain,"In",fbMain,"Out")
    self:createMonoBranch("fbMod",fbMod,"In",fbMod,"Out")
    self:createMonoBranch("f0",f0,"In",f0,"Out")
    self:createMonoBranch("tune",tune,"In",tune,"Out")
    self:createMonoBranch("level",outputLevel,"In",outputLevel,"Out")

end

function EvilTwin:loadStereoGraph()
  self:loadMonoGraph()
  connect(self.objects.outputVCA,"Out",self,"Out2")
end

local views = {
  expanded = {"tune","f0","ratio","fm","am","pm","fbMain","fbMod","level"},
  collapsed = {},
}

local function linMap(min,max,superCoarse,coarse,fine,superFine)
  local map = app.LinearDialMap(min,max)
  map:setSteps(superCoarse,coarse,fine,superFine)
  return map
end

local indexMap = linMap(-1.0,1,0.1,0.01,0.001,0.001)
local amMap = linMap(0,1,0.1,0.01,0.001,0.001)
local ratioMap = linMap(1.0,24.0,1.0,1.0,0.1,0.01)

function EvilTwin:onLoadViews(objects,branches)
  local controls = {}

  controls.ratio = GainBias {
    button = "ratio",
    description = "Ratio",
    branch = branches.ratio,
    gainbias = objects.ratio,
    range = objects.ratioRange,
    biasMap = ratioMap,
    initialBias = 1.0,
  }  

  controls.fbMain = GainBias {
    button = "fbMain",
    description = "Main osc phase fb",
    branch = branches.fbMain,
    gainbias = objects.fbMain,
    range = objects.fbMainRange,
    biasMap = indexMap,
    initialBias = 0.0,
  }
  
  controls.fbMod = GainBias {
    button = "fbMod",
    description = "Mod osc phase fb",
    branch = branches.fbMod,
    gainbias = objects.fbMod,
    range = objects.fbModRange,
    biasMap = indexMap,
    initialBias = 0.0,
  }  

  controls.tune = Pitch {
    button = "V/oct",
    branch = branches.tune,
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.f0 = GainBias {
    button = "f0",
    description = "Fundamental",
    branch = branches.f0,
    gainbias = objects.f0,
    range = objects.f0Range,
    biasMap = Encoder.getMap("oscFreq"),
    biasUnits = app.unitHertz,
    initialBias = 32.7,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.fm = GainBias {
    button = "fm",
    description = "FM Index",
    branch = branches.fm,
    gainbias = objects.fmIndex,
    range = objects.fmIndexRange,
    biasMap = indexMap,
    initialBias = 0.0,
  }


  controls.pm = GainBias {
    button = "pm",
    description = "PM Index",
    branch = branches.pm,
    gainbias = objects.pmIndex,
    range = objects.pmIndexRange,
    biasMap = indexMap,
    initialBias = 0.0,
  }

  controls.am = GainBias {
    button = "am",
    description = "AM Index",
    branch = branches.am,
    gainbias = objects.amIndex,
    range = objects.amIndexRange,
    biasMap = amMap,
    initialBias = 0.0,
  }

  controls.level = GainBias {
    button = "level",
    description = "Output level",
    branch = branches.level,
    gainbias = objects.outputLevel,
    range = objects.outputLevelRange,
    biasMap = indexMap,
    initialBias = 0.5,
  }

  return controls, views
end

return EvilTwin
