
require './colorprint.rb'

def wait_for(command, msg=nil)
  if msg
    print_info "waiting for #{msg}"
  end

  `#{command}`
  until $?.success?
    sleep 1
    print "."
    `#{command}`
  end

  print_info "condition passed"
end
