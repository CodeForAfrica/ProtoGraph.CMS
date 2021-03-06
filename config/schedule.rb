# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
set :output, {:error => "log/cron_error_log.log", :standard => "log/cron_log.log"}
every 6.hours do
  rake "piwik:fetch_metrics"
end

# Learn more: http://github.com/javan/whenever
every 2.hours do
    runner "ViewCast.create_missing_images"
end