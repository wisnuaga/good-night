module Errors
  class UsecaseError < StandardError; end

  class UserNotFoundError < UsecaseError
    def initialize(msg = "User not found")
      super
    end
  end
end
