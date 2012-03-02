require 'logger'
require 'swift'

class AutoMigrate
  attr_reader :path, :logger

  def initialize path
    @path   = path
    @logger = Logger.new($stderr, 0)
  end

  def run
    setup
    completed = completed_migrations
    Swift.db.transaction do |db|
      migrations.reject {|path| completed.include?(File.basename(path))}.each do |path|
        logger.info "running migration: #{File.basename(path)}"
        runner = define_class(path).new
        begin
          runner.run
        rescue => e
          logger.error '%s - %s' [e.message, e.backtrace.join("\n")]
          runner.teardown if runner.respond_to?(:teardown)
          exit
        end
        db.execute('insert into schema_migrations(name) values(?)', File.basename(path))
      end
    end
  end

  private

  def setup
    begin
      Swift.db.execute('select * from schema_migrations limit 0')
    rescue
      Swift.db.execute <<-SQL
        create table schema_migrations(
          id serial primary key,
          name text,
          created_at timestamp with time zone not null default now()
        )
      SQL
    end
  end

  def migrations
    Dir["#{path}/*.{sql,rb}"]
  end

  def completed_migrations
    Swift.db.execute('select name from schema_migrations').map {|r| r[:name]}
  end

  def define_class file
    case File.extname(file)
      when '.rb'  then define_class_for_ruby(file)
      when '.sql' then define_class_for_sql(file)
      else        raise NotImplementedError, "unsupported file: #{file}"
    end
  end

  def define_class_for_ruby file
    klass = Class.new
    klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
      #{File.read(file)}
    RUBY
    raise ArgumentError, "ruby migration does not define a 'run' method" unless klass.new.respond_to?(:run)
    klass
  end

  def define_class_for_sql file
    klass = Class.new
    klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def run
        Swift.db.execute(File.read('#{file}'))
      end
    RUBY
    klass
  end
end
