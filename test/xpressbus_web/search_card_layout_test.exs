defmodule XpressbusWeb.SearchCardLayoutTest do
  @moduledoc """
  Regression guard for the bus search-result journey timeline.

  The bus icon used to be absolutely positioned over the line (`-top-3.5`), so it
  overlapped the duration/departure label above the line on narrow (phone) cards.
  The icon is now an inline white chip between two line segments and the time
  labels cannot be squeezed into it.
  """

  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @template Path.join(@root, "lib/xpressbus_web/live/booking_live.html.heex")

  test "journey timeline bus icon is inline, not overlapping the label" do
    template = File.read!(@template)

    [journey] =
      Regex.run(~r/<%!-- Col 2: Journey --%>(.*?)<%!-- Col 3:/s, template,
        capture: :all_but_first
      )

    # The old bug: icon absolutely positioned upward into the duration label.
    refute journey =~ "-top-3.5"
    refute journey =~ ~s(class="absolute inset-0 flex items-center justify-center)

    # Icon sits in its own white chip between the line segments.
    assert journey =~ "bg-white rounded-full"
    assert journey =~ "directions_bus"

    # Time labels cannot wrap/collapse into the middle column on small screens.
    assert journey =~ "whitespace-nowrap"
    assert journey =~ "shrink-0"
    assert journey =~ "min-w-[8px]"
  end
end
