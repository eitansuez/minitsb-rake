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

  def run_command(cmd)
    Open3.popen2(cmd) do |stdin, stdout, thread|
      stdout.each_line do |line|
        puts "> " + line
      end
      raise "Command failed"  unless thread.value.success?
    end
  end

end