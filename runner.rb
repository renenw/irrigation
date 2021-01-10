require 'json'
require 'syslog/logger'
require "uri"
require "net/http"
# require 'date'

@log = Syslog::Logger.new 'IRRIGATION_RUNNER'

INSTRUCTIONS_DIRECTORY            = '/home/pi/irrigation_instructions'
SWITCHER_URL                      = 'http://192.168.0.203/'
RAINY_DAY_PRECIPITATION_THRESHOLD = 2.5
CONFIG                            = JSON.parse(File.read('/home/pi/irrigation/config.json'))

# Based instructions in the IRRIGATION_INSTRUCTIONS directory....
# Trigger irrigations if conditions allow (not conditions may be ignored using the ignore parameter):
#   windy:        wait to see if the weather improves
#   hot:          wait for it to cool down
#   wet:          bin the instruction
#   time_of_day:  by default, don't run during the middle of the day

def process_instructions
  instructions = Dir.children(INSTRUCTIONS_DIRECTORY)
  log("#{instructions.count} instructions found.")
  rule_params  = initialise_rules  if !instructions.empty?
  Dir.children(INSTRUCTIONS_DIRECTORY).each do |file|
    file_name   = "#{INSTRUCTIONS_DIRECTORY}/#{file}"
    instruction = JSON.parse(File.read(file_name), symbolize_names: true)
    process_instruction(file_name, instruction, rule_params)
  end
end

def process_instruction(file_name, instruction, rule_params)
  if allowed_to_run?(instruction, rule_params)
    if rule_params[:running]
      log("Currently irrigating. Skipping #{instruction[:circuit_name]} for now.")
    else
      rule_params[:running] = true
      trigger_circuit(instruction)
      File.delete(file_name)
    end
  else
    # if this instruction has been blocked because it is wet, delete the instruction
    if rule_params[:wet] && (instruction[:ignore] || []).include?('wet')
      log("Its wet, so not going to run #{instruction[:circuit_name]}.")
      File.delete(file_name)
    end
  end
end

def trigger_circuit(instruction)

  circuit  = instruction[:circuit_name]
  duration = instruction[:duration_seconds]
  switch   = CONFIG[circuit]

  if switch
    url      = URI("#{SWITCHER_URL}on?switch=#{switch}&duration=#{duration}")
    http     = Net::HTTP.new(url.host, url.port);
    request  = Net::HTTP::Get.new(url)
    response = http.request(request)
    response.read_body
    log("#{circuit} (switch #{switch}) switched on for #{duration} seconds.")
  else
    log("Switch number not found: #{circuit}")
  end

end

def delete_instruction(file_name)
  File.delete(file_name)
end

def allowed_to_run?(instruction, rule_params)
  run    = !rule_params[:running]
  if run
    ignore = instruction[:ignore] || []
    if ignore!='all'
      assess = (rule_params.keys - ignore.map(&:to_sym) )
      if !assess.empty?
        run = !rule_params.fetch_values( *assess ).any?
        if !run
          log(instruction[:circuit_name] + ': ' + rule_params.select { |k,v| v && assess.include?(k) }.keys.join(', ') + ' block from running.')
        end
      end
    end
  end
  run
end

def main
  if are_there_any_instructions?
    if are_any_circuits_running?
      log('Irrigation currently running. Not going to process any instructions.')
    else
      process_instructions
    end
  else
    log('No instructions to process.')
  end
end

def initialise_rules
  {
    running:     false,
    time_of_day: (8..14).include?(Time.now.utc.hour),
  }.merge(weather_rules)
end

def weather_rules

  weather = load_current_weather

  windy   = (weather[:hourly][:wind_speed][0]   >  5)
  hot     = (weather[:hourly][:temperatures][0] > 30)

  wet     = false
  wet     = true  if weather[:today][:precipitation]      > RAINY_DAY_PRECIPITATION_THRESHOLD
  wet     = true  if weather[:three_days][:precipitation] > RAINY_DAY_PRECIPITATION_THRESHOLD * 2
  wet     = true  if weather[:week][:precipitation]       > RAINY_DAY_PRECIPITATION_THRESHOLD * 4

  {
    windy:  windy,
    hot:    hot,
    wet:    wet,
  }

end


def load_current_weather
  source  = `ruby /home/pi/yr_parser/yr.rb --latitude -33.95283 --longitude 18.48056 --msl 11`
  weather = JSON.parse(source, symbolize_names: true)
end


def are_any_circuits_running?
  !(request_switcher_status=~/^Switch:\s\d+:\sOn/).nil?
end

def are_there_any_instructions?
  (Dir.children(INSTRUCTIONS_DIRECTORY).count > 0)
end

def request_switcher_status
  url      = URI(SWITCHER_URL)
  http     = Net::HTTP.new(url.host, url.port);
  request  = Net::HTTP::Get.new(url)
  response = http.request(request)
  response.read_body
end


def log(line)
  @log.info(line)
end

main
