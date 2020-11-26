defmodule TogglerCli.Timetracker do
  require Logger

  defp parse_cookie(header_value) do
    [key, val] =
      String.split(header_value, ";")
      |> Enum.map(fn t -> String.split(t, "=") end)
      |> hd

    {key, val}
  end

  defp get_cookie(headers, name) do
    cookie_headers =
      Enum.filter(headers, fn {key, _} -> String.match?(key, ~r/\Aset-cookie\z/i) end)
      |> Enum.map(fn {_, v} -> v end)

    cookie_headers
    |> Enum.map(fn c -> parse_cookie(c) end)
    |> Enum.filter(fn {key, _val} -> key == name end)
    |> hd
  end

  defp get_url do
    Application.get_env(:toggler_cli, :timetracker_url)
  end

  def get_session_id do
    case HTTPoison.get(
           "#{get_url()}/login.php",
           []
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        Logger.debug("TT get login: OK from timetracker.")

        {:ok, get_cookie(headers, "tt_PHPSESSID")}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("TT get login: #{status_code}")
        {:err, "err"}

      {:error, error} ->
        {:err, error}
    end
  end

  def login_session({cookie_name, session_id}) do
    username = Application.get_env(:toggler_cli, :timetracker_username)
    password = Application.get_env(:toggler_cli, :timetracker_password)

    form =
      {:form,
       [
         {"login", username},
         {"password", password},
         {"btn_login", "Login"},
         {"browser_today", Calendar.strftime(Date.utc_today(), "%Y-%m-%d")}
       ]}

    res =
      case HTTPoison.post(
             "#{get_url()}/login.php",
             form,
             %{},
             hackney: [cookie: ["#{cookie_name}=#{session_id}; tt_login=#{username}"]]
           ) do
        {:ok, %HTTPoison.Response{status_code: 302, headers: headers}} ->
          Logger.debug("TT login: OK from timetracker.")

          {:ok, [{cookie_name, session_id}, get_cookie(headers, "tt_login")]}

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          Logger.error("TT login: #{status_code}")
          {:err, "err"}

        {:error, error} ->
          {:err, error}
      end

    res
  end

  defp scrape_projects_tasks(body) do
    {:ok, document} = Floki.parse_document(body)

    {_, _, [script]} =
      Floki.find(document, "script:not([src])")
      |> Enum.filter(fn {_, _, children} ->
        String.contains?(hd(children), "project_names")
      end)
      |> hd

    projects =
      Regex.scan(
        ~r/project_names\[(?<project_index>(\d)*)\](\s)?=(\s)?\"(?<project_name>(\d)+ - (.)+)\";/,
        script,
        capture: :all_names
      )
      |> Enum.map(fn [id, name] -> [id: id, name: name] end)

    # TODO gotta array indexes too!
    tasks =
      Regex.scan(
        ~r/task_names\[(?<task_index>(\d)*)\](\s)?=(\s)?\"(?<task_name>(\d)+ - (.)+)\";/,
        script,
        capture: :all_names
      )
      |> Enum.map(fn [index, name] -> %{:index => index, :name => name} end)

    {projects, tasks}
  end

  defp get_cookie_options(cookies) do
    [cookie: [Enum.join(Enum.map(cookies, fn {key, val} -> "#{key}=#{val}" end), ";")]]
  end

  def get_projects(cookies) do
    # :hackney_trace.enable(:max, :io)

    res =
      case HTTPoison.get(
             "#{get_url()}/time.php",
             %{},
             hackney: get_cookie_options(cookies)
           ) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          Logger.debug("TT get time: OK from timetracker.")

          {projects, tasks} = scrape_projects_tasks(body)

          Logger.debug(
            "scraped the html, got #{length(projects)} projects, #{length(tasks)} tasks."
          )

          {:ok, [projects: projects, tasks: tasks]}

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          Logger.error("TT get time: #{status_code}")
          {:err, "err"}

        {:error, error} ->
          {:err, error}
      end

    # :hackney_trace.disable()
    res
  end

  def get_daily_tasks(cookies, date) do
    # :hackney_trace.enable(:max, :io)
    date_string = Date.to_string(date)

    res =
      case HTTPoison.get(
             "#{get_url()}/time.php",
             %{},
             params: %{
               date: date_string
             },
             hackney: get_cookie_options(cookies)
           ) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          Logger.debug("TT get time for date #{date_string}: OK from timetracker.")
          {:ok, document} = Floki.parse_document(body)

          entry_rows =
            Floki.find(document, "form[name=\"timeRecordForm\"]")
            |> Floki.find("table:nth-child(3) tr")
            |> Floki.find("table")
            |> Floki.find("tr[bgcolor]")

          entries =
            entry_rows
            |> Enum.map(fn entry ->
              note =
                entry
                |> Floki.find("td:nth-child(6)")
                |> Floki.text()

              toggl_id =
                case Regex.run(~r/\[\[(?<id>(\d)*)\]\]/, note, capture: :all_names) do
                  [id] -> id
                  nil -> nil
                end

              link =
                entry
                |> Floki.find("a[href^=\"time_edit.php\"]")
                |> Floki.attribute("href")
                |> hd

              [_, tt_id] = String.split(link, "=")
              {toggl_id, tt_id}
            end)
            # we're only touching those that originate from toggl
            |> Enum.filter(fn {toggl_id, _} -> toggl_id end)

          Logger.debug(
            "scraped the html, got #{length(entry_rows)} entries, #{length(entries)} from toggl."
          )

          {:ok, entries}

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          Logger.error("TT get time: #{status_code}")
          {:err, "err"}

        {:error, error} ->
          {:err, error}
      end

    res
  end

  def push_new_entry(cookies, form) do
    Logger.debug(Poison.encode!(form))
    # :hackney_trace.enable(:max, :io)

    form_for_sending =
      {:form,
       form
       |> Map.to_list()}

    res =
      case HTTPoison.post(
             "#{get_url()}/time.php",
             form_for_sending,
             %{},
             params: %{
               date: form["date"]
             },
             hackney: get_cookie_options(cookies)
           ) do
        {:ok, %HTTPoison.Response{status_code: 302, headers: _headers}} ->
          Logger.debug("TT post time: OK from timetracker.")

          {:ok, ""}

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          Logger.error("TT post time: #{status_code}")
          Logger.debug(body)
          {:error, "err"}

        {:error, error} ->
          {:error, error}
      end

    # :hackney_trace.disable()

    res
  end
end
