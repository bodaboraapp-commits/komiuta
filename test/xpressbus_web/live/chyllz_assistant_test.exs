defmodule XpressbusWeb.ChyllzAssistantTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "entry points" do
    test "the assistant is available on every Chyllz page and nowhere else", %{conn: conn} do
      for path <- [
            ~p"/tour-packages",
            ~p"/tour-packages/hotels",
            ~p"/our-packages/hidden-gems",
            ~p"/tour-packages/car",
            ~p"/tour-packages/events"
          ] do
        {:ok, view, _html} = live(conn, path)
        assert has_element?(view, "#chyllz-assistant-launcher")
        assert has_element?(view, "#chyllz-assistant[data-open='false']")
      end

      {:ok, _view, html} = live(conn, ~p"/")
      refute html =~ "chyllz-assistant-launcher"
    end

    test "the Chyllz hub hero has an Ask Chyllz AI button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tour-packages")

      assert has_element?(view, "#chyllz-ai-hero-cta")

      view |> element("#chyllz-ai-hero-cta") |> render_click()
      assert has_element?(view, "#chyllz-assistant[data-open='true']")
    end

    test "?assistant=1 opens the assistant from the Chyllz account Build with AI link", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/tour-packages?assistant=1")

      assert has_element?(view, "#chyllz-assistant[data-open='true']")
    end
  end

  describe "panel" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tour-packages")
      view |> element("#chyllz-assistant-launcher") |> render_click()
      %{view: view}
    end

    test "shows the brand, tabs and greeting", %{view: view} do
      assert has_element?(view, "#assistant-hero-title")
      assert has_element?(view, "#assistant-greeting")
      assert has_element?(view, "#assistant-tab-chat[aria-selected='true']")
      assert has_element?(view, "#assistant-tab-lens")
      assert has_element?(view, "#assistant-tab-receipt")
      assert has_element?(view, "#assistant-tab-food")
      assert has_element?(view, "#assistant-chat-form")
      assert render(view) =~ "Chyllz"
    end

    test "switches tabs and keeps tab-specific tools", %{view: view} do
      view |> element("#assistant-tab-lens") |> render_click()
      assert has_element?(view, "#assistant-tools-lens")
      assert has_element?(view, "#assistant-photo-form")
      assert has_element?(view, "#assistant-hero-title")

      view |> element("#assistant-tab-receipt") |> render_click()
      assert has_element?(view, "#assistant-tools-receipt")
      assert has_element?(view, "#assistant-receipt-form")
      assert has_element?(view, "#assistant-receipt-text")

      view |> element("#assistant-tab-food") |> render_click()
      assert render(view) =~ "Taste Chyllz"
      refute has_element?(view, "#assistant-tools-lens")
    end

    test "sends a message and renders the local reply", %{view: view} do
      view
      |> element("#assistant-chat-form")
      |> render_submit(%{"message" => "hello"})

      assert has_element?(view, "#assistant-message-1")
      assert has_element?(view, "#assistant-message-2")
      assert render(view) =~ "travel companion"
    end

    test "quick suggestions start a conversation", %{view: view} do
      assert has_element?(view, "#assistant-suggestions")

      view
      |> element("#assistant-suggestions button[phx-value-prompt='Plan a 3-day trip to Diani']")
      |> render_click()

      assert has_element?(view, "#assistant-message-1")
      assert has_element?(view, "#assistant-message-2")
    end

    test "closing the panel updates the open state", %{view: view} do
      view |> element("#assistant-close") |> render_click()

      assert has_element?(view, "#chyllz-assistant[data-open='false']")
      assert has_element?(view, "#chyllz-assistant-launcher")
    end

    test "new chat clears the current thread", %{view: view} do
      view
      |> element("#assistant-chat-form")
      |> render_submit(%{"message" => "hello"})

      assert has_element?(view, "#assistant-message-1")

      view |> element("#assistant-new-chat") |> render_click()

      refute has_element?(view, "#assistant-message-1")
      assert has_element?(view, "#assistant-greeting")
    end

    test "shows the guided-engine label when no provider is configured", %{view: view} do
      assert has_element?(view, "#assistant-engine-label")
      assert render(view) =~ "Live catalogue guide"
    end
  end

  describe "receipt tab" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tour-packages")
      view |> element("#chyllz-assistant-launcher") |> render_click()
      view |> element("#assistant-tab-receipt") |> render_click()
      %{view: view}
    end

    test "totals a pasted receipt and keeps a running log", %{view: view} do
      view
      |> element("#assistant-receipt-form")
      |> render_submit(%{
        "receipt_text" => "KOMIUTA CAFE\nChapati 120\nTilapia 850\nTotal 970"
      })

      assert has_element?(view, "#assistant-expense-log")
      assert has_element?(view, "#assistant-expense-total")
      assert render(view) =~ "KES 970"
      assert render(view) =~ "Receipt captured"
    end

    test "explains how to format an unreadable receipt", %{view: view} do
      view
      |> element("#assistant-receipt-form")
      |> render_submit(%{"receipt_text" => "no amounts here"})

      assert render(view) =~ "receipt lines"
      refute has_element?(view, "#assistant-expense-log")
    end

    test "clearing the log removes the summary", %{view: view} do
      view
      |> element("#assistant-receipt-form")
      |> render_submit(%{"receipt_text" => "Chapati 120\nTotal 120"})

      assert has_element?(view, "#assistant-expense-log")

      view |> element("#assistant-expense-log button") |> render_click()

      refute has_element?(view, "#assistant-expense-log")
    end
  end

  describe "lens tab" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tour-packages")
      view |> element("#chyllz-assistant-launcher") |> render_click()
      view |> element("#assistant-tab-lens") |> render_click()
      %{view: view}
    end

    test "accepts a photo and returns a local catalogue match", %{view: view} do
      upload =
        file_input(view, "#assistant-photo-form", :assistant_photo, [
          %{
            name: "inspiration.png",
            content: <<137, 80, 78, 71, 13, 10, 26, 10>>,
            type: "image/png"
          }
        ])

      assert render_upload(upload, "inspiration.png") =~ "inspiration.png"

      view |> element("#assistant-photo-form") |> render_submit()

      assert render(view) =~ "stands out"
    end

    test "captions are submitted with the photo", %{view: view} do
      upload =
        file_input(view, "#assistant-photo-form", :assistant_photo, [
          %{
            name: "beach.png",
            content: <<137, 80, 78, 71, 13, 10, 26, 10>>,
            type: "image/png"
          }
        ])

      render_upload(upload, "beach.png")

      view
      |> element("#assistant-photo-form")
      |> render_change(%{"caption" => "beach sunset"})

      assert render(view) =~ "beach sunset"
    end
  end
end
