defmodule Bonfire.Me.Web.HeroProfileLive do
  use Bonfire.Web, :live_component


  def render(assigns) do
    ~L"""
      <div class="mainContent__hero">
        <div class="hero__image">
          <img alt="background image" src="<%= @current_user.image_url %>" />
        </div>
        <div class="hero__info">
          <div class="info__icon">
            <img alt="profile pic" src="<%= @current_user.icon_url %>" />
          </div>
          <div class="info__meta">
            <h1><%= @current_user.name %></h1>
            <h4 class="info__username"><%= @current_user.username %></h4>
            <div class="info__details">
            <%= if @current_user.website do %>
              <div class="details__meta">
                <a href="#" target="_blank">
                  <i class="feather-external-link"></i>
                  <%= @current_user.website %>
                </a>
              </div>
              <% end %>
              <%= if @current_user.location do %>
                <div class="details__meta">
                  <i class="feather-map-pin"></i><%= @current_user.location %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    """
  end
end
