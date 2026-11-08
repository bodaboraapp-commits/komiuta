defmodule Xpressbus.AgentDashboardGreetingTest do
  use ExUnit.Case, async: true

  alias Xpressbus.AgentDashboard

  test "uses morning, afternoon and evening consistently in Kenya time" do
    assert AgentDashboard.greeting(~U[2026-11-08 04:00:00Z]) == "Good Morning"
    assert AgentDashboard.greeting(~U[2026-11-08 09:30:00Z]) == "Good Afternoon"
    assert AgentDashboard.greeting(~U[2026-11-08 14:30:00Z]) == "Good Evening"
    assert AgentDashboard.greeting(~U[2026-11-08 17:59:00Z]) == "Good Evening"
  end

  test "uses Hi from 9pm to 11:59pm Kenya time" do
    assert AgentDashboard.greeting(~U[2026-11-08 18:00:00Z]) == "Hi"
    assert AgentDashboard.greeting(~U[2026-11-08 20:00:00Z]) == "Hi"
  end
end
