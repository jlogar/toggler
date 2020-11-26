defmodule TogglerCli.App do
  require Logger

  def main(args) do
    options_def = [strict: [date: :string, dry_run: :boolean]]

    {options, argv, errors} = OptionParser.parse(args, options_def)
    # IO.inspect(args, label: "CLI args")

    # IO.puts(:stdio, "args: #{argv}")
    # IO.inspect(options, label: "CLI args")
    # [toggl_token: toggl_token] = options
    # IO.puts(:stdio, "date: #{options.date}")

    # IO.inspect(errors, label: "errors")
    # IO.inspect(argv, label: "argv")
    # IO.puts(:stdio, TogglerCli.hello())
    # expect input in the form "2020-11"
    [year, month] = options[:date] |> String.split("-")
    {iyear, _} = Integer.parse(year)
    {imonth, _} = Integer.parse(month)
    first_day = Date.new!(iyear, imonth, 1)
    last_day = Date.end_of_month(first_day)

    toggl_token = Application.get_env(:toggler_cli, :toggl_token)

    Logger.info("will go for: #{first_day} to #{last_day}.")
    TogglerCli.sync(toggl_token, first_day, last_day)
  end
end
