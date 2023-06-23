require 'colorize'

def print_info(msg)
  puts msg.green.bold
end

def print_warning(msg)
  puts msg.yellow.bold
end

def print_error(msg)
  puts msg.red.bold
end

def print_command(msg)
  puts msg.light_blue.bold
end