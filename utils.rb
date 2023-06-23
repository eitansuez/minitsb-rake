
require './logger.rb'

def wait_for(command, msg=nil)
  if msg
    Logger.instance.info "waiting for #{msg}"
  end

  `#{command}`
  until $?.success?
    sleep 1
    print "."
    `#{command}`
  end

  Logger.instance.info "condition passed"
end
