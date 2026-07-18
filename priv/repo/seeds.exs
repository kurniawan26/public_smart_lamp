alias SmartCityLamp.Devices.Device
alias SmartCityLamp.Accounts
alias SmartCityLamp.Repo

seed_admin? =
  if Code.ensure_loaded?(Mix) do
    Mix.env() != :prod or
      String.downcase(System.get_env("INIT_DEMO_DATA", "false")) in ~w(true 1 yes on)
  else
    String.downcase(System.get_env("INIT_DEMO_DATA", "false")) in ~w(true 1 yes on)
  end

admin_email = System.get_env("DEMO_ADMIN_EMAIL", "admin@smartlamp.local")
admin_password = System.get_env("DEMO_ADMIN_PASSWORD", "admin12345")
admin_name = System.get_env("DEMO_ADMIN_NAME", "Smart Lamp Administrator")

if seed_admin? and is_nil(Accounts.get_admin_by_email(admin_email)) do
  {:ok, _admin} =
    Accounts.create_admin(%{
      email: admin_email,
      password: admin_password,
      name: admin_name,
      role: :admin
    })
end

now = DateTime.utc_now()
installed_on = ~D[2025-01-15]

locations = [
  {"Monas North", "Jl. Medan Merdeka Utara", -6.1718, 106.8272},
  {"Monas South", "Jl. Medan Merdeka Selatan", -6.1794, 106.8277},
  {"Gambir Station", "Jl. Medan Merdeka Timur", -6.1767, 106.8306},
  {"Menteng Park", "Jl. HOS Cokroaminoto", -6.1963, 106.8296},
  {"Bundaran HI", "Jl. M.H. Thamrin", -6.1931, 106.823},
  {"Sarinah", "Jl. M.H. Thamrin No. 11", -6.1871, 106.8236},
  {"Dukuh Atas", "Jl. Jenderal Sudirman", -6.2048, 106.8224},
  {"Setiabudi", "Jl. Setiabudi Tengah", -6.2151, 106.8302},
  {"Kuningan West", "Jl. H.R. Rasuna Said", -6.2197, 106.8326},
  {"Kuningan East", "Mega Kuningan", -6.2285, 106.8277},
  {"Senayan Gate", "Jl. Asia Afrika", -6.2186, 106.8024},
  {"GBK North", "Pintu Satu Senayan", -6.2144, 106.807},
  {"Semanggi", "Simpang Susun Semanggi", -6.2196, 106.8148},
  {"SCBD Central", "Jl. Jenderal Sudirman Kav. 52", -6.2259, 106.8096},
  {"Pacific Place", "Jl. Jenderal Sudirman Kav. 52-53", -6.2253, 106.8108},
  {"Tebet Park", "Jl. Tebet Barat Raya", -6.2376, 106.8528},
  {"Cikini Station", "Jl. Pegangsaan Timur", -6.1986, 106.841},
  {"Tanah Abang", "Jl. Jatibaru Raya", -6.1851, 106.8108},
  {"Slipi Junction", "Jl. Letjen S. Parman", -6.2001, 106.7987},
  {"Kemang Junction", "Jl. Kemang Raya", -6.2607, 106.8132}
]

Enum.with_index(locations, 1)
|> Enum.each(fn {{name, address, latitude, longitude}, index} ->
  state =
    case index do
      number when number <= 15 ->
        %{}

      number when number in [16, 17] ->
        %{security_status: :warning, lamp_status: :flickering, brightness_level: 65}

      18 ->
        %{
          connectivity_status: :offline,
          lamp_status: :offline,
          brightness_level: 0,
          last_seen_at: DateTime.add(now, -300, :second)
        }

      19 ->
        %{security_status: :suspected_vandalism, lamp_status: :dimmed, brightness_level: 35}

      20 ->
        %{security_status: :critical, lamp_status: :power_failure, brightness_level: 0}
    end

  attrs =
    %{
      device_code: "LAMP-JKT-#{String.pad_leading(Integer.to_string(index), 3, "0")}",
      name: name,
      description: "Municipal smart LED street lamp",
      latitude: latitude,
      longitude: longitude,
      installation_address: address,
      installation_date: Date.add(installed_on, index),
      firmware_version: "1.0.#{rem(index, 4)}",
      last_seen_at: DateTime.add(now, -index * 2, :second)
    }
    |> Map.merge(state)

  %Device{}
  |> Device.changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :device_code)
end)
