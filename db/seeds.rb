# Seed users
users = [
  { name: "Alice" },
  { name: "Bob" },
  { name: "Charlie" },
  { name: "Diana" },
  { name: "Eve" }
]

users.each do |attrs|
  User.find_or_create_by!(name: attrs[:name])
end
