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

    Logger.info("Timetracker login...")
    {:ok, session_id} = Timetracker.get_session_id()
    {:ok, cookies} = Timetracker.login_session(session_id)
    Logger.info("Getting projects from timetracker...")
    {:ok, [{:projects, tt_projects}, {:tasks, tt_tasks}]} = Timetracker.get_projects(cookies)

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

    Logger.info("Mapping to form keyw. maps...")

    _form_maps =
      new_entries
      |> Enum.map(fn t_entry ->
        pid = t_entry["pid"]
        project = get_mapping_project(projects, toggl_projects, tasks, pid)

        tt_project_task =
          with {:ok, tt_project} <- get_tt_project(project, tt_projects),
               {:ok, tt_task} <- get_tt_task(project, tt_tasks) do
            {:ok, {tt_project, tt_task}}
          end

        map_to_form(tt_project_task, t_entry)
      end)
  end

  defp map_to_form({:ok, {tt_project, tt_task}}, t_entry) do
    {:ok, entry_start, _} = DateTime.from_iso8601(t_entry["start"])
    {:ok, entry_stop, _} = DateTime.from_iso8601(t_entry["stop"])

    {tt_project_id, _} = tt_project
    {tt_task_id, _} = tt_task

    duration =
      ((DateTime.diff(entry_stop, entry_start) / 3600)
       |> Decimal.from_float()
       |> Decimal.round(2)
       |> Decimal.to_string()
       |> String.replace(".", ",")) <> "h"

    %{
      "project" => tt_project_id,
      "task" => tt_task_id,
      "duration" => duration,
      "date" => Date.to_string(DateTime.to_date(entry_start)),
      "note" => "#{t_entry["description"]} [[#{t_entry["id"]}]]",
      "btn_submit" => "Submit",
      "browser_today" => Date.to_string(Date.utc_today())
    }
  end

  defp map_to_form({:error, error}, _), do: {:error, error}

  defp get_tt_project({:ok, {project, _task}}, tt_projects) do
    [p_1, p_2] = project

    case Enum.find(tt_projects, nil, fn {_id, name} ->
           name == p_2 <> " - " <> p_1
         end) do
      nil -> {:error, "project not found"}
      tt_project -> {:ok, tt_project}
    end
  end

  defp get_tt_project({:error, error}, _), do: {:error, error}

  defp get_tt_task({:ok, {_project, task}}, tt_tasks) do
    [t_1, t_2] = task

    case Enum.find(tt_tasks, nil, fn {_index, name} ->
           name == t_2 <> " - " <> t_1
         end) do
      nil -> {:error, "task not found"}
      tt_task -> {:ok, tt_task}
    end
  end

  defp get_tt_task({:error, error}, _), do: {:error, error}

  defp get_mapping_project(projects, toggl_projects, tasks, toggl_pid) do
    toggl_project_name = toggl_projects[toggl_pid]

    case projects[toggl_project_name] do
      nil ->
        case String.split(toggl_project_name, "/") do
          ["general", task_name] -> {:ok, {projects["general"], tasks[task_name]}}
          _ -> {:error, "no project found for #{toggl_project_name}"}
        end

      [name, code] ->
        {:ok, {[name, code], tasks["swdev"]}}
    end
  end
end
