require 'rubygems'
require 'bluepill'
require 'logger'
require 'yaml'

config_path = "/etc/thin"
app_short_name = "whatever"

File.open("/proc/meminfo").each do |line|
  if /^MemTotal:\s+(\d+) (.+)$/.match(line)
    $memory = $1.to_i
  end
end

Dir[config_path + "/*.yml"].each do |file|
  config = YAML.load_file(file)
  num_servers = config["servers"] ||= 1
  mem_per_instance = (($memory - ($memory * 0.2)) / num_servers)
  Bluepill.application(app_short_name.to_sym, :log_file => "#{config["chdir"]}/log/bluepill.log") do
    num_servers.times do |i|
      port = config["port"] + i
      process("thin-#{i}") do
        pid_file config["chdir"] + "/tmp/pids/thin.#{port}.pid"
        puts pid_file
        working_dir config["chdir"]

        start_command "bundle exec thin start -C #{file} -o #{port}"
        stop_command "kill -9 {{PID}}"
        #stop_signals = [:kill]
        #stop_command "bundle exec thin stop -C #{file} -o #{port}"

        start_grace_time 15.seconds
        restart_grace_time 20.seconds
        stop_grace_time 15.seconds

        checks :mem_usage, :every => 5.minutes, :below => mem_per_instance.kilobytes, :times => [3,5]
      end
    end
  end
end
