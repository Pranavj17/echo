defmodule NexusWeb.ClientmasterLive.Show do
  use NexusWeb, :live_view

  alias NexusWeb.Clientmaster.Components.{
    ScripboxHeaderLive,
    FamilyMembersLive,
    ProfileUpdatesLive,
    RegistrationBlockersLive,
    AdvisoryAgreementLive,
    BankAccountLive
  }

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       show_details: true,
       active_tab: "profile-updates",
       loading: false,
       query: "",
       member_attrs: %{},
       user_attrs: %{},
       family_members: [],
       member: nil,
       blockers: [],
       bank_account_attrs: %{},
       role: "admin"
     )}
  end

  def handle_event("toggle_details", _, socket) do
    {:noreply, assign(socket, show_details: !socket.assigns.show_details)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def render(assigns) do
    ~H"""
    <%= live_component(NexusWeb.LoaderLive,
      id: :loader,
      loading: @loading
    ) %>
    <.flash_group flash={@flash} />
    <%= live_component(ScripboxHeaderLive,
      id: :scripbox_header_component,
      query: @query
    ) %>
    <div class="px-5 py-2 flex justify-end">
      <button
        phx-click="toggle_details"
        class="flex items-center gap-2 text-white bg-gray-700 hover:bg-gray-600 px-3 py-2 rounded-lg shadow transition-colors duration-200"
        aria-label="Toggle details"
      >
        <!-- Chevron Icon -->
        <svg
          class={"h-5 w-5 transition-transform duration-300 ease-in-out #{if @show_details, do: "", else: "rotate-180"}"}
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
        </svg>
        <!-- Dynamic label -->
        <span><%= if @show_details, do: "Hide", else: "Show" %></span>
      </button>
    </div>
    <div id="member-user-wrapper" class={"px-5 py-2 flex space-x-6 #{unless @show_details, do: "hidden"}"}>
      <div class="w-2/3">
        <div class="bg-gray-800 shadow-md rounded-lg p-6 mb-2">
          <h2 class="text-xl font-bold text-white mb-4">Member</h2>
          <div class="grid grid-cols-2 gap-6 divide-x divide-gray-600 bg-gray-900 rounded-lg shadow-md p-6">
            <div class="pr-6 space-y-4">
              <%= for {{key, value}, index} <- Enum.with_index(Enum.to_list(@member_attrs)), rem(index, 2) == 0 do %>
                <p class="text-base text-gray-300">
                  <strong><%= humanize(key) %>:</strong> <%= value %>
                </p>
              <% end %>
            </div>
            <div class="pl-6 space-y-4">
              <%= for {{key, value}, index} <- Enum.with_index(Enum.to_list(@member_attrs)), rem(index, 2) == 1 do %>
                <p class="text-base text-gray-300">
                  <strong><%= humanize(key) %>:</strong> <%= value %>
                </p>
              <% end %>
            </div>
          </div>
        </div>
        <div class="bg-gray-800 shadow-md rounded-lg p-6">
          <h2 class="text-xl font-bold text-white mb-4">User</h2>
          <div class="grid grid-cols-2 gap-6 divide-x divide-gray-600 bg-gray-900 rounded-lg shadow-md p-6">
            <div class="pr-6 space-y-4">
              <%= for {{key, value}, index} <- Enum.with_index(Enum.to_list(@user_attrs)), rem(index, 2) == 0 do %>
                <p class="text-base text-gray-300">
                  <strong><%= humanize(key) %>:</strong> <%= value %>
                </p>
              <% end %>
            </div>
            <div class="pl-6 space-y-4">
              <%= for {{key, value}, index} <- Enum.with_index(Enum.to_list(@user_attrs)), rem(index, 2) == 1 do %>
                <p class="text-base text-gray-300">
                  <strong><%= humanize(key) %>:</strong> <%= value %>
                </p>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      <div class="w-1/3">
        <%= live_component(FamilyMembersLive,
          id: :family_member_component,
          family_members: @family_members
        ) %>
      </div>
    </div>
    <%= if @role == "admin" do %>
      <div class="px-5 py-2">
        <div class="bg-gray-800 shadow-md rounded-lg p-6">
          <div class="grid grid-cols-4 gap-4 mb-4">
            <button
              phx-click="switch_tab"
              phx-value-tab="profile-updates"
              class={"w-full px-4 py-2 rounded-lg shadow-md transition-colors duration-300 #{if @active_tab == "profile-updates", do: "bg-blue-500 text-white", else: "bg-gray-700 text-white hover:bg-blue-600"}"}
            >
              Profile
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="blockers"
              class={"w-full px-4 py-2 rounded-lg shadow-md transition-colors duration-300 #{if @active_tab == "blockers", do: "bg-blue-500 text-white", else: "bg-gray-700 text-white hover:bg-blue-600"}"}
            >
              Blockers
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="advisory-agreement"
              class={"w-full px-4 py-2 rounded-lg shadow-md transition-colors duration-300 #{if @active_tab == "advisory-agreement", do: "bg-blue-500 text-white", else: "bg-gray-700 text-white hover:bg-blue-600"}"}
            >
              Advisory Agreement
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="bank-account"
              class={"w-full px-4 py-2 rounded-lg shadow-md transition-colors duration-300 #{if @active_tab == "bank-account", do: "bg-blue-500 text-white", else: "bg-gray-700 text-white hover:bg-blue-600"}"}
            >
              Bank Account
            </button>
          </div>
          <div id="tab-content">
            <div class={if @active_tab == "profile-updates", do: "", else: "hidden"}>
              <%= live_component(ProfileUpdatesLive,
                id: :profile_updates_component,
                member: @member
              ) %>
            </div>
            <div class={if @active_tab == "blockers", do: "", else: "hidden"}>
              <%= live_component(RegistrationBlockersLive,
                id: :registration_blockers_component,
                blockers: @blockers
              ) %>
            </div>
            <div class={if @active_tab == "advisory-agreement", do: "", else: "hidden"}>
              <%= live_component(AdvisoryAgreementLive,
                id: :advisory_agreement_component,
                member: @member
              ) %>
            </div>
            <div class={if @active_tab == "bank-account", do: "", else: "hidden"}>
              <%= live_component(BankAccountLive,
                id: :bank_account_component,
                bank_account: @bank_account_attrs
              ) %>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
