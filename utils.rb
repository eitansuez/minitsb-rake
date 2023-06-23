
module Utils

  def wait_for(command, msg=nil)
    if msg
      log.info "waiting for #{msg}"
    end

    `#{command}`
    until $?.success?
      sleep 1
      print "."
      `#{command}`
    end

    log.info "condition passed"
  end

end