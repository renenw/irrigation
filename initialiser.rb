require 'json'
require 'syslog/logger'
require 'date'

@log = Syslog::Logger.new 'IRRIGATION_INITIALISER'

INSTRUCTIONS_DIRECTORY = '/home/pi/irrigation_instructions'

CIRCUITS               = %w(pond_ferns front_misters front front_fynbos outhouse_lawn driveway vegetable_patch jungle_gym pool_beds pool_lawn pool front_lawn trees)

# Based on day, write an instruction to the IRRIGATION_INSTRUCTIONS directory.
# Instruction indicates that, if conditions allow, irrigation should be triggered.
# Instruction parameters include:
#   duration_seconds: run the irrigation for this number of seconds
#   circuit_name: the circuit to be run
#   ignore: %w(wind wet temperature time_of_day): override rules so that circuit triggers irrespective of, for example, wether the wind is blowing

def main
  CIRCUITS.map(&:to_sym).each do |circuit|
    instruction = self.send(circuit)                                                 if respond_to?(circuit, true)
    write({ circuit_name: circuit, created_at: Time.new.ctime }.merge(instruction))  if instruction
    log("#{circuit} instruction created.")                                           if instruction
  end
end


def pond_ferns
  {
    duration_seconds: 180,
    description:      'Next to pond, under yellow wood (daily) [6]',
    ignore:           'all',
  }
end

def front_misters
  {
    duration_seconds: 180,
    description:      'Next to driveway, under jacaranda (daily) [2]',
    ignore:           'all',
  }
end

def front_lawn
  {
    duration_seconds: 1200,
    description:      'Front lawn (every third day) [4]',
  } if is_day_n?(3)
end

def outhouse_lawn
  {
    duration_seconds: 1200,
    description:      'Outhouse lawn (every third day) [10]',
  } if is_day_n?(3)

end

def front
  {
    duration_seconds: 1200,
    description:      'Front Beds, under jacaranda (every third day) [1]',
  }  if is_day_n?(3)
end

def front_fynbos
  {
    duration_seconds: 1200,
    description:      'Front beds round pond and in front of house (every third day) [0]',
  }  if is_day_n?(3)
end

def pool_beds
  {
    duration_seconds: 1200,
    description:      'Beds down past pool (every third day) [5]',
  }  if is_day_n?(3)
end

def driveway
  {
    duration_seconds: 1200,
    description:      'Driveway flower beds (every third day) [14]',
  }  if is_day_n?(3)
end


def write(instruction)
  File.write("#{INSTRUCTIONS_DIRECTORY}/#{instruction[:circuit_name]}.json", instruction.to_json)
end

def log(line)
  @log.info(line)
end

def is_day_of_week?(days)
  days.include?(Time.new.strftime('%A').downcase)
end

# if n==3, returns true every third day.
def is_day_n?(n)
  (Time.new.yday % n)==0
end

def test
  pp 'day of week'
  pp is_day_of_week?(%w(monday))
  pp 'every 3rd day'
  pp is_day_n?(3)
  pp 'every 2nd day'
  pp is_day_n?(2)
end

main
