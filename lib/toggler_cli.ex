defmodule TogglerCli do
  require Logger
  alias TogglerCli.Toggl
  alias TogglerCli.Timetracker

  def sync(toggl_token, first_day, last_day) do
    projects = Application.get_env(:toggler_cli, :projects)
    tasks = Application.get_env(:toggler_cli, :tasks)
    Logger.debug("projects mapping size: #{map_size(projects)}")
    Logger.debug("taks mapping size: #{map_size(tasks)}")

    f_midnight = DateTime.new!(first_day, ~T[00:00:00], "Etc/UTC")
    l_midnight = DateTime.new!(last_day, ~T[00:00:00], "Etc/UTC")

    dates = Date.range(first_day, last_day)
    Logger.info("Getting projects from toggl...")

    {:ok, toggl_projects} =
      Toggl.get_projects(toggl_token, Application.get_env(:toggler_cli, :workspace_id))

    Logger.debug(
      "toggl projects (#{map_size(toggl_projects)}):\n" <>
        (toggl_projects
         |> Enum.map(fn {k, v} -> "#{k}:\t#{v}" end)
         |> Enum.join("\n"))
    )

    Logger.info("Getting entries from toggl...")
    {:ok, toggl_entries} = Toggl.get_time_entries(toggl_token, f_midnight, l_midnight)

    Logger.debug(
      toggl_entries
      |> Enum.map(&"[[#{&1["id"]}]]: #{&1["description"]}")
      |> Enum.join("\n")
    )

    {:ok, session_id} = Timetracker.get_session_id()
    {:ok, cookies} = Timetracker.login_session(session_id)
    Logger.info("Getting projects from timetracker...")
    {:ok, _projects} = Timetracker.get_projects(cookies)

    Logger.info("Getting entries from timetracker...")

    tt_entries =
      dates
      |> Enum.map(fn date -> Timetracker.get_daily_tasks(cookies, date) end)
      |> Enum.flat_map(fn {:ok, elts} -> elts end)
      |> Map.new()

    existing =
      toggl_entries
      |> Enum.filter(fn t_entry -> Map.has_key?(tt_entries, Integer.to_string(t_entry["id"])) end)

    new_entries = toggl_entries -- existing

    Logger.info(
      "got #{length(toggl_entries)} toggl & #{map_size(tt_entries)} timetracker entries, #{
        length(existing)
      } previously synced & #{length(new_entries)} to sync."
    )

    new_entries
    |> Enum.map(fn t_entry ->
      pid = t_entry["pid"]
      toggl_project_name = toggl_projects[pid]

      _pmap =
        case projects[toggl_project_name] do
          nil ->
            case String.split(toggl_project_name, "/") do
              ["general", task_name] -> {:ok, {projects["general"], tasks[task_name]}}
              _ -> {:error, "no project found for #{toggl_project_name}"}
            end

          [name, code] ->
            {:ok, {{name, code}, tasks["swdev"]}}
        end

      # IO.inspect(pmap, label: "project")
    end)
  end
end
