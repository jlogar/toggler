defmodule PhoenixPocWeb.Router do
  use PhoenixPocWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixPocWeb do
    pipe_through :browser

    get "/", PageController, :index
    post "/do", PageController, :process_form
  end

  # Other scopes may use custom stacks.
  scope "/api", PhoenixPocWeb do
    pipe_through :api

    get "/", ApiController, :get
  end
end
