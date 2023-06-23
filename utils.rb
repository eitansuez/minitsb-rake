require 'open3'

module Utils

  def wait_for(command, msg=nil)
    if msg
      log.info "waiting for #{msg}"
    end

    output, status = Open3.capture2(command)
    until status.success?
      sleep 1
      print "."
      output, status = Open3.capture2(command)
    end

    log.info "condition passed"
  end

end