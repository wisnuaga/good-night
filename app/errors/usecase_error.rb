class UsecaseError < StandardError
  class UserNotFoundError < UsecaseError
    def initialize(msg = "User not found")
      super
    end
  end

  class ActiveSleepSessionNotFound < UsecaseError
    def initialize(msg = "No active sleep session found")
      super
    end
  end

  class ActiveSleepSessionAlreadyExists < UsecaseError
    def initialize(msg = "You already have an active sleep session")
      super
    end
  end
end
