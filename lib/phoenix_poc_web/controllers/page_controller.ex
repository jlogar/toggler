defmodule PhoenixPocWeb.PageController do
  require Logger
  use PhoenixPocWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def workday?(date) do
    case Date.day_of_week(date) do
      x when x > 5 -> true
      _ -> false
    end
  end

  def prev_month(%Date{year: year, month: month}) do
    case month do
      1 ->
        Date.new(year - 1, 12, 1)

      _ ->
        Date.new(year, month - 1, 1)
    end
  end

  def month_range(start_month, end_month, rng) when start_month == end_month do
    [start_month | rng]
  end

  def month_range(start_month, end_month, rng) do
    case prev_month(end_month) do
      {:ok, prev_month} ->
        month_range(start_month, prev_month, [end_month | rng])

      {:error, _err} ->
        []
    end
  end

  def process_form(conn, %{
        "toggl_api_token" => toggl_api_token,
        "date_from" => _date_from
      }) do
    Logger.info(toggl_api_token)

    _handicap = 0
    _dayOffProjects = ["general/sickness leave", "general/national holiday"]
    _vacationProject = "general/day off"

    first_day = ~D[2019-09-01]
    last_day = Date.utc_today()
    last_month = Date.add(last_day, -last_day.day + 1)
    Logger.info("will go for: #{first_day} to #{last_month}.")
    months = month_range(first_day, last_month, [])
    Logger.info(Enum.join(months, "; "))

    case PhoenixPocWeb.Toggl.get_time_entries(toggl_api_token, first_day, ~D[2019-09-30]) do
      {:ok, _entries} ->
        render(conn, "process_form.html")

      {:err, _} ->
        resp(conn, 500, PhoenixPocWeb.ErrorView.render("500.html"))
    end
  end
end
