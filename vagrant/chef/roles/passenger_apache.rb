name 'passenger_apache'
description 'A default role for passenger through apache.'

run_list([
  'recipe[passenger_apache2]',
  'recipe[passenger_apache2::mod_rails]'
])

# TODO check how many of these are now deprecated? https://github.com/opscode-cookbooks/passenger_apache2/blob/master/attributes/default.rb
default_attributes(
    passenger: {
      version: '4.0.50',

      # explicitly set the path so it know which ruby to use
      #:root_path => "/opt/rbenv/shims",

      # Run all passengers processes as the apache user.
      user_switching: false,
      default_user: 'apache',

      # Disable friendly error pages by default.
      friendly_error_pages: false,

      # Allow more application instances.
      max_pool_size: 16,

      # Ensure this is less than :max_pool_size, so there's always room for all
      # other apps, even if one app is popular.
      max_instances_per_app: 6,

      # Keep at least one instance running for all apps.
      min_instances: 1,

      # Increase an instance idle time to 15 minutes.
      pool_idle_time: 900,

      # Keep the spanwers alive indefinitely, so new app processes can spin up
      # quickly.
      rails_framework_spawner_idle_time: 0, # Not actually used since we use smart-lv2 spawning?
      rails_app_spawner_idle_time: 0
    }
)
