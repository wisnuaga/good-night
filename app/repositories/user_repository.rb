class UserRepository
  def find(id)
    User.find_by(id: id)
  end
end
