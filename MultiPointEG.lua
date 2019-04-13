-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local InputGate = require "Unit.ViewControl.InputGate"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local MultiPointEG = Class{}
MultiPointEG:include(Unit)

function MultiPointEG:init(args)
  args.title = "MPEG"
  args.mnemonic = "ME"
  Unit.init(self,args)
end

function MultiPointEG:onLoadGraph()
  
  local gate = self:createObject("Comparator","gate")
  local noteOn = self:createObject("Comparator","noteOn")
  local noteOff = self:createObject("Comparator","noteOff")
  gate:setGateMode()
  noteOn:setTriggerOnRiseMode()
  noteOff:setTriggerOnFallMode()
  self:createMonoBranch("Gate",gate,"In",gate,"Out")

  local outLevel = self:createObject("GainBias","outLevel")
  local outLevelAdapter = self:createObject("ParameterAdapter","outLevelAdapter")
  tie(outLevel,"Bias",outLevelAdapter,"Out")
  local slew = self:createObject("SlewLimiter","slew")
  local slewAdapter = self:createObject("ParameterAdapter","slewAdapter")
  slewAdapter:hardSet("Gain",1.0)
  tie(slew,"Time",slewAdapter,"Out")
  local uDelay = self:createObject("MicroDelay","uDelay",0.01)
  uDelay:hardSet("Delay",0.00001)
  local uDelay2 = self:createObject("MicroDelay","uDelay2",0.01)
  uDelay2:hardSet("Delay",0.00001)

  local phase = self:createObject("Counter","phase")
  phase:hardSet("Start",0)
  phase:hardSet("Finish",4)
  phase:hardSet("Step Size",1)
  phase:hardSet("Gain",0.1)
  phase:optionSet("Wrap",0)

  local testdial = self:createObject("GainBias","testdial")
  local testdialRange = self:createObject("MinMax","testdialRange")
  connect(testdial,"Out",testdialRange,"In")
  self:createMonoBranch("testdial",testdial,"In",testdial,"Out")

  local DSPObjects = {}

  for i = 1, 3 do
    DSPObjects["levelControlMix" .. i] = self:createObject("Sum","levelControlMix" .. i)
    DSPObjects["rateControlMix" .. i] = self:createObject("Sum","rateControlMix" .. i)
  end
  
  for i = 1, 4 do 
      DSPObjects["level" .. i] = self:createObject("GainBias","level" .. i)
      DSPObjects["levelRange" .. i] = self:createObject("MinMax","levelRange" .. i)
      DSPObjects["rate" .. i] = self:createObject("GainBias","rate" .. i)
      DSPObjects["rateRange" .. i] = self:createObject("GainBias","rateRange" .. i)
      DSPObjects["levelVCA" .. i] = self:createObject("Multiply","levelVCA" .. i)
      DSPObjects["rateVCA" .. i] = self:createObject("Multiply","rateVCA" .. i)
      connect(DSPObjects["level" .. i],"Out",DSPObjects["levelRange" .. i],"In")
      connect(DSPObjects["rate" .. i],"Out",DSPObjects["rateRange" .. i],"In")
      self:createMonoBranch("level" .. i,DSPObjects["level" .. i],"In",DSPObjects["level" .. i],"Out")
      self:createMonoBranch("rate" .. i,DSPObjects["rate" .. i],"In",DSPObjects["rate" .. i],"Out")
      connect(DSPObjects["level" .. i],"Out",DSPObjects["levelVCA" .. i],"Right")
      connect(DSPObjects["rate" .. i],"Out",DSPObjects["rateVCA" .. i],"Right")
      -- DSPObjects["compRise" .. i] = self:createObject("Comparator","compRise" .. i)
      -- DSPObjects["compRise" .. i]:setTriggerOnRiseMode()
      -- DSPObjects["compRise" .. i]:hardSet("Hysteresis",0.0)
      -- DSPObjects["compFall" .. i] = self:createObject("Comparator","compFall" .. i)
      -- DSPObjects["compFall" .. i]:setTriggerOnFallMode()
      -- DSPObjects["compFall" .. i]:hardSet("Hysteresis",0.0)
      -- DSPObjects["compFallAdapter" .. i] = self:createObject("ParameterAdapter","compFallAdapter" .. i)
      -- DSPObjects["compRiseAdapter" .. i] = self:createObject("ParameterAdapter","compRiseAdapter" .. i)
      -- DSPObjects["compFallAdapter" .. i]:hardSet("Gain",1.0)
      -- DSPObjects["compRiseAdapter" .. i]:hardSet("Gain",1.0)
      -- tie(DSPObjects["compFall" .. i],"Threshold",DSPObjects["compFallAdapter" .. i],"Out")
      -- tie(DSPObjects["compRise" .. i],"Threshold",DSPObjects["compRiseAdapter" .. i],"Out")
      -- connect(DSPObjects["level" .. i],"Out",DSPObjects["compFallAdapter" .. i],"In")
      -- connect(DSPObjects["level" .. i],"Out",DSPObjects["compRiseAdapter" .. i],"In")
      -- connect(slew,"Out",DSPObjects["compRise" .. i],"In")
      -- connect(slew,"Out",DSPObjects["compFall" .. i],"In")
      DSPObjects["levelDetector" .. i] = self:createObject("BumpMap","levelDetector" .. i)
      DSPObjects["levelDetector" .. i]:hardSet("Width",0.0)
      DSPObjects["levelDetector" .. i]:hardSet("Height",1.0)
      DSPObjects["levelDetector" .. i]:hardSet("Fade",0.0)
      DSPObjects["ldCenter" .. i] = self:createObject("ParameterAdapter","ldCenter" .. i)
      tie(DSPObjects["levelDetector" .. i],"Center",DSPObjects["ldCenter" .. i],"Out")
      DSPObjects["ldCenter" .. i]:hardSet("Gain",1.0)
      connect(DSPObjects["level" .. i],"Out",DSPObjects["ldCenter" .. i],"In")
      connect(slew,"Out",DSPObjects["levelDetector" .. i],"In")
      DSPObjects["phaseDetectionMixer" .. i] = self:createObject("Sum","phaseDetectionMixer" .. i)
      -- connect(DSPObjects["compRise" .. i],"Out",DSPObjects["phaseDetectionMixer" .. i],"Left")
      -- connect(DSPObjects["compFall" .. i],"Out",DSPObjects["phaseDetectionMixer" .. i],"Right")
      DSPObjects["permissionToTalk" .. i] = self:createObject("Multiply","permissionToTalk" .. i)
      -- connect(DSPObjects["phaseDetectionMixer" .. i],"Out",DSPObjects["permissionToTalk" .. i],"Left")
      connect(DSPObjects["levelDetector" .. i],"Out",DSPObjects["permissionToTalk" .. i],"Left")
      DSPObjects["bumpScan" .. i] = self:createObject("BumpMap","bumpScan" .. i)
      DSPObjects["bumpScan" .. i]:hardSet("Center",i/10)
      DSPObjects["bumpScan" .. i]:hardSet("Width",0.0)
      DSPObjects["bumpScan" .. i]:hardSet("Height",1.0)
      DSPObjects["bumpScan" .. i]:hardSet("Fade",0.0)
      connect(phase,"Out",DSPObjects["bumpScan" .. i],"In")
      -- connect(testdial,"Out",DSPObjects["bumpScan" .. i],"In")
      connect(DSPObjects["bumpScan" .. i],"Out",DSPObjects["permissionToTalk" .. i],"Right")
      connect(DSPObjects["bumpScan" .. i],"Out",DSPObjects["levelVCA" .. i],"Left")
      connect(DSPObjects["bumpScan" .. i],"Out",DSPObjects["rateVCA" .. i],"Left")
      DSPObjects["pttMix" .. i] = self:createObject("Sum","pttMix" .. i)
      
  end

  connect(self,"In1",gate,"In")
  connect(gate,"Out",noteOn,"In")
  connect(gate,"Out",noteOff,"In")

  connect(DSPObjects["levelVCA1"],"Out",DSPObjects["levelControlMix1"],"Left")
  connect(DSPObjects["levelVCA2"],"Out",DSPObjects["levelControlMix1"],"Right")
  connect(DSPObjects["levelVCA3"],"Out",DSPObjects["levelControlMix2"],"Left")
  connect(DSPObjects["levelVCA4"],"Out",DSPObjects["levelControlMix2"],"Right")
  connect(DSPObjects["levelControlMix1"],"Out",DSPObjects["levelControlMix3"],"Left")
  connect(DSPObjects["levelControlMix2"],"Out",DSPObjects["levelControlMix3"],"Right")  

  connect(DSPObjects["rateVCA1"],"Out",DSPObjects["rateControlMix1"],"Left")
  connect(DSPObjects["rateVCA2"],"Out",DSPObjects["rateControlMix1"],"Right")
  connect(DSPObjects["rateVCA3"],"Out",DSPObjects["rateControlMix2"],"Left")
  connect(DSPObjects["rateVCA4"],"Out",DSPObjects["rateControlMix2"],"Right")
  connect(DSPObjects["rateControlMix1"],"Out",DSPObjects["rateControlMix3"],"Left")
  connect(DSPObjects["rateControlMix2"],"Out",DSPObjects["rateControlMix3"],"Right")  

  connect(DSPObjects["levelControlMix3"],"Out",uDelay,"In")
  connect(uDelay,"Out",slew,"In")
  connect(DSPObjects["rateControlMix3"],"Out",slewAdapter,"In")

  connect(DSPObjects["pttMix1"],"Out",DSPObjects["pttMix3"],"Left")
  connect(DSPObjects["pttMix2"],"Out",DSPObjects["pttMix3"],"Right")
  connect(DSPObjects["permissionToTalk1"],"Out",DSPObjects["pttMix1"],"Left")
  connect(DSPObjects["permissionToTalk2"],"Out",DSPObjects["pttMix1"],"Right")
  connect(DSPObjects["permissionToTalk3"],"Out",DSPObjects["pttMix2"],"Left")
  connect(DSPObjects["permissionToTalk4"],"Out",DSPObjects["pttMix2"],"Right")
  
  

  -- connect(noteOn,"Out",phase,"Reset")
  connect(noteOn,"Out",uDelay2,"In")
  connect(DSPObjects["pttMix3"],"Out",DSPObjects["pttMix4"],"Left")
  connect(noteOn,"Out",DSPObjects["pttMix4"],"Right")
  connect(DSPObjects["pttMix4"],"Out",phase,"In")

  -- connect(outLevel,"Out",slew,"In")
  connect(DSPObjects["permissionToTalk3"],"Out",self,"Out1")


