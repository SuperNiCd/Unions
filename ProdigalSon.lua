-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Pitch = require "Unit.ViewControl.Pitch"
local GainBias = require "Unit.ViewControl.GainBias"
local Gate = require "Unit.ViewControl.Gate"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ProdigalSon = Class{}
ProdigalSon:include(Unit)

function ProdigalSon:init(args)
  args.title = "Prodigal Son"
  args.mnemonic = "PS"
  Unit.init(self,args)
end

function ProdigalSon:onLoadGraph(channelCount)
  if channelCount==2 then
    self:loadStereoGraph()
  else
    self:loadMonoGraph()
  end
end

function ProdigalSon:loadMonoGraph()

  -- DSP Objects

  local osc = self:createObject("SineOscillator","osc")
  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")
  local f0 = self:createObject("GainBias","f0")
  local f0Range = self:createObject("MinMax","f0Range")
  local ratio = self:createObject("GainBias","ratio")
  local ratioRange = self:createObject("MinMax","ratioRange")
  local ratioVCA = self:createObject("Multiply","ratioVCA")
  local offset = self:createObject("GainBias","offset")
  local offsetRange = self:createObject("MinMax","offsetRange")
  local offsetMixer = self:createObject("Sum","offsetMixer")
  local phase = self:createObject("GainBias","phase")
  local phaseRange = self:createObject("MinMax","phaseRange")
  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local vca = self:createObject("Multiply","vca")
  local level = self:createObject("GainBias","level")
  local levelRange = self:createObject("MinMax","levelRange")
  local sync = self:createObject("Comparator","sync")

  -- Settings
  sync:setTriggerMode()

  -- Indicators
  connect(tune,"Out",tuneRange,"In")
  connect(f0,"Out",f0Range,"In")
  connect(phase,"Out",phaseRange,"In")
  connect(feedback,"Out",feedbackRange,"In")
  connect(level,"Out",levelRange,"In")
  connect(ratio,"Out",ratioRange,"In")
  connect(offset,"Out",offsetRange,"In")

  -- Tuning
  connect(tune,"Out",osc,"V/Oct")
  connect(f0,"Out",ratioVCA,"Left")
  connect(ratio,"Out",ratioVCA,"Right")
  connect(ratioVCA,"Out",offsetMixer,"Left")
  connect(offset,"Out",offsetMixer,"Right")
  connect(offsetMixer,"Out",osc,"Fundamental")

  -- Sync
  connect(sync,"Out",osc,"Sync")

  -- Phase
  connect(phase,"Out",osc,"Phase")
  
  -- Feeback
  connect(feedback,"Out",osc,"Feedback")

  -- Output
  connect(level,"Out",vca,"Left")
  connect(osc,"Out",vca,"Right")
  connect(vca,"Out",self,"Out1")

  -- Branches
  self:createMonoBranch("level",level,"In",level,"Out")
  self:createMonoBranch("tune",tune,"In",tune,"Out")
  self:createMonoBranch("sync",sync,"In",sync,"Out")
  self:createMonoBranch("f0",f0,"In",f0,"Out")
  self:createMonoBranch("phase",phase,"In",phase,"Out")
  self:createMonoBranch("feedback",feedback,"In",feedback,"Out")
  self:createMonoBranch("ratio",ratio,"In",ratio,"Out")
  self:createMonoBranch("offset",offset,"In",offset,"Out")

end

function ProdigalSon:loadStereoGraph()
  self:loadMonoGraph()
  connect(self.objects.vca,"Out",self,"Out2")
end

local views = {
  expanded = {"tune","freq","ratio","offset","phase","feedback","sync","level"},
  collapsed = {},
}

local function linMap(min,max,superCoarse,coarse,fine,superFine)
    local map = app.LinearDialMap(min,max)
    map:setSteps(superCoarse,coarse,fine,superFine)
    return map
end

local indexMap = linMap(-1.0,1,0.1,0.01,0.001,0.00001)
local amMap = linMap(0,1,0.1,0.01,0.001,0.00001)
local ratioMap = linMap(0.0,24.0,1.0,1.0,0.1,0.01)
local offsetMap = linMap(-1000.0,1000.0,100.0,1.0,0.01,0.001)

function ProdigalSon:onLoadViews(objects,branches)
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

  controls.phase = GainBias {
    button = "phase",
    description = "Phase Offset",
    branch = branches.phase,
    gainbias = objects.phase,
    range = objects.phaseRange,
    biasMap = Encoder.getMap("[-1,1]"),
    initialBias = 0.0,
  }

  controls.ratio = GainBias {
    button = "ratio",
    description = "tuning ratio to f0",
    branch = branches.ratio,
    gainbias = objects.ratio,
    range = objects.ratioRange,
    biasMap = ratioMap,
    initialBias = 1.0,
  }

  controls.offset = GainBias {
    button = "offset",
    description = "fixed f0 offset",
    branch = branches.offset,
    gainbias = objects.offset,
    range = objects.offsetRange,
    biasMap = offsetMap,
    biasUnits = app.unitHertz,
    initialBias = 0.0,
  }

  controls.level = GainBias {
    button = "level",
    description = "Level",
    branch = branches.level,
    gainbias = objects.level,
    range = objects.levelRange,
    biasMap = Encoder.getMap("[-1,1]"),
    initialBias = 0.5,
  }

  controls.sync = Gate {
    button = "sync",
    description = "Sync",
    branch = branches.sync,
    comparator = objects.sync,
  }

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = branches.feedback,
    gainbias = objects.feedback,
    range = objects.feedbackRange,
    biasMap = Encoder.getMap("[-1,1]"),
    initialBias = 0,
  }

  return controls, views
end



return ProdigalSon
