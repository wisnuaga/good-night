class UserRepository
  def find_by_id(id)
    User.find_by(id: id)
  end
end