end

local views = {
  expanded = {"input","level1","rate1","level2","rate2","level3","rate3","level4","rate4","testdial"},
  collapsed = {},
  input = {"scope","input"}
}

local function linMap(min,max,superCoarse,coarse,fine,superFine)
  local map = app.LinearDialMap(min,max)
  map:setSteps(superCoarse,coarse,fine,superFine)
  return map
end

local rateMap = linMap(0.0,10.0,0.1,0.01,0.001,0.001)

function MultiPointEG:onLoadViews(objects,branches)
  local controls = {}
  local initialLevels = {1.0, 0.75, 0.44, 0.1}
  local initialRates = {0.5, 0.7, 0.8, 0.300}

  controls.input = InputGate {
    button = "input",
    description = "Unit Input",
    comparator = objects.gate,
  }

  controls.testdial = GainBias {
    button = "test",
    description = "test",
    branch = branches.testdial,
    gainbias = objects.testdial,
    range = objects.testdialRange,
    initialBias = 0.0,
  }    

  for i= 1, 4 do
    controls["level" .. i] = GainBias {
      button = "lvl " .. i,
      description = "Level " .. i,
      branch = branches["level" .. i],
      gainbias = objects["level" .. i],
      range = objects["level" .. i],
      biasMap = Encoder.getMap("unit"),
      initialBias = initialLevels[i]
    }
  end

  for i=1, 4 do
    controls["rate" .. i] = GainBias {
      button = "rate " .. i,
      description = "Rate " .. i,
      branch = branches["rate" .. i],
      gainbias = objects["rate" .. i],
      range = objects["rate" .. i],
      biasMap = rateMap,
      biasUnits = app.unitSecs,
      initialBias = initialRates[i]
    }
  end

  return controls, views
end

return MultiPointEG
