require 'colorize'
require 'singleton'

class Logger
  include Singleton

  @@LEVELS = { debug: 0, info: 1, warn: 2, error: 3 }

  def initialize()
    @level = :info
  end

  attr_accessor :level

  def debug(msg)
    puts msg.white.bold if @@LEVELS[:debug] >= @@LEVELS[@level]
  end

  def info(msg)
    puts msg.green.bold if @@LEVELS[:info] >= @@LEVELS[@level]
  end

  def warn(msg)
    puts msg.yellow.bold if @@LEVELS[:warn] >= @@LEVELS[@level]
  end

  def error(msg)
    puts msg.red.bold if @@LEVELS[:error] >= @@LEVELS[@level]
  end

end