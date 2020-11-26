defmodule TogglerCli.Toggl do
  require Logger
  require Jason

  def toggl_url, do: "https://toggl.com/api/v8"

  def get_time_entries(toggl_api_token, date_from, date_to) do
    base64_token = Base.encode64("#{toggl_api_token}:api_token")

    res =
      case HTTPoison.get(
             "#{toggl_url()}/time_entries",
             [
               Authorization: "Basic #{base64_token}"
             ],
             params: %{
               start_date: DateTime.to_iso8601(date_from),
               end_date: DateTime.to_iso8601(date_to)
             }
           ) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          Logger.debug("OK from toggl.")
          {:ok, Poison.decode!(body)}

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          Logger.error("#{status_code}")
          {:err, status_code}

        {:error, _} ->
          {:err, :unknown}
      end

    res
  end

  def get_projects(toggl_api_token, workspace_id) do
    base64_token = Base.encode64("#{toggl_api_token}:api_token")

    res =
      case HTTPoison.get(
             "#{toggl_url()}/workspaces/#{workspace_id}/projects",
             Authorization: "Basic #{base64_token}"
           ) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          Logger.debug("OK from toggl.")
          projects = Poison.decode!(body)
          projects_by_id = projects |> Map.new(fn project -> {project["id"], project["name"]} end)
          {:ok, projects_by_id}

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          Logger.error("#{status_code}")
          {:err, status_code}

        {:error, _} ->
          {:err, :unknown}
      end

    res
  end
end
