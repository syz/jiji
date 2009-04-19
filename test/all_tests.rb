#!/usr/bin/ruby

$: << "../lib"


require "runit/testcase"
require "runit/cui/testrunner"

require "test_BackTestCollector"
require "test_Collector"
require "test_SingleClickClient"
require "test_BlockToSession"
require "test_AgentManager"

require "test_AgentRegistry"
require "test_Configuration"
require "test_CSV"
require "test_Operator"
require "test_Output"
require "test_Output_registry"
require "test_PeriodicallyAgent"
require "test_Process"
require "test_ProcessManager"
require "test_RateDao"
require "test_Permitter"
require "test_TradeResultDao"

require "migration/test_Migrator"
require "migration/test_Migrator1_0_3"