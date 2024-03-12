# frozen_string_literal: true

require "test_helper"

class Solid::Process::ProcessInstanceTest < ActiveSupport::TestCase
  def setup
    ::User.delete_all
  end

  test "#input" do
    user_creation1 = UserCreation.new

    assert_nil user_creation1.input

    user_creation1.call(name: "\tJohn     Doe \n", email: "   JOHN.doe@email.com", password: "123123123")

    assert_match(TestUtils::UUID_REGEX, user_creation1.input.uuid)
    assert_equal("John Doe", user_creation1.input.name)
    assert_equal("john.doe@email.com", user_creation1.input.email)

    # ---

    user_creation2 = UserCreation.new

    assert_nil user_creation2.input

    user_creation2.call(uuid: "", name: nil, email: nil)

    refute_match(TestUtils::UUID_REGEX, user_creation2.input.uuid)
    assert_nil user_creation2.input.name
    assert_nil user_creation2.input.email
  end

  test "#input?" do
    user_creation1 = UserCreation.new

    refute_predicate user_creation1, :input?

    user_creation1.call(name: "\tJohn     Doe \n", email: "   JOHN.doe@email.com", password: "123123123")

    assert_predicate user_creation1, :input?

    # ---

    user_creation2 = UserCreation.new

    refute_predicate user_creation2, :input?

    user_creation2.call(uuid: "", name: nil, email: nil)

    assert_predicate user_creation2, :input?
  end

  test "#output" do
    user_creation1 = UserCreation.new

    assert_nil user_creation1.output
    assert_nil user_creation1.result

    result = user_creation1.call(name: "John Doe", email: "   JOHN.doe@email.com", password: "123123123")

    assert_same result, user_creation1.output
    assert_same result, user_creation1.result

    # ---

    user_creation2 = UserCreation.new

    assert_nil user_creation2.output
    assert_nil user_creation2.result

    result = user_creation2.call(uuid: "", name: nil, email: nil)

    assert_same result, user_creation2.output
    assert_same result, user_creation2.result
  end

  test "#output?" do
    user_creation1 = UserCreation.new

    refute_predicate user_creation1, :output?
    refute_predicate user_creation1, :result?

    refute user_creation1.output?(:user_created)
    refute user_creation1.result?(:user_created)

    user_creation1.call(name: "John Doe", email: "john.doe@email.com", password: "123123123")

    assert_predicate user_creation1, :output?
    assert_predicate user_creation1, :result?

    assert user_creation1.output?(:user_created)
    assert user_creation1.result?(:user_created)

    # ---

    user_creation2 = UserCreation.new

    refute_predicate user_creation2, :output?
    refute_predicate user_creation2, :result?

    refute user_creation2.output?(:invalid_input)
    refute user_creation2.result?(:invalid_input)

    user_creation2.call(uuid: "", name: nil, email: nil)

    assert_predicate user_creation2, :output?
    assert_predicate user_creation2, :result?

    assert user_creation2.output?(:invalid_input)
    assert user_creation2.result?(:invalid_input)
  end

  test "#dependencies" do
    user_creation1 = UserCreation.new

    assert_nil(user_creation1.dependencies)
    assert_nil(user_creation1.deps)

    # ---

    user_creation2 = CreateUser.new

    assert_same(User, user_creation2.dependencies.repository)
    assert_same(user_creation2.dependencies, user_creation2.deps)

    # ---

    user_creation3 = CreateUser.new(repository: ::Object)

    assert_same(::Object, user_creation3.dependencies.repository)
    assert_same(user_creation3.dependencies, user_creation3.deps)
  end

  test "#dependencies?" do
    user_creation1 = UserCreation.new

    refute_predicate user_creation1, :dependencies?
    refute_predicate user_creation1, :deps?

    # ---

    user_creation2 = CreateUser.new

    assert_predicate user_creation2, :dependencies?
    assert_predicate user_creation2, :deps?
  end

  test "#call when the output is already set" do
    user_creation = UserCreation.new

    user_creation.call(name: nil, email: nil)

    err = assert_raises(Solid::Process::Error) do
      user_creation.call(name: nil, email: nil)
    end

    assert_equal(
      "UserCreation#call already called. " \
      "Use UserCreation#output to access the result or create a new instance to call again.",
      err.message
    )
  end

  test "#inspect" do
    user_creation = UserCreation.new

    assert_equal("#<UserCreation dependencies=nil input=nil output=nil>", user_creation.inspect)
  end

  test "#method_missing" do
    user_creation1 = UserCreation.new

    user_creation1.call(name: "John Doe", email: "john.doe@email.com", password: "123123123")

    assert_predicate user_creation1, :user_created?

    # ---

    user_creation2 = UserCreation.new

    user_creation2.call(uuid: "", name: nil, email: nil)

    assert_predicate user_creation2, :invalid_input?

    # ---

    assert_raises(NoMethodError) { user_creation1.foo }
    assert_raises(NoMethodError) { user_creation2.foo }
  end

  test "#respond_to_missing?" do
    user_creation1 = UserCreation.new

    refute user_creation1.method(:foo?).call
  end
end