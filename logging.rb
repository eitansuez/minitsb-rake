require 'logger'
require 'colorize'

module Logging
  def log
    Logging.log
  end

  def self.log
    @log ||= Logger.new(STDOUT, formatter: proc {|severity, datetime, progname, msg|
      color = if severity == "DEBUG"
          :white
        elsif severity == "INFO"
          :green
        elsif severity == "WARN"
          :yellow
        elsif severity == "ERROR"
          :red
        else
          :light_blue
        end
      sprintf("%s: %s\n", datetime.strftime('%Y-%m-%d %H:%M:%S'), msg.colorize(color: color, mode: :bold))
    })
  end
end