# frozen_string_literal: true

require "active_support/all"
require "active_model"
require "bcdd/result"

module Solid
  require "solid/input"
  require "solid/result"

  class Process
    require "solid/process/version"
    require "solid/process/error"
    require "solid/process/caller"
    require "solid/process/callbacks"
    require "solid/process/class_methods"
    require "solid/process/active_record"

    extend ClassMethods

    include Callbacks
    include ::BCDD::Context.mixin(config: {addon: {continue: true}})

    def self.inherited(subclass)
      super

      subclass.prepend(Caller)
    end

    def self.call(arg = nil)
      new.call(arg)
    end

    attr_reader :output, :input, :dependencies

    def initialize(arg = nil)
      self.dependencies = arg
    end

    def call(_arg = nil)
      raise Error, "#{self.class}#call must be implemented."
    end

    def with(dependencies)
      self.class.new(dependencies.with_indifferent_access.with_defaults(deps&.attributes))
    end

    def new(dependencies = {})
      with(dependencies)
    end

    def input?
      !input.nil?
    end

    def output?(type = nil)
      type.nil? ? !output.nil? : !!output&.is?(type)
    end

    def dependencies?
      !dependencies.nil?
    end

    def success?(type = nil)
      !!output&.success?(type)
    end

    def failure?(type = nil)
      !!output&.failure?(type)
    end

    def inspect
      "#<#{self.class.name} dependencies=#{dependencies.inspect} input=#{input.inspect} output=#{output.inspect}>"
    end

    def method_missing(name, *args, &block)
      name.end_with?("?") ? output&.is?(name.to_s.chomp("?")) : super
    end

    def respond_to_missing?(name, include_private = false)
      name.end_with?("?") || super
    end

    alias_method :deps, :dependencies
    alias_method :deps?, :dependencies?
    alias_method :result, :output
    alias_method :result?, :output?

    private

    def dependencies=(arg)
      raise Error, "The `#{self.class}#dependencies` is already set." unless dependencies.nil?

      @dependencies = self.class.dependencies&.then { arg.instance_of?(_1) ? arg : _1.new(arg) }
    end

    def input=(arg)
      raise Error, "The `#{self.class}#input` is already set." unless input.nil?

      @input = self.class.input.then { arg.instance_of?(_1) ? arg : _1.new(arg) }
    end

    def output_already_set!
      raise Error, "The `#{self.class}#output` is already set. " \
                   "Use `.output` to access the result or create a new instance to call again."
    end

    def output=(result)
      output_already_set! unless output.nil?

      raise Error, "The result #{result.inspect} must be a BCDD::Context." unless result.is_a?(::BCDD::Context)

      @output = result
    end
  end
end
