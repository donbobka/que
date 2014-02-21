require 'socket' # For Socket.gethostname

module Que
  autoload :Job,         'que/job'
  autoload :JobQueue,    'que/job_queue'
  autoload :Locker,      'que/locker'
  autoload :Migrations,  'que/migrations'
  autoload :Pool,        'que/pool'
  autoload :ResultQueue, 'que/result_queue'
  autoload :SQL,         'que/sql'
  autoload :Version,     'que/version'
  autoload :Worker,      'que/worker'

  begin
    require 'multi_json'
    JSON_MODULE = MultiJson
  rescue LoadError
    require 'json'
    JSON_MODULE = JSON
  end

  class << self
    attr_accessor :logger, :error_handler, :mode
    attr_writer :pool, :log_formatter

    def connection_proc=(connection_proc)
      @pool = connection_proc && Pool.new(connection_proc)
    end

    def pool
      @pool || raise("Que connection not established!")
    end

    def clear!
      execute "DELETE FROM que_jobs"
    end

    def job_stats
      execute :job_stats
    end

    def job_states
      execute :job_states
    end

    # Give us a cleaner interface when specifying a job_class as a string.
    def enqueue(*args)
      Job.enqueue(*args)
    end

    def db_version
      Migrations.db_version
    end

    def migrate!(version = {:version => Migrations::CURRENT_VERSION})
      Migrations.migrate!(version)
    end

    # Have to support create! and drop! in old migrations. They just created
    # and dropped the bare table.
    def create!
      migrate! :version => 1
    end

    def drop!
      migrate! :version => 0
    end

    def log(data)
      level = data.delete(:level) || :info
      data = {:lib => 'que', :hostname => Socket.gethostname, :thread => Thread.current.object_id}.merge(data)

      if logger && output = log_formatter.call(data)
        logger.send level, output
      end
    end

    def log_formatter
      @log_formatter ||= JSON_MODULE.method(:dump)
    end

    # Copy some methods on the connection pool wrapper here for convenience.
    [:execute, :checkout, :in_transaction?].each do |meth|
      define_method(meth) { |*args, &block| pool.send(meth, *args, &block) }
    end
  end
end

require 'que/railtie' if defined? Rails::Railtie
