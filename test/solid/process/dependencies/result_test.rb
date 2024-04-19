# frozen_string_literal: true

require "test_helper"

class Solid::Process::DependenciesResultTest < ActiveSupport::TestCase
  def setup
    ::User.delete_all
  end

  def user_creation
    [
      -> { UserCreationWithDeps.call(_1) },
      -> { UserCreationWithDeps.new.call(_1) }
    ].sample
  end

  def map_input(data)
    [data, UserCreationWithDeps::Input.new(data)].sample
  end

  test "failure (invalid_dependencies)" do
    result = UserCreationWithDeps.new(repository: Object).call(name: "John", email: "john@email.com", password: "321321321")

    assert_kind_of Solid::Result, result
    assert_kind_of Solid::Failure, result

    assert_predicate result, :invalid_dependencies?

    assert result.is?(:invalid_dependencies)
    assert result.type?(:invalid_dependencies)
    assert result.failure?(:invalid_dependencies)

    assert_equal [:dependencies], result.value.keys

    dependencies = result.value.fetch(:dependencies)

    assert_kind_of UserCreationWithDeps::Dependencies, dependencies

    dependencies.errors.added? :repository, :invalid
  end

  test "success" do
    password = "123123123"

    input = map_input(name: "\tJohn     Doe \n", email: "   JOHN.doe@email.com", password: password)

    result = assert_difference(-> { User.count } => 1) do
      UserCreationWithDeps.new(repository: User).call(input)
    end

    assert_kind_of Solid::Result, result
    assert_kind_of Solid::Success, result

    assert_predicate result, :user_created?

    assert result.is?(:user_created)
    assert result.type?(:user_created)
    assert result.success?(:user_created)

    assert_equal [:user], result.value.keys

    user = result.value.fetch(:user)

    assert_match(TestUtils::UUID_REGEX, user.uuid)
    assert_equal("John Doe", user.name)
    assert_equal("john.doe@email.com", user.email)

    assert BCrypt::Password.new(user.password_digest).is_password?(password)
  end

  test "failure (invalid_input)" do
    input = map_input(name: nil, email: nil, password: nil)

    result = assert_no_difference(-> { User.count }) { user_creation.call(input) }

    assert_kind_of Solid::Result, result
    assert_kind_of Solid::Failure, result

    assert_predicate result, :invalid_input?

    assert result.is?(:invalid_input)
    assert result.type?(:invalid_input)
    assert result.failure?(:invalid_input)

    assert_equal [:input], result.value.keys

    input = result.value[:input]

    assert_kind_of Solid::Input, input
    assert_instance_of UserCreationWithDeps::Input, input

    input.errors.added? :name, :blank
    input.errors.added? :email, :invalid
  end

  test "failure (email_already_taken)" do
    input = map_input(name: "John Doe", email: "john.doe@email.com", password: "123123123")

    user_creation.call(input)

    result = assert_no_difference(-> { User.count }) do
      UserCreationWithDeps.new(UserCreationWithDeps::Dependencies.new(repository: User)).call(input)
    end

    assert_predicate result, :email_already_taken?

    assert result.is?(:email_already_taken)
    assert result.type?(:email_already_taken)
    assert result.failure?(:email_already_taken)
  end
end
