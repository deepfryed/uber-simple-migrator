#!/usr/bin/env ruby

require 'auto_migrate'

Swift.setup :default, Swift::DB::Postgres, db: 'test'

Swift.db.execute('drop schema public cascade')
Swift.db.execute('create schema public')

AutoMigrate.new('migrations').run
