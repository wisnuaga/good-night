class UsecaseError < StandardError
  class UserNotFoundError < UsecaseError
    def initialize(msg = "User not found")
      super
    end
  end
end
