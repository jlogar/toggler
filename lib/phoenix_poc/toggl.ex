defmodule PhoenixPocWeb.Toggl do
  @toggl_url "https://toggl.com/api/v8"

  def toggl_url, do: @toggl_url

  def get_time_entries(toggl_api_token, date_from, date_to) do
    base64_token = Base.encode64("#{toggl_api_token}:api_token")

    case HTTPoison.get(
           "#{@toggl_url}/time_entries",
           ["Content-Type": "application/json", Authorization: "Basic #{base64_token}"],
           [{:parameters, [{"start_date", date_from}, {"end_date", date_to}]}]
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:err, status_code}

      {:error, _} ->
        {:err, :unknown}
    end
  end
end
